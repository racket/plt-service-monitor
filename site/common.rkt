#lang racket/base

(provide get-from-site
         get-config
         format-file)

(require racket/port
         net/url)

(define (get-from-site file src-url)
  (port->string
   (get-pure-port
    (combine-url/relative (string->url src-url) file))
   #:close? #t))

(define (get-config url)
  (read (open-input-string (get-from-site "config.rktd" url))))

(define (format-file id)
  (string-append id "-beat.json"))
