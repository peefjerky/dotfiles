#!/usr/bin/env bash
# Updates material-code colors in VSCodium settings from matugen's generated color.
# Keeps both the new (material-code.colors.primary) and deprecated (material-code.primaryColor)
# keys in sync so the end4 material-code-set-color.sh script doesn't corrupt the file.

COLOR_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/quickshell/user/generated/color.txt"
SETTINGS="${XDG_CONFIG_HOME:-$HOME/.config}/VSCodium/User/settings.json"

[[ ! -f "$COLOR_FILE" ]] && exit 0
[[ ! -f "$SETTINGS" ]] && exit 0

new_color=$(cat "$COLOR_FILE")

python3 - "$SETTINGS" "$new_color" <<'EOF'
import sys, re, json

settings_path = sys.argv[1]
new_color = sys.argv[2]

with open(settings_path, 'r') as f:
    content = f.read()

# Strip trailing commas before } or ] (JSONC -> strict JSON)
cleaned = re.sub(r',(\s*[}\]])', r'\1', content)

data = json.loads(cleaned)
data['material-code.colors'] = {'primary': new_color}
data['material-code.primaryColor'] = new_color  # keep so end4 script doesn't corrupt the file

output = json.dumps(data, indent=2)
# Restore trailing comma on last entry (VSCodium JSONC style)
output = re.sub(r'(\n  "[^"]+": [^\n]+)(\n\}$)', r'\1,\2', output)

with open(settings_path, 'w') as f:
    f.write(output + '\n')
EOF
