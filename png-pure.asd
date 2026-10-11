;;;; png-pure.asd — a pure Common Lisp PNG encoder.
(asdf:defsystem :png-pure
  :description "Pure-CL PNG encoder: 8-bit greyscale, grey+alpha, RGB and RGBA scanlines
to a PNG byte vector or file.  The DEFLATE/zlib compression, CRC-32 and Adler-32 come
from cram; no FFI, no other dependency.  The decoder lives in pigment."
  :license "MIT"
  :depends-on (:cram)
  :components ((:module "src"
                :serial t
                :components ((:file "packages")
                             (:file "encode")))))
