#!/bin/bash

set -e

SCRIPT_DIR=$(dirname ${BASH_SOURCE})
DEPENDENCIES=(
    ax25-apps ax25-tools direwolf pipewire pipewire-audio-client-libraries
    pulseaudio-utils wireplumber jq git curl
)

stderr(){ echo "$@" >/dev/stderr; }
error(){ stderr "Error: $@"; }
cancel(){ stderr "Canceled."; exit 2; }
fault(){ test -n "$1" && error $1; stderr "Exiting."; exit 1; }
wizard() { ${SCRIPT_DIR}/script-wizard "$@"; }

check_var(){
    local __missing=false
    local __vars="$@"
    for __var in ${__vars}; do
        if [[ -z "${!__var}" ]]; then
            error "${__var} variable is missing."
            __missing=true
        fi
    done
    if [[ ${__missing} == true ]]; then
        fault
    fi
}

dotenv() {
    # https://github.com/bashup/dotenv @d71c9d7
    # Copied by permission CC0 1.0 Universal
    local __dotenv=
    local __dotenv_file=
    local __dotenv_cmd=.env
    .env() {
	    REPLY=()
	    [[ $__dotenv_file || ${1-} == -* ]] || .env.--file .env || return
	    if declare -F -- ".env.${1-}" >/dev/null; then .env."$@"; return ; fi
	    .env --help >&2; return 64
    }
    .env.-f() { .env.--file "$@"; }
    .env.get() {
	    .env::arg "get requires a key" "$@" &&
	        [[ "$__dotenv" =~ ^(.*(^|$'\n'))([ ]*)"$1="(.*)$ ]] &&
	        REPLY=${BASH_REMATCH[4]%%$'\n'*} && REPLY=${REPLY%"${REPLY##*[![:space:]]}"}
    }
    .env.parse() {
	    local line key
	    while IFS= read -r line; do
		    line=${line#"${line%%[![:space:]]*}"}  # trim leading whitespace
		    line=${line%"${line##*[![:space:]]}"}  # trim trailing whitespace
		    if [[ ! "$line" || "$line" == '#'* ]]; then continue ; fi
		    if (($#)); then
			    for key; do
				    if [[ $key == "${line%%=*}" ]]; then REPLY+=("$line"); break;
				    fi
			    done
		    else
			    REPLY+=("$line")
		    fi
	    done <<<"$__dotenv"
	    ((${#REPLY[@]}))
    }
    .env.export() {	! .env.parse "$@" || export "${REPLY[@]}"; }
    .env.set() {
	    .env::file load || return ; local key saved=$__dotenv
	    while (($#)); do
		    key=${1#+}; key=${key%%=*}
		    if .env.get "$key"; then
			    REPLY=()
			    if [[ $1 == +* ]]; then shift; continue  # skip if already found
			    elif [[ $1 == *=* ]]; then
				    __dotenv=${BASH_REMATCH[1]}${BASH_REMATCH[3]}$1$'\n'${BASH_REMATCH[4]#*$'\n'}
			    else
				    __dotenv=${BASH_REMATCH[1]}${BASH_REMATCH[4]#*$'\n'}
				    continue   # delete all occurrences
			    fi
		    elif [[ $1 == *=* ]]; then
			    __dotenv+="${1#+}"$'\n'
		    fi
		    shift
	    done
	    [[ $__dotenv == "$saved" ]] || .env::file save
    }
    .env.puts() { echo "${1-}">>"$__dotenv_file" && __dotenv+="$1"$'\n'; }
    .env.generate() {
	    .env::arg "key required for generate" "$@" || return
	    .env.get "$1" && return || REPLY=$("${@:2}") || return
	    .env::one "generate: ouptut of '${*:2}' has more than one line" "$REPLY" || return
	    .env.puts "$1=$REPLY"
    }
    .env.--file() {
	    .env::arg "filename required for --file" "$@" || return
	    __dotenv_file=$1; .env::file load || return
	    (($#<2)) || .env "${@:2}"
    }
    .env::arg() { [[ "${2-}" ]] || { echo "$__dotenv_cmd: $1" >&2; return 64; }; }
    .env::one() { [[ "$2" != *$'\n'* ]] || .env::arg "$1"; }
    .env::file() {
	    local REPLY=$__dotenv_file
	    case "$1" in
	        load)
		        __dotenv=; ! [[ -f "$REPLY" ]] || __dotenv="$(<"$REPLY")"$'\n' || return ;;
	        save)
		        if [[ -L "$REPLY" ]] && declare -F -- realpath.resolved >/dev/null; then
			        realpath.resolved "$REPLY"
		        fi
		        { [[ ! -f "$REPLY" ]] || cp -p "$REPLY" "$REPLY.bak"; } &&
		            printf %s "$__dotenv" >"$REPLY.bak" && mv "$REPLY.bak" "$REPLY"
	    esac
    }
    .env.-h() { .env.--help "$@"; }
    .env.--help() {
	    echo "Usage:
  $__dotenv_cmd [-f|--file FILE] COMMAND [ARGS...]
  $__dotenv_cmd -h|--help
Options:
  -f, --file FILE          Use a file other than .env
Read Commands:
  get KEY                  Get raw value of KEY (or fail)
  parse [KEY...]           Get trimmed KEY=VALUE lines for named keys (or all)
  export [KEY...]          Export the named keys (or all) in shell format
Write Commands:
  set [+]KEY[=VALUE]...    Set or unset values (in-place w/.bak); + sets default
  puts STRING              Append STRING to the end of the file
  generate KEY [CMD...]    Set KEY to the output of CMD unless it already exists;
                           return the new or existing value."
    }
    __dotenv() {
	    set -eu
	    __dotenv_cmd=${0##*/}
	    .env.export() { .env.parse "$@" || return 0; printf 'export %q\n' "${REPLY[@]}"; REPLY=(); }
	    .env "$@" || return $?
	    ${REPLY[@]+printf '%s\n' "${REPLY[@]}"}
    }
    __dotenv "$@"
}
install_script_wizard() {
    local REPO=https://github.com/EnigmaCurry/script-wizard
    local INSTALLER=https://raw.githubusercontent.com/EnigmaCurry/script-wizard/refs/heads/master/install.sh
    local DEST=${1}
    check_var DEST
    if [[ ! -f ${DEST}/script-wizard ]]; then
        echo "This tool requires script-wizard from ${REPO}"
        read -e -p "Install script-wizard automatically? [y/N]: " answer
        if [[ ${answer,,} != "y" ]]; then
            echo "Canceled"
            exit 1
        fi
        bash <(curl ${INSTALLER}) "${DEST}"
    fi
    echo
}

ask_valid() {
    local varname="$1"
    local prompt="$2"
    shift 2
    local mutators=()
    local validators=()
    local value
    for fn in "$@"; do
        if declare -f "$fn" >/dev/null; then
            if [[ "$fn" == mutate_* ]]; then
                mutators+=("$fn")
            else
                validators+=("$fn")
            fi
        else
            echo "Warning: function '$fn' not found" >&2
        fi
    done
    while true; do
        value=$(wizard ask "$prompt" "$(get "$varname")")
        # Apply mutators in order
        for mut in "${mutators[@]}"; do
            value="$("$mut" "$value")"
        done
        # Validate
        local valid=true
        for validator in "${validators[@]}"; do
            if ! "$validator" "$value"; then
                valid=false
                break
            fi
        done
        if $valid; then
            set -- "$varname" "$value"
            eval "$1=\"\$2\""
            return 0
        fi
    done
}

get() {
    check_var 1
    dotenv -f ${SCRIPT_DIR}/.env get $1
}

save() {
    check_var 1
    local EXISTING=$(get $1)
    if [[ "$EXISTING" != "${!1}" ]]; then
        dotenv -f ${SCRIPT_DIR}/.env set $1=${!1}
        echo "# Saved .env : ${1}=${!1}"
    fi
}

config_ask() {
    # config THING "Please enter your thing"
    check_var 1 2
    eval "${1}=\"$(wizard ask "$2" "$(get $1)")\""
    save "${1}" >/dev/null
}

validate_word() {
    local input="$*"
    if [[ -z "$input" || "$input" =~ [[:space:]] ]]; then
        stderr "Invalid word. Don't enter any whitespace."
        return 1
    fi
    return 0
}

validate_callsign() {
    local input="$*"
    if [[ "$input" =~ ^[[:alnum:]/-]+$ ]]; then
        return 0
    else
        stderr "Invalid callsign. Use only letters, numbers, / or -."
        return 1
    fi
}

validate_int() {
    local input="$*"
    if [[ "$input" =~ ^-?[0-9]+$ ]]; then
        return 0
    else
        stderr "Invalid number. Enter a whole number (integer) only."
        return 1
    fi
}
mutate_upcase() {
    local input="$*"
    echo "${input^^}"
}

install_packages() {
    # Check if all packages are already installed
    local missing=()
    for pkg in "${@}"; do
        dpkg -s "$pkg" &> /dev/null || missing+=("$pkg")
    done
    # If all are installed, return immediately
    if [ ${#missing[@]} -eq 0 ]; then
        echo -e "## All packages were found.\n"
        return 0
    fi
    echo "Installing missing packages: ${missing[*]}"
    sudo apt update
    sudo apt install -y "${missing[@]}"
    echo
}

setup() {
    if [ ! -f /etc/debian_version ]; then
        fault "This script only supports Debian-based systems."
    else
        echo "## Debian $(cat /etc/debian_version) or similar OS detected."
    fi

    install_packages ${DEPENDENCIES[@]}
    install_script_wizard ${SCRIPT_DIR}

    ## CALLSIGN
    ask_valid CALLSIGN "Enter your callsign:" validate_word mutate_upcase validate_callsign
    save CALLSIGN
}

setup
