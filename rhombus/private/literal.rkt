#lang racket/base
(require (for-syntax racket/base
                     syntax/parse
                     shrubbery/print)
         "binding.rkt"
         "parse.rkt")

(provide literal-infoer)

(define-syntax (literal-infoer stx)
  (syntax-parse stx
    [(_ static-infos datum)
     (binding-info (shrubbery-syntax->string #'datum)
                   #'literal
                   #'static-infos
                   #'()
                   #'literal-matcher
                   #'literal-bind-nothing
                   #'datum)]))

(define-syntax (literal-matcher stx)
  (syntax-parse stx
    [(_ arg-id datum IF success fail)
     #'(IF (equal? arg-id (quote datum))
           success
           fail)]))

(define-syntax (literal-bind-nothing stx)
  (syntax-parse stx
    [(_ arg-id datum)
     #'(begin)]))
