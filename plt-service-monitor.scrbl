#lang scribble/manual

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

@defproc[(beat [s3-bucket string?] [task-name string?]) void?]{

Records a heartbeat, based on the current machine's time in UTC.}

@; ------------------------------------------------------------
@section{Taking a Pulse}

@defmodule[plt-service-monitor/take-pulse]{The
@racketmodname[plt-service-monitor/take-pulse] library implements the
monitor; it polls an S3 bucket and associated HTTP sites.}

The @racketmodname[plt-service-monitor/take-pulse] module can be run
from the command-line, in which case the S3 bucket name must be given
as a command-line argument. In addition, @DFlag{smtp} can specify the
SMTP server for e-mail alerts.

@defproc[(take-pulse [s3-bucket string?]
                     [#:smtp-server smtp-server (or/c #f string?) #f])
         boolean?]{

Polls the specified S3 bucket for heartbeats and polls configured HTTP
sites. The results are printed to the current output port and the
resulting boolean is @racket[#t] only if all checks succeed.

The S3 bucket's configuration file may specify e-mail addresses to
receive the poll summary. In that case, if @racket[smtp-server] is
@racket[#f], then e-mail is sent through @exec{sendmail}, otherwise
the SMTP protocol is used with the specified server.}

@; ------------------------------------------------------------
@section{Configuring a Service Monitor}

@defmodule[plt-service-monitor/config]{The
@racketmodname[plt-service-monitor/config] library provides functions
for adjusting a service monitor's configuration as stored at its S3
bucket.}

@deftogether[(
@defproc[(add-task [s3-bucket string?]
                   [task-name string?]
                   [#:force? force? any/c #f])
          void?]
@defproc[(remove-task [s3-bucket string?]
                      [task-name string?])
          void?]
)]{

Adds or removes a task to the configuration at @racket[s3-bucket] for
use by @racket[take-pulse].

The task name should be the same as used with @racket[beat], although
@racket[beat] does not check whether the task name is configured as
one that is checked by @racket[take-pulse].

If @racket[force?] is true, the configuration is initialized to the
empty configuration before adding @racket[task-name].}


@deftogether[(
@defproc[(add-site [s3-bucket string?]
                   [url string?]
                   [#:force? force? any/c #f])
          void?]
@defproc[(remove-site [s3-bucket string?]
                      [url string?])
          void?]
)]{

Adds or removes a polled URL to the configuration at
@racket[s3-bucket] for use by @racket[take-pulse].

If @racket[force?] is true, the configuration is initialized to the
empty configuration before adding @racket[url].}



@deftogether[(
@defproc[(add-email [s3-bucket string?]
                    [addr string?]
                    [#:force? force? any/c #f])
          void?]
@defproc[(remove-email [s3-bucket string?]
                       [addr string?])
          void?]
)]{

Adds or removes an e-mail address to the configuration at
@racket[s3-bucket] for use by @racket[take-pulse]. Each e-mail address
receives a message to summarize the check results.

If @racket[force?] is true, the configuration is initialized to the
empty configuration before adding @racket[addr].}
