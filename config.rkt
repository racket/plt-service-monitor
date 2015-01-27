#lang racket/base
(require aws/s3
         racket/format)

(provide get-task set-task remove-task
         get-site set-site remove-site
         get-email set-email remove-email)

;; ----------------------------------------

(define (make-getter-setter key name-key fields)
  (values
   ;; Getter
   (lambda (s3-bucket name #:force? [force? #f])
     (define (who)
       (string->symbol (regexp-replace #rx"s$" (~a "get-" key) "")))
     (unless (string? s3-bucket)
       (raise-argument-error (who) "string?" s3-bucket))
     (unless (string? name)
       (raise-argument-error (who) "string?" name))
     (adjust 'get s3-bucket key name-key
             (hash name-key name)
             force?))
   ;; Setter
   (lambda (s3-bucket table #:force? [force? #f])
     (define (who)
       (string->symbol (regexp-replace #rx"s$" (~a "set-" key) "")))
     (unless (string? s3-bucket)
       (raise-argument-error (who) "string?" s3-bucket))
     (unless (hash? table)
       (raise-argument-error (who) "hash?" table))
     
     (define not-there (gensym))
     (for ([(key pred) (in-hash fields)])
       (define v (hash-ref table key not-there))
       (unless (eq? v not-there)
         (unless (pred v)
           (error (who)
                  "bad value for table's `~a` field"
                  key))))
     
     (for ([key (in-hash-keys table)])
       (unless (hash-ref fields key #f)
         (error (who)
                "unexpected key `~a` in table"
                key)))
     
     (when (eq? not-there (hash-ref table name-key not-there))
       (error (who)
              "expected a table entry with key `~a`"
              name-key))
     
     (void (adjust 'set s3-bucket key name-key
                   table
                   force?)))
   ;; Remover
   (lambda (s3-bucket name)
     (define (who)
       (string->symbol (regexp-replace #rx"s$" (~a "remove-" key) "")))
     (unless (string? s3-bucket)
       (raise-argument-error (who) "string?" s3-bucket))
     (unless (string? name)
       (raise-argument-error (who) "string?" name))
     
     (void (adjust 'remove s3-bucket key name-key
                   (hash name-key name)
                   #f)))))

(define-values (get-task set-task remove-task)
  (make-getter-setter 'tasks 'name (hash 'name string?
                                         'period exact-nonnegative-integer?)))

(define-values (get-site set-site remove-site)
  (make-getter-setter 'sites 'url (hash 'url string?)))

(define-values (get-email set-email remove-email)
  (make-getter-setter 'emails 'to (hash 'to string?
                                        'on-success? boolean?)))
   
;; ----------------------------------------

(define (adjust mode s3-bucket key name-key ht force?)
  (define config (get-config s3-bucket force?))
  (define old-list (hash-ref config key null))
  (define old-val (for/first ([e (in-list old-list)])
                    (and (equal? (hash-ref ht name-key)
                                 (hash-ref e name-key))
                         e)))
  (case mode
   [(get) old-val]
   [(set remove)
    (define rest-list (for/list ([e (in-list old-list)]
                                 #:unless (equal? (hash-ref ht name-key)
                                                  (hash-ref e name-key)))
                        e))
    (define new-list (case mode
                       [(set) (cons ht rest-list)]
                       [(remove) rest-list]))
    (unless (equal? new-list old-list)
      (put-config s3-bucket (hash-set config key new-list)))]))

;; ----------------------------------------

(define (get-config s3-bucket force?)
  (with-handlers ([exn:fail? (lambda (exn)
                               (if force?
                                   (hash)
                                   (raise exn)))])
    (read
     (open-input-bytes
      (get/bytes (format "~a/config.rktd" s3-bucket))))))

(define (put-config s3-bucket new-config)
  (void (put/bytes (format "~a/config.rktd" s3-bucket)
                   (string->bytes/utf-8 (format "~s\n" new-config))
                   "application/data")))
