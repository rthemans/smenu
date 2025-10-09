#!/usr/bin/env bats
setup() {
    load "mocks.sh"

    export XDG_CONFIG_HOME="$BATS_TMPDIR/config"
    mkdir -p "$XDG_CONFIG_HOME/smenu"
    echo '{"title": "Test", "entries": []}' > "$XDG_CONFIG_HOME/smenu/config.json"
}

teardown() {
    rm -rf "$BATS_TMPDIR/config"
}

@test "fzf" {
    run bash fzf
    echo "output = ${output}"
    echo "status = ${status}"
    [ $status == 0 ]
}
@test "Load config from XDG_CONFIG_HOME" {
    run bash smenu.sh 
    echo "output = ${output}"
    echo "status = ${status}"
  [ "$status" -eq 0 ]
}
