#lang racket/base

(require racket/math racket/class racket/draw)
(module+ test
  (require rackunit))

;; string-width : String -> Natural
(define (string-width s)
  (define-values [w h b v]
    (send (new bitmap-dc% [bitmap (make-object bitmap% 1 1)])
          get-text-extent
          s
          (make-object font% 2 "Unifont" 'modern)))
  (exact-ceiling w))

(module+ test
  (check-equal? (string-width "\n") 0)
  (check-equal? (string-width " ") 1)
  (check-equal? (string-width "a") 1)
  (check-equal? (string-width "W") 1)
  (check-equal? (string-width "λ") 1)
  (check-equal? (string-width "τ") 1)
  (check-equal? (string-width "⟶") 2)
  (check-equal? (string-width "〄") 2)
  (check-equal? (string-width "苹") 2)
  (check-equal? (string-width "\t") 8))
