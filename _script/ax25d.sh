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
