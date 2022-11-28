#lang racket

(require net/url)

(define (clean!)
  (printf "Deleting files\n")
  (for ([f (directory-list)]
        #:when (path-has-extension? f ".json"))
    (delete-file f)))

(define (download! . xs)
  (for ([x xs])
    (printf "Downloading ~a\n" x)
    (define p (get-pure-port (string->url (~a "https://heartbeat.racket-lang.org/" x))))
    (with-output-to-file x
      #:exists 'replace
      (λ () (copy-port p (current-output-port))))
    (close-input-port p)))

(module+ main
  (require racket/cmdline)

  (define clean? #f)

  (command-line
   #:once-each
   [("-c") "Clean sample data"
           (set! clean? #t)])

  (cond
    [clean? (clean!)]
    [else
     (download! "pkgd-update-beat.json"
                "pkgd-upload-beat.json"
                "pkg-build-beat.json"
                "drdr-poll-beat.json"
                "drdr-run-beat.json"
                "drdr-disk-beat.json"
                "snapshot-utah-beat.json"
                "nwu-pkg-build-and-snapshot-beat.json"
                "build-plot-cs-beat.json"
                "build-plot-bc-beat.json"
                "condense-logs-beat.json"
                "condense-west-logs-beat.json"
                "utah-monitor-beat.json"
                "nwu-monitor-beat.json")]))
