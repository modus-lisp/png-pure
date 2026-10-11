;;;; roundtrip.lisp — encode with png-pure, decode with pigment, compare pixels exactly.
;;;; Also writes sample files for an independent oracle (python zlib/struct).
;;;; Run: sbcl --script png-pure/t/roundtrip.lisp   (exit code 0 = all pass)
(require :asdf)
(let ((root #p"/Users/vinnyfiano/workspace/modus-lisp/"))
  (dolist (d '("cram/" "pigment/" "scribe/" "brotli-pure/" "stencil/" "gesso/" "webp-pure/" "reel/" "png-pure/"))
    (push (merge-pathnames d root) asdf:*central-registry*)))
(asdf:load-system :cram)
(asdf:load-system :png-pure)
(asdf:load-system :pigment)

(defun pattern (w h ch)
  (let ((v (make-array (* w h ch) :element-type '(unsigned-byte 8)))
        (rs (make-random-state t)))
    (dotimes (y h v)
      (dotimes (x w)
        (dotimes (c ch)
          (setf (aref v (+ (* (+ (* y w) x) ch) c))
                (logand 255 (+ (* x (1+ c)) (* y 7) (* c 40)
                               (if (zerop (mod (+ x y) 5)) 0 (random 3 rs))))))))))

(defun to-rgba (px w h ch)
  "Expand PX (CH channels per pixel) to RGBA octets; opaque alpha when absent."
  (let ((out (make-array (* w h 4) :element-type '(unsigned-byte 8))))
    (dotimes (i (* w h) out)
      (flet ((src (c) (aref px (+ (* i ch) c)))
             (dst (c v) (setf (aref out (+ (* i 4) c)) v)))
        (ecase ch
          (1 (dst 0 (src 0)) (dst 1 (src 0)) (dst 2 (src 0)) (dst 3 255))
          (2 (dst 0 (src 0)) (dst 1 (src 0)) (dst 2 (src 0)) (dst 3 (src 1)))
          (3 (dst 0 (src 0)) (dst 1 (src 1)) (dst 2 (src 2)) (dst 3 255))
          (4 (dst 0 (src 0)) (dst 1 (src 1)) (dst 2 (src 2)) (dst 3 (src 3))))))))

(defvar *fails* 0)

(defun check (w h ch)
  (let* ((px (pattern w h ch))
         (bytes (png-pure:encode-png px w h :channels ch))
         (img (pigment:decode-image-bytes bytes "image/png"))
         (ok (and img
                  (= (pigment::img-w img) w)
                  (= (pigment::img-h img) h)
                  (equalp (coerce (pigment::img-rgba img) '(vector (unsigned-byte 8)))
                          (to-rgba px w h ch)))))
    (unless ok (incf *fails*))
    (format t "~&~Dx~D ch=~D bytes=~D pixels-match=~A~%" w h ch (length bytes) ok)))

(check 1 1 3)
(check 37 23 1)
(check 64 64 2)
(check 200 90 3)
(check 33 17 4)
(check 1 300 3)
(check 300 1 4)
(check 640 360 3)

(dolist (spec '((64 48 3) (1 1 1) (300 200 4)))
  (destructuring-bind (w h ch) spec
    (png-pure:write-png-file (pattern w h ch) w h
      (format nil "/Users/vinnyfiano/workspace/modus-lisp/png-pure/t/out-~Dx~D-c~D.png" w h ch)
      :channels ch)))

(format t "~&FAILURES: ~D~%" *fails*)
(sb-ext:exit :code (if (zerop *fails*) 0 1))
