;;;; ln-invoice.lisp — make a signed BOLT11 invoice with cl-payments, decode it back,
;;;; check the fields, and write its QR code as a PNG (lispqr + png-pure).
;;;; Run: sbcl --script png-pure/t/ln-invoice.lisp [OUT.png]
(load "/Users/vinnyfiano/quicklisp/setup.lisp")
(ql:quickload :lispqr :silent t)
(let ((root "/Users/vinnyfiano/workspace/modus-lisp/"))
  (dolist (d '("cl-payments/" "cl-payments/deps/cl-consensus/" "cl-payments/deps/secp256k1-fast/"
               "cl-payments/deps/cl-transport/" "cl-payments/deps/pagetree/" "cram/" "png-pure/"))
    (push (merge-pathnames d root) asdf:*central-registry*)))
(ql:quickload :cl-payments :silent t)
(asdf:load-system :png-pure)

(defvar *fails* 0)
(defun must (ok label) (unless ok (incf *fails*)) (format t "~&~A ~A~%" (if ok "PASS" "FAIL") label))

(defun hex-bytes (s)
  (let ((v (make-array (/ (length s) 2) :element-type '(unsigned-byte 8))))
    (dotimes (i (length v) v) (setf (aref v i) (parse-integer s :start (* 2 i) :end (+ 2 (* 2 i)) :radix 16)))))

;; Fixed test key (not a real wallet) and hashes, so the output is repeatable.
(defparameter *priv* (secp256k1-fast:bytes-to-int
                      (hex-bytes "e126f68f7eafcc8b74f54d269fe206be715000f94dac067d1c04a8ca3b2db734")))
(defparameter *phash* (hex-bytes "0001020304050607080900010203040506070809000102030405060708090102"))
(defparameter *psecret* (hex-bytes "1111111111111111111111111111111111111111111111111111111111111111"))
(defparameter *amount* 250000000)      ; msat = 250,000 sat
(defparameter *desc* "png-pure test invoice")

(let* ((unsigned (cl-payments.invoice:make-invoice-for
                  :network :signet :amount-msat *amount* :payment-hash *phash*
                  :payment-secret *psecret* :description *desc* :expiry 3600
                  :timestamp 1700000000))
       (signed (cl-payments.invoice:sign-invoice unsigned *priv*))
       (bolt11 (cl-payments.invoice:encode-invoice signed))
       (back (cl-payments.invoice:decode-invoice bolt11)))
  (format t "~&invoice: ~A~%" bolt11)
  (must (string-equal (subseq bolt11 0 4) "lntb") "hrp is lntb (signet)")
  (must (= (cl-payments.invoice:inv-amount-msat back) *amount*) "amount round-trips")
  (must (equalp (cl-payments.invoice:inv-payment-hash back) *phash*) "payment hash round-trips")
  (must (equalp (cl-payments.invoice:inv-payment-secret back) *psecret*) "payment secret round-trips")
  (must (equal (cl-payments.invoice:inv-description back) *desc*) "description round-trips")
  (must (= (cl-payments.invoice:inv-expiry back) 3600) "expiry round-trips")
  (must (equalp (cl-payments.invoice:inv-payee back) (cl-payments.invoice:inv-payee signed))
        "recovered payee matches signing key")
  (must (not (cl-payments.invoice:inv-expired-p back 1700000001)) "not expired at t+1s")
  ;; QR of the bolt11 string, same rendering as qr-show.lisp
  (let* ((out (or (second sb-ext:*posix-argv*)
                  "/Users/vinnyfiano/workspace/modus-lisp/png-pure/t/invoice-qr.png"))
         (m (mare5x.lispqr.encode:encode->matrix bolt11 :ec-level :m))
         (n (array-dimension m 0)) (scale 8) (quiet 4) (side (* scale (+ n (* 2 quiet))))
         (px (make-array (* side side) :element-type '(unsigned-byte 8) :initial-element 255)))
    (dotimes (y side)
      (dotimes (x side)
        (let ((mx (floor (- x (* scale quiet)) scale)) (my (floor (- y (* scale quiet)) scale)))
          (when (and (< -1 mx n) (< -1 my n) (= 1 (aref m my mx)))
            (setf (aref px (+ (* y side) x)) 0)))))
    (png-pure:write-png-file px side side out :channels 1)
    (format t "~&wrote ~A (~Dpx, ~D modules)~%" out side n)))

(format t "~&FAILURES: ~D~%" *fails*)
(sb-ext:exit :code (if (zerop *fails*) 0 1))
