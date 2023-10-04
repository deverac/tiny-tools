#!/bin/sh
set -e

DIST=./dist

# Minify a single file.
minifyFile() {
    FIL="$1"
    if [ -e "$FIL" ]; then
        ORIG="${FIL}.orig"
        cp "$FIL" "$ORIG"
        sed -f ./src/remove_comments.sed "$ORIG" | sed "s/^[ \t]*//" | sed '/^[[:space:]]*$/d' > "$FIL"
        rm "$ORIG"
    fi
}

# Minify specific files.
minifyProj() {
    TGT=$1

    for nm in common.src browser.cgi editor.cgi index.cgi upload.cgi; do
        minifyFile $TGT/www/$nm
    done

    for nm in shreq.sh shserv.sh shserver.sh decode.sh hex2bin.sh oct2bin.sh; do
        minifyFile $TGT/bin/$nm
    done
}

# Create dist directory.
buildProj() {
    TGT=$1
    mkdir -p $TGT

    cp -r ./src/bin        $TGT
    cp -r ./src/www        $TGT
    cp -r ./src/shserv/*   $TGT/bin

    chmod +x $TGT/bin/*
    chmod +x $TGT/www/*.cgi
}

# Helper function for doMinDiff().
# 'git diff' is used to demarcate all differences that are not whitespace.
# The demarcated text (which should only consist of comments) is extracted
# and trimmed. Every line of the trimmed text should begin with '#'.
gitDiff() {
  git diff -U0 --word-diff --no-index  $1 $2  | sed -e 's/.*\({+.*\)+}.*/\1/' | grep ^{+ | sed -e 's/^{+[ ]*//'
}

# Check for code differences between the dist and the minified dist.
doMinDiff() {
    D1=$1
    D2=${1}-min
    rm -rf $D1
    rm -rf $D2
    doDist    $D1
    doDistMin $D2

    for FIL in $(cd ./$D1 && ls -1 www/* bin/*); do
        RESULT=$(gitDiff ./$D2/$FIL ./$D1/$FIL)
        # Find a line that does not begin with '#'.
        if  echo "$RESULT" | grep -q ^[^#]; then
            echo "$FIL"
            echo "   'git diff' has detected a code difference between the source"
            echo "   file and its minified version. This does not necessarily mean"
            echo "   there *is* a difference. The lines below should help identify"
            echo "   where/what the difference is. To satisfy 'git diff', try"
            echo "   (re)moving comments and/or quoting variables on the line."
            echo "-------------------------------------"
            # Show result with context.
            echo "$RESULT" | grep -B 2 -A 2 ^[^#]
            exit
        fi
    done
    rm -rf $D1
    rm -rf $D2
}



# Clean generated files.
doClean() {
    rm -rf $1
}

# Build dist.
doDist() {
    doClean $1
    buildProj $1
}

# Build dist and minimize.
doDistMin() {
    doDist $1
    minifyProj $1
}

# Run server for distribution.
doRun() {
    if [ ! -d $1 ]; then
        doDist $1
    fi
    ./src/shserv/shserv.sh 8080 ./$1/www
}

# Run server for development.
doRunDev() {
    ./src/shserv/shserv.sh 8080 ./src/www
}

# Show help text.
doHelp() {
    echo "Usage: $0 TARGET"
    echo "TARGET is one of:"
    echo "  clean     Removes generated files."
    echo "  dist      Build distribution version in $1."
    echo "  distmin   Build minified version of 'dist'."
    echo "  mindiff   Check for differences between dist and distmin. (Requires git.)"
    echo "  run       Start ShServer on port 8080 in $1/www."
    echo "  rundev    Start ShServer on port 8080 in ./src/www."
    echo "Minimized builds have all comments and leading whitespace removed"
    echo "which noticably improves response times on low-powered devices."
    exit
}

case $1 in
    clean)   doClean $DIST;;
    dist)    doDist $DIST;;
    distmin) doDistMin $DIST;;
    mindiff) doMinDiff $DIST;;
    run)     doRun $DIST;;
    rundev)  doRunDev;;
    *)       doHelp $DIST;;
esac
