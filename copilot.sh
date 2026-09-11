OUTPUT="./input/concatenated_prompts.txt"
VSCODE_SESSION_DB="$HOME/Library/Application Support/Code/User/globalStorage/github.copilot-chat/session-store.db"

mkdir -p "$(dirname "$OUTPUT")"
touch "$OUTPUT"
echo '' > "$OUTPUT"

if [ -f "$VSCODE_SESSION_DB" ]; then
	sqlite3 "$VSCODE_SESSION_DB" \
		"SELECT user_message FROM turns WHERE user_message IS NOT NULL AND user_message != '' ORDER BY timestamp ASC;" \
		>> "$OUTPUT"
fi


COPILOT_SESSION_DIR="$HOME/.copilot/session-state"

if [ -d "$COPILOT_SESSION_DIR" ]; then
	find "$COPILOT_SESSION_DIR" -name workspace.yaml -print0 |
	  xargs -0 -n1 sed -n 's/^name: //p' >> "$OUTPUT"
fi

WORKSPACE_STORE="$HOME/.config/Code/User/workspaceStorage"

if [ -d "$WORKSPACE_STORE" ]; then
    find "$WORKSPACE_STORE" -type f -name '*.jsonl' -print0 |
        while IFS= read -r -d '' file; do
            jq -r '
                ..
                | objects
                | if (.inputText? | type) == "string" then
                    .inputText
                  elif .k? == ["inputState", "inputText"]
                       and ((.v? | type) == "string") then
                    .v
                  else
                    empty
                  end
                | select(length > 0)
            ' "$file" 2>/dev/null >> "$OUTPUT"
        done
fi
