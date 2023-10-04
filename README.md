# Tiny-tools and shServer

Tiny-tools is a collection of CGI (Common Gateway Interface) programs written
as shell-scripts. Tiny-tools allows interaction with a remote computer through
a web browser interface and has four tools:

     Browser - Navigate the file system of the remote computer
     Editor - Edit text files on the remote computer
     Shell - Run commands on remote computer
     Upload - Upload a file to the remote computer

A simple webserver, shServer, is also included. shServer, is a shell-script
that acts as a webserver and can run CGI scripts. It uses nc (netcat) to
connect to the network. shServer is not a real webserver, but it does just
enough to fool browsers into thinking it is one.

**WARNING: Tiny-tools and shServer should only be used on trusted systems and
networks.  There is no authentication or encryption and no effort is made to validate input. Neither Tiny-tools nor shServer has any defense against
malicious requests.**

Tiny-tools and shServer are shell-scripts but rely on the following external
programs: `cat`, `cut`, `echo`, `grep`, `ls`, `nc`, `rm`, `sed`. No other
programs are needed. If available, `setsid` can be used to create a detached
process which may be useful in some circumstances. `sleep` and `kill` are also
used, but are not required.

Shells support various features and syntax. The shell-scripts of Tiny-tools and
shServer were designed to run under busybox v1.10.4 `ash`, `dash` v0.5.11, and
`bash` v5.1.4.

## Advantages

 * Provides useful tools (Browser, Editor, Shell, Upload) for interacting with
   a computer through a web-browser interface.

 * Tiny-tools and shServer are shell-scripts, so they should run on any
   (Linux) machine. No compiling, extra libraries, or CPU architecture to
   worry about.

 * Only a handful of common, external programs are needed. With a bit of
   [creative scripting](mintool.md), the number of external programs could
   be reduced to three: `ls`, `nc`, and `sed`.

 * No install needed. Tiny-tools and shServer can run from a thumb-drive.
   With minor modifications they can also run from a FAT16 filesystem.

 * Tiny-tools and shServer complement each other, but can be used independently.
   Tiny-tools should work with any webserver that supports CGI. shServer can
   run custom CGI scripts.

 * Tiny-tools is only 20Kb; shServer is 4Kb. (Minified scripts; help files
   removed.)

## Limitations

Tiny-tools and shServer have many limitations. A few are listed below:

 * shServer is not a full-featured webserver. For example, the CGI
   specification lists seventeen variables that must be set, but shServer only
   sets four: CONTENT_LENGTH, QUERY_STRING, REQUEST_METHOD, SCRIPT_NAME.

 * Tiny-tools has no API, so CGI scripts must manually parse submitted data.
   Tiny-tools has [some functions](api.md#functions) that may be useful to CGI scripts.

 * shServer depends on `nc` being able to run a script when a connection is
   received. This capability is often removed in modern versions of netcat.

 * The output of the `ls` command is parsed to find the size of a file. This
   may not work if the output of `ls` differs. `wc` could be used instead.

 * Filenames with a space or other strange character may cause issues.

 * If no read-timeout is supported, shServer will not be able to process
   an 'application/x-www-form-urlencoded' POST request in the expected manner. Several methods for enabling read-timeout are attempted. If none
   are supported, a [work-around](api.md#readtimeout) can be used, instead.

## Running

    ./bin/shserv.sh [ PORT [ DIR ] ]

         PORT  The port to listen on. Default: 80.
         DIR   The directory to serve. Default: ./www.

shServer can also be started with shserver.sh, which is a wrapper-script that
runs shserv.sh as a detached process.

## Building

    ./build.sh dist       Build distribution (in ./dist)
    ./build.sh distmin    Build minified distribution (in ./dist)

    ./build.sh mindiff    Compare outputs of `dist` and `distmin` (requires git)

    ./build.sh run        Start shServer on port 8080 serving files in ./dist

The minified version has all comments removed (using
[sed-octo-proctor](https://github.com/milosz/sed-octo-proctor/))
and all leading spaces removed from the shell-scripts. Running the `mindiff`
target uses `git diff` to compare the normal version to the minified
version and will output any removed text that is not a comment.
