#!/bin/sh
set -e

. ./common.src

# Replacement for $(dirname $0)
basedir() {
    echo "$1" | sed -e 's|[^/]*$||' -e 's|/*$||'
}

WWWDIR="$(pwd)/$(basedir $0)"

# Parse the QUERY_STRING (for GET or POST).
OLDIFS=$IFS
IFS="&"
for KEYVAL in $QUERY_STRING; do
  case "$KEYVAL" in
    dir=*) RAW_DIR=$(echo "$KEYVAL" | cut -b 5-) ;;
  esac
done
IFS=$OLDIFS


TGT_DIR=$(if [ ! -z "$RAW_DIR" ]; then decodeUrl "$RAW_DIR"; fi)
if [ ! -z "$TGT_DIR" ]; then
  cd "$TGT_DIR"
fi
DIR=$(pwd)

if [ "x$REQUEST_METHOD" = "xPOST" ]; then
    decodeMultipartPost

    OUTFIL="$(pwd)/${POSTVAR_filename}"

    if [ ! -z "$POSTVAR_decode" ]; then
        DECODE_RESULT=$("$WWWDIR/../bin/decode.sh" "$OUTFIL")
        if [ $? -ne 0 ]; then
            DECODE_RESULT="Decoding failed."
        fi
    fi

fi





echo "Content-type: text/html; charset=utf-8"
echo "Expires: 0" # Expire immediately

echo "" # Empty line is required

echo "<!DOCTYPE html>"
echo "<html>"
echo "<head>"
echo "    <title>TTUpload</title>"
cat << EOF
<style type='text/css'>
    html { margin: 4px;  font-family: sans-serif; }
    .hdr { background-color: whitesmoke; padding: 4px; font-weight: bold }
    .instr {background-color: lightgray; }
    pre { font-size: 12pt; }
</style>
EOF
echo "</head>"
echo "<body>"

printHeader upload

echo "<p>$DIR</p>"


echo "<form method='POST' action='/$0?dir=$DIR' enctype='multipart/form-data'>"
echo "<input name='filename' type='file' />"
echo "<input name='decode' type='checkbox' checked >Decode"
echo "<input name='act' type='submit' value='Upload'>"
echo "</form>"

if [ ! -z "${CONTENT_LENGTH}" ]; then
  echo "<p>Uploaded data was saved to $OUTFIL</p>"
  echo "<p>$DECODE_RESULT</p>"
fi

echo "<div class='instr'>"
echo "<p>The file <b>MUST</b> be plain text or text-encoded (Uuencode, Base64, Hex, or Oct).<br>"
echo "</div>"

echo "<div class='instr'>"
echo "<pre>"
echo "<b><u>METHODS OF TEXT-ENCODING A FILE</u></b>"
echo "<b>Base64</b>: base64 file.bin > file.b64"
echo "<b>Uuencode</b>: uuencode file.bin file.bin > file.uue"
echo "<b>Hex</b>: hexdump -C -v file.bin | cut -b 11-59 > file.hex"
echo "<b>Hex</b>: xxd -g 1 file.bin | cut -b 11-59 > file.hex"
echo "<b>Hex</b>: od -A n -t x1 -v file.bin > file.hex"
echo "<b>Oct</b>: hexdump -b -v file.bin | cut -b 9- > file.oct"
echo "<b>Oct</b>: od -A n -t o1 -v file.bin > file.oct"
echo "</pre>"
echo "</div>"


echo '</body>'
echo '</html>'
