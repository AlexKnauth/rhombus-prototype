#lang racket/base

(require ffi/unsafe)

(define-cpointer-type _locale)

(define newlocale
  (get-ffi-obj 'newlocale #f
               (_fun [_int = 2]
                     [_string = "en_US.UTF-8"]
                     [_pointer = #f]
                     ->
                     _locale)))

(define loc (newlocale))

(define wcwidth_l
  (get-ffi-obj 'wcwidth_l #f  (_fun _wchar _locale -> _int)))

(define (char-width c)
  (wcwidth_l (char->integer c) loc))
(char-width #\newline)
(char-width #\ )
(char-width #\a)
(char-width #\W)
(char-width #\λ)
(char-width #\〄)
(char-width #\苹)
(char-width #\⟶)
(char-width #\tab)

