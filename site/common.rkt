#lang racket/base

(provide get-from-site
         get-config
         format-file)

(require racket/port
         net/url)

(define (get-from-site file)
  (port->string
   (get-pure-port
    (string->url (string-append "https://heartbeat.racket-lang.org/" file)))
   #:close? #t))

(define (get-config)
  (read (open-input-string (get-from-site "config.rktd"))))

(define (format-file id)
  (string-append id "-beat.json"))
