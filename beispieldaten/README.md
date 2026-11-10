# Beispieldaten · Sample data

**Deutsch** · [English](#english)

Beispieldaten für 3D Print Studio: Filament-Typen, Hersteller, Filamente und Verbrauchsmaterial aus einem
echten Betrieb. Eine neue Installation bringt nur 13 Beispiel-Filamente und kein Verbrauchsmaterial mit; mit
diesen Dateien hat der Kostenrechner gleich eine größere Auswahl.

| Datei | Inhalt |
| --- | --- |
| `filament-typen-export.csv` | 22 Filament-Typen (PLA, PETG, PA-CF, TPU …) |
| `filament-hersteller-export.csv` | 7 Hersteller |
| `datenblaetter-export.zip` | technische Datenblätter der Hersteller als PDF – nur, wenn die Datei in diesem Ordner liegt |
| `filamente-export.csv` | 72 Filamente mit Farbe, Preis je kg, Spulengewicht, Dichte, Durchmesser und Bestand |
| `verbrauchsmaterial-export.csv` | 20 Verschleiß- und Ersatzteile (Hotends, Druckplatten, Schneidmatten …) mit Preis, Lebensdauer und Bestand |

## Einlesen

In der App unter **Grundeinstellungen → Import / Export**. Dort gibt es für jede Liste eine Zeile: Datei
auswählen, dann **Importieren**. Die Reihenfolge ist wichtig:

1. **Filament-Typen** – `filament-typen-export.csv`
2. **Filament-Hersteller** – `filament-hersteller-export.csv`
3. **Datenblätter** – `datenblaetter-export.zip` (falls vorhanden). Vor den Filamenten einlesen: Nur dann
   hängt die App jedes Filament an sein Datenblatt.
4. **Filamente** – `filamente-export.csv`
5. **Verbrauchsmaterial** – `verbrauchsmaterial-export.csv`

Ohne die Datenblätter funktioniert alles genauso, die Filamente haben dann nur kein Datenblatt. Es lässt sich
später in der Datenblatt-Bibliothek hochladen und beim Filament auswählen.

## Gut zu wissen

- **Preise und Bestände sind Beispiele.** Die Preise sind Einkaufspreise in Euro aus dem Jahr 2026, die
  Bestände die eines anderen Betriebs. Nach dem Einlesen an die eigenen Zahlen anpassen.
- **Zweimal einlesen legt nichts doppelt an.** Jede Zeile hat eine Kennung. Gibt es sie schon, entscheidet
  die Auswahl neben der Datei: **Ersetzen** überschreibt den Eintrag mit der Zeile aus der Datei,
  **Überspringen** lässt ihn, wie er ist. Typen und Hersteller werden nach ihrem Namen erkannt.
- **Vorhandenes bleibt.** Die 13 Beispiel-Filamente einer neuen Installation und eigene Einträge bleiben
  bestehen, die Beispieldaten kommen dazu (nach dem Einlesen in eine neue Installation sind es 85 Filamente).
- Die Datenblätter gehören den jeweiligen Herstellern.

---

<a id="english"></a>

# Sample data

[Deutsch](#beispieldaten--sample-data) · **English**

Sample data for 3D Print Studio: filament types, manufacturers, filaments and consumables from a real print
shop. A new installation comes with only 13 example filaments and no consumables; with these files the cost
calculator has a larger selection right away.

| File | Content |
| --- | --- |
| `filament-typen-export.csv` | 22 filament types (PLA, PETG, PA-CF, TPU …) |
| `filament-hersteller-export.csv` | 7 manufacturers |
| `datenblaetter-export.zip` | the manufacturers' technical data sheets as PDF – only if the file is in this folder |
| `filamente-export.csv` | 72 filaments with colour, price per kg, spool weight, density, diameter and stock |
| `verbrauchsmaterial-export.csv` | 20 wear and spare parts (hotends, build plates, cutting mats …) with price, lifetime and stock |

The names and notes in the files are in German and English as the manufacturers use them.

## Importing

In the app under **Basic settings → Import / Export**. There is one row per list: choose the file, then
**Import**. The order matters:

1. **Filament types** – `filament-typen-export.csv`
2. **Filament manufacturers** – `filament-hersteller-export.csv`
3. **Datasheets** – `datenblaetter-export.zip` (if present). Import it before the filaments: only then does
   the app attach each filament to its data sheet.
4. **Filaments** – `filamente-export.csv`
5. **Consumables** – `verbrauchsmaterial-export.csv`

Everything works the same without the data sheets; the filaments then simply have none. You can upload one
later in the datasheet library and select it at the filament.

## Good to know

- **Prices and stock are examples.** The prices are purchase prices in euros from 2026, the stock levels
  are those of another shop. Adjust them to your own numbers after importing.
- **Importing twice creates no duplicates.** Every row has an identifier. If it already exists, the choice
  next to the file decides: **Replace** overwrites the entry with the row from the file, **Skip** leaves it
  as it is. Types and manufacturers are recognised by their name.
- **Existing entries stay.** The 13 example filaments of a new installation and your own entries remain, the
  sample data is added (after importing into a new installation there are 85 filaments).
- The data sheets belong to their respective manufacturers.
