;;;; packages.lisp — png-pure

(defpackage #:png-pure
  (:use #:cl)
  (:documentation
   "png-pure — a pure Common Lisp PNG encoder.  The inverse of pigment's PNG decoder.")
  (:export
   #:encode-png          ; (pixels width height &key channels) -> octet vector
   #:write-png-file))    ; (pixels width height path &key channels) -> path
