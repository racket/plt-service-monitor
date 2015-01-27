#lang racket/base
(require racket/date
         aws/s3
         json
         net/url
         "private/email.rkt")

(provide take-pulse)

(define (take-pulse s3-bucket
                    #:email? [email? #t]
                    #:smtp-server [smtp-server #f])
  (define now (current-seconds))
  (define config
    (read
     (open-input-bytes
      (get/bytes (format "~a/config.rktd" s3-bucket)))))

  ;; Ping sites
  (define sites (hash-ref config 'sites null))
  (define pings
    (for/list ([site (in-list sites)])
      (define url-str (hash-ref site 'url))
      (define url (string->url url-str))
      (define ok? #f)
      (printf "Pinging site ~a\n" url-str)
      (define t (thread (lambda ()
                          (get-pure-port url)
                          (set! ok? #t))))
      (sync/timeout (hash-ref site 'timeout (hash-ref config 'timeout 30))
                    t)
      ok?))

  ;; Download heartbeats
  (define tasks (hash-ref config 'tasks null))
  (define beats
    (for/list ([task (in-list tasks)])
      (define task-name (hash-ref task 'name))
      (printf "Checking task ~s\n" task-name)
      (with-handlers ([exn? (lambda (exn)
                              (hash 'error
                                    (exn-message exn)))])
        (define beat
          (bytes->jsexpr
           (get/bytes (format "~a/~a-beat.json" s3-bucket task-name))))
        (unless (hash? beat)
          (error 'take-pulse "heartbeat content is not a hash: ~e" beat))
        (unless (exact-nonnegative-integer? (hash-ref beat 'seconds 0))
          (error 'take-pulse "heartbeat content is not a hash: ~e" beat))
        beat)))

  (define 1-hour (* 60 60))
  (define 1-day (* 1-hour 24))
  (define (task-period task)
    (or (hash-ref task 'period #f)
        (hash-ref config 'period 1-day)))
  
  (define all-ok?
    (and (andmap values pings)
         (for/and ([task (in-list tasks)]
                   [beat (in-list beats)])
           (and (not (hash-ref beat 'error #f))
                (<= (- now (hash-ref beat 'seconds 0))
                    (task-period task))))))

  (define tos
    (if email?
        (for/list ([to (in-list (hash-ref config 'emails null))]
                   #:when (or (not all-ok?)
                              (hash-ref to 'on-success? #t)))
          to)
        null))
  
  (define collected (if (null? tos)
                        (current-output-port)
                        (open-output-bytes)))
  
  (parameterize ([current-output-port collected])
    ;; Report
    (printf "\n~a\n\n"
            (cond
             [all-ok?
              "All sites and tasks appear healthy"]
             [else
              "CHECK FAILED for some site or task"]))
    
    (for ([site (in-list sites)]
          [ping (in-list pings)])
      (printf "~a: ~a\n"
              (hash-ref site 'url)
              (if ping "ok" "FAILED")))
    
    (for ([task (in-list tasks)]
          [beat (in-list beats)])
      (printf "~a:" (hash-ref task 'name))
      (cond
       [(hash-ref beat 'error #f)
        => (lambda (e)
             (define (add-indentation s)
               (regexp-replace* "\n" s "\n  "))
             (printf " ERROR\n  ~a\n" (add-indentation e)))]
       [(hash-ref beat 'seconds 0)
        => (lambda (s)
             (define elapsed (- now s))
             (define (n-of n u)
               (format "~a ~a~a"
                       n
                       u
                       (if (= 1 n)
                           ""
                           "s")))
             (define ago
               (cond
                [(>= elapsed 1-day)
                 (n-of (quotient elapsed 1-day) "day")]
                [(>= elapsed 1-hour)
                 (n-of (quotient elapsed 1-hour) "hour")]
                [else
                 (n-of elapsed "second")]))
             (define beat-date (date->string (seconds->date s #f) #t))
             (cond
              [(> elapsed
                  (or (hash-ref task 'period #f)
                      (hash-ref config 'period 1-day)))
               (printf " ERROR\n  last report was ~a (~a ago)\n"
                       beat-date
                       ago)]
              [else
               (printf " ok\n  last reported ~a (~a ago)\n"
                       beat-date
                       ago)]))])))
  
  (when (pair? tos)
    (define content (get-output-string collected))
    (display content)
    
    (printf "\nSending email:\n")
    (send-email smtp-server (for/list ([to (in-list tos)])
                              (define addr (hash-ref to 'to))
                              (printf "  ~a\n" addr)
                              addr)
                (format "[take-pulse] ~a health check at ~a"
                        (if all-ok?
                            "successful"
                            "FAILED")
                        s3-bucket)
                content))

  all-ok?)

(module+ main
  (require racket/cmdline)
  (define smtp-server #f)
  (define email? #t)
  (command-line
   #:once-each
   [("--no-email") "Skip sending e-mail with results"
    (set! email? #f)]
   [("--smtp") server "Specify a server for outgoing email"
    (set! smtp-server server)]
   #:args
   (s3-bucket)
   (unless (take-pulse s3-bucket
                       #:email? email?
                       #:smtp-server smtp-server)
     (exit 1))))
