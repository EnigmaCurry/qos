check_rfcomm_kiss() {
    systemctl --no-pager status rfcomm-kiss || true
    echo
    ip link show dev ax0 || true
}

config_radios_rfcomm_enable() {
    cat <<EOF | sudo tee /etc/systemd/system/rfcomm-kiss.service
[Unit]
Description=Bind Bluetooth KISS TNC
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
    cat <<EOF | sudo tee /usr/local/bin/connect_radio.sh
#!/bin/bash
/bin/bash ${QOS_DIR}/_script/connect_radio.sh
EOF
    sudo chmod +x /usr/local/bin/connect_radio.sh
    sudo systemctl daemon-reload
    sudo systemctl enable rfcomm-kiss

    echo
    echo
    echo
    echo "##############################################################################"
    echo "The rfcomm-kiss service has been enabled, but not started yet."
    echo " - Power cycle the radio."
    echo " - Reboot."
    echo " - Check that the rfcomm-kiss service is started and healthy."
    echo "##############################################################################"
    exit 1
}

config_radios_rfcomm_disable() {
    sudo systemctl disable --now rfcomm-kiss
}

config_radios_rfcomm_status() {
    sudo systemctl status --no-pager rfcomm-kiss || true
    echo
    sudo stat /dev/rfcomm0
}

config_radios_pair() {
    RFCOMM_MAC_ADDRESS=$(get RFCOMM_MAC_ADDRESS)
    if [[ -n "$RFCOMM_MAC_ADDRESS" ]]; then
        wizard confirm "Do you wish to unset the existing RFCOMM_MAC_ADDRESS (${RFCOMM_MAC_ADDRESS}) ?" no || return 0
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
