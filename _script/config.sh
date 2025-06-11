check_var SCRIPT_DIR
source ${SCRIPT_DIR}/ssid.sh

FEDORA_DEPENDENCIES=(
    podman ax25-apps ax25-tools jq git curl expect bluez bluez-tools bluez-deprecated kernel-modules-extra
)

DEBIAN_DEPENDENCIES=(
    podman ax25-apps ax25-tools jq git curl expect bluez bluez-tools
)

dependencies() {
    check_not_root || fault "You must not run this script as root (but you do need sudo privileges)."
    check_is_systemd || fault "Sorry, only machines with systemd are supported."
    if check_is_debian; then
        install_packages ${DEBIAN_DEPENDENCIES[@]}
    elif check_is_fedora; then
        install_packages ${FEDORA_DEPENDENCIES[@]}
    else
        echo "Unsupported system OS" >&2
        cat /etc/os-release 2>/dev/null | grep "^NAME" || true
        exit 1
    fi
    install_script_wizard ${QOS_DIR}/_script
}

validate_base_callsign() {
    local cs="$*"
    if [[ "$cs" =~ ^[A-Za-z0-9]{1,7}$ ]]; then
        return 0
    else
        stderr "Invalid base callsign. Must be 1–7 letters or digits (e.g. N0CALL)."
        return 1
    fi
}

validate_station_callsign() {
    local scs="$*"
    # base is 1–7 alnum, SSID 0–15
    if [[ "$scs" =~ ^[A-Za-z0-9]{1,7}-([0-9]|1[0-5])$ ]]; then
        return 0
    else
        stderr "Invalid station callsign. Must be \`CALLSIGN-SSID\` where SSID is 0–15 (e.g. N0CALL-3)."
        return 1
    fi
}

configure_callsign() {
    if ask_valid CALLSIGN "Enter your callsign (No station id suffix):" upcase validate_base_callsign; then
        save CALLSIGN
    fi
}

configure_ssid() {
    echo
}

config_settings() {
    configure_callsign || true
}

config_radios() {
    generate_menu "${QOS} config radios" "$@"
}

config_show() {
    echo ""
    echo "## ${ENV_FILE}"
    cat "$(realpath "$ENV_FILE")"
}
