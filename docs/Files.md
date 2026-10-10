# Glimpse: Professions – Dateien

Alle Dateien im Addon-Ordner `Glimpse_Professions/`, in Ladereihenfolge.

Professions ist der einzige Schreiber des Namespace `fishing` in Glimpse: Database (Bereich Professions). Ohne Database
wird nichts gezählt und die eigenen Zähler fehlen im Tooltip. Einstellungen und zwei Merkwerte pro Charakter liegen
noch in der eigenen SavedVariable `GlimpseProfessionsDB` (AceDB: `global` = Einstellungen, `char` = `fishingGear`,
`fishingSaved`), nicht in einem Namespace von `Glimpse.db`.

| Datei | Beschreibung | Database | Weitere Abhängigkeiten |
| --- | --- | --- | --- |
| `Glimpse_Professions.toc` | Metadaten, Mindestversion Core (`X-Glimpse-MinVersion` 0.3.7), lädt nur `Glimpse_Professions.xml` | – | Benötigt Glimpse; optional Glimpse_Database, FishingBuddy, BetterFishing. SavedVariables `GlimpseProfessionsDB` |
| `Glimpse_Professions.xml` | Lädt Locales, Core, Modules, Commands in dieser Reihenfolge | – | – |
| `Locales/Locales.xml` | Lädt die Sprachdateien, `enUS` zuerst | – | – |
| `Locales/enUS.lua` | Englische Texte (Standard) | – | AceLocale-3.0 |
| `Locales/deDE.lua` | Deutsche Texte | – | AceLocale-3.0 |
| `Core/Core.xml` | Lädt die Core-Dateien, `Professions.lua` zuerst | – | – |
| `Core/Professions.lua` | Legt das Modul an, `RegisterProfession` für die Berufe, Einstellungen (`Opt`/`SetOpt`), `Clean` und `Protected` | – | Glimpse (`NewModule`, `RegisterAddonOptions`, `IsSecret`), AceDB-3.0 mit `GlimpseProfessionsDB`, AceEvent-3.0 |
| `Core/Skills.lua` | `api`-Tabelle der Blizzard-Funktionen, Fertigkeit, Boni und Berufsstufe eines Berufs, Zuordnung Zauber → Beruf | – | `GetProfessions`, `GetProfessionInfo`, `GetSkillLineInfo`, `GetWeaponEnchantInfo`, `C_Spell`, `C_Item` |
| `Core/Blizzard.lua` | Liest Blizzard-Statistiken (`GetStatistic`) und ihre lokalisierten Namen, speichert nichts | – | Blizzard-Statistik-API |
| `Core/Tooltip.lua` | Tooltip-Zeilen für Berufszauber und den Schwimmer (Objekt ohne ID), Anmeldung beim Core | – | `module:RegisterTooltipLine`, `Enum.TooltipDataType` |
| `Core/Probe.lua` | `/gli prof probe`: Rohdaten des Clients zu einem Beruf | – | Blizzard-API über `api` |
| `Core/Events.lua` | Fertigkeits- und Ausrüstungs-Events lösen `refresh` jedes Berufs aus, Login/Reload zusätzlich `login`, meldet die Tooltips an | – | AceEvent-3.0 |
| `Core/Options.lua` | Optionsseite: Tab Allgemein plus ein Tab je Beruf | Einstellungen: liest und schreibt `GlimpseProfessionsDB.global` | AceConfig über `Glimpse:RegisterAddonOptions` |
| `Modules/Modules.xml` | Lädt die Berufe, je Beruf ein Ordner | – | – |
| `Modules/Fishing/Fishing.xml` | Lädt die Angeln-Dateien, `Fishing.lua` zuerst | – | – |
| `Modules/Fishing/Fishing.lua` | Beruf Angeln: Tooltip am Zauber „Fischen“ (Stufe, Fertigkeit mit Boni, Statistik), Options-Tab mit Tastenauswahl des Cores, Probe | liest über `FishingStats.lua`; merkt `fishingGear` in `GlimpseProfessionsDB.char`; Einstellungen `castKey`, `castButton` in `GlimpseProfessionsDB.global.fishing` | `RegisterProfession`, `Glimpse:AddDoubleClickKeyOptions` (Core 0.3.7) |
| `Modules/Fishing/FishingRecord.lua` | Zählt Würfe, Fänge, Beute je Zone und Berufsstufe | schreibt: `fishing` (einziger Schreiber, auch `castabort`, `aborttier`; Weltwissen `looted`, `loot`, `drop`) | `GlimpseDB:Register`, `Glimpse.IDs:ZoneKey`, `C_Loot`, `IsFishingLoot`, `GetUnitSpeed`, `IsFalling`, `UnitAffectingCombat`, `C_Timer` |
| `Modules/Fishing/FishingStats.lua` | Eigene Angelzähler dieses Charakters für den Tooltip (gesamt, heute, 7 Tage, je Stufe) | liest: `fishing` | `GlimpseDB:Get` |
| `Modules/Fishing/FishingBuffs.lua` | Angelboni aus Buffs und Köder an der Angel | – | `C_UnitAuras`, `C_TooltipInfo` |
| `Modules/Fishing/FishingLure.lua` | Auto-Köder: bester Köder aus den Taschen beim Auswerfen | – | `C_Container`, `C_TooltipInfo.GetBagItem` |
| `Modules/Fishing/FishingCast.lua` | Doppelklick-Handler `fishing` für den Verteiler des Cores (nur im Stehen, Kampf sperrt der Core): Angel anlegen, Köder, Fischen; Waffen zurück nach Bewegung | merkt abgelegte Waffen in `GlimpseProfessionsDB.char.fishingSaved` | `Glimpse:RegisterDoubleClick`, `GetDoubleClickText` (Core 0.3.7), `C_Container`, `C_Item`, `C_Timer`, `GetUnitSpeed`; aus bei geladenem FishingBuddy oder BetterFishing |
| `Modules/Fishing/FishingJournal.lua` | Verwittertes Tagebuch (Item 34109, Zauber Fischsuche 43308): Tooltip-Zeile gelernt/nicht gelernt, schaltet die Fischsuche bei Login/Reload und nach dem Lernen ein (Option `findFish`) | – | `IsPlayerSpell`, `C_Minimap` (`GetNumTrackingTypes`, `GetTrackingInfo`, `SetTracking`), `Glimpse.IDs:DescribeItem`, Ereignis `LEARNED_SPELL_IN_TAB` |
| `Modules/Fishing/FishingSources.lua` | Zeilen für `/gli probe db sources` | liest: Stand der Anmeldung an `fishing` | `Glimpse:RegisterDataSource` |
| `Commands/Commands.xml` | Lädt die Slash-Befehle | – | – |
| `Commands/Prof.lua` | `/gli prof` mit `probe`, `cast`, `lure`, `buffs`, `record` | – | `Glimpse:RegisterCommand` |
| `Media/Icon.tga` | Addon-Icon | – | – |
| `LICENSE` | MIT-Lizenz, wird mit dem Addon ausgeliefert | – | – |
