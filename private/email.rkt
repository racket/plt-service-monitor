#lang racket/base
(require net/smtp
         net/sendmail
         net/head)

(provide send-email)

(define (send-email smtp-server tos
                    subject content
                    #:from [from (car tos)])
  (define lines (regexp-split #rx"\n" content))
  (cond
   [smtp-server
    (smtp-send-message smtp-server
                       from
                       tos
                       (standard-message-header from
                                                tos
                                                null
                                                null
                                                subject)
                       lines)]
   [else
    (send-mail-message from
                       subject	 	 	 	 
                       tos
                       null
                       null
                       lines)]))

