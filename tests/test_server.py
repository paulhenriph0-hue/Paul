import anyio

from ai_memory.server import build_server
from ai_memory.vault import Vault


def test_tools_roundtrip(tmp_path):
    mcp = build_server(Vault(tmp_path))

    async def run():
        names = {t.name for t in await mcp.list_tools()}
        assert {"search", "fetch", "memory_context", "memory_save", "memory_log_conversation"} <= names
        await mcp.call_tool("memory_save", {"title": "Notiz A", "content": "Hallo Welt", "source": "ChatGPT"})
        res = await mcp.call_tool("search", {"query": "Welt"})
        found = res.structured_content["results"][0]
        assert found["id"] == "KI-Gedaechtnis/Wissen/Notiz A.md"
        res = await mcp.call_tool("fetch", {"id": found["id"]})
        assert "Hallo Welt" in res.structured_content["text"]

    anyio.run(run)
