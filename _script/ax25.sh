
configure_ax25_ports() {
    CALLSIGN=$(get CALLSIGN)
    check_var CALLSIGN
    echo "radio    ${CALLSIGN}    1200    255    2    Main Radio" \
        | sudo tee /etc/ax25/axports
}

