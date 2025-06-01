#!/bin/bash

set -e

DEPENDENCIES=(
    ax25-apps ax25-tools direwolf
    pipewire pulseaudio-utils wireplumber
    jq git curl
)

configure_sound_input_device() {
    mapfile -t devices < <(get_pipewire_input_devices)
    if [ "${#devices[@]}" -eq 0 ]; then
        fault "No audio input devices found."
    fi
    local existing_device=$(get SOUND_DEVICE_INPUT)
    SOUND_DEVICE_INPUT="$(wizard choose "Select your INPUT sound device" "${devices[@]}" --default "$existing_device")"
    save SOUND_DEVICE_INPUT
}

configure_sound_output_device() {
    mapfile -t devices < <(get_pipewire_output_devices)
    if [ "${#devices[@]}" -eq 0 ]; then
        fault "No audio output devices found."
    fi
    local existing_device=$(get SOUND_DEVICE_OUTPUT)
    SOUND_DEVICE_OUTPUT="$(wizard choose "Select your OUTPUT sound device" "${devices[@]}" --default "$existing_device")"
    save SOUND_DEVICE_OUTPUT
}

configure_ptt_rts() {
    if wizard confirm "Do you want to trigger the radio PTT via USB serial RTS (digirig)?" yes; then
        mapfile -t devices < <(compgen -G "/dev/ttyUSB*" || true)
        if [[ "${#devices[@]}" -eq 0 ]]; then
            fault "No /dev/ttyUSB* devices found."
        fi
        local existing_device=$(get PTT_RTS_DEVICE)
        PTT_RTS_DEVICE="$(wizard choose "Select your USB serial device for PTT RTS" "${devices[@]}" --default "$existing_device")"
    else
        PTT_RTS_DEVICE=""
    fi
    save PTT_RTS_DEVICE
}

configure_callsign() {
    ask_valid CALLSIGN "Enter your callsign:" upcase validate_callsign
    save CALLSIGN
}

config() {
    configure_callsign
    echo
    configure_sound_input_device
    echo
    configure_sound_output_device
    echo
    configure_ptt_rts
    echo
    echo "########################################"
    echo "## Configuration complete."
    echo "########################################"
    echo
}
