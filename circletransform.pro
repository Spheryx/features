;+
; NAME:
;    circletransform
;
; PURPOSE:
;    Performs an orientational alignment transform,
;    which is useful for detecting circular features in an image.
;
; CATEGORY:
;    Image analysis, feature detection
;
; CALLING SEQUENCE:
;    b = circletransform(a)
;
; INPUTS:
;    a: [nx,ny] image data
;
; KEYWORD PARAMETERS:
;    deinterlace: if set to an odd number, then only perform
;        transform on odd field of an interlaced image.
;        If set to an even number, transform even field.
;        Default: Not set or set to zero: transform entire frame.
;
; OUTPUTS:
;    b: [nx,ny] circle transform.  Peaks correspond to estimated
;        centers of circular features in a.
;
; PROCEDURE:
;    Compute the gradient of the image.  The local gradient at each
;    pixel defines a line along which the center of a circle may
;    lie.  Cast votes for pixels along the line in the transformed
;    image.  The pixels in the transformed image with the most votes
;    correspond to the centers of circular features in the original
;    image.
;
; REFERENCES:
; 1. F. C. Cheong, B. Sun, R. Dreyfus, J. Amato-Grill, K. Xiao, L. Dixon
;    & D. G. Grier, "Flow visualization and flow cytometry with
;    holographic video microscopy," Optics Express 17,
;    13071-13079 (2009)
;
; 2. B. J. Krishnatreya & D. G. Grier, "Fast feature identification
;    for holographic tracking: The orientation alignment transform,"
;    preprint (2013)
;
; EXAMPLE:
;    IDL> b = circletransform(a)
;
; MODIFICATION HISTORY:
; 10/07/2008 Written by David G. Grier, New York University.
; 01/26/2009 DGG Added DEINTERLACE keyword. Gracefully handle
;    case when original image has no features. Documentation cleanups.
; 02/03/2009 DGG Replaced THRESHOLD keyword with NOISE.
; 06/10/2010 DGG Documentation fixes.  Added COMPILE_OPT.
; 05/02/2012 DGG Updated keyword parsing.  Formatting.
; 06/24/2012 DGG Streamlined index range checking in inner loop
;    to improve efficiency.
; 07/16/2012 DGG IMPORTANT: Center results on pixels, not on vertices!
;    Use array_indices for clarity.
; 11/10/2012 DGG Default range should be an integer.
;    Returned array should be cast to integer, not float
; 11/23/2012 DGG Use Savitzky-Golay estimate for derivative.
;    Eliminate SMOOTHFACTOR parameter.  Upgrade parameter checking.
; 11/25/2012 DGG Limit search range by uncertainty in gradient
;    direction.  Remove RANGE keyword.
; 11/30/2012 DGG Optionally return mean range as RANGE keyword.
; 01/16/2013 DGG estimate noise with MAD() by default.
; 01/24/2013 DGG correct test for deinterlace = 0.
; 02/09/2013 DGG use savgol2d() to compute derivatives.
;    Displace by half a pixel to center, not a whole pixel.
; 02/17/2013 DGG RANGE is the median range of voting pixels, not the
;    mean.
; 03/04/2013 DGG shift by +1 rather than by +0.5.  Limit range if
;    noise is very small.
; 03/17/2013 DGG calculate coordinates explicitly rather than using
;    array_indices, which turns out to be slow.  More efficient array
;    indexing.  No more need to shift pixels for alignment.
; 03/27/2013 DGG eliminate repetitive operations in loops.
; 05/13/2013 DGG suppress borders, which are over-counted.
; 10/04/2013 DGG and Mark Hannel: fix boundary cropping.
; 10/22/2013 DGG added UNCERTAINTY keyword.
; 12/03/2013 DGG Major overhaul: Field-theoretic implementation of
;    the voting algorithm yields factor of 10 speed-up.
; 12/13/2013 DGG use EXTRA for compatibility with previous version.
; 02/14/2014 DGG better handling of divergence at k = 0.
; 07/06/2014 DGG subtle fix for odd dimensions.
;
; Copyright (c) 2008-2014 David G. Grier and Mark Hannel
;-

function circletransform, a_, $
                          deinterlace = deinterlace, $
                          _extra = ex

COMPILE_OPT IDL2

umsg = 'USAGE: b = circletransform(a)'

if ~isa(a_, /number, /array) then begin
   message, umsg, /inf
   return, -1
endif
if size(a_, /n_dimensions) ne 2 then begin
   message, umsg, /inf
   message, 'A must be a two-dimensional numeric array', /inf
   return, -1
endif

sz = size(a_, /dimensions)
nx = sz[0]
ny = sz[1]

dodeinterlace = isa(deinterlace, /scalar, /number) ? deinterlace gt 0 : 0
if dodeinterlace then begin
   n0 = deinterlace mod 2
   a = float(a_[*, n0:*:2])
   ny = n_elements(a[0, *])
endif else $
   a = float(a_)

; gradient of image
; \nabla a = (dadx, dady)
dx = savgol2d(7, 3, dx = 1)
dadx = convol(a, dx, /edge_truncate)
dady = convol(a, transpose(dx), /edge_truncate)
if dodeinterlace then dady /= 2.

; orientational order parameter
; psi = |\nabla a|^2 \exp(i 2 \theta)
psi = dcomplex(dadx, dady)
psi *= psi

; Fourier transform of the orientational alignment kernel:
; K(k) = e^(-2 i \theta) / k
kx = rebin(findgen(nx)/nx - 0.5 * (1. - (nx mod 2)/float(nx)), nx, ny, /sample)
ky = rebin(findgen(1, ny)/ny - 0.5 * (1. - (ny mod 2)/float(ny)), nx, ny, /sample)
if dodeinterlace then ky /= 2.
k = sqrt(kx^2 + ky^2) > 0.001
ker = (dcomplex(kx, -ky))^2 / k^3

; convolve orientational order parameter with
; orientational alignment kernel using
; Fourier convolution theorem
psi = fft(psi, -1, /center, /overwrite)
psi = fft(psi*ker, 1, /center, /overwrite)

; intensity of convolution identifies rotationally
; symmetric centers
return, real_part(psi*conj(psi))
end
