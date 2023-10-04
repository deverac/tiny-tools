#!/bin/sh
set -e

# This script handles a single HTTP request and then exits.
# For testing, it can be run as: "busybox nc -l -p 8080 -e ./shreq.sh"

# Supported GET requests:
#   /stopserver  Exits this script with exit value of 99
#   /*.png       Returns PNG image
#   /*.cgi*      Runs CGI script
#   /*.htm*      Returns HTML file
#   /*           Returns named file (as plain text)
#   /            Returns '/index.cgi'
# All other GET requests returns HTTP 200 OK, but no data.
#
# Any HEAD request returns HTTP 200 OK, but no data.
#
# For POST requests:
#   Any 'multipart/form-data' request returns HTTP 200 OK.
#   Any 'application/x-www-form-urlencoded' request will return an HTTP 200 OK,
#   if a read-timeout is supported. If a read-timeout is not supported, this
#   script will 'hang' on a read operation that will never complete causing the
#   browser to wait for a response that will never come. If the user cancels
#   the request, the read will terminate and the submitted data can be
#   processed by the CGI script, but the browser will ignore any response.

# Substitute for $(dirname $0)
basedir() {
    echo "$1" | sed -e 's|[^/]*$||' -e 's|[/]*$||'
}


# Get filesize. Assumes filesize is fifth field.
getFilesize() {
    # Use echo to compress multiple spaces into a single space.
    echo $(ls -l "$1") | cut -f 5 -d ' '
}

# Extract whatever string is specified as the boundary.
extractBoundary() {
    if echo "$1" | grep -q "boundary="; then
        # Per spec, all headers end with CRLF. 's/.$//' removes CR.
        echo "$1" | cut -f 2 -d '=' | sed -e 's/.$//'
    fi
}

extractContentLength() {
    # Per spec, all headers end with CRLF. 's/.$//' removes CR.
    echo "$1" | cut -f 2 -d ' ' | sed -e 's/.$//'
}

runCgi() {
    REQUEST_METHOD="$1" # CGI var
    # $2 Url
    CONTENT_LENGTH="$3" # CGI var
    DAT_FIL="$4" # Filename which holds POSTed data.

    OLDIFS=$IFS
    IFS='?'
    for pt in $2; do  # Do not quote '$2'.
        if [ -z "$SCRIPT_NAME" ]; then
            # Prefix SCRIPT_NAME with period to make relative path.
            SCRIPT_NAME=".$pt" # CGI var
        else
            QUERY_STRING="$pt" # CGI var
        fi
    done
    IFS=$OLDIFS

    if [ -f "$SCRIPT_NAME" ]; then
        export QUERY_STRING # CGI var
        export SCRIPT_NAME # CGI var
        export REQUEST_METHOD # CGI var
        if [ "x$REQUEST_METHOD" = "xPOST" ]; then
            export CONTENT_LENGTH # CGI var
            if [ -f "$DAT_FIL" ]; then
                cat "$DAT_FIL" | sh "$SCRIPT_NAME"  2>&1 # Execute CGI script
            fi
        else # Assume GET
            sh "$SCRIPT_NAME" 2>&1  # Execute CGI script
        fi
    else
        echo "$HTTP_CT_PLAIN"
    fi
}


# Define some HTTP response codes.
HTTP_OK="HTTP/1.0 200 OK"
HTTP_NF="HTTP/1.0 404 Not Found"
HTTP_SO="HTTP/1.0 303 See Other"

HTTP_CT_PLAIN="Content-Type: text/plain; charset=utf-8"
HTTP_CT_HTML="Content-Type: text/html; charset=utf-8"

BASEDIR=$(basedir "$0")

# Generate a unique-ish value.
# /proc/uptime outputs two values: the uptime and idle time in seconds.
UVAL=$(cat /proc/uptime | sed -e 's/[ .]//g')

# POSTed data will be saved to this file and then deleted.
POST_DATA="../_$UVAL.post"

METH=0
URL=
LIN=xxx
CONLEN=0
BNDY=
GOT_URL=0
FILNAM=
STOPSRV=


while [ "${#LIN}" -gt 2 ]; do
    read -r LIN

    #echo "$LIN" >> "./httpHeaders.log"     # Log HTTP headers

    if [ "$GOT_URL" = "0" ]; then
        case "$LIN" in
            GET\ *) METH=GET; URL=$(echo $LIN | cut -f 2 -d ' ') ;;
            HEAD\ *) METH=HEAD; URL=$(echo $LIN | cut -f 2 -d ' ') ;;
            POST\ *) METH=POST; URL=$(echo $LIN | cut -f 2 -d ' ') ;;
        esac
        GOT_URL=1
    else
        case "$LIN" in
            [Cc]ontent\-[Ll]ength:*) CONLEN=$(extractContentLength "$LIN") ;;
            [Cc]ontent\-[Tt]ype:*) BNDY=$(extractBoundary "$LIN") ;;
        esac
    fi

done

if [ "x$URL" = "x/" ]; then
    if [ -f ./index.cgi ]; then
        URL=/index.cgi
    elif [ -f ./index.htm ]; then
        URL=/index.htm
    elif [ -f ./index.html ]; then
        URL=/index.html
    fi
fi

# Handle POST requests
if [ "$METH" = "POST" ]; then
    rm -f "$POST_DATA"
    case "$URL" in
        /*.cgi*)
           if [ -z "$BNDY" ]; then
               # Save the 'application/x-www-form-urlencoded' data. Since the
               # data is on a single line that does not end with a newline,
               # the 'read' operation will never complete. Several methods are
               # used to effect a read-timeout. (The 'timeout' command is not
               # used because it does not seem to work the way we need it to.)
               if echo "abcd" | read -t 1 DUMY 2>/dev/null; then
                   read -t 3 -r LIN # timeout of 3 is arbitrary
               elif bash --help > /dev/null; then
                   # A convenience for development environments. Bash honors
                   # TMOUT and exits after N seconds of no activity. (Bash's
                   # 'read' can also accept a timeout parameter.)
                   LIN=$(/bin/bash -c 'TMOUT=3; read -r DUMY; echo "$DUMY"')
               elif (sleep --help && kill -l) > /dev/null; then
                   # Send USR1 signal to terminate the read operation.
                   READER_PID=$$ # Get PID of this process.
                   trap ':' USR1 # Do nothing after receiving USR1 signal.
                   set +e # Disable exit-on-error to ignore USR1 signal.
                   (sleep 3; kill -s USR1 $READER_PID) &  # Sleep, then send USR1
                   read -r LIN
                   set -e # Re-enable exit-on-error.
               else
                   # Since a read-timeout is not available, the best we can do
                   # is read and 'hang'. The read operation requires a newline
                   # to complete, but (per HTTP spec) the data does not end
                   # with a newline. This will cause the browser to wait for a
                   # response that will never come. If the user cancels the
                   # request the CGI script will process the data but any
                   # response will be ignored by the browser.
                   read -r LIN
               fi
               echo "$LIN" > "$POST_DATA"
               echo "$HTTP_OK"
               runCgi "$METH" "$URL" "$CONLEN" "$POST_DATA"   # Run the CGI program
               rm -f "$POST_DATA"
               exit
           else
               # Save 'multipart/form-data' data (multiple lines).
               read -r LIN # Read boundary line.
               echo "$LIN" >> "$POST_DATA"  # Save boundary line
               LIN=
               FIN=0
               while [ "x$FIN" = "x0" ]; do
                   # Clear IFS before read to preserve leading whitespace on lines.
                   IFS= read -r LIN
                   # To save LIN, use cat with EOF, rather than echo. dash's
                   # echo, interprets a backslash as an escape sequence; there
                   # is no way to disable that behavior. Backslashes are not
                   # an issue for most data, but uuencoded data often has them.
                   cat << EOF >> "$POST_DATA"
$LIN
EOF
                   # Final boundary has '--' appended to it.
                   if echo "$LIN" | grep -q -- "${BNDY}--"; then
                       FIN=1
                   fi
               done
               echo "$HTTP_OK"
               runCgi "$METH" "$URL" "$CONLEN" "$POST_DATA"   # Run the CGI program
               rm -f "$POST_DATA"
               exit
           fi
           ;;
        *)
           echo "$HTTP_OK"
           echo "$HTTP_CT_PLAIN"
           ;;
    esac
elif [ "$METH" = "GET" ]; then  # Handle GET requests
    case "$URL" in
        /*.cgi*)
            echo "$HTTP_OK"
            # CONLEN and POST_DATA are place-holders; they are ignored for GET.
            runCgi "$METH" "$URL" "$CONLEN" "$POST_DATA"
            exit
            ;;
        /*.htm*)
            FILNAM=$(pwd)$URL
            if [ -f "$FILNAM" ]; then
                echo "$HTTP_OK"
                echo "$HTTP_CT_HTML"
            else
                FILNAM=
                echo "$HTTP_NF"
                echo "$HTTP_CT_PLAIN"
            fi
            ;;
        /*.png)
            FILNAM=$(pwd)$URL
            if [ -f "$FILNAM" ]; then
                echo "$HTTP_OK"
                echo "Content-Type: image/png"
                echo "Content-Length: " getFilesize "$FILNAM"
            else
                echo "$HTTP_NF"
                FILNAM=
            fi
            ;;
        /stopserver)
            STOPSRV=1
            echo "$HTTP_OK"
            ;;
# An example of how to redirect.
#        /wp)
#           echo "$HTTP_SO"  #HTTP/1.0 303 See Other"
#           echo "Location: https://www.wikipedia.org/"
#           ;;
        *)
            FILNAM="$(pwd)$URL"
            if [ ! -f "$FILNAM" ]; then
                FILNAM=
            fi
            echo "$HTTP_OK"
            echo "$HTTP_CT_PLAIN"
            ;;
    esac
elif [ "$METH" = "HEAD" ]; then # Handle HEAD requests
    echo "$HTTP_OK"
fi

echo "Server: ShServer/0.1"
echo "" # Blank line is required.

# Output content
if [ "$METH" = "GET" ]; then
    if [ -f "$FILNAM" ]; then
        cat "$FILNAM"
    elif [ ! -z "$STOPSRV" ]; then
        exit 99
    else
        echo "ShServer is running."
    fi
fi

exit
