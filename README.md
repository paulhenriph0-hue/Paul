# Obsidian‑Gedächtnis für Claude & ChatGPT

Ein [MCP](https://modelcontextprotocol.io)-Server, der deinen **Obsidian‑Vault in iCloud** zum gemeinsamen Gedächtnis
von **Claude** und **ChatGPT** macht:

- Claude und ChatGPT **speichern** Infos über dich, neue Ergebnisse und Zusammenfassungen ihrer Unterhaltungen als Markdown‑Notizen.
- Bei neuen Anfragen **lesen** beide zuerst dein Profil, die letzten Einträge und passende Notizen. Dazu gehören auch die Notizen des jeweils anderen Modells.
- Ältere Chats kannst du aus den Daten‑Exporten von ChatGPT und Claude **importieren**.

```
 Claude Desktop ──stdio──┐
                         ├──► ai_memory (MCP-Server auf deinem Mac) ──► Obsidian-Vault in iCloud
 ChatGPT ──HTTPS-Tunnel──┘                                                 └─► iPhone / iPad / Mac
```

## Ablage im Vault

```
<Vault>/KI-Gedaechtnis/
├── Profil.md                 ← dauerhafte Infos über dich (wird immer zuerst gelesen)
├── Wissen/                   ← gespeicherte Ergebnisse, Konzepte, Fakten
├── Projekte/                 ← laufende Projekte (werden fortgeschrieben)
├── Gespraeche/Claude/        ← Zusammenfassungen der Claude-Chats
├── Gespraeche/ChatGPT/       ← Zusammenfassungen der ChatGPT-Chats
└── Journal/2026-10-13.md     ← Tagesprotokoll: wer hat wann was gespeichert
```

Jede Notiz hat eine Frontmatter mit `source` (Claude/ChatGPT), `created`, `updated` und `tags`. Damit kannst du in
Obsidian filtern, z. B. mit der Suche `["source":ChatGPT]` oder mit Dataview. Die Suche läuft über den **ganzen Vault**,
also auch über deine eigenen Notizen.

## Werkzeuge, die die Modelle bekommen

| Werkzeug | Zweck |
|---|---|
| `memory_context` | Startpaket: Profil, letzte Einträge und passende Notizen zum Thema |
| `search` / `fetch` | Volltextsuche im Vault und eine Notiz lesen (Format, das ChatGPT erwartet) |
| `memory_save` | Neue Notiz anlegen, anhängen (`append`) oder ersetzen (`overwrite`) |
| `memory_append` | An eine bestehende Notiz anhängen |
| `memory_update_profile` | Dauerhafte Infos über dich ergänzen |
| `memory_log_conversation` | Zusammenfassung des aktuellen Chats speichern |
| `memory_recent` / `memory_list` | Letzte Änderungen bzw. Notizen eines Ordners auflisten |

## 1. Installation (Mac)

Voraussetzungen: macOS, Python ≥ 3.10, Obsidian mit einem Vault in iCloud
(`~/Library/Mobile Documents/iCloud~md~obsidian/Documents/<Vault>`).

```bash
git clone <dieses-repo> ~/ai-memory && cd ~/ai-memory
./scripts/setup_mac.sh            # fragt nach dem Vault-Namen
```

Das Skript legt `.venv` an, installiert das Paket und trägt den Server in
`~/Library/Application Support/Claude/claude_desktop_config.json` ein. Bestehende Einträge bleiben dabei erhalten.

Danach **Claude Desktop neu starten**. Im Chat erscheint unter dem Werkzeug‑Symbol der Server `obsidian-gedaechtnis`.

> **Tipp:** Lade den Vault‑Ordner in iCloud dauerhaft herunter (Finder → Rechtsklick → *Behalten*). Notizen, die nur in
> der Cloud liegen, kann der Server sonst nicht lesen.

**Claude Code** (Terminal):
`claude mcp add obsidian-gedaechtnis -e OBSIDIAN_VAULT_PATH="<Vault>" -- ~/ai-memory/.venv/bin/python -m ai_memory stdio`

## 2. Claude zum automatischen Speichern bringen

Den Text aus [`prompts/claude_anweisungen.md`](prompts/claude_anweisungen.md) in Claude unter
*Einstellungen → Profil → Persönliche Präferenzen* einfügen. Der Server schickt zwar selbst entsprechende Anweisungen
mit. Mit den Präferenzen hält sich Claude aber zuverlässiger daran.

## 3. ChatGPT anbinden

ChatGPT läuft in der Cloud und kommt nicht direkt an die Dateien auf deinem Mac. Deshalb läuft derselbe Server
zusätzlich im **HTTP‑Modus** und wird über einen **HTTPS‑Tunnel** erreichbar gemacht. Dafür muss der Mac laufen.

1. **Geheimes Token erzeugen** und gut aufbewahren. Wer die URL mit dem Token kennt, kann deinen Vault lesen und beschreiben:
   ```bash
   .venv/bin/python -m ai_memory token
   ```
2. **Tunnel mit fester Adresse einrichten**, z. B. mit [ngrok](https://ngrok.com). Der kostenlose Plan enthält eine
   feste Domain wie `dein-name.ngrok-free.app`. Alternativen sind Cloudflare Tunnel (eigene Domain) oder Tailscale Funnel.
3. **Server und Tunnel starten** (zwei Terminal‑Fenster):
   ```bash
   export OBSIDIAN_VAULT_PATH="$HOME/Library/Mobile Documents/iCloud~md~obsidian/Documents/<Vault>"
   export AI_MEMORY_TOKEN="<token>"
   export AI_MEMORY_PUBLIC_HOST="dein-name.ngrok-free.app"
   .venv/bin/python -m ai_memory http          # lauscht nur lokal auf 127.0.0.1:8765
   ```
   ```bash
   ngrok http --url=dein-name.ngrok-free.app 8765
   ```
4. **In ChatGPT**: *Einstellungen → Apps & Connectors → Erweitert → Developer Mode* einschalten. Dann
   *Connector erstellen*:
   - Name: `Obsidian Gedächtnis`
   - URL: `https://dein-name.ngrok-free.app/<token>/mcp`
   - Authentifizierung: *Keine* (das Token steckt in der URL)

   Den Developer Mode gibt es je nach ChatGPT‑Plan, aktuell bei Plus/Pro/Business. Die genauen Menünamen ändert OpenAI gelegentlich.
5. Den Text aus [`prompts/chatgpt_anweisungen.md`](prompts/chatgpt_anweisungen.md) in die *benutzerdefinierten Hinweise*
   von ChatGPT einfügen und den Connector im Chat über „+“ aktivieren.

**Sicherheit:** Der Server nimmt nur Anfragen an, die das Token im Pfad haben (sonst 404) und deren Host‑Header die
eingetragene Tunnel‑Domain ist. Ordner wie `.obsidian`, `.trash` und Pfade außerhalb des Vaults sind gesperrt. Wenn
das Token bekannt geworden ist, erzeugst du ein neues und änderst die Connector‑URL.

**Bonus:** Dieselbe HTTPS‑URL kannst du auch in **Claude im Web oder auf dem iPhone** als benutzerdefinierten Connector
eintragen (*Einstellungen → Connectors → Benutzerdefinierten Connector hinzufügen*). Dann hat Claude auch unterwegs Zugriff.

## 4. Alte Chats importieren

Exporte anfordern: in ChatGPT unter *Einstellungen → Datenkontrollen → Daten exportieren*, in Claude unter
*Einstellungen → Datenschutz → Daten exportieren*. Danach:

```bash
export OBSIDIAN_VAULT_PATH="…/<Vault>"
.venv/bin/python -m ai_memory import chatgpt ~/Downloads/chatgpt-export.zip
.venv/bin/python -m ai_memory import claude  ~/Downloads/claude-export.zip
```

Ein erneuter Import aktualisiert die vorhandenen Notizen und legt keine Duplikate an. Standardmäßig wird jede Nachricht auf
1500 Zeichen gekürzt. Mit `--full` übernimmst du den kompletten Verlauf.

## Wie der Wechsel zwischen Claude und ChatGPT funktioniert

1. Du besprichst in ChatGPT dein Projekt X. ChatGPT speichert `Projekte/Projekt X.md` und eine Gesprächszusammenfassung.
2. Du fragst später Claude: „Mach bei Projekt X weiter“. Claude ruft `memory_context("Projekt X")` auf, findet beide
   Notizen und arbeitet mit dem Stand von ChatGPT weiter. Neue Ergebnisse hängt Claude an dieselbe Projekt‑Notiz an.
3. Alles ist sofort in Obsidian auf Mac, iPhone und iPad sichtbar und bearbeitbar. Deine eigenen Änderungen lesen beide Modelle ebenfalls.

## Entwicklung

```bash
pip install -e ".[dev]" && pytest
```

Konfiguration über Umgebungsvariablen: `OBSIDIAN_VAULT_PATH`, `AI_MEMORY_FOLDER` (Standard `KI-Gedaechtnis`),
`AI_MEMORY_TOKEN`, `AI_MEMORY_PUBLIC_HOST`, `AI_MEMORY_HOST` (Standard `127.0.0.1`), `AI_MEMORY_PORT` (Standard `8765`).
