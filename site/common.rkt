#lang racket/base

(provide get-from-site)

(require racket/port
         net/url)

(define (get-from-site file)
  (port->string (get-pure-port (string->url (string-append "https://heartbeat.racket-lang.org/" file)))
                #:close? #t))
