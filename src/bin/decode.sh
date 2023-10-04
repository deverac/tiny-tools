#!/bin/sh
set -e

isUuencoded() {
   (sed 10q "$1" | grep -q "^begin ") && (grep -q "^end$" "$1")
}

isBase64() {
   # The last two characters (plus and forward-slash) vary between base64 implementations.
   (! grep -q [^A-Za-z0-9=+/] "$1")
}

isHexEncoded() {
    IS_HEX=1
    # Sample some (four) lines and check if every 'word' is two characters.
    for wrd in $(sed 4q "$1"); do
        if [ "${#wrd}" -ne 2 ]; then
            IS_HEX=0
            break
        fi
    done
    [ "$IS_HEX" = "1" ]
}

isOctEncoded() {
    IS_OCT=1
    # Sample some (four) lines and check if every 'word' is three characters.
    for wrd in $(sed 4q "$1"); do
        if [ "${#wrd}" -ne 3 ]; then
            IS_OCT=0
            break
        fi
    done
    [ "$IS_OCT" = "1" ]
}

# Replacement for $(dirname $0)
basedir() {
    echo "$1" | sed -e 's|[^/]*$||' -e 's|[/]*$||'
}

BASEDIR=$(basedir "$0")

if [ "$#" -lt 1 ]; then
    echo "Output a binary file from uuencoded, base64, hex, or oct data."
    echo "Usage: $0 INFILE"
    echo "   INFILE   File containing encoded data"
    echo "The name of the output file is derived from INFILE. If INFILE has an"
    echo "extension, it will be removed. If INFILE has no extension or the derived"
    echo "name of the outfile exists, '.out' will be appended to the INFILE name."
    echo "Uuencoded data includes the filename (and permissions) of the original file"
    echo "so generating an output file name is skipped."
    echo "The type of encoded data in INFILE is auto-detected but is not perfect."
    exit
fi

# Assign the INFILE
FIL="$1"

# Assign the OUTFILE
if [ -z "$2" ]; then
    NM="${FIL%.*}" # Remove the extension.
    if [ -e "$NM" ]; then
        NM="${NM}.out"
    fi
else
    NM="$2"
fi

if isHexEncoded "$FIL"; then
    echo "Decoding hex-encoded data to $NM"
    $BASEDIR/hex2bin.sh "$FIL" "$NM"
elif isOctEncoded "$FIL"; then
    echo "Decoding oct-encoded data to $NM"
    $BASEDIR/oct2bin.sh "$FIL" "$NM"
elif isUuencoded "$FIL"; then
    echo "Decoding uuencoded data to $PWD"
    cat "$FIL" | uudecode
elif isBase64 "$FIL"; then
    echo "Decoding base64 data to $NM"
    cat "$FIL" | base64 -d > "$NM"
else
    echo "Writing text data to $NM"
    cat "$FIL" > "$NM"
fi
