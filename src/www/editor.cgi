#!/bin/sh
set -e

. ./common.src

ACT=
DATA_FIL=
LIN=
RAW_DIR=
RAW_NAME=

if [ "x$REQUEST_METHOD" = "xPOST" ]; then
  # Extract POSTed data.
  decodeMultipartPost

  ACT="$POSTVAR_act"
  DATA_FIL="$(pwd)/$POSTVAR_data"
  RAW_DIR="$POSTVAR_dir"
  RAW_NAME="$POSTVAR_name"
else
  # Extract parameters from query string of GET request.
  OLDIFS=$IFS
  IFS="&"
  for KEYVAL in $QUERY_STRING; do
    case "$KEYVAL" in
       dir=*) RAW_DIR=$(echo "$KEYVAL" | cut -b 5-);;
       name=*) RAW_NAME=$(echo "$KEYVAL" | cut -b 6-);;
    esac
  done
  IFS=$OLDIFS
fi


FNAME=$(if [ ! -z "$RAW_NAME" ]; then decodeUrl "$RAW_NAME"; fi)
if [ ! -z "$FNAME" ]; then
    if echo "$FNAME" | (! grep -q '/'); then
        FNAME="$(pwd)/$FNAME"
    fi
fi

WORK_DIR=$(if [ -z "$RAW_DIR" ]; then pwd; else decodeUrl "$RAW_DIR"; fi)
if [ ! -z "$WORK_DIR" ]; then
  cd "$WORK_DIR"
fi
DIR=$(pwd)


if [ "x$ACT" = "xSave" ]; then
  if [ -f "$DATA_FIL" ]; then
    if [ ! -z "$FNAME" ]; then
        # Perform 'cp $DATA_FIL $FNAME' without using cp.
        cat /dev/null > "$FNAME" # Truncating preserves file permissions.
        # Clear IFS before read to preserve (e.g) leading whitespace on lines.
        while IFS= read -r LIN; do
            # To save LIN, use cat with EOF, rather than echo.
            # dash's echo, interprets any backslash as an escape
            # sequence; there is no way to disable that behavior.
            cat << EOF >> "${FNAME}"
$LIN
EOF
        done < "$DATA_FIL"
        rm -f "$DATA_FIL"
        # Per HTTP spec, all lines end with CRLF. Remove CR (^M) from lines.
        # (This means editor cannot save files in DOS format.)
        sed -i 's/.$//g' "${FNAME}"
    fi
  fi
fi

echo "Content-type: text/html; charset=utf-8"

echo "Cache-Control: no-store"
echo "Expires: 0" # Expire immediately
echo "" # Empty line is required
echo "<!DOCTYPE html>"
echo "<html>"
echo "<head>"
echo "   <title>TTEditor</title>"


cat << EOF
<style type='text/css'>
    #assist { display: 'none'; }
    html { margin: 4px; font-family: sans-serif; }
    textarea { width: 99%; }
    .ctl { padding: 5pt; background-color: lightblue; margin-right: 8pt; }
    .hdr { background-color: whitesmoke; padding: 4px; font-weight: bold }
</style>
EOF

cat << EOF
<script type='text/javascript'>
    function replaceTokens(idStr, code) {
        if (code > 0 && code < 256) {
            var src = document.getElementById(idStr);
            var ta = document.getElementById('ta');
            if (src && ta) {
                var str = src.value;
                if (str.length > 0) {
                    while (ta.value.indexOf(str) >= 0) {
                        ta.value = ta.value.replace(str, String.fromCharCode(code));
                    }
                }
            }
        }
    }

    function insertReturn() {
        replaceTokens('ret', 10);
    }

    function insertTab() {
        replaceTokens('tab', 9);
    }

    function insertAny() {
        var cd = document.getElementById('code');
        if (cd) {
            replaceTokens('tok', cd.value);
        }
    }

    function moveCursor(dir) {
        var step = parseInt(document.getElementById('curstep').value) || 10;
        if (dir < 0) {
            step = -step;
        }
        var txta = document.getElementById('ta');
        if (txta.setSelectionRange) {
            txta.focus();
            var curpos = txta.selectionStart + step;
            txta.setSelectionRange(curpos, curpos);
        }
    }

    function openFile(dir, dt) {
        // For shell-scripts, processing a (x-www-form-urlencoded) POST request
        // can be problematic. We use a GET request as a reliable work-around.
        var fname = document.getElementById('name').value;
        if (fname) {
            if (fname.indexOf('/') < 0) {
                fname = dir + '/' + fname;
            }
            window.location.href='editor.cgi?name=' + fname + '&dir=' + dir + '&dt=' + dt;
        }
    }

    function toggleAssist() {
        var ast = document.getElementById('assist');
        if (ast.style.display == 'block') {
           ast.style.display = 'none';
        } else {
           ast.style.display = 'block';
        }
    }

    function init() {
        // Detect if the assist controls should be shown. This method of
        // detection is not accurate and is really just testing the age
        // of the browser, rather than if the controls are actually needed.
        // DOM_VK_* values are defined in the W3C DOM Level 3 spec (2001).
        var ast = document.getElementById('assist');
        if (typeof this.KeyEvent.DOM_VK_RETURN == 'undefined') {
            ast.style.display = 'block';
        } else {
            ast.style.display = 'none';
        }

    }
</script>
EOF

echo "</head>"
echo "<body onload='init()'>"

printHeader editor

echo "<form action='/$0' method='POST' enctype='multipart/form-data'>"

  echo "<input type='hidden' name='dir' value='$DIR' />"
  echo "$DIR<br>"


  echo "<p>"
  echo "  <input type='button' onclick='openFile(\"$DIR\", \"$DT\")' value='Open' />"
  echo "  <input type='submit' name='act' value='Save' />"
  echo "  <input type='text' name='name' id='name' value='$FNAME' size='50' />"
  echo "  <input type='button' value='Assist' onclick='toggleAssist()' />"
  echo "</p>"

  if [ ! -z "$FNAME" ]; then
    if [ ! -f "$FNAME" ]; then
      echo "<p>Error: <tt>$FNAME</tt> does not exist</p>"
    fi
  fi

  echo "<p id='assist'>"

  echo "  <span class='ctl'><input type='button' value='<<' onclick='moveCursor(-1)' /><input type='text' value='10' id='curstep' size='2' /><input type='button' value='>>' onclick='moveCursor(1)' /></span>"

  echo "  <span class='ctl'><input type='text' value='||' id='ret' size='2' /><input type='button' value='Enter' onclick='insertReturn()' /></span>"

  echo "  <span class='ctl'><input type='text' value='@@' id='tab' size='2' /><input type='button' value='Tab' onclick='insertTab()'/></span>"

  echo "  <span class='ctl'><input type='text' value='^^' id='tok' size='2' /><input type='text' value='12' id='code' size='2' /><input type='button' value='Any' onclick='insertAny()' /></span>"

  echo "</p>"

  echo "<textarea rows='20' name='data' id='ta'>"
  if [ -f "$FNAME" ]; then
      cat "$FNAME"
  fi
  echo "</textarea>"

echo "</form>"

echo '</body>'
echo '</html>'
