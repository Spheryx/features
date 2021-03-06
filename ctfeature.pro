;+
; NAME:
;    ctfeature
;
; PURPOSE:
;    Identify ring-like features in images
;
; CATEGORY:
;    Image analysis, feature detection
;
; CALLING SEQUENCE:
;    f = ctfeature(a)
;
; INPUTS:
;    a: two-dimensional image data
;
; KEYWORD PARAMETERS:
;    threshold: threshold for detecting features
;        Default: estimated from A.
;
;    pickn: number of features to seek, brightest first
;        Default: all
;
;    count: number of features returned.
;
; KEYWORD FLAGS:
;    deinterlace: Set to an even number to find features
;        in the even field, odd in the odd.
;
;    quiet: If set, do not print informational messages.
;
; OUTPUTS:
;    f: [2,npts] array of feature coordinates
;
; PROCEDURE:
;    CT2 transforms ring-like features in an image into
;        bright features on a dark background.
;    FASTFEATURE locates these bright features.
;
; MODIFICATION HISTORY:
; 10/15/2012 Written by David G. Grier, New York University
; 11/10/2012 DGG Added QUIET keyword.  Changed default smooth factor
;   from 3 to 5.  Cast threshold to an integer.
; 11/23/2012 DGG Updated for consistency with CIRCLETRANSFORM.
;   Removed SMOOTHFACTOR parameter.
; 11/25/2012 DGG Removed NOISE and RANGE parameters.
; 12/21/2012 DGG Pass NOISE estimate to CIRCLETRANSFORM to take
;   advantage of new range-estimation code.
; 01/16/2013 DGG Use RANGE from CIRCLETRANSFORM to estimate threshold.
; 03/19/2013 DGG Smooth result of circletransform to suppress spurious
;   features.
; 05/12/2013 DGG Only keep features with 9 pixels or more.  No need to
;   smooth.
; 10/22/2013 DGG Default threshold is SNR above random hits at range
;   provided by circletransform.  Added SNR keyword.
; 12/04/2013 DGG Updated for new version of circletransform.
; 12/13/2013 DGG Use EXTRA for compatibility with older versions
;
; Copyright (c) 2012-2013 David G. Grier
;-
function ctfeature, a, $
                    ct = ct, $
                    threshold = threshold, $
                    pickn = pickn, $
                    count = count, $
                    deinterlace = deinterlace, $
                    quiet = quiet, $
                    _extra = ex

COMPILE_OPT IDL2

umsg = 'USAGE: f = ctfeature(a)'

if n_params() ne 1 then begin
   message, umsg, /inf
   return, -1
endif

noprint = keyword_set(quiet)

; Find candidate features ...
;; transform ring-like patterns into spots
ct = circletransform(a, deinterlace = deinterlace)

;; estimate threshold for feature detection
if ~isa(threshold, /number, /scalar) then begin
   npts = n_elements(ct)
   mb = total(ct)/npts
   sb = sqrt(total((ct - mb)^2)/(npts - 1.))
   threshold = mb + 3.*sb
endif

;; centers of spots are estimates for particle centers: (xp, yp)
p = fastfeature(ct, threshold, pickn = pickn, count = count, /npixels) ; find peaks
if count lt 1 then begin
   message, umsg, /inf, noprint = noprint
   message, 'no features found above threshold = '+strtrim(threshold, 2), /inf, noprint = noprint
   return, -1
endif
w = where(p[2, *] ge 9, count)
if count lt 1 then begin
   message, umsg, /inf, noprint = noprint
   message, 'no 8-pixel features found above threshold = '+strtrim(threshold, 2), /inf, $
            noprint = noprint
   return, -1
endif
p = p[*, w]

;; scale y coordinate in deinterlaced images
if (isa(deinterlace, /number, /scalar)) ? deinterlace gt 0 : 0 then $
   p[1, *] =  2.*p[1, *] + (deinterlace mod 2)

return, p
end
