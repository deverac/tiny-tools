#!/bin/sh
set -e

. ./common.src

# Parse query string.
OLDIFS=$IFS
IFS="&"
for KEYVAL in $QUERY_STRING; do
   case "$KEYVAL" in
       cmd=*) RAW_CMD=$(echo "$KEYVAL" | cut -b 5-);;
       dir=*) RAW_DIR=$(echo "$KEYVAL" | cut -b 5-);;
   esac
done
IFS=$OLDIFS


USER_ID=$(cat /proc/$PPID/status | grep Uid: | cut -f 2)
PRMPT=$(if [ "x$USER_ID" = "x0" ]; then echo '#'; else echo '$'; fi)
CMD=$(if [ ! -z "$RAW_CMD" ]; then decodeUrl "$RAW_CMD"; fi)

WORK_DIR=$(if [ -z "$RAW_DIR" ]; then pwd; else decodeUrl "$RAW_DIR"; fi)
if [ ! -z "$WORK_DIR" ]; then
  cd $WORK_DIR
fi
DIR=$(pwd)

echo "Content-type: text/html; charset=utf-8"
echo "Cache-Control: no-store"
echo "Expires: 0" # Expire immediately
echo "" # Empty line is required
echo "<!DOCTYPE html>"
echo "<html>"
echo "<head>"
echo "<title>TTShell</title>"

cat << EOF
<style type='text/css'>
    html { margin: 4px; font-family: sans-serif; }
    .hdr { background-color: whitesmoke; padding: 4px; font-weight: bold }
    #cmd { width: 20%; }
</style>
EOF

cat << EOF
<script type='text/javascript'>
    // The Enter key and the 'form.submit()' function may not work in some
    // browsers, so repeatedly read value of 'cmd' and if it ends with
    // three spaces, then submit the form by clicking button.
    function init() {
        var cmd = document.getElementById('cmd');
        if (cmd) {
            var tail = cmd.value.substr(-3);
            if (tail == '   ') {
                // Remove tail from command.
                cmdval = cmd.value;
                cmd.value = cmdval.substr(0, cmdval.length-tail.length);
                // Submit form.
                var btn = document.getElementById('subm');
                if (btn) {
                    btn.click();
                }
            }
        }
        setTimeout(init, 100);
    }
</script>
EOF

echo "</head>"
echo "<body onload='init()'>"


case "$CMD" in
    cd[\ ]*) NEWDIR=$(echo "$CMD" | cut -b 4-)
          cd "$NEWDIR"
          DIR=$(pwd)
          ;;
    *) OUTP=$(eval "$CMD");; # Execute command. Using eval allows multiple commands separated by semi-colon.
esac

printHeader shell "$DIR"

echo "<p>$DIR</p>"

echo "<form method='GET' action='/$0' id='frm'>"
echo "  $PRMPT <input id='cmd' name='cmd' type='text' autofocus />"
echo "  <input name='dir' type='hidden' value='$DIR' />"
echo "  <input name='dt' type='hidden' value='$DT' />"
echo "  <input id='subm' type='submit' value='Run'>"
echo "</form>"

echo "<pre>"
echo "$OUTP" | sed -e 's/</\&lt;/g'
echo "</pre>"

echo '</body>'
echo '</html>'
