smenu_popup() {
    local title="${1:-Popup}"
    local cmd="$2"
    local current_dir="${TMUX_PWD:-$PWD}"

    # Vérifications préalables
    if [[ -z "$cmd" ]]; then
        echo "Error : expected cmd to be given." >&2
        return 1
    fi

    if ! command -v tmux &> /dev/null; then
        echo "Error : tmux not installed" >&2
        return 1
    fi

    if [[ -z "$TMUX" ]]; then
        echo "Warning : you need to be in a tmux session to have popups" >&2
        echo "Running cmd directly with eval"
        eval $cmd
    fi

    # Exécution
    if ! tmux display-popup -E -d "$current_dir" -h ${menu_popup_height:-$menu_height} -w ${menu_popup_width:-$menu_width} -T "$title" \
        "$cmd; read -n 1 -s -p 'Press any key to close...'"; then
        echo "Error : Failure occured with popup" >&2
        return 1
    fi

    return 0
}