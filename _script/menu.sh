get_valid_subcommands() {
    check_array MENU_TREE
    local path="$1"
    echo "${MENU_TREE[$path]}"
}

generate_menu() {
    check_var QOS_BIN
    check_array MENU_TREE MENU_DESC

    local title="$1"
    shift

    local path
    case "$title" in
        qos) path="root" ;;
        qos\ *) path="${title#qos }" ;;  # strip 'qos '
        *) stderr "Could not infer path from title: $title"; return 1 ;;
    esac

    # If extra args were passed (e.g. config show), dispatch or recurse
    if [[ $# -gt 0 ]]; then
        local sub="$1"
        shift

        if [[ "$path" == "root" && "${MENU_TREE[$sub]+_}" ]]; then
            # e.g. qos config [show]
            local nested_path="$sub"

            if [[ $# -gt 0 ]]; then
                local nested_sub="$1"
                shift
                dispatch_path_command "$nested_path" "$nested_sub" "$@"
            else
                echo menu fallback
                generate_menu "qos $nested_path"
            fi
        else
            dispatch_path_command "$path" "$sub" "$@"
        fi
        return
    fi

    local prefix=""
    [[ "$path" != "root" ]] && prefix="$path "

    local choices=()
    for sub in $(get_valid_subcommands "$path"); do
        local full_key="${path:+$path/}$sub"
        local desc="${MENU_DESC[$full_key]}"
        local cmd="${QOS_BIN} ${prefix}${sub}"
        choices+=("$sub = $cmd${desc:+ # $desc}")
    done
    debug_array choices
    wizard menu "$title" "${choices[@]}"
}
