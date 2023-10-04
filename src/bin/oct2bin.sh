#!/bin/sh
set -e

# This script reads a file containing three-character octal values and
# outputs their binary equivalent. The octal chars on each line must
# be separated by one or more spaces. Any number of three-character
# octal values can appear on a line.
# E.g.
#     177 105 114 106 001
#     002 000 003 000 001
#     314 014 000 000 000
#     044 000 041 000 006
#     064 200 004 010 340
#
# This script uses no external commands and is targeted to work
# under the busybox v1.10.2 ash shell.


if [ "x$1" = "x-h" ]; then
    echo "Convert a file of octal values into binary."
    echo "Usage: $0 [infile [outfile]] [-h]"
    echo "       cat infile | $0 > outfile"
    echo " -h  Show this help."
    echo "The following commands can generate a suitable file of octal values:"
    echo "    hexdump -b -v file.bin | cut -b 9- > file.oct"
    echo "    od -A n -t o1 -v file.bin > file.oct"
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

while read line; do
    # Do not quote $line; we depend on it being expanded.
    for ch in $line; do
        if [ "${#ch}" = "3" ]; then

            if [ ! -z "$PREV_CH" ]; then
                echo "Error: Read invalid hex value: $PREV_CH" > /dev/stderr
                exit 1
            fi

            # Prefix with '0', if needed.
            if [ ! -z "$PREFIX_ZERO" ]; then
                ch="0$ch"
            fi

            # Output character without adding newline.
            echo -n $E_PARM "\\$ch" >> "$OUTFIL"

        else
            # We have a value that is not three characters long. In some cases,
            # depending on how this script is called, it can be a newline
            # character at the very end of the oct data; this is normal
            # and should be ignored. In any other case, it is bad data.
            # Testing for a single newline in some shells seems to not be
            # possible (without using external tools), so we will simply
            # remember that the value has been read.
            if [ "${#ch}" = "1" ]; then
                PREV_CH="$ch"
            else
                echo "Error: Bad oct value: $ch" > /dev/stderr
                exit 1
            fi
        fi
    done
done < "$INFIL"
