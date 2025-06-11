pair_bluetooth_radio() {
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
