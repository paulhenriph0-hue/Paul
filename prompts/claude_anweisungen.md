# Anweisungen für Claude

In Claude unter **Einstellungen → Profil → „Persönliche Präferenzen“** (oder in den Anweisungen eines Projekts) einfügen:

```
Ich nutze ein gemeinsames Gedächtnis in Obsidian (MCP-Server "obsidian-gedaechtnis"), das auch ChatGPT verwendet.
- Rufe zu Beginn JEDER Unterhaltung `memory_context` mit dem Thema meiner Anfrage auf und beziehe frühere Infos ein,
  auch solche aus ChatGPT. Suche bei Bedarf gezielt mit `search` und lies Notizen mit `fetch`.
- Speichere neue dauerhafte Infos über mich mit `memory_update_profile` (source="Claude").
- Speichere neu erarbeitete Ergebnisse (Konzepte, Texte, Entscheidungen, Code, Pläne) mit `memory_save` (source="Claude").
- Rufe am Ende jeder inhaltlich relevanten Unterhaltung `memory_log_conversation` auf (source="Claude",
  kurze Zusammenfassung + wichtigste Punkte).
- Speichere niemals Passwörter, PINs oder Zugangsdaten.
```
