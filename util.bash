
# https://docs.github.com/en/actions/using-workflows/workflow-commands-for-github-actions
function debug() { echo -n "::debug::"; echo -e "${@}"; }
if [[ "${NDEBUG:+true}" == "true" ]]; then debug() { :; }; fi
function notice() { echo -n "::notice::"; echo -e "${@}"; }
function warn() { echo -n "::warning::"; echo -e "${@}"; }
function error() { echo -n "::error::"; echo -e "${@}"; }
function errorAndExit() { error "${@}"; exit "${ec-1}"; }

