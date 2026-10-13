"""Konfiguration über Umgebungsvariablen."""

from __future__ import annotations

import os
from dataclasses import dataclass
from pathlib import Path

# Standardpfad der Obsidian-App in iCloud Drive auf macOS.
ICLOUD_OBSIDIAN_ROOT = Path.home() / "Library" / "Mobile Documents" / "iCloud~md~obsidian" / "Documents"


def _default_vault() -> Path:
    """Nimmt den ersten Vault im iCloud-Obsidian-Ordner, falls genau einer existiert."""
    if ICLOUD_OBSIDIAN_ROOT.is_dir():
        vaults = sorted(p for p in ICLOUD_OBSIDIAN_ROOT.iterdir() if p.is_dir() and not p.name.startswith("."))
        if len(vaults) == 1:
            return vaults[0]
    raise RuntimeError(
        "Kein Vault gefunden. Bitte OBSIDIAN_VAULT_PATH setzen, z.B. "
        f"'{ICLOUD_OBSIDIAN_ROOT}/MeinVault'."
    )


@dataclass(frozen=True)
class Settings:
    vault_path: Path
    memory_folder: str = "KI-Gedaechtnis"
    http_host: str = "127.0.0.1"
    http_port: int = 8765
    http_token: str | None = None
    public_host: str | None = None

    @classmethod
    def from_env(cls) -> "Settings":
        raw = os.environ.get("OBSIDIAN_VAULT_PATH")
        vault = Path(raw).expanduser() if raw else _default_vault()
        return cls(
            vault_path=vault,
            memory_folder=os.environ.get("AI_MEMORY_FOLDER", "KI-Gedaechtnis"),
            http_host=os.environ.get("AI_MEMORY_HOST", "127.0.0.1"),
            http_port=int(os.environ.get("AI_MEMORY_PORT", "8765")),
            http_token=os.environ.get("AI_MEMORY_TOKEN") or None,
            public_host=os.environ.get("AI_MEMORY_PUBLIC_HOST") or None,
        )
