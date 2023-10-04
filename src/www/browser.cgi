#!/bin/sh
set -e

. ./common.src

# Extract query parameters.
OLDIFS=$IFS
IFS="&"
for KEYVAL in $QUERY_STRING; do
  case "$KEYVAL" in
    dir=*) RAW_DIR=$(echo "$KEYVAL" | cut -b 5-);;
    dl=*) FILE_DL=1;;
    h=*) HDN=$(echo "$KEYVAL" | cut -b 3-);;
    name=*) RAW_NAME=$(echo "$KEYVAL" | cut -b 6-);;
    view=*) FILE_VIEW=1;;
  esac
done
IFS=$OLDIFS


FNAME=$(if [ ! -z "$RAW_NAME}" ]; then decodeUrl "$RAW_NAME"; fi)

WORK_DIR=$(if [ ! -z "$RAW_DIR" ]; then decodeUrl "$RAW_DIR"; fi)
if [ ! -z "$WORK_DIR" ]; then
  cd "$WORK_DIR"
fi
DIR=$(pwd)



SEND_CONTENTS=0
if [ "x$FILE_VIEW" = "x1" ]; then
  if echo "$FNAME" | grep -i -q \.htm$; then
    echo "Content-Type: text/html; charset=utf-8"
  elif echo "$FNAME" | grep -i -q \.html$; then
    echo "Content-Type: text/html; charset=utf-8"
  else
    echo "Content-Type: text/plain; charset=utf-8"
  fi
  SEND_CONTENTS=1
elif [ "x$FILE_DL" = "x1" ]; then
  echo "Content-Type: application/octet-stream"
  echo "Content-Disposition: attachment; filename=\""$(echo "$FNAME" | sed -e 's|.*/||')"\""
  SEND_CONTENTS=1
fi

if [ "x$SEND_CONTENTS" = "x1" ]; then
  echo "Accept-Ranges: bytes"
  echo "Connection: close"
  echo "" # Blank line is required.
  cat "$FNAME"
  exit
fi





echo "Content-type: text/html; charset=utf-8"
echo "Cache-Control: no-store"
echo "Expires: 0" # Expire immediately
echo "" # Blank line is required.
echo "<!DOCTYPE html>"
echo "<html>"
echo "<head>"
echo "    <title>TTBrowser</title>"

cat << EOF
<style type='text/css'>
  html { margin: 4px; font-family: sans-serif; }
  pre { display: inline; }
  .hdr { background-color: whitesmoke; padding: 4px; font-weight: bold }
</style>
EOF
echo "</head>"
echo "<body>"

printHeader browser

echo "<p>"$(pwd)
if [ "x$HDN" = "x1" ]; then
    echo " (<a href='$0?dir=$DIR&amp;&amp;h=0&amp;dt=$DT'>Hide Hidden</a>)"
else
    echo " (<a href='$0?dir=$DIR&amp;&amp;h=1&amp;dt=$DT'>Show Hidden</a>)"
fi
echo "</p>"

echo "<table>"
if [ "x$DIR" != "x/" ]; then
  echo "<tr>"
    echo "<td><a href='$0?dir=$DIR/..&amp;h=$HDN&amp;dt=$DT'>[..]</a></td>"
    echo "<td></td>"
    echo "<td></td>"
  echo "</tr>"
fi
LSA=$(if [ "x$HDN" = "x1" ]; then echo "-A"; fi)
ls -1 $LSA | while read -r nm; do
    DETAILS=
    echo "<tr>"
    if [ -d "$nm" ]; then
      if [ "x$DIR" = "x/" ]; then
        DIR=''
      fi
      DETAILS=$(ls -l -d "$nm")
      echo "<td><a href='$0?dir=$DIR/$nm&amp;h=$HDN&amp;dt=$DT'>[$nm]</a></td>"
      echo "<td></td>"
      echo "<td></td>"
    else
      DETAILS=$(ls -l "$nm")
      ENCNM=$(encodeUrl "$DIR/$nm")
      echo "<td><a href='$0?name=$ENCNM&amp;view=1&amp;dt=$DT'>$nm</a></td>"
      echo "<td>(<a href='/editor.cgi?name=$ENCNM&amp;dir=$DIR&amp;dt=$DT'>Edit</a>)</td>"
      echo "<td>(<a href='$0?name=$ENCNM&amp;dl=1&amp;dt=$DT'>DL</a>)</td>"
    fi
    echo "<td><pre>$DETAILS</pre></td>"
    echo "</tr>"
done
echo "</table>"
echo '</body>'
echo '</html>'
