stderr(){ echo "$@" >&2; }
error(){ stderr "Error: $@"; }
cancel(){ stderr "Canceled."; exit 2; }
fault(){ test -n "$1" && error $1; stderr "Exiting."; exit 1; }
wizard() { ${QOS_DIR}/_script/script-wizard "$@"; }
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
debug_var() {
    local var=$1
    check_var var
    stderr "## DEBUG: ${var}=${!var}"
}
debug_array() {
    local -n ary=$1
    echo "## DEBUG: Array '$1' contains:"
    for i in "${!ary[@]}"; do
        echo "## ${i} = ${ary[$i]}"
    done
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
    local INSTALLER=https://raw.githubusercontent.com/EnigmaCurry/script-wizard/refs/heads/master/install.sh
    local DEST=${1}
    check_var DEST
    if [[ ! -f ${DEST}/script-wizard ]]; then
        echo
        echo "This script requires script-wizard, which can be installed automatically from the following URL: "
        echo "${INSTALLER}"
        echo
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
    ## Ask a question to set a var and pass it through a series of validators and mutators.
    ##   ask_valid VAR_NAME "Prompt for VAR_NAME:" [mutators...] [validators...]
    ## Validators are functions that must be named with the `validator_` prefix.
    ##   Validators check the passed value and return true (0) or false (1).
    ## Mutators are functions that may have any other name.
    ##   Mutators take the passed value and return a modified value.
    ## Example:
    ##   ask_valid CALLSIGN "Enter your CALLSIGN:" upcase validate_callsign
    local varname="$1"
    local prompt="$2"
    shift 2
    local mutators=()
    local validators=()
    local value
    for fn in "$@"; do
        if declare -f "$fn" >/dev/null; then
            if [[ "$fn" == validate_* ]]; then
                validators+=("$fn")
            else
                mutators+=("$fn")
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
                echo
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
    check_var ENV_FILE 1
    local default="${2:-}"
    local value="$(dotenv -f ${ENV_FILE} get $1)"
    value="${value:-$default}"
    echo "$value"
}

save() {
   check_var ENV_FILE 1
   local existing="$(get $1)"
   if [[ "$existing" != "${!1}" ]]; then
       dotenv -f ${ENV_FILE} set $1="${!1}"
       echo "# Saved ${ENV_FILE} : ${1}=${!1}"
   fi
}

set_default() {
    check_var ENV_FILE 1
    local varname="$1"
    local default="$2"
    check_var varname default
    local existing
    existing="$(get "$varname")"
    if [[ -z "$existing" ]]; then
        printf -v "$varname" '%s' "$default"
        dotenv -f "$ENV_FILE" set "$varname=${!varname}"
        echo "# Set default in ${ENV_FILE} : ${varname}=${!varname}"
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


validate_int() {
    local input="$*"
    if [[ "$input" =~ ^-?[0-9]+$ ]]; then
        return 0
    else
        stderr "Invalid number. Enter a whole number (integer) only."
        return 1
    fi
}

validate_decimal() {
    local input="$*"
    if [[ "$input" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
        return 0
    else
        stderr "Invalid decimal. Enter a decimal number only."
        return 1
    fi
}

upcase() {
    local input="$*"
    echo "${input^^}"
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


install_packages() {
    if ! check_rpm_ostree; then
        echo "Error: This function is intended for rpm-ostree systems."
        return 1
    fi
    local missing=()
    for pkg in "$@"; do
        rpm -q "$pkg" &> /dev/null || missing+=("$pkg")
    done
    if [ ${#missing[@]} -eq 0 ]; then
        #echo -e "## All packages were found.\n"
        return 0
    fi
    echo "Installing missing packages via rpm-ostree override: ${missing[*]}"
    sudo rpm-ostree install "${missing[@]}"
    echo -e "\nYou must now reboot."
    exit 0
}

check_rpm_ostree() {
    if command -v rpm-ostree >/dev/null 2>&1; then
        if rpm-ostree status >/dev/null 2>&1; then
            return 0
        fi
    fi
    return 1
}

check_has_sudo() {
    # Prompt for password if needed and validate sudo session
    echo "## Checking for sudo privileges ..."
    if [[ "$(sudo -u root whoami)" != "root" ]]; then
        fault "Failed to authenticate with sudo."
    fi
}

check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        fault "Error: This script should be run as root."
    fi
}

check_not_root() {
    if [ "$(id -u)" -eq 0 ]; then
        fault "Error: This script should not be run as root."
    fi
}

create_asoundrc() {
    local card="$1"
    local device="${2:-0}"
    local ALSA_DEV_ALIAS=$(get ALSA_DEV_ALIAS radio)
    check_var card
    cat <<EOF > ${HOME}/.asoundrc
pcm.$ALSA_DEV_ALIAS {
    type plug
    slave {
        pcm {
            type hw
            card $card
            device $device
        }
    }
}

ctl.$ALSA_DEV_ALIAS {
    type hw
    card $card
}

pcm.default {
    type plug
    slave.pcm "${ALSA_DEV_ALIAS}"
}

ctl.default {
    type hw
    card $card
}
EOF
}

create_direwolf_config() {
    check_var ENV_FILE
    CALLSIGN="$(get CALLSIGN)"
    cat <<EOF > ${QOS_DIR}/direwolf.conf
## DON'T EDIT ${QOS_DIR}/direwolf.conf!
## This file is overwritten by the main BBS config script each time it is run.
EOF
    cat <<EOF >> ${QOS_DIR}/direwolf.conf
ADEVICE  radio
EOF
    cat <<EOF >> ${QOS_DIR}/direwolf.conf
CHANNEL 0
MYCALL ${CALLSIGN}
MODEM 1200
EOF
if [[ -n "${PTT_RTS_DEVICE}" ]]; then
    cat <<EOF >> ${QOS_DIR}/direwolf.conf
PTT ${PTT_RTS_DEVICE} RTS
EOF
fi
}

enable_direwolf_service() {
    check_var QOS_DIR
    mkdir -p ${HOME}/.config/systemd/user
    cat <<EOF > ${HOME}/.config/systemd/user/direwolf.service
## DON'T EDIT THIS SERVICE FILE!
## IT IS GENERATED BY THE BBS ADMIN SCRIPT.
[Unit]
Description=DireWolf TNC for AX.25
AssertPathExists=${QOS_DIR}/direwolf.conf
After=sound.target

[Service]
Type=simple
ExecStart=${QOS_DIR}/bbs.sh start_direwolf
Restart=on-failure
Environment=HOME=%h
WorkingDirectory=${QOS_DIR}

[Install]
WantedBy=default.target
EOF
    systemctl --user daemon-reload
    systemctl --user stop direwolf
    systemctl --user enable --now direwolf
    systemctl --user status direwolf
}

disable_direwolf_service() {
    local unit="${HOME}/.config/systemd/user/direwolf.service"
    echo "Stopping direwolf service (if running)..."
    if systemctl --user is-active --quiet direwolf; then
        systemctl --user stop direwolf
        echo "✔️  Direwolf service stopped."
    else
        echo "ℹ️  Direwolf service was not running."
    fi
    if [[ -f "$unit" ]]; then
        rm -f "$unit"
        echo "🗑️  Removed service file: $unit"
    else
        echo "ℹ️  Service file not found, nothing to remove."
    fi
    systemctl --user daemon-reload
    echo "🔄 Systemd user daemon reloaded."
    return 0
}

set_sound_volumes() {
    local SOUND_DEVICE
    SOUND_DEVICE="$(get SOUND_DEVICE)"
    local SOUND_VOLUME_INPUT
    SOUND_VOLUME_INPUT="$(get SOUND_VOLUME_INPUT 0)"
    local SOUND_VOLUME_OUTPUT
    SOUND_VOLUME_OUTPUT="$(get SOUND_VOLUME_OUTPUT 0.25)"
    check_var SOUND_DEVICE SOUND_VOLUME_INPUT SOUND_VOLUME_OUTPUT
    local card_index
    card_index=$(get_sound_card_index "$SOUND_DEVICE") || return 1
    local input_percent output_percent
    input_percent=$(awk -v v="$SOUND_VOLUME_INPUT" 'BEGIN { printf "%d%%", v * 100 }')
    output_percent=$(awk -v v="$SOUND_VOLUME_OUTPUT" 'BEGIN { printf "%d%%", v * 100 }')
    # Unmute and set playback (output) volume
    amixer -c "$card_index" sset Master "$output_percent" unmute || true
    amixer -c "$card_index" sset Speaker "$output_percent" unmute || true
    amixer -c "$card_index" sset PCM "$output_percent" unmute || true
    # Unmute and set capture (input) volume
    amixer -c "$card_index" sset Capture "$input_percent" cap || true
    amixer -c "$card_index" sset Mic "$input_percent" cap || true
}


start_direwolf() {
    local SOUND_DEVICE="$(get SOUND_DEVICE)"
    check_var SOUND_DEVICE
    local device_index=$(get_sound_card_index "${SOUND_DEVICE}")
    create_asoundrc "${device_index}"
    create_direwolf_config
    set_sound_volumes
    /usr/bin/direwolf -p -t 0 -c "${QOS_DIR}/direwolf.conf"
}

list_alsa_device_names() {
    local buffer=""
    while IFS= read -r line; do
        if [[ "$line" =~ ^[[:space:]]*([0-9]+)[[:space:]]+\[([^\]]+)\][[:space:]]*:\ ([^[:space:]]+)\ -\ (.*)$ ]]; then
            # If there's a previous buffered description, print it
            if [[ -n "$buffer" ]]; then
                echo "$buffer"
            fi
            buffer="${BASH_REMATCH[3]} - ${BASH_REMATCH[4]}|"
        elif [[ -n "$buffer" && -n "$line" ]]; then
            # Trim leading whitespace from continuation line
            line="${line#"${line%%[![:space:]]*}"}"
            buffer+="$line"
        fi
    done < /proc/asound/cards
    # Print last buffer
    if [[ -n "$buffer" ]]; then
        echo "$buffer"
    fi
}

get_sound_card_index() {
    local search="$1"
    check_var search
    local index=""
    local current_index=""
    while IFS= read -r line; do
        if [[ "$line" =~ ^[[:space:]]*([0-9]+)[[:space:]]+\[([^\]]+)\][[:space:]]*:\ ([^[:space:]]+)\ -\ (.*)$ ]]; then
            current_index="${BASH_REMATCH[1]}"
            local dev="${BASH_REMATCH[3]} - ${BASH_REMATCH[4]}"
            if [[ "$dev" == "$search" ]]; then
                index="$current_index"
                break
            fi
        fi
    done < /proc/asound/cards
    if [[ -n "$index" ]]; then
        echo "$index"
    else
        fault "Could not find card index for: $search"
    fi
}
