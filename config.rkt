#lang racket/base
(require aws/s3)

(provide add-task
         remove-task
         add-site
         remove-site
         add-email
         remove-email)

;; ----------------------------------------

(define (add-task s3-bucket task-name
                     #:force? [force? #f])
  (adjust s3-bucket 'tasks (hash 'name task-name) 'name
          #:force? force?))

(define (remove-task s3-bucket task-name)
  (adjust s3-bucket 'tasks (hash 'name task-name) 'name
          #:add? #f
          #:force? #f))


(define (add-site s3-bucket url-str
                  #:force? [force? #f])
  (adjust s3-bucket 'sites (hash 'url url-str) 'url
          #:force? force?))

(define (remove-site s3-bucket url-str)
  (adjust s3-bucket 'sites (hash 'url url-str) 'url
          #:add? #f
          #:force? #f))

(define (add-email s3-bucket addr
                  #:force? [force? #f])
  (adjust s3-bucket 'emails (hash 'to addr) 'to
          #:force? force?))

(define (remove-email s3-bucket addr)
  (adjust s3-bucket 'emails (hash 'to addr) 'to
          #:add? #f
          #:force? #f))

;; ----------------------------------------

(define (adjust s3-bucket key ht name-key
                #:add? [add? #t]
                #:force? force?)
  (config s3-bucket (list key)
          (lambda (old-val)
            (define old-list
              (for/list ([e (in-list (or old-val null))]
                         #:unless (equal? (hash-ref ht name-key)
                                          (hash-ref e name-key)))
                e))
            (if add?
                (cons ht old-list)
                old-list))
          #:force? force?))

;; ----------------------------------------

(define (config s3-bucket path adjust-value
                #:force? [force? #f])
  (define config
    (with-handlers ([exn:fail? (lambda (exn)
                                 (if force?
                                     (hash)
                                     (raise exn)))])
      (read
       (open-input-bytes
        (get/bytes (format "~a/config.rktd" s3-bucket))))))
  (define (update ht path)
    (cond
     [(null? path) (adjust-value ht)]
     [else
      (hash-set ht (car path)
                (update (hash-ref ht (car path)
                                  (if (null? (cdr path))
                                      #f
                                      (hash)))
                        (cdr path)))]))
  (define new-config (update config path))
  (void (put/bytes (format "~a/config.rktd" s3-bucket)
                   (string->bytes/utf-8 (format "~s" new-config))
                   "application/data")))
