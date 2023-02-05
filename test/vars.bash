
# These test cases exist to stress test our `env` to `$GITHUB_ENV` logic; we
# want to make sure that "weird" env variable values still roundtrip.
#
# Anything starting with `TESTCASE_` is roundtripped; i.e.:
#  - added to a nix develop shell
#  - added to `$GITHUB_ENV` by this action
#  - compared against the original form of the variable, after base64-ing

export TESTCASE_SIMPLE="hello"
export TESTCASE_SPACES=" hey there, "
export TESTCASE_TRAILING_SPACES=" "

export TESTCASE_EMPTY=""
export TESTCASE_QUOTE="\""
export TESTCASE_QUOTES="\"\"\"''\"'"
export TESTCASE_QUOTES="\"\"\"''\"'"
export TESTCASE_PARENS="(((((((()()())))"

export TESTCASE_SPECIAL_CHARS="<<><>>#))(&D(&*#:LJHY^R%!$%^RFTYDGIH(#*)(D_)+P{CEOIJFHG><CE:E:PC{#)CJP{{"

# shellcheck disable=SC1111
export TESTCASE_NON_ASCII="gfg∆˙©ƒ©†˙∆¨¥†©√ç∂ ˆ   ™¨˙∂ˆ™´\e[1;34m˙ƒø•´ç©\e[0m † ˆ´˙çˆø¨™⭕️🙂😬woiefjwoeij≥≤µ˜◊ÇÓ‰´›ÁØ‚·°Ø±±’’”"

export TESTCASE_ESCAPES="\t\t\t\t\t\n\n\n\e\e\e\e\\\"\'\\\r\r"

export TESTCASE_MULTILINE="

  fjio
    wpeijf  .

"
export TESTCASE_NEWLINE="
"

# shellcheck disable=SC2016
export TESTCASE_UNEVAL='$PATH'

# Technically variable *names* are permitted to have special characters too
# (Linux will accept anything that does not have ASCII nuls in it, I think) and
# `env` will happily regurgitate such vars (*and* `$GITHUB_ENV` will let us
# such vars) but: as far as I know there's no way to set such variables from
# bash.
#
# So we'll leave things like `export "VAR With Spaces"=3` untested.
#
# According to the bash manual identifiers are allowed to have alphanum chars,
# numbers, and underscores (and are not allowed to start with a number).
#
# So:
export TESTCASE__='~~~'
export TESTCASE_d22="039ur"
export TESTCASE_Jff555HuhuyHHUYgikj_iuYr__3434_="test"

# shellcheck disable=SC2155
export TESTCASE_BIG="$(cat "test/vars.bash")"

# Also see: https://unix.stackexchange.com/questions/59360/what-is-the-zsh-equivalent-of-bashs-export-f
#
# We will not test this.
