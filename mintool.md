## Minimizing external tools (a.k.a. stupid shell tricks)

Tiny-tools and shServer rely on the following external tools: `cat`, `cut`,
`echo`, `grep`, `ls`, `nc`, `rm`, `sed`. This page illustrates scripting
techniques that can be used to reduce the list to three: `ls`, `nc`, and `sed`.
Replacing an external tool with a shell-equivalent is not recommended, but
might be useful is some situations.

 * `cat` can be replaced with redirection.
   (e.g. `while read line; do echo $line; done < file.txt`) `sed` can also
   be used to replace `cat`. `sed -n 'p' file.txt` will display the
   contents of file.txt.
   `sed -n 'p' file1.bin > out.bin; sed -n 'p' file2.bin >> out.bin` will
   concatenate file1.bin and file2.bin.
   `sed -n 'p' file1.bin file2.bin > out.bin` will also concatenate the
   two files but will insert a newline character between each file. For
   some `sed` versions, concatenating files will work on binary files;
   other `sed` versions will always append a newline after each file.

 * `cut` can be replaced with `sed`.
   (e.g. `echo "abcdefg" | sed -e 's/^..\(...\).*$/\1/'`)

 * `echo` cannot be replaced perfectly, but work-arounds may exist. To display
   text, `"message" 2>&1 | sed -e 's/^sh: \(.*\): not found$/\1/'` will print
   `message` (and a newline); this technique can also be used to display the
   contents of a variable. Most `echo` programs have the ability to interpret
   backslash sequences. Any version of `sed` that can interpret
   backslash sequences (e.g. `echo "a" | sed -e 's/a/\x41/'` prints 'A') can
   be used as a replacement. Another feature of `echo` is the ability to
   print text without a newline character at the end. This feature is
   impossible to duplicate with `sed` because `sed` appends a newline to any
   line it processes.

 * `grep` can be replaced with `sed`. To return all lines that match a
   pattern: `sed -n -e '/pattern/p' file.txt`; this will always return an
   exit code of 0 even if no matching lines are found. To return an exit
   code of 0 if the pattern is found and a non-zero exit code if the pattern
   is not found:
   `MAT=$(sed -n -e '/pattern/p' file.txt); $(if [ "${#MAT}" = "0" ]; then exit 1; fi);`.

 * `rm` is not technically not necessary. An empty file can be created, or the
   contents of a file can be erased with `sed -e '/^/d' /dev/null > file.txt`.
   shServer saves POSTed data to a (mostly) unique filename, then processes the
   data, and then deletes the file. If `rm` were not used, shServer would need
   to save POSTed data to the same file in order to avoid constantly creating
   temporary files that it never deletes.


    #!/bin/sh
    set -e

    # This script is more interesting than useful. There are easier, faster,
    # and better ways to accomplish what this script does.
    #
    # This script converts a file containing two-character hex-values,
    # separated by spaces, to their binary equivalents.
    #
    # sed, and only sed, is used. No other tool, like echo or cat, is used.
    # As a consequence of using sed, a final newline character (0x0a) will be
    # appended to the end of the output file. The final newline will
    # not affect the functionality of the executable, but will cause
    # programs like diff, md5sum, and sha256sum to return differing values
    # from the original executable.
    #
    # The success of this script depends on sed being able to interpret
    # escaped values (e.g. '\n', '\x41').
    #
    #
    # To convert a binary file to a file of two-character hex-values:
    #     hexdump -v -C file.bin | cut -b 11-58 > data.hex

    INFIL=data.hex
    OUTFIL=out.bin

    rm -f "$OUTFIL"
    (
        while read LIN; do
            for ch in $LIN; do
                # 'bogusCmd' is ignored; sed is used to output binary values.
                "bogusCmd" 2>&1 | sed -e "s/.*/\x$ch/"
            done
        done < "$INFIL"
    ) | sed -e '/^$/{n;d}' | sed -e 's/^$/x_NEWLINE_x/g' | sed -e ':x; /$/{N; s/\n//; bx}' | sed -e 's/x_NEWLINE_x/\n/g' > "$OUTFIL"

    # sed -e '/^$/{n;d}'              # Convert each pair of empty lines to one.
    # sed -e 's/^$/x_NEWLINE_x/g'     # Replace empty lines with 'x_NEWLINE_x'
    # sed -e ':x; /$/{N; s/\n//; bx}' # Join all lines, removing newlines.
    # sed -e 's/x_NEWLINE_x/\n/g'     # Replace 'x_NEWLINE_x' with a newline.
