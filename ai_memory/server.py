"""MCP-Server: stellt den Obsidian-Vault als Gedächtnis für Claude (stdio) und ChatGPT (HTTP) bereit."""

from __future__ import annotations

import argparse
import secrets
import sys
from typing import Any

from mcp.server.mcpserver import MCPServer

from .config import Settings
from .vault import Vault

INSTRUCTIONS = """\
Du hast Zugriff auf das persönliche Gedächtnis des Nutzers (ein Obsidian-Vault in iCloud), \
das von Claude UND ChatGPT gemeinsam genutzt wird.

1. Zu Beginn jeder Unterhaltung: `memory_context` mit dem Thema der Anfrage aufrufen und \
relevante frühere Infos in die Antwort einbeziehen. Bei Bedarf mit `search`/`fetch` nachlesen.
2. Neue dauerhafte Infos über den Nutzer (Vorlieben, Ziele, Fakten) mit `memory_update_profile` speichern.
3. Neu erarbeitete Ergebnisse (Konzepte, Texte, Entscheidungen, Code, Recherchen) mit `memory_save` \
als eigene Notiz ablegen; für laufende Projekte `memory_save` mit folder="Projekte" und mode="append".
4. Am Ende einer inhaltlich relevanten Unterhaltung `memory_log_conversation` mit einer \
Zusammenfassung und den wichtigsten Punkten aufrufen.
Gib beim Speichern immer die richtige Quelle an ("Claude" oder "ChatGPT"). Speichere keine Passwörter oder Zugangsdaten.
"""


def build_server(vault: Vault) -> MCPServer:
    mcp = MCPServer(name="obsidian-ki-gedaechtnis", instructions=INSTRUCTIONS, version="0.1.0")

    # --- Werkzeuge im Format, das ChatGPT (Connectors / Deep Research) erwartet -------------
    @mcp.tool(description="Durchsucht den gesamten Obsidian-Vault (inkl. Gesprächen aus Claude und ChatGPT). "
                          "Gibt eine Trefferliste mit IDs zurück, die mit `fetch` gelesen werden können.")
    def search(query: str) -> dict[str, Any]:
        hits = vault.search(query, limit=10)
        return {"results": [{"id": h.path, "title": h.title, "url": f"obsidian://open?path={h.path}",
                             "snippet": h.snippet} for h in hits]}

    @mcp.tool(description="Liest eine Notiz vollständig. `id` ist der Pfad aus `search`, z.B. 'KI-Gedaechtnis/Wissen/Thema.md'.")
    def fetch(id: str) -> dict[str, Any]:
        note = vault.read(id)
        return {"id": note["path"], "title": note["title"], "text": note["content"],
                "url": f"obsidian://open?path={note['path']}", "metadata": note["meta"]}

    # --- Gedächtnis-Werkzeuge ------------------------------------------------------------------
    @mcp.tool(description="IMMER zu Beginn einer Unterhaltung aufrufen. Liefert das Nutzerprofil, die zuletzt "
                          "gespeicherten Notizen (aus Claude und ChatGPT) und zum Thema passende Notizen.")
    def memory_context(topic: str = "") -> dict[str, Any]:
        return vault.context(topic or None)

    @mcp.tool(description="Speichert neue Informationen/Ergebnisse als Obsidian-Notiz. folder: 'Wissen' (Standard), "
                          "'Projekte' oder ein eigener Unterordner. mode: 'create' (neu), 'append' (an gleichnamige "
                          "Notiz anhängen), 'overwrite' (ersetzen). source: 'Claude' oder 'ChatGPT'. Inhalt in Markdown; "
                          "Verweise auf andere Notizen als [[Notizname]].")
    def memory_save(title: str, content: str, source: str, folder: str = "Wissen",
                    tags: list[str] | None = None, mode: str = "create") -> dict[str, str]:
        return vault.save_note(title, content, folder=folder, tags=tags, source=source, mode=mode)

    @mcp.tool(description="Hängt Text an eine bestehende Notiz an (Pfad aus search/memory_context).")
    def memory_append(path: str, content: str, source: str, heading: str = "") -> dict[str, str]:
        return vault.append(path, content, source=source, heading=heading or None)

    @mcp.tool(description="Ergänzt das Nutzerprofil um dauerhafte persönliche Infos (Vorlieben, Ziele, Rahmenbedingungen).")
    def memory_update_profile(content: str, source: str) -> dict[str, str]:
        return vault.update_profile(content, source=source)

    @mcp.tool(description="Speichert eine Zusammenfassung der aktuellen Unterhaltung. key_points: wichtigste "
                          "Ergebnisse/Entscheidungen. transcript optional (gekürzter Verlauf in Markdown).")
    def memory_log_conversation(source: str, title: str, summary: str, key_points: list[str] | None = None,
                                transcript: str = "", tags: list[str] | None = None) -> dict[str, str]:
        return vault.log_conversation(source, title, summary, key_points=key_points,
                                      transcript=transcript or None, tags=tags)

    @mcp.tool(description="Zeigt die zuletzt geänderten Gedächtnis-Notizen. source optional: 'Claude' oder 'ChatGPT'.")
    def memory_recent(days: int = 7, source: str = "") -> list[dict[str, str]]:
        return vault.recent(days=days, source=source or None)

    @mcp.tool(description="Listet Notizen in einem Ordner des Vaults (leer = ganzer Vault), neueste zuerst.")
    def memory_list(folder: str = "", limit: int = 50) -> list[dict[str, str]]:
        return vault.list_notes(folder, limit=limit)

    return mcp


def run_http(mcp: MCPServer, settings: Settings) -> None:
    import uvicorn
    from mcp.server.transport_security import TransportSecuritySettings

    if not settings.http_token:
        sys.exit("AI_MEMORY_TOKEN fehlt. Erzeuge einen mit:  python -m ai_memory token")
    # Das geheime Token steckt im Pfad, weil ChatGPT-Connectors ohne OAuth keine eigenen Header senden.
    path = f"/{settings.http_token}/mcp"
    hosts = [f"127.0.0.1:{settings.http_port}", f"localhost:{settings.http_port}"]
    if settings.public_host:
        hosts.append(settings.public_host)
    security = TransportSecuritySettings(enable_dns_rebinding_protection=bool(settings.public_host),
                                         allowed_hosts=hosts, allowed_origins=["https://chatgpt.com"])
    app = mcp.streamable_http_app(streamable_http_path=path, stateless_http=True, transport_security=security,
                                  host=settings.http_host)
    public = f"https://{settings.public_host}" if settings.public_host else "https://<dein-tunnel>"
    print(f"MCP-Server läuft. ChatGPT-Connector-URL: {public}{path}", file=sys.stderr)
    uvicorn.run(app, host=settings.http_host, port=settings.http_port, log_level="warning")


def main(argv: list[str] | None = None) -> None:
    parser = argparse.ArgumentParser(prog="ai_memory", description="Obsidian-Gedächtnis für Claude und ChatGPT")
    sub = parser.add_subparsers(dest="command")
    sub.add_parser("stdio", help="für Claude Desktop / Claude Code (Standard)")
    sub.add_parser("http", help="für ChatGPT (Streamable HTTP, über Tunnel erreichbar machen)")
    sub.add_parser("token", help="erzeugt ein zufälliges Zugriffstoken für den HTTP-Modus")
    imp = sub.add_parser("import", help="importiert einen Chat-Export (conversations.json) in den Vault")
    imp.add_argument("source", choices=["chatgpt", "claude"])
    imp.add_argument("file", help="Pfad zu conversations.json (oder dem entpackten Export-Ordner)")
    imp.add_argument("--full", action="store_true", help="kompletten Verlauf statt nur Auszug speichern")
    args = parser.parse_args(argv)

    if args.command == "token":
        print(secrets.token_urlsafe(32))
        return

    settings = Settings.from_env()
    vault = Vault(settings.vault_path, settings.memory_folder)

    if args.command == "import":
        from .importers import import_export
        count = import_export(vault, args.source, args.file, full=args.full)
        print(f"{count} Unterhaltungen importiert nach {settings.memory_folder}/Gespraeche/")
        return

    mcp = build_server(vault)
    if args.command == "http":
        run_http(mcp, settings)
    else:
        mcp.run("stdio")
