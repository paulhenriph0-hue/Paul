"""Lese- und Schreibzugriff auf den Obsidian-Vault (reine Dateioperationen, keine MCP-Abhängigkeit)."""

from __future__ import annotations

import os
import re
import tempfile
from dataclasses import dataclass, field
from datetime import datetime, timedelta
from pathlib import Path

SOURCES = ("Claude", "ChatGPT", "Manuell")
PROFILE_NOTE = "Profil.md"
_FORBIDDEN = re.compile(r'[\\/:*?"<>|#^\[\]\x00-\x1f]')
_FRONTMATTER = re.compile(r"\A---\n(.*?)\n---\n?", re.DOTALL)
_WORD = re.compile(r"\w+", re.UNICODE)


def now() -> datetime:
    return datetime.now().replace(microsecond=0)


def safe_filename(title: str, max_len: int = 120) -> str:
    """Macht aus einem Titel einen gültigen Obsidian-Dateinamen (ohne Endung)."""
    name = _FORBIDDEN.sub("-", title).strip(" .-")
    name = re.sub(r"\s+", " ", name)
    return (name[:max_len].rstrip(" .-") or "Unbenannt")


def _yaml_value(value: object) -> str:
    if isinstance(value, (list, tuple)):
        return "[" + ", ".join(_yaml_value(v) for v in value) + "]"
    text = str(value)
    if text == "" or re.search(r"[:#\[\]{},&*!|>'\"%@`]|^\s|\s$", text):
        return '"' + text.replace("\\", "\\\\").replace('"', '\\"') + '"'
    return text


def render_frontmatter(meta: dict[str, object]) -> str:
    lines = [f"{key}: {_yaml_value(val)}" for key, val in meta.items() if val not in (None, [], "")]
    return "---\n" + "\n".join(lines) + "\n---\n"


def parse_frontmatter(text: str) -> tuple[dict[str, str], str]:
    """Einfacher Parser für flache YAML-Frontmatter (ausreichend für die selbst geschriebenen Notizen)."""
    match = _FRONTMATTER.match(text)
    if not match:
        return {}, text
    meta: dict[str, str] = {}
    for line in match.group(1).splitlines():
        if ":" in line and not line.startswith(" "):
            key, _, val = line.partition(":")
            meta[key.strip()] = val.strip().strip('"')
    return meta, text[match.end():]


def normalize_tags(tags: list[str] | str | None) -> list[str]:
    if not tags:
        return []
    if isinstance(tags, str):
        tags = re.split(r"[,\s]+", tags)
    out: list[str] = []
    for tag in tags:
        tag = re.sub(r"[^\w/-]", "", tag.strip().lstrip("#").replace(" ", "-"))
        if tag and tag not in out:
            out.append(tag)
    return out


@dataclass
class SearchHit:
    path: str
    title: str
    score: float
    snippet: str
    modified: str
    meta: dict[str, str] = field(default_factory=dict)

    def as_dict(self) -> dict[str, object]:
        return {
            "path": self.path,
            "title": self.title,
            "score": round(self.score, 2),
            "snippet": self.snippet,
            "modified": self.modified,
            "source": self.meta.get("source", ""),
            "tags": self.meta.get("tags", ""),
        }


class Vault:
    """Kapselt alle Zugriffe auf den Vault. Alle Pfade sind relativ zum Vault-Stammordner."""

    def __init__(self, root: Path | str, memory_folder: str = "KI-Gedaechtnis") -> None:
        self.root = Path(root).expanduser().resolve()
        if not self.root.is_dir():
            raise FileNotFoundError(f"Vault-Ordner existiert nicht: {self.root}")
        self.memory_folder = memory_folder
        self.memory = self.root / memory_folder
        for sub in ("Wissen", "Projekte", "Journal", "Gespraeche/Claude", "Gespraeche/ChatGPT"):
            (self.memory / sub).mkdir(parents=True, exist_ok=True)
        profile = self.memory / PROFILE_NOTE
        if not profile.exists():
            self._write(profile, render_frontmatter({"type": "profil", "created": now().isoformat()})
                        + "# Profil\n\nDauerhafte Infos über mich (Vorlieben, Ziele, Kontext). "
                          "Claude und ChatGPT lesen diese Notiz zu Beginn jeder Unterhaltung.\n")

    # ------------------------------------------------------------------ Pfade
    def resolve(self, rel_path: str) -> Path:
        """Wandelt einen relativen Pfad in einen absoluten um und verhindert Ausbrüche aus dem Vault."""
        rel = rel_path.strip().lstrip("/")
        if not rel:
            raise ValueError("Leerer Pfad")
        candidate = (self.root / rel).resolve()
        if candidate != self.root and self.root not in candidate.parents:
            raise ValueError(f"Pfad liegt außerhalb des Vaults: {rel_path}")
        if any(part.startswith(".") for part in candidate.relative_to(self.root).parts):
            raise ValueError("Versteckte Ordner (.obsidian, .trash, …) sind gesperrt")
        return candidate

    def rel(self, path: Path) -> str:
        return path.relative_to(self.root).as_posix()

    def _folder(self, folder: str) -> Path:
        path = self.resolve(f"{self.memory_folder}/{folder.strip('/')}") if folder else self.memory
        path.mkdir(parents=True, exist_ok=True)
        return path

    @staticmethod
    def _write(path: Path, text: str) -> None:
        """Atomar schreiben, damit iCloud nie eine halb geschriebene Datei synchronisiert."""
        path.parent.mkdir(parents=True, exist_ok=True)
        fd, tmp = tempfile.mkstemp(dir=path.parent, prefix=".tmp-", suffix=".md")
        try:
            with os.fdopen(fd, "w", encoding="utf-8") as fh:
                fh.write(text)
            os.replace(tmp, path)
        except BaseException:
            Path(tmp).unlink(missing_ok=True)
            raise

    def _iter_notes(self, base: Path | None = None):
        base = base or self.root
        for dirpath, dirnames, filenames in os.walk(base):
            dirnames[:] = [d for d in dirnames if not d.startswith(".")]
            for name in filenames:
                # iCloud-Platzhalter (".Notiz.md.icloud") sind noch nicht heruntergeladen und werden übersprungen.
                if name.endswith(".md") and not name.startswith("."):
                    yield Path(dirpath) / name

    # --------------------------------------------------------------- Schreiben
    def save_note(
        self,
        title: str,
        content: str,
        folder: str = "Wissen",
        tags: list[str] | str | None = None,
        source: str = "Claude",
        mode: str = "create",
    ) -> dict[str, str]:
        """Legt eine Notiz an. mode: create (neue Datei, bei Namenskonflikt mit Suffix),
        overwrite (ersetzen) oder append (an bestehende Notiz anhängen bzw. neu anlegen)."""
        if mode not in ("create", "overwrite", "append"):
            raise ValueError("mode muss create, overwrite oder append sein")
        target_dir = self._folder(folder)
        base = safe_filename(title)
        path = target_dir / f"{base}.md"
        stamp = now()
        tag_list = normalize_tags(tags)

        if mode == "append" and path.exists():
            self.append(self.rel(path), content, source=source)
            return {"path": self.rel(path), "action": "appended"}

        created = stamp.isoformat()
        if mode == "create":
            counter = 2
            while path.exists():
                path = target_dir / f"{base} ({counter}).md"
                counter += 1
        elif mode == "overwrite" and path.exists():
            created = parse_frontmatter(path.read_text(encoding="utf-8"))[0].get("created", created)

        meta = {"title": title, "source": source, "created": created, "updated": stamp.isoformat(), "tags": tag_list}
        body = content if content.lstrip().startswith("#") else f"# {title}\n\n{content}"
        self._write(path, render_frontmatter(meta) + body.rstrip() + "\n")
        self.journal(f"{source} hat [[{self.rel(path)[:-3]}|{title}]] gespeichert")
        return {"path": self.rel(path), "action": "overwritten" if mode == "overwrite" else "created"}

    def append(self, rel_path: str, content: str, source: str = "Claude", heading: str | None = None) -> dict[str, str]:
        path = self.resolve(rel_path if rel_path.endswith(".md") else f"{rel_path}.md")
        stamp = now()
        if path.exists():
            text = path.read_text(encoding="utf-8")
            meta, body = parse_frontmatter(text)
            if meta:
                meta["updated"] = stamp.isoformat()
                text = render_frontmatter(meta) + body
        else:
            text = render_frontmatter({"source": source, "created": stamp.isoformat()}) + f"# {path.stem}\n"
        block = f"\n## {heading or stamp.strftime('%Y-%m-%d %H:%M')} ({source})\n\n{content.strip()}\n"
        self._write(path, text.rstrip() + "\n" + block)
        return {"path": self.rel(path), "action": "appended"}

    def update_profile(self, content: str, source: str = "Claude") -> dict[str, str]:
        return self.append(f"{self.memory_folder}/{PROFILE_NOTE}", content, source=source)

    def journal(self, line: str) -> None:
        stamp = now()
        path = self.memory / "Journal" / f"{stamp:%Y-%m-%d}.md"
        text = path.read_text(encoding="utf-8") if path.exists() else f"# Journal {stamp:%Y-%m-%d}\n\n"
        self._write(path, text.rstrip("\n") + f"\n- {stamp:%H:%M} {line}\n")

    def log_conversation(
        self,
        source: str,
        title: str,
        summary: str,
        key_points: list[str] | None = None,
        transcript: str | None = None,
        tags: list[str] | str | None = None,
        started: datetime | None = None,
        conversation_id: str | None = None,
        journal: bool = True,
    ) -> dict[str, str]:
        """Speichert eine Unterhaltung (Zusammenfassung + optional Verlauf) unter Gespraeche/<Quelle>/."""
        source = source if source in SOURCES else "Claude"
        when = started or now()
        folder = self._folder(f"Gespraeche/{source}")
        path = folder / f"{when:%Y-%m-%d} {safe_filename(title, 90)}.md"
        if conversation_id:
            # Erneuter Import derselben Unterhaltung überschreibt die alte Datei statt Duplikate zu erzeugen.
            path = self._conversation_index(folder).get(conversation_id, path)
        meta = {
            "title": title,
            "source": source,
            "type": "gespraech",
            "created": when.isoformat(),
            "updated": now().isoformat(),
            "conversation_id": conversation_id,
            "tags": normalize_tags(tags) + [f"ki/{source.lower()}"],
        }
        parts = [f"# {title}", "", "## Zusammenfassung", "", summary.strip()]
        if key_points:
            parts += ["", "## Wichtige Punkte", ""] + [f"- {p}" for p in key_points]
        if transcript:
            parts += ["", "## Verlauf", "", transcript.strip()]
        self._write(path, render_frontmatter(meta) + "\n".join(parts) + "\n")
        if conversation_id:
            self._conversation_index(folder)[conversation_id] = path
        if journal:
            self.journal(f"Gespräch mit {source}: [[{self.rel(path)[:-3]}|{title}]]")
        return {"path": self.rel(path), "action": "saved"}

    def _conversation_index(self, folder: Path) -> dict[str, Path]:
        if not hasattr(self, "_conv_index"):
            self._conv_index: dict[Path, dict[str, Path]] = {}
        if folder not in self._conv_index:
            index = {}
            for existing in folder.glob("*.md"):
                conv_id = parse_frontmatter(existing.read_text(encoding="utf-8"))[0].get("conversation_id")
                if conv_id:
                    index[conv_id] = existing
            self._conv_index[folder] = index
        return self._conv_index[folder]

    # ------------------------------------------------------------------ Lesen
    def read(self, rel_path: str, max_chars: int = 20000) -> dict[str, object]:
        path = self.resolve(rel_path if rel_path.endswith(".md") else f"{rel_path}.md")
        if not path.exists():
            icloud = path.with_name(f".{path.name}.icloud")
            if icloud.exists():
                raise FileNotFoundError(f"{rel_path} liegt nur in iCloud – bitte in Finder/Obsidian öffnen, damit sie geladen wird.")
            raise FileNotFoundError(f"Notiz nicht gefunden: {rel_path}")
        text = path.read_text(encoding="utf-8")
        meta, body = parse_frontmatter(text)
        truncated = len(body) > max_chars
        return {
            "path": self.rel(path),
            "title": meta.get("title", path.stem),
            "meta": meta,
            "content": body[:max_chars] + ("\n…[gekürzt]" if truncated else ""),
            "truncated": truncated,
        }

    def list_notes(self, folder: str = "", limit: int = 100) -> list[dict[str, str]]:
        base = self.resolve(folder) if folder else self.root
        if not base.is_dir():
            raise FileNotFoundError(f"Ordner nicht gefunden: {folder}")
        notes = sorted(self._iter_notes(base), key=lambda p: p.stat().st_mtime, reverse=True)
        return [{"path": self.rel(p), "modified": datetime.fromtimestamp(p.stat().st_mtime).isoformat(timespec="minutes")}
                for p in notes[:limit]]

    def search(self, query: str, limit: int = 10, folder: str = "", source: str | None = None) -> list[SearchHit]:
        """Volltextsuche über den ganzen Vault mit einfacher Relevanzbewertung (Titel > Tags > Text, neuere Notizen leicht bevorzugt)."""
        terms = [t.lower() for t in _WORD.findall(query) if len(t) > 1]
        if not terms:
            return []
        base = self.resolve(folder) if folder else self.root
        hits: list[SearchHit] = []
        cutoff = datetime.now() - timedelta(days=30)
        for path in self._iter_notes(base):
            try:
                text = path.read_text(encoding="utf-8")
            except (OSError, UnicodeDecodeError):
                continue
            meta, body = parse_frontmatter(text)
            if source and meta.get("source", "").lower() != source.lower():
                continue
            title = meta.get("title", path.stem)
            lowered_title, lowered_body, lowered_tags = title.lower(), body.lower(), meta.get("tags", "").lower()
            score = 0.0
            matched = 0
            for term in terms:
                in_title = lowered_title.count(term)
                in_tags = lowered_tags.count(term)
                in_body = lowered_body.count(term)
                if in_title or in_tags or in_body:
                    matched += 1
                score += 5 * in_title + 3 * in_tags + min(in_body, 20)
            if not matched:
                continue
            score *= matched / len(terms)  # Notizen, die alle Begriffe enthalten, nach oben
            mtime = datetime.fromtimestamp(path.stat().st_mtime)
            if mtime > cutoff:
                score *= 1.2
            hits.append(SearchHit(self.rel(path), title, score, self._snippet(body, terms),
                                  mtime.isoformat(timespec="minutes"), meta))
        hits.sort(key=lambda h: h.score, reverse=True)
        return hits[:limit]

    @staticmethod
    def _snippet(body: str, terms: list[str], width: int = 240) -> str:
        lowered = body.lower()
        positions = [lowered.find(t) for t in terms if lowered.find(t) >= 0]
        start = max(0, min(positions) - width // 3) if positions else 0
        snippet = re.sub(r"\s+", " ", body[start:start + width]).strip()
        return ("…" if start else "") + snippet + ("…" if start + width < len(body) else "")

    def recent(self, days: int = 7, limit: int = 15, source: str | None = None) -> list[dict[str, str]]:
        cutoff = datetime.now() - timedelta(days=days)
        out = []
        for path in sorted(self._iter_notes(self.memory), key=lambda p: p.stat().st_mtime, reverse=True):
            mtime = datetime.fromtimestamp(path.stat().st_mtime)
            if mtime < cutoff:
                break
            meta, body = parse_frontmatter(path.read_text(encoding="utf-8"))
            if source and meta.get("source", "").lower() != source.lower():
                continue
            out.append({"path": self.rel(path), "title": meta.get("title", path.stem), "source": meta.get("source", ""),
                        "modified": mtime.isoformat(timespec="minutes"),
                        "preview": re.sub(r"\s+", " ", body)[:200]})
            if len(out) >= limit:
                break
        return out

    def context(self, topic: str | None = None, limit: int = 8) -> dict[str, object]:
        """Startpaket für eine neue Unterhaltung: Profil, zuletzt Gespeichertes und passende Notizen zum Thema."""
        profile = self.read(f"{self.memory_folder}/{PROFILE_NOTE}", max_chars=6000)["content"]
        result: dict[str, object] = {"profil": profile, "zuletzt": self.recent(days=14, limit=limit)}
        if topic:
            result["relevant"] = [h.as_dict() for h in self.search(topic, limit=limit)]
        return result
