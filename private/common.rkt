#lang racket/base

(provide task-period
         1-minute
         1-hour
         1-day)

(define 1-minute 60)
(define 1-hour (* 1-minute 60))
(define 1-day (* 1-hour 24))

(define (task-period task config)
  (or (hash-ref task 'period #f)
      (hash-ref config 'period 1-day)))
