import json
import zipfile

import pytest

from ai_memory.importers import import_export
from ai_memory.vault import Vault, parse_frontmatter, safe_filename


@pytest.fixture
def vault(tmp_path):
    return Vault(tmp_path)


def test_creates_structure_and_profile(vault, tmp_path):
    assert (tmp_path / "KI-Gedaechtnis/Profil.md").exists()
    assert (tmp_path / "KI-Gedaechtnis/Gespraeche/ChatGPT").is_dir()


def test_save_search_read(vault):
    res = vault.save_note("Urlaub Italien", "Budget 2000 €, Toskana im Mai.", tags=["reise"], source="ChatGPT")
    assert res["path"] == "KI-Gedaechtnis/Wissen/Urlaub Italien.md"
    hits = vault.search("toskana budget")
    assert hits[0].path == res["path"] and hits[0].meta["source"] == "ChatGPT"
    note = vault.read(res["path"])
    assert "Toskana" in note["content"] and note["meta"]["tags"] == "[reise]"


def test_create_does_not_overwrite_and_append_works(vault):
    a = vault.save_note("Idee", "eins")
    b = vault.save_note("Idee", "zwei")
    assert b["path"].endswith("Idee (2).md")
    vault.save_note("Idee", "drei", mode="append", source="ChatGPT")
    content = vault.read(a["path"])["content"]
    assert "eins" in content and "drei" in content and "(ChatGPT)" in content


def test_overwrite_keeps_created(vault):
    p = vault.save_note("X", "alt")["path"]
    created = vault.read(p)["meta"]["created"]
    vault.save_note("X", "neu", mode="overwrite")
    note = vault.read(p)
    assert note["meta"]["created"] == created and "neu" in note["content"] and "alt" not in note["content"]


def test_path_traversal_blocked(vault):
    for bad in ("../geheim.md", "KI-Gedaechtnis/../../x.md", ".obsidian/app.json"):
        with pytest.raises(ValueError):
            vault.read(bad)
    # Absolute Pfade werden relativ zum Vault interpretiert, nicht zum Dateisystem.
    with pytest.raises(FileNotFoundError):
        vault.read("/etc/passwd")
    with pytest.raises(ValueError):
        vault.save_note("t", "c", folder="../../draussen")


def test_safe_filename():
    assert safe_filename('a/b:c?*"[x]#') == "a-b-c----x"
    assert safe_filename("   ") == "Unbenannt"


def test_context_contains_profile_recent_and_relevant(vault):
    vault.update_profile("Ich heiße Paul und mag kurze Antworten.", source="Claude")
    vault.save_note("Python Projekt", "FastAPI Backend", folder="Projekte")
    ctx = vault.context("FastAPI")
    assert "kurze Antworten" in ctx["profil"]
    assert ctx["relevant"][0]["path"].endswith("Python Projekt.md")
    assert any(r["path"].endswith("Python Projekt.md") for r in ctx["zuletzt"])


def test_log_conversation_and_reimport_is_idempotent(vault, tmp_path):
    export = [{
        "title": "Rezept", "create_time": 1700000000.0, "conversation_id": "c1", "current_node": "n3",
        "mapping": {
            "n1": {"message": None, "parent": None},
            "n2": {"message": {"author": {"role": "user"}, "content": {"content_type": "text", "parts": ["Wie backe ich Brot?"]}}, "parent": "n1"},
            "n2b": {"message": {"author": {"role": "assistant"}, "content": {"content_type": "text", "parts": ["VERWORFEN"]}}, "parent": "n2"},
            "n3": {"message": {"author": {"role": "assistant"}, "content": {"content_type": "text", "parts": ["Mehl, Wasser, Salz, Hefe."]}}, "parent": "n2"},
        },
    }]
    zpath = tmp_path / "export.zip"
    with zipfile.ZipFile(zpath, "w") as zf:
        zf.writestr("conversations.json", json.dumps(export))
    assert import_export(vault, "chatgpt", str(zpath)) == 1
    assert import_export(vault, "chatgpt", str(zpath)) == 1
    files = list((tmp_path / "KI-Gedaechtnis/Gespraeche/ChatGPT").glob("*.md"))
    assert len(files) == 1
    text = files[0].read_text()
    assert "Mehl" in text and "VERWORFEN" not in text
    assert parse_frontmatter(text)[0]["conversation_id"] == "c1"
    assert vault.search("Brot", source="ChatGPT")


def test_claude_import(vault, tmp_path):
    export = [{"uuid": "u1", "name": "Steuern", "created_at": "2026-01-05T10:00:00Z",
               "chat_messages": [{"sender": "human", "text": "Frage zur Steuer"},
                                 {"sender": "assistant", "text": "", "content": [{"type": "text", "text": "Antwort"}]}]}]
    f = tmp_path / "conversations.json"
    f.write_text(json.dumps(export))
    assert import_export(vault, "claude", str(f)) == 1
    hit = vault.search("Steuer", source="Claude")[0]
    assert hit.path.startswith("KI-Gedaechtnis/Gespraeche/Claude/2026-01-05")
