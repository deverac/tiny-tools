# Un-commented source: https://github.com/milosz/sed-octo-proctor/
# This file contains sed commands to remove comments from a shell script.
# It does a good enough job, but is not perfect. For example, this line can
# confuse it: TMP=$(echo "$DIR" | sed -e 's#[^/]*$##')  # A comment here
# The examples below may also confuse it, but can be fixed by quoting them.
#   ${#VAR}    Length of VAR
#   ${VAR#??}  Substring of VAR
#
# An actual shell-script parser is available: https://github.com/mvdan/sh.
# It requires Go 1.20 or later.


# Ignore the first line if it's a shebang.
1 {
  /^#!/ {
    p
  }
}

# Delete line comments.
/^[\t\ ]*#/d

# Any line with a comment in it.
/\.*#.*/ {

  # Remove comments from lines without ' or " characters.
  /[\x22\x27].*#.*[\x22\x27]/ !{
    :regular_loop
      s/\(.*\)*[^\$]#.*/\1/
    t regular_loop
  }

  # Remove comments from lines with ' or " characters.
  /[\x22\x27].*#.*[\x22\x27]/ {
    :special_loop
      s/\([\x22\x27].*#.*[^\x22\x27]\)#.*/\1/
    t special_loop
  }

  # Remove comments from lines with an escaped # character.
  /\\#/ {
    :second_special_loop
      s/\(.*\\#.*[^\]\)#.*/\1/
    t second_special_loop
  }

  # Remove comments from lines with $#
  /$#/ {
    :third_special_loop
      s/\(.*$#.*[^$\]\)#.*/\1/
    t third_special_loop
  }
}
