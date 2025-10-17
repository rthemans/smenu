#!/usr/bin/env bash

main() {
    check_dependency fzf
    check_dependency jq
    load_config
    source_libs
    source_extensions
    cd_to_tmux_pwd
    show_main_menu
}

check_dependency() {
    local util=$1
    if ! command -v $util &> /dev/null; then
        echo "Error: ${util} is required but not installed." >&2
        exit 1
    fi
}

setup_defaults() {
    menu_title="smenu"
    menu_width=80%
    menu_height=80%
    menu_popup_width=80%
    menu_popup_height=80%
}


load_config() {
    local config_paths=(
        "${XDG_CONFIG_HOME:-$HOME/.config}/smenu/config.json"
        "$HOME/.smenu/config.json"
        "$HOME/.smenu.json"
    )

    setup_defaults

    for path in "${config_paths[@]}"; do
        if [[ -f "$path" ]]; then
            menu_title=$(jq -r --arg def "$title" '.title // $def' $path)
            menu_width=$(jq -r --arg def "$menu_width" '.settings.width // $def' $path)
            menu_height=$(jq -r --arg def "$menu_height" '.settings.height // $def' $path)
            menu_popup_width=$(jq -r --arg def "$menu_popup_width" '.settings.popup.width // $def' $path)
            menu_popup_height=$(jq -r --arg def "$menu_popup_height" '.settings.popup.height // $def' $path)
            menu_entries=$(jq -c '.entries' $path)
        fi
    done
}

source_libs() {
    local lib_dir="${SMENU_LIB_DIR:-$(dirname "$0")/lib}"
    local file

    if [[ ! -d "$lib_dir" ]]; then
        echo "Warning: No lib folder found ($lib_dir)." >&2
        return 0
    fi

    local sh_files=()
    while IFS= read -r -d '' file; do
        sh_files+=("$file")
    done < <(find "$lib_dir" -maxdepth 1 -name '*.sh' -print0 | sort -z)

    if [[ ${#sh_files[@]} -eq 0 ]]; then
        echo "Warning: no .sh files found under $lib_dir." >&2
        return 0
    fi

    for file in "${sh_files[@]}"; do
        if [[ -f "$file" && -r "$file" ]]; then
            if ! source "$file"; then
                echo "Error: Échec du chargement de $file" >&2
                return 1
            fi
            echo "Debug: Loaded $file" >&2 
        fi
    done

    echo "Info: ${#sh_files[@]} libraries loaded from $lib_dir." >&2
    return 0
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

cd_to_tmux_pwd() {
    if [ "$TMUX_PWD" ]; then
        cd "$TMUX_PWD"
    fi
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

