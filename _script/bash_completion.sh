bash_completion() {
    check_var QOS QOS_DIR QOS_BIN SCRIPT_DIR
    if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
        echo
        echo "## To enable Bash shell completion support, put this in your ~/.bashrc:"
        echo "source <(${QOS} bash_completion)"
        echo
    else
        cat <<EOF
_qos_complete() {
    QOS=${QOS}
    QOS_DIR=${QOS_DIR}
    QOS_BIN=${QOS_BIN}
    SCRIPT_DIR=${SCRIPT_DIR}

    source "\${SCRIPT_DIR}/funcs.sh"
    source "\${SCRIPT_DIR}/menu.sh"

    check_array MENU_TREE

    local cur prev
    cur="\${COMP_WORDS[COMP_CWORD]}"
    prev="\${COMP_WORDS[COMP_CWORD-1]}"

    # Build slash-separated path
    local -a path_parts=()
    for ((i = 1; i < COMP_CWORD; i++)); do
        path_parts+=("\${COMP_WORDS[i]}")
    done

    local path="\${path_parts[*]}"
    path="\${path// /\/}"  # "config show" → "config/show"
    [[ -z "\$path" ]] && path="${QOS}"

    local subcommands="\${MENU_TREE[\$path]}"

    COMPREPLY=( \$(compgen -W "\$subcommands" -- "\$cur") )
}

complete -F _qos_complete ${QOS}
EOF
    fi
}
