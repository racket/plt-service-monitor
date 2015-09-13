#lang racket/base
(require racket/date
         aws/s3
         json)

(provide beat)

(define (beat s3-bucket service-name
              #:region [region (bucket-location s3-bucket)])
  (parameterize ([s3-region region])
    (define now (current-seconds))
    (define now-str (parameterize ([date-display-format 'rfc2822])
                      (date->string (seconds->date now #f) #t)))
    (void (put/bytes (format "~a/~a-beat.json" s3-bucket service-name)
                     (jsexpr->bytes (hash 'seconds now
                                          'date now-str))
                     "application/json"))))

(module+ main
  (require racket/cmdline)
  (command-line
   #:args
   (s3-bucket service-name)
   (beat s3-bucket service-name)))
