This directory contains components for a site like https://heartbeat.racket-lang.org/

- `script.js`: JavaScript for the dashboard page
- `style.css`: CSS for the dashboard page
- `gen-index.rkt`: a script that generates `index.html`
- `sample-data.rkt`: a script to manage sample data required by `index.html`
  (download and clean)

## Testing

Run `racket sample-data.rkt` to populate sample data.

Launch a local server (e.g. with [`raco static-web`](https://github.com/samdphillips/raco-static-web/)).
Then, you can view the page locally.

## Deployment

Use `set-task`, `set-site`, etc., to update configuration, and then `index.html` and its support files are uploaded as part of the update.
