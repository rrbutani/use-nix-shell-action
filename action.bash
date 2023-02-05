#!/usr/bin/env bash

set -euo pipefail

source "$(dirname "$0")/util.bash"

# Contexts: https://docs.github.com/en/actions/learn-github-actions/contexts
# Commands: https://docs.github.com/en/actions/using-workflows/workflow-commands-for-github-actions

readonly GITHUB_ENV_FILE="${1-"nix-shell.env"}"
readonly GITHUB_PATH_FILE="${2-"nix-shell.path"}"

#################################   Inputs   ##################################

# $1: opt var; $2: input name
checkBoolOption() {
    local v="INPUT_${1}"
    if ! [[ "${!v}" == "true" || "${!v}" == "false" ]]; then
        ec=2 errorAndExit "Input '$2' must be a boolean: 'true' or 'false'; got: '${!v}'"
    fi
}

readonly INPUT_EXPORT_ENV=${INPUT_EXPORT_ENV-true}
checkBoolOption EXPORT_ENV exportEnv

readonly INPUT_PRESERVE_DEFAULT_PATH=${INPUT_PRESERVE_DEFAULT_PATH-true}
checkBoolOption PRESERVE_DEFAULT_PATH preserveDefaultPath

readonly INPUT_PACKAGES_SET=${INPUT_PACKAGES:+true}
readonly INPUT_FLAKES_SET=${INPUT_FLAKES:+true}
readonly INPUT_DEVSHELL_SET=${INPUT_DEVSHELL:+true}
readonly INPUT_FILE_SET=${INPUT_FILE:+true}

# Can only have 1 input:
_to_int() { if [[ "${!1}" == "true" ]]; then echo "1"; else echo "0"; fi }
num_input_sources_set=$((
    $(_to_int INPUT_PACKAGES_SET) +
    $(_to_int INPUT_FLAKES_SET) +
    $(_to_int INPUT_DEVSHELL_SET) +
    $(_to_int INPUT_FILE_SET)
))

case $num_input_sources_set in
    0)
        debug "falling back to default shell source: devShell from flake at the top-level"
        INPUT_DEVSHELL=".#"
        INPUT_SOURCE="INPUT_DEVSHELL"
        ;;
    1)
        if [[ $INPUT_PACKAGES_SET == "true" ]]; then
            INPUT_SOURCE="INPUT_PACKAGES"
            IFS=", " read -ra INPUT_PACKAGES_LIST <<<"$INPUT_PACKAGES"
        elif [[ $INPUT_FLAKES_SET == "true" ]]; then
            INPUT_SOURCE="INPUT_FLAKES"
            IFS=", " read -ra INPUT_FLAKES_LIST <<<"$INPUT_FLAKES"
        elif [[ $INPUT_DEVSHELL_SET == "true" ]]; then
            INPUT_SOURCE="INPUT_DEVSHELL"
        elif [[ $INPUT_FILE_SET == "true" ]]; then
            INPUT_SOURCE="INPUT_FILE"
        else
            error unreachable
        fi
        ;;

    *)  # shellcheck disable=SC2016
        ec=3 errorAndExit \
            "Must only specify one nix shell source; got: $num_input_sources_set sources: " \
                ${INPUT_PACKAGES:+'`packages`'} \
                ${INPUT_FLAKES:+'`flakes`'} \
                ${INPUT_DEVSHELL:+'`devShell`'} \
                ${INPUT_FILE:+'`file`'}
       ;;
esac
readonly INPUT_SOURCE
debug "grabbing nix shell from: '${INPUT_SOURCE/INPUT_/}' with: '${!INPUT_SOURCE}'"

# shellcheck disable=SC2206
declare -a INPUT_EXTRA_NIX_OPTIONS=(${INPUT_EXTRA_NIX_OPTIONS-})

###############################################################################

#################################   Helpers  ##################################

# TODO: it would be neat to turn nix error messages into `warning`/`error`
# annotations...

function echoAndRun() {
    echo "running: \`${*@Q}\`" >&2
    command "${@}"
}
function nixCmd() {
    echoAndRun nix \
        "${1}" --extra-experimental-features "nix-command flakes" \
        "${@:2}"
}

###############################################################################

# in section
# TODO: print what's in the shell in markdown

# in section
# TODO: print exported env in markdown

# notice for each?

# echo "::group::TODO"

# echo "$@"
# env
# echo "::endgroup::"

# TODO: don't set `PATH` in `GITHUB_ENV`; append instead?

# TODO(feature): deny list/allow list for env vars..
