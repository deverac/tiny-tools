#!/bin/sh
set -e

# Usage: ./shserv.sh [ PORT [ DIR ] ]
#   PORT  The port to listen on
#   DIR   The directory to serve files from
#
# This is a simple server. It handles one request at a time.
#
# There are three ways to terminate the server:
#    1) Kill the 'busybox nc' process
#    2) Visit the '/stopserver' URL
#    3) Press Ctrl-C
#

# Substitute for $(dirname $0)
basedir() {
    echo "$1" | sed -e 's|[^/]*$||' -e 's|[/]*$||'
}

BASEDIR="$(pwd)/$(basedir $0)"

# The port to listen on.
PORT=$(if [ -z "$1" ]; then echo 80; else echo $1; fi)

# The directory to serve files from.
if [ -z "$2" ]; then
    cd "$BASEDIR/../www"
else
    cd "$2"
fi


echo "Listening on port $PORT. Serving $(pwd)"
while true; do
    # Calling the nc applet of busybox is probably required as some
    # stand-alone versions of nc do not support the '-e' option.
    # -l         Listen
    # -p NNN     Port to listen on
    # -e script  Execute script when connection is received. Some
    #            versions of busybox do not allow parameters.
    if (busybox nc -l -p $PORT -e $BASEDIR/shreq.sh); then
        echo "  Processed request"
    else
        RV=$?
        if [ $RV -eq 143 ]; then  # 143 == SIGTERM
            echo "$0: Server was killed."
            exit $RV
        elif [ $RV -eq 141 ]; then # 141 == SIGPIPE
            # Ignore.
            echo "$0: User cancelled request."
        elif [ $RV -eq 99 ]; then # 99 is specified in shreq.sh.
            echo "$0: Received shutdown URL."
            exit $RV
        else
            echo "$0: Exiting with code $RV."
            exit $RV
        fi
    fi
done
