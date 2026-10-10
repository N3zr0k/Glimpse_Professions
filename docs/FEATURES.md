# Glimpse: Professions – Features

Stand 0.3.13. Berufe: bisher nur Angeln.

## Angeln

| Feature | Beschreibung |
| --- | --- |
| Tooltip am Zauber „Fischen“ | Berufsstufe als Überschrift (Name aus dem Client), Fertigkeit mit Boni (Köder grün, Buffs orange, Ausrüstung blau) und Liste von Köder und Buffs |
| Tooltip am Schwimmer | Während des Angelns: Fertigkeit und eigene Zähler |
| Spielstatistik | Blizzard-Statistiken zum Angeln (gefangene Fische, Fänge, Tagesquests), einzeln abschaltbar |
| Eigene Zähler | Würfe, Fänge, Würfe ohne Fang, Fangquote gesamt und je Stufe, heute und 7 Tage, gefangene Fische, seit wann gezählt wird |
| Auswerfen per Doppelklick | Taste (Shift, Strg, Alt, keine) und Maustaste wählbar oder zentral im Core; nur im Stehen und außerhalb des Kampfes |
| Waffenwechsel | Ohne Angel: Waffen ablegen, Angel anlegen; nach 5 m Bewegung kommen die Waffen zurück (im Kampf danach); ohne Taschenplatz kein Wechsel |
| Auto-Köder | Angel ohne Köder: bester Köder aus den Taschen, Meldung mit Bonus |
| Verwittertes Tagebuch | Tooltip zeigt gelernt / nicht gelernt; Fischsuche wird bei Login/Reload und nach dem Lernen eingeschaltet (abschaltbar) |
| Fishing Buddy, Better Fishing | Ist eins davon geladen, bleibt nur der Tooltip; Doppelklick, Waffenwechsel und Köder sind aus, der Angeln-Tab zeigt einen Hinweis |

## Allgemein

| Feature | Beschreibung |
| --- | --- |
| Optionen | Tab Allgemein plus ein Tab je Beruf (`/gli config`) |
| Befehle | `/gli prof`, zur Fehlersuche `probe`, `cast`, `buffs`, `lure` |
| Datenquellen | Zeilen für `/gli probe db sources` |
| Sprachen | Deutsch, Englisch |

## Datenbank

Glimpse: Database, Bereich Professions. Ohne Glimpse_Database wird nichts gezählt.

| Namespace | Daten | Lesen | Schreiben |
| --- | --- | --- | --- |
| `fishing` | `cast`, `catch` (je Zone), `casttier`, `catchtier` (je Stufe), `fish` (Item je Zone) | ja (`FishingStats.lua`, Tooltip) | ja (`FishingRecord.lua`, einziger Schreiber) |
| `fishing` | Weltwissen `looted`, `loot:<Zone>`, `drop:<Zone>` | nein | ja (`FishingRecord.lua`) |

Einstellungen liegen noch in der eigenen SavedVariable `GlimpseProfessionsDB`, nicht in der Datenbank.
