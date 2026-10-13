# FitTrack

Native iPhone-Fitness-App mit **Swift**, **SwiftUI**, **SwiftData** und **Swift Charts**. Sie hat ein helles, modernes Design und speichert alle Daten lokal – ohne Benutzerkonto und ohne Cloud.

## Funktionen

| Bereich | Inhalt |
|---|---|
| **Übersicht** | Kalorienring mit verbleibenden kcal, Makro-Fortschritt (Protein/KH/Fett), Trainingswoche mit Wochenziel, Volumen und letztem Training, Gewichtstrend, Schnellaktionen |
| **Training** | Freies Training oder Start aus Plan, Sätze mit Gewicht/Wiederholungen, „Vorher“-Werte aus dem letzten Training, Abhaken mit automatischem Pausen-Timer (±15 s), Live-Dauer und -Volumen, Verlauf mit Detailansicht, „Als Plan speichern“ |
| **Pläne** | 4 Startpläne (Ganzkörper, Push, Pull, Beine), Pläne anlegen/bearbeiten, Zielsätze/-wiederholungen/-gewicht, Reihenfolge per Drag & Drop |
| **Übungen** | 36 Übungen nach Muskelgruppen, Suche, eigene Übungen, Detailansicht mit 1RM-Diagramm und Historie |
| **Ernährung** | Tagebuch pro Tag mit Frühstück/Mittag/Abend/Snacks, 45 Lebensmittel (Nährwerte pro 100 g), Suche, Favoriten, „Zuletzt verwendet“, Portionsvorschläge, eigene Lebensmittel, Schnelleintrag, Einträge bearbeiten |
| **Fortschritt** | Körpergewicht (Linien-Diagramm mit Zielgewicht und Antippen-Auswahl), Kraftentwicklung pro Übung (geschätztes 1RM und Top-Satz), wöchentliches Trainingsvolumen, Kalorien der letzten 14 Tage mit Ziellinie, jeweils Zeiträume 1M/3M/6M/1J/Alle |
| **Profil** | Persönliche Daten, BMI, Ziel und Aktivität, Kalorien-/Makroempfehlung (Mifflin-St Jeor), Wochenziel, Satzpause, Demo-Daten laden, alles zurücksetzen |

## Voraussetzungen

- Mac mit **Xcode 16 oder neuer** (die Projektdatei nutzt das Xcode-16-Format mit synchronisierten Ordnern)
- iOS **17.0** oder neuer auf iPhone bzw. Simulator
- Keine externen Abhängigkeiten, keine Pakete, kein Account nötig

## Installation

1. **macOS aktualisieren**, dann **Xcode** aus dem Mac App Store installieren und einmal starten (zusätzliche Komponenten installieren lassen, inklusive iOS-Simulator).
2. Dieses Repository auf den Mac holen, z. B.:
   ```bash
   git clone <Repository-URL>
   cd Paul/FitTrack
   ```
   Alternativ lädst du es auf GitHub als ZIP herunter („Code“ → „Download ZIP“).
3. **`FitTrack/FitTrack.xcodeproj` doppelklicken.** Xcode öffnet das Projekt.
4. Oben in der Leiste das Schema **FitTrack** und einen Simulator wählen (z. B. *iPhone 16*). Dann **⌘R** drücken.
5. In der App unter **Profil → Demo-Daten laden** tippen. Damit werden alle Diagramme sofort mit Beispieldaten gefüllt.

### Auf dem eigenen iPhone testen

1. Xcode → *Settings* → *Accounts* → mit deiner Apple-ID anmelden (eine kostenlose Apple-ID reicht).
2. Im Projekt: Ziel **FitTrack** → *Signing & Capabilities* → bei *Team* deine Apple-ID wählen.
3. Den **Bundle Identifier** von `com.example.FitTrack` auf etwas Eindeutiges ändern, z. B. `de.deinname.FitTrack`.
4. iPhone per Kabel verbinden. Auf dem iPhone den **Entwicklermodus** aktivieren (*Einstellungen → Datenschutz & Sicherheit → Entwicklermodus*).
5. iPhone als Ziel wählen und **⌘R** drücken. Beim ersten Start musst du dem Entwickler vertrauen: *Einstellungen → Allgemein → VPN & Geräteverwaltung*.

> Mit einer kostenlosen Apple-ID läuft die App 7 Tage. Danach einfach erneut aus Xcode installieren.

### Tests ausführen

**⌘U** führt die Unit-Tests aus (`FitTrackTests`). Sie prüfen unter anderem:

- Formeln für 1RM, Grundumsatz, Kalorien- und Makroempfehlung
- Zahlen-Parsing mit Komma und Punkt
- Startdaten, Training aus Plan und Demo-Daten
- Ernährungs-Tagessummen

### Falls sich das Projekt nicht öffnen lässt

Bei älterem Xcode (15.x) kannst du das Projekt mit [XcodeGen](https://github.com/yonaskolb/XcodeGen) neu erzeugen:

```bash
brew install xcodegen
cd FitTrack
xcodegen generate   # überschreibt FitTrack.xcodeproj anhand von project.yml
```

## Projektstruktur

```
FitTrack/
├── FitTrack.xcodeproj           Xcode-Projekt (+ geteiltes Schema)
├── project.yml                  Alternative Projektdefinition für XcodeGen
├── FitTrack/                    App-Quellcode (wird automatisch eingebunden)
│   ├── App/                     App-Einstieg, Tab-Navigation
│   ├── Models/                  SwiftData-Modelle (Profil, Übung, Plan, Training, Satz,
│   │                            Lebensmittel, Ernährungseintrag, Körpergewicht) + Enums
│   ├── Services/                Berechnungen, Auswertungen, Speicher, Startdaten,
│   │                            Trainingssteuerung, Formatierung
│   ├── Theme/                   Farben, Karten-Stil
│   ├── Components/              Wiederverwendbare Views (Ringe, Kacheln, Zahlenfelder)
│   ├── Views/
│   │   ├── Dashboard/           Übersicht
│   │   ├── Training/            Workouts, aktives Training, Pläne, Übungen
│   │   ├── Nutrition/           Tagebuch, Suche, Lebensmittelverwaltung
│   │   ├── Progress/            Diagramme, Gewicht
│   │   └── Profile/             Profil, Ziele, Datenverwaltung
│   └── Assets.xcassets          App-Icon, Akzentfarbe
└── FitTrackTests/               Unit-Tests
```

Neue Swift-Dateien legst du einfach in den Ordner `FitTrack/`. Xcode nimmt sie automatisch ins Projekt auf.

## Technische Hinweise

- **Datenspeicherung:** SwiftData speichert lokal in der App-Sandbox. CloudKit ist ausdrücklich deaktiviert. Beim Löschen der App werden alle Daten gelöscht.
- **Ernährungseinträge** kopieren die Nährwerte beim Erfassen. Spätere Änderungen oder das Löschen eines Lebensmittels verändern deinen Verlauf also nicht.
- **1RM-Schätzung** nach Epley: `Gewicht × (1 + Wiederholungen / 30)`.
- **Kalorienempfehlung:** Mifflin-St Jeor × Aktivitätsfaktor, je nach Ziel −500 / ±0 / +300 kcal. Protein richtet sich nach dem Körpergewicht, Fett liegt bei 25 % der Kalorien, den Rest bilden Kohlenhydrate.
- Die App nutzt Swift 5 im Sprachmodus und erzwingt das helle Erscheinungsbild.
- Die Nährwerte der Startlebensmittel sind Durchschnittswerte, keine medizinischen Angaben.
