check_rfcomm_kiss() {
    systemctl --no-pager status rfcomm-kiss || true
    echo
    ip link show dev ax0 || true
}


configure_ax25_ports() {
    CALLSIGN=$(get CALLSIGN)
    check_var CALLSIGN
    echo "radio    ${CALLSIGN}    1200    255    2    Main Radio" \
        | sudo tee /etc/ax25/axports
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
