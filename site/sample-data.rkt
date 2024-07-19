#lang racket/base

(require racket/path
         "common.rkt")

;; source of sample data:
(define url "https://heartbeat.racket-lang.org/")

(define (clean!)
  (printf "Deleting files\n")
  (for ([file (in-list (directory-list))]
        #:when (path-has-extension? file ".json"))
    (delete-file file)))

(define (download!)
  (define config (get-config url))
  (define tasks (hash-ref config 'tasks null))
  (define files
    (for/list ([task (in-list tasks)])
      (format-file (hash-ref task 'name))))

  (for ([file (in-list files)])
    (printf "Downloading ~a\n" file)
    (with-output-to-file file
      #:exists 'replace
      (λ () (display (get-from-site file url))))))

(module+ main
  (require racket/cmdline)

  (define clean? #f)

  (command-line
   #:once-each
   [("-c") "Clean sample data"
           (set! clean? #t)])

  (cond
    [clean? (clean!)]
    [else (download!)]))
