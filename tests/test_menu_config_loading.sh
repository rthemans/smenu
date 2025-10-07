setup() {
    export XDG_CONFIG_HOME="$BATS_TMPDIR/config"
    mkdir -p "$XDG_CONFIG_HOME/smenu"
    echo '{"title": "Test", "entries": []}' > "$XDG_CONFIG_HOME/smenu/smenu.json"
}

@test "Load config from XDG_CONFIG_HOME" {
    run bash smenu.sh --test-config
    [[ "$output" == *"Test"* ]]
}