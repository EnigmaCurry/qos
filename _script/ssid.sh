# -----------------------------------------------------------------------------
# create_ssid_map_value:  build the string you’ll stash in $SSID_MAP
#
# Usage:
#   SSID_MAP=$(create_ssid_map_value \
#                0 weather \
#                1 calendar \
#                5 ssh \
#              )
#
# Output format: "0=weather,1=calendar,5=ssh"
# -----------------------------------------------------------------------------
create_ssid_map_value() {
    local out="" ssid app
    while (( $# )); do
        ssid=$1; shift
        app=$1; shift
        # join entries with commas
        [[ -n $out ]] && out+=','
        out+="${ssid}=${app}"
    done
    printf '%s' "$out"
}

# -----------------------------------------------------------------------------
# read_ssid_map:  parse $SSID_MAP back into two arrays:
#
#   ssid_to_app[<SSID>] → <app>
#   app_to_ssid[<app>]  → <SSID>
#
# Usage (after you've exported SSID_MAP from your .env):
#   read_ssid_map "$SSID_MAP"
#   echo "${ssid_to_app[5]}"       # => "ssh"
#   echo "${app_to_ssid[calendar]}" # => "1"
# -----------------------------------------------------------------------------
read_ssid_map() {
    local mapstr=$1
    local entry ssid app

    # reset / declare globals:
    unset ssid_to_app app_to_ssid
    declare -g -a ssid_to_app
    declare -g -A app_to_ssid

    IFS=',' read -ra entries <<< "$mapstr"
    for entry in "${entries[@]}"; do
        IFS='=' read -r ssid app <<< "$entry"
        # only accept non-empty
        if [[ -n $ssid && -n $app ]]; then
            ssid_to_app[$ssid]=$app
            app_to_ssid[$app]=$ssid
        fi
    done
}
