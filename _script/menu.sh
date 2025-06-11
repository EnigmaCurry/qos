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
            local nested_path="$sub"

            if [[ $# -gt 0 ]]; then
                local nested_sub="$1"
                shift
                dispatch_path_command "$nested_path" "$nested_sub" "$@"
            else
                generate_menu "qos $nested_path"
            fi
        else
            dispatch_path_command "$path" "$sub" "$@"
        fi
        return
    fi

    local prefix=""
    [[ "$path" != "root" ]] && prefix="$path "

    local -a subs
    IFS=' ' read -ra subs <<< "$(get_valid_subcommands "$path")"

    # Find the longest subcommand name
    local max_len=0
    for sub in "${subs[@]}"; do
        (( ${#sub} > max_len )) && max_len=${#sub}
    done

    # Construct aligned choices
    local choices=()
    for sub in "${subs[@]}"; do
        local full_key="${path:+$path/}$sub"
        local desc="${MENU_DESC[$full_key]}"
        local cmd="${QOS_BIN} ${prefix}${sub}"
        if [[ -n "$desc" ]]; then
            # Pad sub name to max_len + 2 spaces
            printf -v padded "%-*s" $((max_len + 2)) "$sub"
            choices+=("$padded($desc) = $cmd")
        else
            choices+=("$sub = $cmd")
        fi
    done

    #debug_array choices
    wizard menu "$title" "${choices[@]}"
}
