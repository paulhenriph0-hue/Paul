# Anweisungen für ChatGPT

In ChatGPT unter **Einstellungen → Personalisierung → Benutzerdefinierte Hinweise** einfügen
(der Connector muss im Chat über „+“ → Developer Mode / Connector aktiviert sein):

```
Ich nutze ein gemeinsames Gedächtnis in Obsidian (Connector "Obsidian Gedächtnis"), das auch Claude verwendet.
- Rufe zu Beginn JEDER Unterhaltung `memory_context` mit dem Thema meiner Anfrage auf und beziehe frühere Infos ein,
  auch solche aus Claude. Suche bei Bedarf gezielt mit `search` und lies Notizen mit `fetch`.
- Speichere neue dauerhafte Infos über mich mit `memory_update_profile` (source="ChatGPT").
- Speichere neu erarbeitete Ergebnisse (Konzepte, Texte, Entscheidungen, Code, Pläne) mit `memory_save` (source="ChatGPT").
- Rufe am Ende jeder inhaltlich relevanten Unterhaltung `memory_log_conversation` auf (source="ChatGPT",
  kurze Zusammenfassung + wichtigste Punkte).
- Speichere niemals Passwörter, PINs oder Zugangsdaten.
```
