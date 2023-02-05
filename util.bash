
# https://docs.github.com/en/actions/using-workflows/workflow-commands-for-github-actions
function debug() { echo -n "::debug::"; echo -e "${@}"; }
if [[ "${NDEBUG:+true}" == "true" ]]; then debug() { :; }; fi
function notice() { echo -n "::notice::"; echo -e "${@}"; }
function warn() { echo -n "::warning::"; echo -e "${@}"; }
function error() { echo -n "::error::"; echo -e "${@}"; }
function errorAndExit() { error "${@}"; exit "${ec-1}"; }

# Note that unlike bash-style heredocs, the GitHub Actions CI runner seems to
# disregard the *required* trailing newline in a heredoc.
#
# For example, in bash it's impossible to have a heredoc represent "foo" because
# this is not valid:
# ```bash
# cat <<EOF
# fooEOF
# ```
#
# Instead you must do this:
# ```bash
# cat <<EOF
# foo
# EOF
# ```
# which is equivalent to `echo -ne "foo\n"`, not `"foo"`.
#
# Because the GitHub Actions CI runner seems to strip this required trailing
# newline, we can represent all our variables in heredocs which makes things
# simple for us.
function export_var() {
    # Colors:
    local color_bold='\033[0;1m' #(OR USE 31)
    local color_brown='\033[0;33m'
    local color_nc='\033[0m' # No Color

    local info="exporting env var '${color_bold}$1${color_nc}' as '${color_brown}${!1}${color_nc}'"
    debug "${info}"
    if [[ ${echo-false} == "true" ]]; then echo -e "$info" >&2; fi

    {
        echo "$1<<__EOV__"
        echo "${!1}" # note the added trailing newline here (see comment above)
        echo "__EOV__"
    } >> "$GITHUB_ENV"
}
