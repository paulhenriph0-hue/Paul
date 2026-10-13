"""Importiert Daten-Exporte von ChatGPT und Claude (conversations.json) in den Vault.

ChatGPT: Einstellungen → Datenkontrollen → Daten exportieren
Claude:  Einstellungen → Datenschutz → Daten exportieren
Beide liefern eine ZIP-Datei mit conversations.json.
"""

from __future__ import annotations

import json
import zipfile
from datetime import datetime
from pathlib import Path
from typing import Any, Iterable

from .vault import Vault

EXCERPT_CHARS = 1500


def _load(path_str: str) -> list[dict[str, Any]]:
    path = Path(path_str).expanduser()
    if path.is_dir():
        path = path / "conversations.json"
    if path.suffix == ".zip":
        with zipfile.ZipFile(path) as zf:
            name = next(n for n in zf.namelist() if n.endswith("conversations.json"))
            return json.loads(zf.read(name).decode("utf-8"))
    return json.loads(path.read_text(encoding="utf-8"))


def _chatgpt_messages(conv: dict[str, Any]) -> list[tuple[str, str]]:
    """Folgt dem aktiven Zweig (current_node → Wurzel), damit verworfene Antworten nicht mit importiert werden."""
    mapping = conv.get("mapping") or {}
    node_id = conv.get("current_node")
    chain = []
    while node_id and node_id in mapping:
        chain.append(mapping[node_id])
        node_id = mapping[node_id].get("parent")
    out = []
    for node in reversed(chain):
        msg = node.get("message") or {}
        role = (msg.get("author") or {}).get("role")
        content = msg.get("content") or {}
        if role not in ("user", "assistant") or content.get("content_type") not in ("text", "multimodal_text"):
            continue
        text = "\n".join(p for p in content.get("parts") or [] if isinstance(p, str)).strip()
        if text and not (msg.get("metadata") or {}).get("is_visually_hidden_from_conversation"):
            out.append((role, text))
    return out


def _claude_messages(conv: dict[str, Any]) -> list[tuple[str, str]]:
    out = []
    for msg in conv.get("chat_messages") or []:
        role = "user" if msg.get("sender") == "human" else "assistant"
        text = msg.get("text") or "\n".join(
            c.get("text", "") for c in msg.get("content") or [] if c.get("type") == "text")
        if text.strip():
            out.append((role, text.strip()))
    return out


def _transcript(messages: Iterable[tuple[str, str]], other: str, full: bool) -> str:
    lines = []
    for role, text in messages:
        if not full and len(text) > EXCERPT_CHARS:
            text = text[:EXCERPT_CHARS].rstrip() + " …"
        speaker = "**Ich**" if role == "user" else f"**{other}**"
        lines.append(f"{speaker}:\n{text}\n")
    return "\n".join(lines)


def _parse_time(value: Any) -> datetime | None:
    if isinstance(value, (int, float)):
        return datetime.fromtimestamp(value)
    if isinstance(value, str) and value:
        return datetime.fromisoformat(value.replace("Z", "+00:00")).astimezone().replace(tzinfo=None)
    return None


def import_export(vault: Vault, source: str, path: str, full: bool = False) -> int:
    conversations = _load(path)
    label = "ChatGPT" if source == "chatgpt" else "Claude"
    count = 0
    for conv in conversations:
        if source == "chatgpt":
            messages, title = _chatgpt_messages(conv), conv.get("title")
            started, conv_id = _parse_time(conv.get("create_time")), conv.get("conversation_id") or conv.get("id")
        else:
            messages, title = _claude_messages(conv), conv.get("name")
            started, conv_id = _parse_time(conv.get("created_at")), conv.get("uuid")
        if not messages:
            continue
        first_question = next((t for r, t in messages if r == "user"), "")
        summary = conv.get("summary") or f"Importiert aus {label}. Erste Frage: {first_question[:400]}"
        vault.log_conversation(
            label, title or "Ohne Titel", summary,
            transcript=_transcript(messages, label, full),
            tags=["import"], started=started, conversation_id=conv_id, journal=False,
        )
        count += 1
    if count:
        vault.journal(f"{count} Unterhaltungen aus {label} importiert")
    return count
