#lang agile

(define (port-char-width c)
  (parameterize [(port-count-lines-enabled #true)]
    (define in (open-input-string (string c)))
    (read-char in)
    (define-values [ln col pos] (port-next-location in))
    (close-input-port in)
    col))

(port-char-width #\newline)
(port-char-width #\ )
(port-char-width #\a)
(port-char-width #\W)
(port-char-width #\λ)
(port-char-width #\〄)
(port-char-width #\苹)
(port-char-width #\⟶)
(port-char-width #\tab)
