#lang agile

(require racket/bool
         syntax/srcloc
         data/applicative
         data/monad
         "token.rkt")

;; A Tight is one of:
;;  - Token
;;  - Syntax
;; A Tights is a [Listof Tight]

;; A syntax object that has the "original?" property
;; (borrowed from the scribble reader)
(define orig-stx (read-syntax #f (open-input-string "dummy")))

(define (get-srcloc v)
  (cond [(token? v) (token-srcloc v)]
        [else (build-source-location v)]))
(define (line v) (srcloc-line (get-srcloc v)))
(define (column v) (srcloc-column (get-srcloc v)))
(define ((column>=? c) v) (>= (column v) c))

;; end? : (U Token Eof) (U #f Nat) -> Bool
(define (end? tok lcol)
  (or (eof-object? tok)
      (and (symbol=? (token-type tok) 'parenthesis)
           (member (token-string tok) '(")" "]" "}")))
      (and lcol (<= (srcloc-column (token-srcloc tok)) lcol))))

;; ---------------------------------------------------------

(define peek-line (pure 1))
(define peek-token (pure (token "" 'error (srcloc #f 1 0 1 0))))
(define get-token (pure (token "" 'error (srcloc #f 1 0 1 0))))
(define tight (pure (token "" 'error (srcloc #f 1 0 1 0))))

(define (line-reversed ln acc)
  (do
    [tok <- peek-token]
    (cond
      [(end? tok #f)                     (pure acc)]
      [(string=? (token-string tok) "&") (pure acc)]
      [(string=? (token-string tok) "\\\n")
       (do get-token (line-reversed (add1 ln) acc))]
      [(<= (line tok) ln)
       (do [t <- tight] (line-reversed ln (cons t acc)))]
      [else
       (pure acc)])))

(define (indentation-single)
  (do
    [ln <- peek-line]
    [line-rev <- (line-reversed ln '())]
    (let loop ([line-rev line-rev] [acc '()])
      (pure '()))))

