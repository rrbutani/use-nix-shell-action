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

readonly INPUT_SCRIPT_SET=${INPUT_SCRIPT:+true}
readonly INPUT_INTERPRETER=${INPUT_INTERPRETER-bash}
readonly INPUT_CLEAR_ENV_FOR_SCRIPT=${INPUT_CLEAR_ENV_FOR_SCRIPT-false}
checkBoolOption CLEAR_ENV_FOR_SCRIPT clearEnvForScript


# Warn if no script provided + `exportEnv == false`:
if ! [[ "$INPUT_EXPORT_ENV" == true || "$INPUT_SCRIPT_SET" == true ]]; then
    # shellcheck disable=SC2016
    warn '`exportEnv` is set to false and no script is provided; this action will have no side-effects'
fi

# shellcheck disable=SC2206
declare -a INPUT_EXTRA_NIX_OPTIONS=(${INPUT_EXTRA_NIX_OPTIONS-})

###############################################################################

#################################   Helpers  ##################################

# TODO: it would be neat to turn nix error messages into `warning`/`error`
# annotations...

function echoAndRun() {
    echo "::group::running: \`${*@Q}\`" >&2
    command "${@}"
    echo "::endgroup::" >&2
}
function nixCmd() {
    echoAndRun nix \
        "${1}" --extra-experimental-features "nix-command flakes" \
        "${@:2}"
}

###############################################################################

################################# Export Env ##################################
if [[ $INPUT_EXPORT_ENV == true ]]; then
    # Get nix-direnv if not already provided:
    if ! [ -e "${NIX_DIRENV_PATH:=""}" ]; then
        warn "specified nix-direnv path (${NIX_DIRENV_PATH}) isn't present; grabbing from <nixpkgs>..."
        NIX_DIRENV_PATH="$(
            nixCmd build \
                --expr "(import <nixpkgs> {}).nix-direnv" \
                --impure --no-link \
                --print-out-paths \
                --builders '' --max-jobs 0
        )/share/nix-direnv/direnvrc"

        debug "using: ${NIX_DIRENV_PATH} for direnv"
    fi
    readonly NIX_DIRENV_PATH

    # We only actually need this in the subshell; we eval here to catch errors
    # early.
    #
    # shellcheck source=vendored/nix-direnv.envrc
    source "${NIX_DIRENV_PATH}"

    declare -a cmd_args=()
    case ${INPUT_SOURCE/INPUT_/} in
        PACKAGES) # `nix print-dev-env` with `mkShell` expr
            notice "nix shell from packages: ${INPUT_PACKAGES_LIST[*]@Q}"

            # we don't sanitize `INPUT_PACKAGES_LIST` so arbitrary nix
            # expressions can sneak in but I think this is okay?
            #
            # if it's not we can switch to using `nix shell` + `env` here too..
            # (see what we do for `script` and INPUT_PACKAGES below)
            cmd_args=(
                print-dev-env
                --impure
                --expr "with (import <nixpkgs> {}); mkShell { packages = [ ${INPUT_PACKAGES_LIST[*]} ]; }"
                "${INPUT_EXTRA_NIX_OPTIONS[@]}"
            )
            ;;
        FLAKES) # `nix shell` + `env`
            notice "nix shell from flakes: ${INPUT_FLAKES_LIST[*]@Q}"
            cmd_args=(
                shell
                "${INPUT_FLAKES_LIST[@]}"
                --ignore-environment
                "${INPUT_EXTRA_NIX_OPTIONS[@]}"
                --command "$(which bash)" -c "$(which env)"
            )
            ;;
        DEVSHELL) # `nix print-dev-env`
            notice "nix shell from devShell: ${INPUT_DEVSHELL}"
            cmd_args=(
                print-dev-env
                "${INPUT_DEVSHELL}"
                "${INPUT_EXTRA_NIX_OPTIONS[@]}"
            )
            ;;
        FILE) # `nix print-dev-env`
            notice "nix shell from file: ${INPUT_FILE}"
            cmd_args=(
                print-dev-env
                --file "${INPUT_FILE}"
                "${INPUT_EXTRA_NIX_OPTIONS[@]}"
            )
            ;;
        *) error unreachable
    esac

    profileRaw="$(mktemp --suffix=-profile.rc)"
    nixCmd "${cmd_args[@]}" > "$profileRaw"

    echo "::group::Exporting Env"

    # Run in a subshell with it's environment cleared so we can tell what
    # actually came from the nix shell:
    env -i "$(which bash)" <<-EOF
        set -eo pipefail
        shopt -s lastpipe

		# Within this subshell we can't assume anything about PATH so we can
		# only use bash built-ins and things we explicitly define.
		rm() { "$(which rm)" "\$@"; } # nix-direnv wants this
		tac() { "$(which tac)" "\$@"; } # we want this below to reverse \$PATH

		source "${NIX_DIRENV_PATH}"
		NDEBUG="${NDEBUG-""}" source "$(dirname "$0")/util.bash"

		_nix_import_env "${profileRaw}" # from nix-direnv

        declare -a _env_vars=()
		compgen -v | while read -r name; do
		    if [[ "\$name" == "SHLVL" || "\$name" == "PWD" ]]; then continue; fi

		    # Skip variables that aren't exported:
		    debug "[attrs] \${name}: \${!name@a}"
		    if ! [[ "\${!name@a}" == *x* ]]; then
		        debug "skipping env var '\$name'"
		        continue
		    fi

		    if [[ "\$name" == "PATH" ]]; then
		        continue # we will handle PATH separately, see below
		    fi
		    _env_vars+=("\$name")

		    GITHUB_ENV="${GITHUB_ENV_FILE}" echo=true export_var "\$name"
		done
		echo "exported \${#_env_vars[@]} variables: \${_env_vars[*]@Q}"
		notice "exported \${#_env_vars[@]} variables: \${_env_vars[*]@Q}"

		if [[ "${INPUT_PRESERVE_DEFAULT_PATH}" == "false" ]]; then
		    echo 'PATH=""' >> "${GITHUB_ENV_FILE}"
		    debug "cleared host path!"
		fi

		declare -a _path_segs=()
		echo "\${PATH//:/\$'\n'}" | tac | while read -r path_seg; do
		    _path_segs+=("\$path_seg")
		    echo "\$path_seg" >> "${GITHUB_PATH_FILE}"
		done
		notice \
		    "added \${#_path_segs[@]} elements to PATH" \
		    "(reverse order, last has highest precedence):" \
		    "\${_path_segs[*]@Q}"

		EOF

    echo "::endgroup::"
fi
###############################################################################

################################# Run Script ##################################
if [[ $INPUT_SCRIPT_SET == true ]]; then
    declare -a cmd_args=()
    case ${INPUT_SOURCE/INPUT_/} in
        PACKAGES) # `nix shell`
            notice "nix shell (for running script) from packages: ${INPUT_PACKAGES_LIST[*]@Q}"
            cmd_args=(
                shell
                --impure
                --expr '(import <nixpkgs> {})' "${INPUT_PACKAGES_LIST[@]}"
            )
            ;;
        FLAKES) # `nix shell`
            notice "nix shell (for running script) from flakes: ${INPUT_FLAKES_LIST[*]@Q}"
            cmd_args=(
                shell
                "${INPUT_FLAKES_LIST[@]}"
            )
            ;;
        DEVSHELL) # `nix develop`
            notice "nix shell (for running script) from devShell: ${INPUT_DEVSHELL}"
            cmd_args=(
                develop
                "${INPUT_DEVSHELL}"
            )
            ;;
        FILE) # `nix develop --file`
            notice "nix shell (for running script) from file: ${INPUT_FILE}"
            cmd_args=(
                develop
                --file "${INPUT_FILE}"
            )
            ;;
        *) error unreachable
    esac

    # Write out the script:
    scriptFile="$(mktemp --suffix=-.script)"
    echo -n "$INPUT_SCRIPT" > "$scriptFile"
    chmod +x "$scriptFile"

    # Append the common args to the command:
    if [[ "${INPUT_CLEAR_ENV_FOR_SCRIPT}" == "true" ]]; then
        cmd_args+=(--ignore-environment)
    fi
    cmd_args+=(
        "${INPUT_EXTRA_NIX_OPTIONS[@]}"
        --command "${INPUT_INTERPRETER}" "${scriptFile}"
    )

    # Finally, run it:
    notice "Running script with ${INPUT_INTERPRETER}"
    nixCmd "${cmd_args[@]}"
fi
###############################################################################

# TODO(feature): deny list/allow list for env vars..
