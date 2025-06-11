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

pair() {
    RFCOMM_MAC_ADDRESS=$(get RFCOMM_MAC_ADDRESS)
    if [[ -n "$RFCOMM_MAC_ADDRESS" ]]; then
        wizard confirm "Do you wish to unset the existing RFCOMM_MAC_ADDRESS (${RFCOMM_MAC_ADDRESS}) ?" yes
        bluetoothctl remove "$RFCOMM_MAC_ADDRESS" || true
        RFCOMM_MAC_ADDRESS=""
        save RFCOMM_MAC_ADDRESS
        sleep 2
    fi
    tmp_file=$(mktemp)
    expect ${QOS_DIR}/_script/bt_pair.exp "${tmp_file}"
    read -r RFCOMM_MAC_ADDRESS < ${tmp_file}
    check_var RFCOMM_MAC_ADDRESS || fault "Found no bluetooth MAC address for the radio"
    echo "MAC ADDRESS: ${RFCOMM_MAC_ADDRESS}"
    save RFCOMM_MAC_ADDRESS
}

check_rfcomm_kiss() {
    systemctl --no-pager status rfcomm-kiss || true
    echo
    ip link show dev ax0 || true
}

# __configure_sound_device() {
#     local varname="$1"
#     local prompt="$2"
#     check_var varname prompt
#     mapfile -t full_devices < <(list_alsa_device_names)
#     if [ "${#full_devices[@]}" -eq 0 ]; then
#         fault "No audio devices found."
#     fi
#     local existing_device
#     existing_device=$(get "$varname")
#     local descriptons=()
#     local dev_names=()
#     local default_display=""
#     for entry in "${full_devices[@]}"; do
#         IFS='|' read -r dev desc <<< "$entry"
#         dev_names+=("$dev")
#         desc="${desc#"${desc%%[![:space:]]*}"}"  # trim leading space
#         descriptions+=("$desc")

#         # If this dev matches the saved name, remember the description
#         if [[ "$dev" == "$existing_device" ]]; then
#             default_display="$desc"
#         fi
#     done
#     local index
#     index=$(wizard choose -n "$prompt" "${descriptions[@]}" --default "$default_display")
#     local selected="${dev_names[$index]}"
#     printf -v "$varname" '%s' "$selected"
#     save "$varname"
# }

# configure_sound_device() {
#     __configure_sound_device SOUND_DEVICE "Select your sound device"
# }

# configure_volume_input_device() {
#     set_default SOUND_VOLUME_INPUT 0
#     ask_valid SOUND_VOLUME_INPUT "Enter the INPUT volume GAIN (decimal between 0 and 1)" validate_decimal
#     save SOUND_VOLUME_INPUT
# }

# configure_volume_output_device() {
#     set_default SOUND_VOLUME_OUTPUT 0.25
#     ask_valid SOUND_VOLUME_OUTPUT "Enter the OUTPUT volume (decimal between 0 and 1)" validate_decimal
#     save SOUND_VOLUME_OUTPUT
# }

# configure_ptt_rts() {
#     if wizard confirm "Do you want to trigger the radio PTT via USB serial RTS (digirig)?" yes; then
#         mapfile -t devices < <(compgen -G "/dev/ttyUSB*" || true)
#         if [[ "${#devices[@]}" -eq 0 ]]; then
#             fault "No /dev/ttyUSB* devices found."
#         fi
#         local existing_device=$(get PTT_RTS_DEVICE)
#         PTT_RTS_DEVICE="$(wizard choose "Select your USB serial device for PTT RTS" "${devices[@]}" --default "$existing_device")"
#     else
#         PTT_RTS_DEVICE=""
#     fi
#     save PTT_RTS_DEVICE
# }

configure_ax25_ports() {
    CALLSIGN=$(get CALLSIGN)
    check_var CALLSIGN
    echo "radio    ${CALLSIGN}    1200    255    2    BTECH UV-PRO" \
        | sudo tee /etc/ax25/axports
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
    ask_valid CALLSIGN "Enter your callsign (No station id suffix):" upcase validate_base_callsign
    save CALLSIGN
}

configure_ssid() {
    echo
}

configure_rfcomm_service() {
    cat <<EOF | tee /etc/systemd/system/rfcomm-kiss.service
[Unit]
Description=Bind Bluetooth TNC and attach KISS interface
After=bluetooth.target network.target
Requires=bluetooth.target

[Service]
Type=oneshot
RemainAfterExit=true
WorkingDirectory=${HOME}
Environment=HOME=${HOME}
ExecStart=/usr/local/bin/connect_radio.sh
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

    ## Create wrapper script in /usr/local/bin that runs our own script
    ## This is to evade the SELinux enforcement against running scripts in $HOME.
    cat <<EOF | tee /usr/local/bin/connect_radio.sh
#!/bin/bash
/bin/bash ${QOS_DIR}/_script/connect_radio.sh
EOF
    chmod +x /usr/local/bin/connect_radio.sh
    systemctl daemon-reload
    systemctl enable rfcomm-kiss

    echo
    echo "Power cycle the radio and then reboot."
    echo
    exit 1
}

configure_ax25d_service() {
    CALLSIGN=$(get CALLSIGN)
    cat <<EOF | sudo tee /etc/ax25/ax25d.conf
[${CALLSIGN}]
default * * * * * * *  ${USER}  ${QOS_DIR}/bbs.py BBS ${CALLSIGN} %S
EOF

    cat <<EOF | tee /etc/systemd/system/ax25d.service
[Unit]
Description=AX.25 Daemon
After=rfcomm-kiss.service

[Service]
Type=forking
ExecStart=/usr/local/bin/ax25d_start.sh
Restart=always

[Install]
WantedBy=multi-user.target
EOF

    ## Create wrapper script in /usr/local/bin that runs our own script
    ## This is to evade the SELinux enforcement against running scripts in $HOME.
    cat <<EOF | tee /usr/local/bin/ax25d_start.sh
#!/bin/bash
/bin/bash ${QOS_DIR}/ax25d/start.sh
EOF
    chmod +x /usr/local/bin/ax25d_start.sh

    sudo systemctl daemon-reload
    sudo systemctl enable --now ax25d
}

settings() {
    configure_callsign
}
