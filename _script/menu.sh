check_var QOS QOS_BIN

MENU_BIN="${QOS_BIN}"
MENU_ROOT="${QOS}"
declare -A MENU_TREE=(
    [$MENU_ROOT]="config apps"
    [config]="settings radios show"
    [config/radios]="pair"
    [apps]="ax25 ax25d"
)

declare -A MENU_DESC=(
    [config]="Configuration commands"
    [config/show]="Show current .env file"
    [config/settings]="Edit settings like Callsign, SSID"
    [config/radios]="Configure radios"
    [config/radios/pair]="Pair bluetooth radio"
    [apps]="Application-specific commands"
    [apps/ax25]="Configure AX.25"
    [apps/ax25d]="Configure AX.25 daemon"
)


get_valid_subcommands() {
    check_array MENU_TREE
    local path="$1"
    echo "${MENU_TREE[$path]}"
}

generate_menu() {
    check_var MENU_BIN MENU_ROOT
    check_array MENU_TREE MENU_DESC

    local title="$1"
    shift

    local -a args=("$@")
    local path="${MENU_ROOT}"

    # Walk down the MENU_TREE based on args
    while [[ ${#args[@]} -gt 0 ]]; do
        local candidate_path="${path}/${args[0]}"
        candidate_path="${candidate_path#${MENU_ROOT}/}"

        if [[ -n "${MENU_TREE[$candidate_path]}" ]]; then
            path="$candidate_path"
            args=("${args[@]:1}")  # shift
        else
            break
        fi
    done

    # If args remain, dispatch to appropriate function
    if [[ ${#args[@]} -gt 0 ]]; then
        local sub="${args[0]}"
        shift
        local func="${path//\//_}_${sub}"
        if declare -f "$func" &>/dev/null; then
            "$func" "$@"
        else
            stderr "No function: $func"
            return 1
        fi
        return
    fi

    # Otherwise, display menu
    local choices=()
    local prefix="${path:+$path }"

    for sub in ${MENU_TREE[$path]}; do
        local full_key="${path:+$path/}$sub"
        local desc="${MENU_DESC[$full_key]}"
        local cmd="${MENU_BIN} ${prefix}${sub}"
        printf -v padded "%-14s" "$sub"
        choices+=("${padded}${desc:+($desc)} = $cmd")
    done
    if [[ "$title" == "${MENU_ROOT}" ]]; then
        title="$title"
    else
        title="$title ${path//\// }"
    fi
    wizard menu "$title" "${choices[@]}"
}
