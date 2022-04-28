#lang scribble/manual
@(require (for-label racket/base
                     racket/contract/base
                     plt-service-monitor/beat
                     plt-service-monitor/take-pulse
                     plt-service-monitor/config))

@title{PLT Service Monitor}

The @filepath{plt-service-monitor} package provides tools for tasks to
register ``heartbeat'' activity to an AWS S3 bucket and for a periodic
polling of heartbeats and HTTP sites.

The configuration of tasks, sites, and e-mail addresses to alert are
stored in the S3 bucket in a @filepath{config.rktd} file. The
@racketmodname[plt-service-monitor/config] module provides functions to
adjusting the configuration.

@; ------------------------------------------------------------
@section{Heartbeats}

@defmodule[plt-service-monitor/beat]{The
@racketmodname[plt-service-monitor/beat] library provides an API for a
monitored task to register a heartbeat---typically as the last step in
a periodic task.}

Besides providing the @racket[beat] function,
@racketmodname[plt-service-monitor/beat] can be run from the command
line and given its arguments as command-line arguments.

@defproc[(beat [s3-bucket string?]
               [task-name string?]
               [#:region region string? ...])
         void?]{

Records a heartbeat, based on the current machine's time in UTC.

If the @racket[region] of @racket[s3-bucket] is not supplied, it is
determined through a query.}

@; ------------------------------------------------------------
@section{Taking a Pulse}

@defmodule[plt-service-monitor/take-pulse]{The
@racketmodname[plt-service-monitor/take-pulse] library implements the
monitor; it polls an S3 bucket and associated HTTP sites.}

The @racketmodname[plt-service-monitor/take-pulse] module can be run
from the command-line, in which case the S3 bucket name must be given
as a command-line argument. In addition, @DFlag{email-config} can specify
a file that contains a configuration hash table for sending e-mail alerts,
and @DFlag{no-email} or @DFlag{fail-email} configure the e-mail alert mode.
A @DFlag{beat} argument registers a new heartbeat for a given task name
after taking a pulse (and sending e-mail, if any), which is useful for
monitoring the server monitor itself from the a different service
monitor.

@defproc[(take-pulse [s3-bucket string?]
                     [#:region region string? ...]
                     [#:email-mode email-mode (or/c 'none 'always 'failure) 'always]
                     [#:email-config email-config hash? (hash)])
         boolean?]{

Polls the specified S3 bucket for heartbeats and polls configured HTTP
sites. The results are printed to the current output port and the
resulting boolean is @racket[#t] only if all checks succeed. If
the @racket[region] of @racket[s3-bucket] is not supplied, it is
determined through a query.

The S3 bucket's configuration file may specify e-mail addresses to
receive the poll summary. If @racket[email-mode] is @racket['always]
or it is @racket['failure] and the health check fails, then e-mail is
sent (although individual e-mail addresses can be configured to send
mail only on failure). In that case, @racket[email-config] configures
the way that e-mail is sent through the following keys:

@itemlist[

 @item{@racket['server] --- a string or @racket[#f] (the default); if
       a string is provided then the SMTP protocol is used with the
       specified server, otherwise e-mail is sent through
       @exec{sendmail}}

 @item{@racket['from] --- an e-mail address for the sender; the
       default is the first e-mail address in the list of receivers}

 @item{@racket['connect] (SMTP only) --- @racket['plain],
       @racket['ssl], or @racket['tls]}

 @item{@racket['user] (SMTP only) --- a username string for
       authentication}

 @item{@racket['password] (SMTP only) --- a password string for
       authentication}

]}

@; ------------------------------------------------------------
@section{Configuring a Service Monitor}

@defmodule[plt-service-monitor/config]{The
@racketmodname[plt-service-monitor/config] library provides functions
for adjusting a service monitor's configuration as stored at its S3
bucket. (The region of the bucket is determined automatically
through a query.)}

@deftogether[(
@defproc[(get-task [s3-bucket string?]
                   [task-name string?]
                   [#:force? force? any/c #f])
          (or/c #f hash?)]
@defproc[(set-task [s3-bucket string?]
                   [task hash?]
                   [#:force? force? any/c #f])
          void?]
@defproc[(remove-task [s3-bucket string?]
                      [task-name string?])
          void?]
)]{

Gets, adjusts, or removes a task to the configuration at
@racket[s3-bucket] for use by @racket[take-pulse].

The @racket[get-task] function returns @racket[#f] if the task name is
not configured, otherwise it returns a hash table suitable for
updating and returning to @racket[set-task].

The hash table provided to @racket[set-task] can have the following
keys with the indicated contracts on the key values:

@itemlist[

 @item{@racket['name : string?] (required) --- the task name as used
        with @racket[beat] (but @racket[beat] does not check whether
        a given task name is configured as one that is checked by
        @racket[take-pulse])}

 @item{@racket['period : exact-nonnegative-integer?] --- the maximum
       number of seconds that should elapse between heartbeats for the
       task; the default is one day}

]

Unless @racket[force?] is true, then @racket[get-task] or
@racket[set-task] fail if @racket[s3-bucket] does not have a
configuration object @filepath{config.rktd}.}

@deftogether[(
@defproc[(get-site [s3-bucket string?]
                   [url string?]
                   [#:force? force? any/c #f])
          (or/c #f hash?)]
@defproc[(set-site [s3-bucket string?]
                   [site hash?]
                   [#:force? force? any/c #f])
          void?]
@defproc[(remove-site [s3-bucket string?]
                      [url string?])
          void?]
)]{

Gets, adjusts, or removes a polled URL to the configuration at
@racket[s3-bucket] for use by @racket[take-pulse]. The function
protocol is the same as for @racket[get-task], @racket[set-task], and
@racket[remove-task].

The hash table provided to @racket[set-site] can have the following
keys with the indicated contracts on the key values:

@itemlist[

 @item{@racket['url : string?] (required) --- the URL to poll}

]}


@deftogether[(
@defproc[(get-email [s3-bucket string?]
                    [addr string?]
                    [#:force? force? any/c #f])
          (or/c #f hash?)]
@defproc[(set-email [s3-bucket string?]
                    [to hash?]
                    [#:force? force? any/c #f])
          void?]
@defproc[(remove-email [s3-bucket string?]
                       [addr string?])
          void?]
)]{

Gets, adjusts, or removes an e-mail address to the configuration at
@racket[s3-bucket] for use by @racket[take-pulse], where Each e-mail
address receives a message to summarize the check results. The
function protocol is the same as for @racket[get-task],
@racket[set-task], and @racket[remove-task].

The hash table provided to @racket[set-email] can have the following
keys with the indicated contracts on the key values:

@itemlist[

 @item{@racket['to : string?] (required) --- the e-mail address}

 @item{@racket['on-success? : boolean?] --- whether e-mail is sent
       even when all health checks succeed; the default is @racket[#t]}

]}
