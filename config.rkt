#lang racket/base
(require aws/s3
         racket/format
         racket/path
         racket/port
         racket/file
         "site/gen-index.rkt")

(provide get-task set-task remove-task
         get-site set-site remove-site
         get-email set-email remove-email
         get-html set-html)

;; ----------------------------------------

(define (make-getter-setter key name-key fields)
  (values
   ;; Getter
   (lambda (s3-bucket name #:force? [force? #f])
     (define (who)
       (string->symbol (regexp-replace #rx"s$" (~a "get-" key) "")))
     (unless (string? s3-bucket)
       (raise-argument-error (who) "string?" s3-bucket))
     (when name-key
       (unless (string? name)
         (raise-argument-error (who) "string?" name)))
     (adjust 'get s3-bucket key name-key
             (hash name-key name)
             force?
             #t))
   ;; Setter
   (lambda (s3-bucket table #:force? [force? #f]  #:skip-html? [skip-html? #f])
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

     (when name-key
       (when (eq? not-there (hash-ref table name-key not-there))
         (error (who)
                "expected a table entry with key `~a`"
                name-key)))

     (void (adjust 'set s3-bucket key name-key
                   table
                   force?
                   skip-html?)))
   ;; Remover
   (lambda (s3-bucket name #:skip-html? [skip-html? #f])
     (define (who)
       (string->symbol (regexp-replace #rx"s$" (~a "remove-" key) "")))
     (unless (string? s3-bucket)
       (raise-argument-error (who) "string?" s3-bucket))
     (unless (string? name)
       (raise-argument-error (who) "string?" name))
     
     (void (adjust 'remove s3-bucket key name-key
                   (hash name-key name)
                   #f
                   skip-html?)))))

(define-values (get-task set-task remove-task)
  (make-getter-setter 'tasks 'name (hash 'name string?
                                         'period exact-nonnegative-integer?)))

(define-values (get-site set-site remove-site)
  (make-getter-setter 'sites 'url (hash 'url string?)))

(define-values (get-email set-email remove-email)
  (make-getter-setter 'emails 'to (hash 'to string?
                                        'on-success? boolean?)))

(define-values (get-html* set-html remove-html*)
  (make-getter-setter 'html #f (hash 'title string?)))
(define (get-html s3-bucket #:force? [force? #f])
  (get-html* s3-bucket #f
             #:force? force?))

;; ----------------------------------------

(define (adjust mode s3-bucket key name-key ht force? skip-html?)
  (parameterize ([s3-region (bucket-location s3-bucket)])
    (define config (get-config s3-bucket force?))
    (define old-list/val (hash-ref config key (and name-key null)))
    (define old-val (if name-key
                        (for/or ([e (in-list old-list/val)])
                          (and (equal? (hash-ref ht name-key)
                                       (hash-ref e name-key))
                               e))
                        old-list/val))
    (case mode
      [(get) old-val]
      [(set remove)
       (define rest-list (and name-key
                              (for/list ([e (in-list old-list/val)]
                                         #:unless (equal? (hash-ref ht name-key)
                                                          (hash-ref e name-key)))
                                e)))
       (define new-list/val (if name-key
                                (case mode
                                  [(set) (cons ht rest-list)]
                                  [(remove) rest-list])
                                ht))
       (unless (equal? new-list/val old-list/val)
         (define new-config (hash-set config key new-list/val))
         (define index-html (call-with-output-bytes (lambda (o) (gen-index new-config o))))
         (put-config s3-bucket new-config)
         (unless skip-html?
           (put-web-file s3-bucket "index.html" index-html)
           (for ([support-file (in-list support-files)])
             (put-web-file s3-bucket
                           (path->string (file-name-from-path support-file))
                           (file->bytes support-file)))))])))

;; ----------------------------------------

(define (get-config s3-bucket force?)
  (with-handlers ([exn:fail? (lambda (exn)
                               (log-error "config failure: ~s" (exn-message exn))
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

(define (put-web-file s3-bucket name content)
  (define bucket+path (format "~a/~a" s3-bucket name))
  (put/bytes bucket+path
             content
             (case (filename-extension name)
               [(#"html" #"htm") "text/html; charset=utf-8"]
               [(#"txt") "text/plain; charset=utf-8"]
               [(#"js") "text/javascript"]
               [(#"css") "text/css"]
               [else "application/octet-stream"]))
  (put-acl bucket+path #f (hash 'x-amz-acl "public-read"))
  (void))
