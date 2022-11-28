#lang racket/base

(require "common.rkt")

(define files
  (list "pkgd-update-beat.json"
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
        "nwu-monitor-beat.json"))

(define (clean!)
  (printf "Deleting files\n")
  (for ([file (in-list files)] #:when (file-exists? file))
    (delete-file file)))

(define (download!)
  (for ([file (in-list files)])
    (printf "Downloading ~a\n" file)
    (with-output-to-file file
      #:exists 'replace
      (λ () (display (get-from-site file))))))

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
