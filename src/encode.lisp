;;;; encode.lisp — PNG encoder.
;;;;
;;;; Input is a row-major, 8-bit-per-sample, interleaved octet vector of
;;;; WIDTH*HEIGHT*CHANNELS bytes, top row first.  CHANNELS selects the colour type:
;;;;   1 -> greyscale (0)       2 -> grey+alpha (4)
;;;;   3 -> RGB (2)             4 -> RGBA (6)
;;;; Every scanline is written with filter type 0 (None).  The IDAT stream is
;;;; compressed by cram:zlib-compress.

(in-package #:png-pure)

(defparameter +signature+ '(137 80 78 71 13 10 26 10))

(defun %u32be-bytes (v)
  (list (ldb (byte 8 24) v) (ldb (byte 8 16) v) (ldb (byte 8 8) v) (ldb (byte 8 0) v)))

(defun %colour-type (channels)
  (ecase channels (1 0) (2 4) (3 2) (4 6)))

(defun %octets (n) (make-array n :element-type '(unsigned-byte 8)))

(defun %chunk (out type data)
  "Append a chunk (TYPE is a 4-char string, DATA an octet vector) to adjustable OUT."
  (let* ((tbytes (map '(vector (unsigned-byte 8)) #'char-code type))
         (payload (concatenate '(vector (unsigned-byte 8)) tbytes data)))
    (dolist (b (%u32be-bytes (length data))) (vector-push-extend b out))
    (loop for b across payload do (vector-push-extend b out))
    (dolist (b (%u32be-bytes (cram:crc32 payload))) (vector-push-extend b out))))

(defun %filtered-scanlines (pixels width height channels)
  "Prefix each row of PIXELS with a filter-type byte of 0."
  (let* ((rowb (* width channels))
         (stride (1+ rowb))
         (raw (%octets (* height stride))))
    (dotimes (y height raw)
      (let ((ri (* y stride)) (base (* y rowb)))
        (setf (aref raw ri) 0)
        (replace raw pixels :start1 (1+ ri) :start2 base :end2 (+ base rowb))))))

(defun encode-png (pixels width height &key (channels 3))
  "Encode PIXELS (octet vector, WIDTH*HEIGHT*CHANNELS bytes) as a PNG; return the octets."
  (check-type width (integer 1))
  (check-type height (integer 1))
  (unless (member channels '(1 2 3 4))
    (error "png-pure: CHANNELS must be 1, 2, 3 or 4, not ~S" channels))
  (let ((need (* width height channels)))
    (unless (and (typep pixels '(simple-array (unsigned-byte 8) (*)))
                 (= (length pixels) need))
      (error "png-pure: PIXELS must be an (unsigned-byte 8) vector of ~D bytes" need)))
  (let* ((raw (%filtered-scanlines pixels width height channels))
         (idat (cram:zlib-compress raw))
         (out (make-array 0 :element-type '(unsigned-byte 8) :adjustable t :fill-pointer 0))
         (ihdr (coerce (append (%u32be-bytes width) (%u32be-bytes height)
                               (list 8 (%colour-type channels) 0 0 0))
                       '(vector (unsigned-byte 8)))))
    (dolist (b +signature+) (vector-push-extend b out))
    (%chunk out "IHDR" ihdr)
    (%chunk out "IDAT" (coerce idat '(vector (unsigned-byte 8))))
    (%chunk out "IEND" (%octets 0))
    (coerce out '(simple-array (unsigned-byte 8) (*)))))

(defun write-png-file (pixels width height path &key (channels 3))
  "Encode PIXELS as a PNG and write it to PATH.  Returns PATH."
  (let ((bytes (encode-png pixels width height :channels channels)))
    (with-open-file (s path :direction :output :element-type '(unsigned-byte 8)
                            :if-exists :supersede :if-does-not-exist :create)
      (write-sequence bytes s))
    path))
