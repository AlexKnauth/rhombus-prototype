#lang racket/base
(require (for-syntax racket/base)
         syntax/parse/pre
         enforest/syntax-local
         "define-arity.rkt"
         "class-primitive.rkt"
         (submod "annotation.rkt" for-class)
         "name-root.rkt"
         "class-parse.rkt"
         (for-template
          (only-in "class-clause-parse.rkt"
                   class-clause-extract
                   method-shape-extract))
         "call-result-key.rkt"
         "realm.rkt"
         "pack.rkt")

(provide (for-space rhombus/namespace
                    class_meta))

(module+ for-class
  (provide class-expand-data))

(module+ for-static-info
  (provide (for-syntax get-class-data-static-infos)))

(define-name-root class_meta
  #:fields
  (Info
   [describe class_meta.describe]))

(define/method (class_meta.Info.lookup info key)
  (lookup who info key))

(define-primitive-class Info class-data
  #:new
  #:just-annot
  #:fields
  ()
  #:properties
  ()
  #:methods
  ([lookup class_meta.Info.lookup]))

(define/arity (class_meta.describe id)
  #:static-infos ((#%call-result #,(get-class-data-static-infos)))
  (describe who id))

(struct class-expand-data class-data (stx accum-stx))
(struct class-describe-data class-data (desc private-idesc))

(define (class-expand-data-internal-info-name data)
  (syntax-parse (class-expand-data-stx data)
    [(_ base-stx scope-stx
        reflect-name
        . _)
     #'reflect-name]))

(define (class-expand-data-internal-info-fields data)
  (syntax-parse (class-expand-data-stx data)
    [(_ base-stx scope-stx
        reflect-name name name-extends tail-name
        constructor-field-names
        constructor-field-keywords
        constructor-field-defaults
        constructor-field-mutables
        constructor-field-privates
        . _)
     (values #'constructor-field-names
             #'constructor-field-keywords
             #'constructor-field-defaults
             #'constructor-field-mutables
             #'constructor-field-privates)]))

(define (lookup who info key)
  (unless (class-data? info)
    (raise-annotation-failure who info "class_meta.Info"))
  (unless (symbol? key)
    (raise-annotation-failure who key "Symbol"))
  (case key
    [(name)
     (cond
       [(class-expand-data? info)
        (class-expand-data-internal-info-name info)]
       [else
        (class-desc-id (class-describe-data-desc info))])]
    [(extends implements implements_visibilities internal_names
              uses_default_constructor uses_default_binding uses_default_annotation
              method_names method_arities method_visibilities
              property_names property_arities property_visibilities)
     (cond
       [(class-expand-data? info)
        (define r (class-clause-extract who (class-expand-data-accum-stx info) key))
        (case key
          [(uses_default_constructor uses_default_binding uses_default_annotation)
           (null? r)]
          [else r])]
       [else
        (define desc (class-describe-data-desc info))
        (case key
          [(internal_names) null]
          [(extends)
           (define super (class-desc-super-id desc))
           (if super (list super) null)]
          [(uses_default_constructor)
           (not (class-desc-custom-constructor? desc))]
          [(uses_default_binding)
           (not (class-desc-custom-binding? desc))]
          [(uses_default_annotation)
           (not (class-desc-custom-annotation? desc))]
          [(implements implements_visibilities)
           (define idesc (class-describe-data-private-idesc info))
           (define (vis v l)
             (if (eq? key 'implements_visibilities)
                 (for/list ([x (in-list l)]) v)
                 l))
           (append
            (if idesc
                (vis 'private (syntax->list (class-internal-desc-private-interfaces idesc)))
                null)
            (vis 'public (syntax->list (objects-desc-interface-ids desc))))]
          [else
           (define idesc (class-describe-data-private-idesc info))
           (method-shape-extract (objects-desc-method-shapes desc)
                                 (if idesc (class-internal-desc-private-methods idesc) null)
                                 (if idesc (class-internal-desc-private-properties idesc) null)
                                 key)])])]
    [(field_names field_keywords field_mutabilities field_visibilities field_constructives)
     (cond
       [(class-expand-data? info)
        (define-values (constructor-names
                        constructor-keywords
                        constructor-defaults
                        constructor-mutables
                        constructor-exposes)
          (class-expand-data-internal-info-fields info))
        (case key
          [(field_names)
           (append (syntax->list constructor-names)
                   (class-clause-extract who (class-expand-data-accum-stx info) 'field-names))]
          [(field_keywords)
           (append (map syntax-e (syntax->list constructor-keywords))
                   (map (lambda (n) #f)
                        (class-clause-extract who (class-expand-data-accum-stx info) 'field-names)))]
          [(field_mutabilities)
           (append (for/list ([mutable? (in-list (syntax->list constructor-mutables))])
                     (if (syntax-e mutable?) 'mutable 'immutable))
                   (map syntax-e
                        (class-clause-extract who (class-expand-data-accum-stx info) 'field-mutabilities)))]
          [(field_visibilities)
           (append (for/list ([expose (in-list (syntax->list constructor-exposes))])
                     (syntax-e expose))
                   (map syntax-e
                        (class-clause-extract who (class-expand-data-accum-stx info) 'field-visibilities)))]
          [(field_constructives)
           (append (for/list ([expose (in-list (syntax->list constructor-exposes))]
                              [default (in-list (syntax->list constructor-defaults))])
                     (if (eq? (syntax-e expose) 'public)
                         (if (syntax-e default)
                             'optional
                             'required)
                         'absent))
                   (map (lambda (x) 'absent)
                        (class-clause-extract who (class-expand-data-accum-stx info) 'field-names)))]
          [else (error "internal error: key")])]
       [else
        (define desc (class-describe-data-desc info))
        (define (arg-keyword arg0)
          (let* ([arg0 (if (vector? arg0) (vector-ref arg0 0) arg0)]
                 [arg0 (if (syntax? arg0) (syntax-e arg0) arg0)])
            (define arg (if (box? arg0)
                            (let ([v (unbox arg0)])
                              (if (syntax? v)
                                  (syntax-e v)
                                  v))
                            arg0))
            (if (keyword? arg) arg #f)))
        (define (arg-constructive arg)
          (let* ([arg (if (vector? arg) (vector-ref arg 0) arg)]
                 [arg (if (syntax? arg) (syntax-e arg) arg)])
            (cond
              [(symbol? arg) 'absent]
              [(box? arg) 'optional]
              [else 'required])))
        (cond
          [(not (and (class-describe-data-private-idesc info)
                     (class-desc-all-fields desc)))
           ;; public only
           (case key
             [(field_names) (for/list ([f (in-list (class-desc-fields desc))])
                              (datum->syntax #f (field-desc-name f)))]
             [(field_keywords) (for/list ([f (in-list (class-desc-fields desc))])
                                 (arg-keyword (field-desc-constructor-arg f)))]
             [(field_mutabilities) (for/list ([f (in-list (class-desc-fields desc))])
                                     (if (identifier? (field-desc-mutator-id f))
                                         'mutable
                                         'immutable))]
             [(field_visibilities) (for/list ([f (in-list (class-desc-fields desc))])
                                     'public)]
             [(field_constructives)
              (for/list ([f (in-list (class-desc-fields desc))])
                (define arg (syntax-e (field-desc-constructor-arg f)))
                (cond
                  [(symbol? arg) 'absent]
                  [(box? arg) 'optional]
                  [else 'required]))])]
          [else
           ;; public and private, but not inherited private
           (define all-fields (class-desc-all-fields desc))
           (let loop ([all-fields all-fields]
                      [fields (class-desc-fields desc)]
                      [inherited (class-desc-inherited-field-count desc)])
             (cond
               [(null? all-fields) '()]
               [(symbol? (car all-fields))
                (define arg (field-desc-constructor-arg (car fields)))
                (cons (case key
                        [(field_names) (datum->syntax #f (car all-fields))]
                        [(field_keywords) (arg-keyword arg)]
                        [(field_constructives) (arg-constructive arg)]
                        [(field_mutabilities) (if (identifier? (field-desc-mutator-id (car fields)))
                                                  'mutable
                                                  'immutable)]
                        [(field_visibilities) 'public])
                      (loop (cdr all-fields)
                            (cdr fields)
                            (sub1 inherited)))]
               [(positive? inherited)
                (loop (cdr all-fields) fields (sub1 inherited))]
               [(or (identifier? (cdar all-fields))
                    (and (vector? (cdar all-fields))
                         (identifier? (vector-ref (cdar all-fields) 0))))
                (cons (case key
                        [(field_names) (datum->syntax #f (caar all-fields))]
                        [(field_keywords) #f]
                        [(field_constructives) 'absent]
                        [(field_mutabilities) (if (identifier? (cdar all-fields))
                                                  'mutable
                                                  'immutable)]
                        [(field_visibilities) 'private])
                      (loop (cdr all-fields)
                            fields
                            0))]
               [else
                (define arg (cdar all-fields))
                (cons (case key
                        [(field_names) (datum->syntax #f (caar all-fields))]
                        [(field_keywords) (arg-keyword arg)]
                        [(field_constructives) (arg-constructive arg)]
                        [(field_mutabilities) (if (vector? arg) 'mutable 'immutable)]
                        [(field_visibilities) 'private])
                      (loop (cdr all-fields)
                            fields
                            0))]))])])]
    [else
     (raise-arguments-error* who rhombus-realm
                             "unrecognized key symbol"
                             "symbol" key)]))

(define (unpack-identifier who id-in)
  (define id (unpack-term/maybe id-in))
  (unless (identifier? id)
    (raise-annotation-failure who id-in "Identifier"))
  id)

(define (describe who id-in)
  (define id (unpack-identifier who id-in))
  (define desc (syntax-local-value* (in-class-desc-space id) class-desc-ref))
  (define idesc (and (not desc)
                     (syntax-local-value* (in-class-desc-space id) class-internal-desc-ref)))
  (unless (or desc idesc)
    (raise-arguments-error* who rhombus-realm
                            "not bound as a class name or internal name"
                            "identifier" id))
  (cond
    [desc
     (class-describe-data desc #f)]
    [else
     (define desc (syntax-local-value* (in-class-desc-space (class-internal-desc-id idesc)) class-desc-ref))
     (unless desc
       (raise-arguments-error* who rhombus-realm
                               "could not find class description for internal class name"
                               "internal name" id))
     (class-describe-data desc idesc)]))
