#!/usr/bin/env bash
# Einrichtung auf dem Mac: virtuelle Umgebung + Eintrag in Claude Desktop.
# Aufruf:  ./scripts/setup_mac.sh "<Pfad zum Vault>"   (ohne Argument wird nachgefragt)
set -euo pipefail

VAULT="${1:-}"
ICLOUD="$HOME/Library/Mobile Documents/iCloud~md~obsidian/Documents"
if [[ -z "$VAULT" ]]; then
  echo "Verfügbare Vaults in iCloud:"; ls -1 "$ICLOUD" 2>/dev/null || true
  read -r -p "Name des Vaults: " NAME
  VAULT="$ICLOUD/$NAME"
fi
[[ -d "$VAULT" ]] || { echo "Vault nicht gefunden: $VAULT"; exit 1; }

REPO="$(cd "$(dirname "$0")/.." && pwd)"
python3 -m venv "$REPO/.venv"
"$REPO/.venv/bin/pip" install -q --upgrade pip
"$REPO/.venv/bin/pip" install -q -e "$REPO"
PY="$REPO/.venv/bin/python"

CFG="$HOME/Library/Application Support/Claude/claude_desktop_config.json"
mkdir -p "$(dirname "$CFG")"
"$PY" - "$CFG" "$PY" "$VAULT" <<'PYEOF'
import json, sys, pathlib
cfg_path, py, vault = sys.argv[1:]
p = pathlib.Path(cfg_path)
cfg = json.loads(p.read_text()) if p.exists() and p.read_text().strip() else {}
cfg.setdefault("mcpServers", {})["obsidian-gedaechtnis"] = {
    "command": py, "args": ["-m", "ai_memory", "stdio"], "env": {"OBSIDIAN_VAULT_PATH": vault}}
p.write_text(json.dumps(cfg, indent=2, ensure_ascii=False))
print(f"Claude Desktop konfiguriert: {p}")
PYEOF

echo "Fertig. Claude Desktop jetzt komplett beenden und neu starten."
echo "Für ChatGPT siehe README, Abschnitt 'ChatGPT anbinden'."
