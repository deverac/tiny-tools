#!/bin/sh
set -e

# Run a detached process.

# Substitute for $(dirname $0)
basedir() {
    echo "$1" | sed -e 's|[^/]*$||' -e 's|[/]*$||'
}

BASEDIR=$(basedir "$0")

PORT=$(if [ -z "$1" ]; then echo 80; else echo $1; fi)

# setsid           Start a new session
# '> /dev/null'    Detach stdout.
# '2>&1'           Redirect stderr to stdout.
# '< /dev/null'    Detach stdin.
# '&'              Run in background.
setsid $BASEDIR/shserv.sh $PORT > /dev/null 2>&1 < /dev/null &

