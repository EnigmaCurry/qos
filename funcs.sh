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
    dotenv -f ${ENV_FILE} get $1
}

save() {
    check_var ENV_FILE 1
    local EXISTING="$(get $1)"
    if [[ "$EXISTING" != "${!1}" ]]; then
        dotenv -f ${ENV_FILE} set $1="${!1}"
        echo "# Saved ${ENV_FILE} : ${1}=${!1}"
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

get_pipewire_devices() {
    local class="$1"
    check_var class
    pw-dump | jq -r --arg class "$class" '
        .[]
        | select(.type == "PipeWire:Interface:Node")
        | select(.info.props."media.class" == $class)
        | .info.props."node.description"
        ' | grep -v '^null$'
}

get_pipewire_device() {
    local class="$1"
    local search="$2"
    check_var class search
    debug_var class
    debug_var search

    local id
    id=$(pw-dump | jq -r --arg class "$class" --arg desc "$search" '
        .[]
        | select(.type == "PipeWire:Interface:Node")
        | select(.info.props."media.class" == $class)
        | select(.info.props."node.description"? // "" | test($desc; "i"))
        | .id
    ' | head -n 1)

    if [[ -z "$id" ]]; then
        stderr "No matching PipeWire device named '$search'"
        return 1
    fi

    echo "$id"
}

get_pipewire_input_devices() {
    get_pipewire_devices "Audio/Source"
}

get_pipewire_input_device() {
    get_pipewire_device "Audio/Source" "$1"
}

get_pipewire_output_devices() {
    get_pipewire_devices "Audio/Sink"
}

get_pipewire_output_device() {
    get_pipewire_device "Audio/Sink" "$1"
}

check_os_is_debian() {
    if [ ! -f /etc/debian_version ]; then
        fault "This script only supports Debian-based systems."
    else
        echo "## Debian $(cat /etc/debian_version) or similar OS detected."
    fi

}

setup_pipewire() {
    echo "[+] Enabling systemd lingering for user: $USER"
    sudo loginctl enable-linger "$USER"
    echo "[+] Enabling PipeWire services for user: $USER"
    systemctl --user daemon-reexec
    systemctl --user daemon-reload
    systemctl --user enable --now pipewire.service pipewire.socket wireplumber.service
    echo "[✓] PipeWire and WirePlumber enabled for user $USER"
    echo
}

check_has_sudo() {
    # Prompt for password if needed and validate sudo session
    echo "## Checking for sudo privileges ..."
    if [[ "$(sudo -u root whoami)" != "root" ]]; then
        fault "Failed to authenticate with sudo."
    fi
}

check_not_root() {
    if [ "$(id -u)" -eq 0 ]; then
        fault "Error: This script should not be run as root."
    fi
}

set_pipewire_device_volume() {
    local pipewire_id="$1"
    local volume="$2"
    check_var pipewire_id
    validate_decimal "${volume}"
    if ! wpctl inspect ${pipewire_id} >/dev/null; then
        stderr "Could not set volume of device."
        fault "Invalid pipewire device id: ${pipewire_id}"
    fi
    wpctl set-volume "${pipewire_id}" "${volume}"
    wpctl set-mute "${pipewire_id}" 0
}

set_pipewire_input_device_volume() {
    local pipewire_input="$1"
    local volume="$2"
    check_var pipewire_input
    validate_decimal "${volume}"
    local pipewire_id="$(get_pipewire_input_device "${pipewire_input}")"
    set_pipewire_device_volume "${pipewire_id}" "${volume}"
}

set_pipewire_output_device_volume() {
    local pipewire_output="$1"
    local volume="$2"
    check_var pipewire_output
    validate_decimal "${volume}"
    local pipewire_id="$(get_pipewire_output_device "${pipewire_output}")"
    set_pipewire_device_volume "${pipewire_id}" "${volume}"
}

get_plughw_name_for_pipewire_id() {
    local node_id="$1"
    check_var node_id
    pw-dump | jq -r --argjson id "$node_id" '
        .[]
        | select(.id == $id)
        | .info.props
        | "\(.["alsa.card"] // "unknown"),\(.["alsa.device"] // "unknown")"
    ' | awk -F, '{
        if ($1 == "unknown" || $2 == "unknown") {
            print "Error: ALSA card/device not found" > "/dev/stderr"
            exit 1
        }
        print "plughw:" $1 "," $2
    }'
}

create_direwolf_config() {
    check_var ENV_FILE
    CALLSIGN="$(get CALLSIGN)"
    SOUND_DEVICE_INPUT="$(get SOUND_DEVICE_INPUT)"
    SOUND_DEVICE_OUTPUT="$(get SOUND_DEVICE_OUTPUT)"
    PTT_RTS_DEVICE="$(get PTT_RTS_DEVICE)"
    check_var CALLSIGN SOUND_DEVICE_INPUT SOUND_DEVICE_OUTPUT
    PIPEWIRE_INPUT_DEVICE="$(get_pipewire_input_device "${SOUND_DEVICE_INPUT}")"
    PIPEWIRE_OUTPUT_DEVICE="$(get_pipewire_output_device "${SOUND_DEVICE_OUTPUT}")"
    check_var PIPEWIRE_INPUT_DEVICE PIPEWIRE_OUTPUT_DEVICE
    PLUGHW_INPUT_DEVICE="$(get_plughw_name_for_pipewire_id ${PIPEWIRE_INPUT_DEVICE})"
    PLUGHW_OUTPUT_DEVICE="$(get_plughw_name_for_pipewire_id ${PIPEWIRE_OUTPUT_DEVICE})"
    check_var PLUGHW_INPUT_DEVICE PLUGHW_OUTPUT_DEVICE
    cat <<EOF > ${SCRIPT_DIR}/direwolf.conf
## DON'T EDIT ${SCRIPT_DIR}/direwolf.conf!
## This file is overwritten by the main BBS config script each time it is run.
EOF
    cat <<EOF >> ${SCRIPT_DIR}/direwolf.conf
ADEVICE  ${PLUGHW_INPUT_DEVICE} ${PLUGHW_OUTPUT_DEVICE}
EOF
    cat <<EOF >> ${SCRIPT_DIR}/direwolf.conf
CHANNEL 0
MYCALL ${CALLSIGN}
MODEM 1200
EOF
if [[ -n "${PTT_RTS_DEVICE}" ]]; then
    cat <<EOF >> ${SCRIPT_DIR}/direwolf.conf
PTT ${PTT_RTS_DEVICE} RTS
EOF
fi
}

enable_direwolf_service() {
    check_var SCRIPT_DIR
    mkdir -p ${HOME}/.config/systemd/user
    cat <<EOF > ${HOME}/.config/systemd/user/direwolf.service
## DON'T EDIT THIS SERVICE FILE!
## IT IS GENERATED BY THE BBS ADMIN SCRIPT.
[Unit]
Description=DireWolf TNC for AX.25
AssertPathExists=${SCRIPT_DIR}/direwolf.conf
After=sound.target

[Service]
Type=simple
ExecStart=${SCRIPT_DIR}/bbs.sh start_direwolf
Restart=on-failure
Environment=HOME=%h
WorkingDirectory=${SCRIPT_DIR}

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
    SOUND_DEVICE_INPUT=$(get SOUND_DEVICE_INPUT)
    SOUND_DEVICE_OUTPUT=$(get SOUND_DEVICE_OUTPUT)
    SOUND_VOLUME_INPUT=$(get SOUND_VOLUME_INPUT)
    SOUND_VOLUME_OUTPUT=$(get SOUND_VOLUME_OUTPUT)
    set_pipewire_input_device_volume "${SOUND_DEVICE_INPUT}" "${SOUND_VOLUME_INPUT}"
    set_pipewire_output_device_volume "${SOUND_DEVICE_OUTPUT}" "${SOUND_VOLUME_OUTPUT}"
}

start_direwolf() {
    create_direwolf_config
    set_sound_volumes
    /usr/bin/direwolf -p -t 0 -c ${SCRIPT_DIR}/direwolf.conf
}
