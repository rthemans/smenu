#!/usr/bin/env bash

main() {
    check_dependency fzf
    check_dependency jq
    load_config
    source_extensions
    show_main_menu
}

check_dependency() {
    local util=$1
    if ! command -v $util &> /dev/null; then
        echo "Error: ${util} is required but not installed." >&2
        exit 1
    fi
}


load_config() {
    local config_paths=(
        "${XDG_CONFIG_HOME:-$HOME/.config}/smenu/config.json"
        "$HOME/.smenu/config.json"
        "$HOME/.smenu.json"
    )

    for path in "${config_paths[@]}"; do
        if [[ -f "$path" ]]; then
            config_content=$(cat "$path")
            menu_title=$(jq -r '.title' <<< "$config_content")
            menu_width=$(jq -r '.width // "80%"' <<< "$config_content")
            menu_height=$(jq -r '.height // "80%"' <<< "$config_content")
            menu_entries=$(jq -c '.entries' <<< "$config_content")
            return
        fi
    done

    echo "Error: No smenu.json config found in:" >&2
    printf "  - %s\n" "${config_paths[@]}" >&2
    exit 1
}

source_extensions() {
    local extension_paths=(
        "${XDG_CONFIG_HOME:-$HOME/.config}/smenu/*.sh"
        "$HOME/.smenu/*.sh"
        "$HOME/.smenu_extension*.sh"
    )

    for pattern in "${extension_paths[@]}"; do
        for file in $pattern; do
            [[ -f "$file" ]] && source "$file"
        done
    done
}

fzft() {
    fzf-tmux --color=fg:#ebdbb2,bg:#282828,hl:#fabd2f \
        --color=fg+:#fbf1c7,bg+:#3c3836,hl+:#fe8019 \
        --color=info:#83a598,prompt:#b8bb26,pointer:#fb4934 \
        --color=marker:#98971a,spinner:#fabd2f,header:#689d6a \
        --margin=1% \
        --padding=1% \
        -w $menu_width \
        -h $menu_height \
        "$@"

}

show_main_menu() {
    local selected_entry
    selected_entry=$(jq -r '.[] | "\(.name)\t\(.type)"' <<< "$menu_entries" | \
        fzft --reverse --header-first --header="$menu_title" --delimiter='\t' --with-nth=1)

    [[ -z "$selected_entry" ]] && exit 0

    local entry_name=$(cut -f1 <<< "$selected_entry")
    local entry_type=$(cut -f2 <<< "$selected_entry")
    local entry_data=$(jq -r ".[] | select(.name == \"$entry_name\" and .type == \"$entry_type\")" <<< "$menu_entries")

    handle_entry "$entry_data"
}

handle_entry() {
    local entry_data="$1"
    local type=$(jq -r '.type' <<< "$entry_data")

    case "$type" in
        "submenu") handle_submenu "$entry_data" ;;
        "exec") handle_exec "$entry_data" ;;
        "call") handle_call "$entry_data" ;;
        "option_call") handle_option_call "$entry_data" ;;
    esac
}

handle_submenu() {
    local entries=$(jq -r '.entries' <<< "$1")
    local selected_subentry

    selected_subentry=$(jq -r '.[] | "\(.name)\t\(.type)"' <<< "$entries" | \
        fzft --header="Submenu" --delimiter='\t' --with-nth=1)

    [[ -z "$selected_subentry" ]] && return

    local subentry_name=$(cut -f1 <<< "$selected_subentry")
    local subentry_data=$(jq -r ".[] | select(.name == \"$subentry_name\")" <<< "$entries")

    handle_entry "$subentry_data"
}

handle_exec() {
    local command=$(jq -r '.exec' <<< "$1")
    eval "$command"
}

handle_call() {
    local call=$(jq -r '.call' <<< "$1")
    local parameters=$(jq -r '.parameters // [] | join(" ")' <<< "$1")
    "$call" $parameters
}

handle_option_call() {
    local call=$(jq -r '.call' <<< "$1")
    local options=$(jq -r '.options' <<< "$1")

    if [[ "$options" =~ ^\[.*\]$ ]]; then
        local options_list="$options"
    else
        local options_list=$("$options")
    fi

    local selected_options=$(jq -r '.[] | "\(.display)\t\(.value)"' <<< "$options_list" | \
        fzft --multi --header="Select options" --delimiter='\t' --with-nth=1 | \
        cut -f2)

    [[ -z "$selected_options" ]] && return

    "$call" $selected_options
}

main

