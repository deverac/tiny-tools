<a name='functions'></a>
### Helper functions
Tiny-tools does not have any sort of API. The `common.src` file has a few
items that may be useful in CGI scripts.


> **encodeUrl()**  Url-encodes a string. Accepts a single required parameter
which is the string to encode.

> **decodeUrl()** Decodes a url-encoded string. Accepts a single required
parameter which is the encoded string.

> **decodeMultipartPost()** Parses data that has been submitted as
'multipart/form-data' and sets shell variables to values of the form's fields.
The shell variables are named 'POSTVAR_xxxx' where 'xxxx' is the name of the
form field. The variable value will be the value of the form field. There are
two exceptions to this: 1) When 'type="file"' is included in the form. 2) The
name of the form field begins with 'data'. In either case, the value of the
shell variable will contain the name of a file. The file will contain the value
of the form field. The `data*` field name should be used for an HTML
&lt;textarea&gt; element in order to save its contents properly.

> **printHeader()** Outputs a common HTML header of links. Accepts two parameters.
The first parameter is required and is one of: 'browser', 'editor', 'upload',
'shell'. Whichever value is specified will be output as text, rather than a
link. The second parameter is optional and is the directory name to include in
each link.

> **DT** A unique-ish value. Use of this variable is optional. This is used in
the name of a temporary files. It is also submitted with each GET request in
order to create a unique request to prevent the browser or server from
returning a previously cached response.

<a name='readtimeout'></a>
### Read-timeout
Since shServer is just a shell-script - and thus depends on line-buffered
input - there is a certain type of HTML form that shserver may not be able to process in the normal manner. The issue will exist if all four of the following
conditions are true:

 1. The HTML form must be submitted as a POST request.
 2. The request must be 'application/x-www-form-encoded' (i.e. 'enctype' is not specified).
 3. The request must be submitted to the shServer.
 4. Read-timeout is not supported.

The CGI script below can test if read-timeout is supported. The script builds
two HTML forms on one page. The first HTML form is submitted as a GET request
and is only included to verify that the page is able to send a request to the
server and receive a response back. The second HTML form is submitted as an
'application/x-www-form-encoded' POST request and can be used to check if
read-timeout is supported. If, after clicking the 'Submit POST' button of
the second form, the browser continuously 'spins' and never receives a
response from the shServer, then read-timeout is not supported. The following
work-arounds can be used:

 * The HTML form can be submitted as a GET request.
 * The HTML form can specify 'enctype="multipart/form-data" and be submitted as
   a POST request. The `decodeMultipartPost()` function can be used to parse
   the submitted data.
 * The user can cancel the browser request. The submitted data will then be
   processed by the CGI script, but the browser will ignore any response from
   the server. This behavior is not desirable, but can be 'good enough' in some
   situations.


    #!/bin/sh
    set -e

    # If the browser never receives a response after clicking 'Submit POST',
    # then the shServer is not able to process 'application/x-www-form-encoded'
    # POST requests in a normal manner.

    # Include common functions.
    . ./common.src

    LIN=
    if [ "x$REQUEST_METHOD" = "xPOST" ]; then
      # Temporarily disable exit-on-error because when running under a real web
      # server (e.g. thttpd), read exits with an error due to reading EOF.
      set +e
      read -r LIN
      set -e
    elif [ "x$REQUEST_METHOD" = "xGET" ]; then
      LIN="$QUERY_STRING"
    fi

    # Parse the submitted values.
    OLDIFS=$IFS
    IFS="&"
    for KEYVAL in $LIN; do
      case "$KEYVAL" in
         act=*) ACT=$(echo "$KEYVAL" | cut -b 5-);;
         dir=*) RAW_DIR=$(echo "$KEYVAL" | cut -b 5-);;
         name=*) RAW_NAME=$(echo "$KEYVAL" | cut -b 6-);;
      esac
    done
    IFS=$OLDIFS

    echo "Content-type: text/html; charset=utf-8"
    echo "Cache-Control: no-store"
    echo "Expires: 0" # Expire immediately
    echo "" # Empty line is required
    echo "<!DOCTYPE html><html><head><title>TTDemo</title></head>"
    echo "<body>"
    echo "<p>Example GET and 'application/x-www-form-urlencoded' POST.</p>"
    echo "Submitted data: $LIN<br>"
    echo "<pre style='border: 1px solid black'>"
    echo "PARSED VALUES"
    echo "    Act: $(decodeUrl $ACT)"
    echo "    Dir: $(decodeUrl $RAW_DIR)"
    echo "   Name: $(decodeUrl $RAW_NAME)"
    echo "</pre>"
    echo "<form action='/$0' method='GET' style='border: 1px solid black'>"
    echo "  Dir: <input name='dir' value='GET dir' /><br>"
    echo "  Act: <input type='submit' name='act' value='Submit GET' />"
    echo "</form><br>"
    echo "<form action='/$0' method='POST' style='border: 1px solid black'>"
    echo "  Name: <input name='name' value='POST name' /><br>"
    echo "  Act: <input type='submit' name='act' value='Submit POST' />"
    echo "</form>"
    echo "</body>"
    echo "</html>"
