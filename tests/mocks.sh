MOCK_BIN="$BATS_TMPDIR/mock_bin"
mkdir -p "$MOCK_BIN"

cat > "$MOCK_BIN/fzf" <<'EOF'
#!/bin/bash
echo "fzf mock called with $@"
exit 0
EOF

chmod +x "$MOCK_BIN/fzf"

cat > "$MOCK_BIN/tmux" <<'EOF'
#!/bin/bash
echo "tmux mock called with: $@"
exit 0
EOF

chmod +x "$MOCK_BIN/tmux"

export PATH="$MOCK_BIN:$PATH"

