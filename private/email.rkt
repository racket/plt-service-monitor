#lang racket/base
(require net/smtp
         net/sendmail
         net/head
         racket/tcp
         openssl)

(provide send-email)

(define (send-email config tos subject content)
  (define lines (regexp-split #rx"\n" content))
  (define (get-opt key default)
    (hash-ref config key default))
  (define from (get-opt 'from (car tos)))
  (cond
   [(get-opt 'server #f)
    (let* ([smtp-connect (get-opt 'connect 'plain)]
           [port-no (get-opt 'port 
                             (case smtp-connect
                               [(plain) 25]
                               [(ssl) 465]
                               [(tls) 587]
                               [else (error "bad connect mode: " smtp-connect)]))])
      (parameterize ([smtp-sending-server (or (get-opt 'sending-server #f)
                                              (smtp-sending-server))])
        (smtp-send-message (get-opt 'server #f)
                           #:port-no port-no
                           #:tcp-connect (if (eq? 'ssl smtp-connect)
                                             (lambda (server port)
                                               (ssl-connect server port 'secure))
                                             tcp-connect)
                           #:tls-encode (and (eq? 'tls smtp-connect)
                                             (lambda (i o
                                                        #:mode mode
                                                        #:encrypt encrypt ; dropped
                                                        #:close-original? close?)
                                               (ports->ssl-ports i o
                                                                 #:mode mode
                                                                 #:close-original? close?)))
                           #:auth-user (get-opt 'user #f)
                           #:auth-passwd (get-opt 'password #f)
                           from
                           tos
                           (standard-message-header from
                                                    tos
                                                    null
                                                    null
                                                    subject)
                           lines)))]
   [else
    (send-mail-message from
                       subject	 	 	 	 
                       tos
                       null
                       null
                       lines)]))

