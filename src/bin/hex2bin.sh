#!/bin/sh
set -e

# This script reads a file containing two-character hex values and
# outputs their binary equivalent. The hex chars on each line must
# be separated by one or more spaces. Any number of two-character
# hex values can appear on a line.
# E.g.
#     7f 45 4c 46 01
#     02 00 03 00 01
#     cc 0c 00 00 00
#     24 00 21 00 06
#     34 80 04 08 e0
#
# This script uses no external commands and is targeted to work
# under the busybox v1.10.2 ash shell.

if [ "x$1" = "x-h" ]; then
    echo "Convert a file of octal values into binary."
    echo "Usage: $0 [infile [outfile]] [-h]"
    echo "       cat infile | $0 > outfile"
    echo " -h  Show this help."
    echo "The following commands can generate a suitable file of hex values:"
    echo "  hexdump -C -v file.bin | cut -b 11-59 > file.hex"
    echo "  xxd -g 1 file.bin | cut -b 11-59 > file.hex"
    echo "  od -A n -t x1 -v file.bin > file.hex"
    exit
fi

# Set the file to read from.
if [ -z "$1" ]; then
    INFIL=/dev/stdin
else
    INFIL="$1"
fi

# Set the file to write to.
if [ -z "$2" ]; then
    OUTFIL=/dev/stdout
else
    OUTFIL="$2"
    rm -f "$OUTFIL"
fi

# Determine how to get 'echo' to output an octal value.
#   The Ash shell requires that '-e' be used. (Busybox uses Ash.)
#   The Dash shell requires that '-e' not be used. (Dash will print '-e'.)
#   The Bash shell requires that '-e' be used and the value be prefixed with 0.
#   Other shells may be some variation of the above.
E_PARM=
PREFIX_ZERO=

OCT_A=$(echo -e "\0101") # Octal 101 == 'A'
if [ "$OCT_A" = "A" ]; then
    PREFIX_ZERO=1
    E_PARM="-e"
fi

if [ -z $PREFIX_ZERO ]; then
    OCT_B=$(echo "\0102")  # Octal 102 == 'B'
    if [ "$OCT_B" = "B" ]; then
        PREFIX_ZERO=1
    fi
fi

if [ -z $E_PARM ]; then
    OCT_C=$(echo -e "\103")  # Octal 103 == 'C'
    if [ "$OCT_C" = "C" ]; then
        E_PARM="-e"
    fi
fi

PREV_CH=

# Eliminating subshells and function calls decreased the time required
# to decode a file of hex data from 76 seconds to one second.
while read line; do
    for ch in $line; do

        if [ "${#ch}" = "2" ]; then

            if [ ! -z "$PREV_CH" ]; then
                echo "Error: Read invalid hex value: $PREV_CH" > /dev/stderr
                exit 1
            fi

            C1="${ch%?}" # First character of $ch.
            C2="${ch#?}" # Second character of $ch.

            # Convert two-character hex-code to its eight-character
            # binary representation. A "0" is prepended making it
            # a nine-character string of zeros and ones.
            BIN="0"
            case "$C1" in
              0) BIN="${BIN}0000";;
              1) BIN="${BIN}0001";;
              2) BIN="${BIN}0010";;
              3) BIN="${BIN}0011";;
              4) BIN="${BIN}0100";;
              5) BIN="${BIN}0101";;
              6) BIN="${BIN}0110";;
              7) BIN="${BIN}0111";;
              8) BIN="${BIN}1000";;
              9) BIN="${BIN}1001";;
              a|A) BIN="${BIN}1010";;
              b|B) BIN="${BIN}1011";;
              c|C) BIN="${BIN}1100";;
              d|D) BIN="${BIN}1101";;
              e|E) BIN="${BIN}1110";;
              f|F) BIN="${BIN}1111";;
            esac

            case "$C2" in
              0) BIN="${BIN}0000";;
              1) BIN="${BIN}0001";;
              2) BIN="${BIN}0010";;
              3) BIN="${BIN}0011";;
              4) BIN="${BIN}0100";;
              5) BIN="${BIN}0101";;
              6) BIN="${BIN}0110";;
              7) BIN="${BIN}0111";;
              8) BIN="${BIN}1000";;
              9) BIN="${BIN}1001";;
              a|A) BIN="${BIN}1010";;
              b|B) BIN="${BIN}1011";;
              c|C) BIN="${BIN}1100";;
              d|D) BIN="${BIN}1101";;
              e|E) BIN="${BIN}1110";;
              f|F) BIN="${BIN}1111";;
            esac

            # Convert the nine-character binary string to its
            # three-character octal equivalent.

            HED="${BIN%??????}"  # The first three characters of BIN
            TMP="${BIN#???}"
            MID="${TMP%???}"     # The second three characters of BIN
            TIL="${BIN#??????}"  # The last three characters of BIN

            OCT=
            case $HED in
              000) OCT="0";;
              001) OCT="1";;
              010) OCT="2";;
              011) OCT="3";;
              100) OCT="4";;
              101) OCT="5";;
              110) OCT="6";;
              111) OCT="7";;
            esac

            case $MID in
              000) OCT="${OCT}0";;
              001) OCT="${OCT}1";;
              010) OCT="${OCT}2";;
              011) OCT="${OCT}3";;
              100) OCT="${OCT}4";;
              101) OCT="${OCT}5";;
              110) OCT="${OCT}6";;
              111) OCT="${OCT}7";;
            esac

            case $TIL in
              000) OCT="${OCT}0";;
              001) OCT="${OCT}1";;
              010) OCT="${OCT}2";;
              011) OCT="${OCT}3";;
              100) OCT="${OCT}4";;
              101) OCT="${OCT}5";;
              110) OCT="${OCT}6";;
              111) OCT="${OCT}7";;
            esac

            # Prefix with '0', if needed.
            if [ ! -z "$PREFIX_ZERO" ]; then
                OCT="0$OCT"
            fi

            # Output the octal character.
            echo -n $E_PARM "\\$OCT" >> "$OUTFIL"

        else
            # We have a value that is not two characters long. In some cases,
            # depending on how this script is called, it can be a newline
            # character at the very end of the hex data; this is normal
            # and should be ignored. In any other case, it is bad data.
            # Testing for a single newline in some shells seems to not be
            # possible (without using external tools), so we will simply
            # remember that the value has been read.
            if [ "${#ch}" = "1" ]; then
                PREV_CH="$ch"
            else
                echo "Error: Bad hex value: $ch" > /dev/stderr
                exit 1
            fi
        fi
    done
done < "$INFIL"
