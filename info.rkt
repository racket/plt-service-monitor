#lang info

(define collection "plt-service-monitor")

(define deps '("net-lib"
               "base"
               ["aws" #:version "1.6"]
               "http"))
(define build-deps '("racket-doc"
                     "scribble-lib"))

(define pkg-desc "service-monitoring and \"heartbeat\" tools")

(define pkg-authors '(mflatt))

(define scribblings '(("plt-service-monitor.scrbl")))
