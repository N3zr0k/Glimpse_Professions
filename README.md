# Glimpse: Professions

<p align="center"><img src="docs/icon.png" alt="Professions icon" width="160"></p>

Extends the tooltips of profession spells with what you want to know about the profession: your skill with bonus, the
profession tier and the statistics of the game. Every profession has its own tab in the options; fishing comes first.

Requires [Glimpse](https://github.com/N3zr0k/Glimpse) 0.2.3 or newer. For WoW Forever (interface 16001).

## Contents

* [Features](#features)
* [Options](#options)
* [Commands](#commands)
* [Installation](#installation)
* [For developers](#for-developers)
* [Credits](#credits)
* [License](#license)

## Features

### Fishing

Hover the Fishing spell (spell book, professions window, action bar; all ranks):

```
Apprentice                                      the tier of the profession (from the client)
Fishing skill: 20 (+25)(+10)(+5)/75 · Total: 60
• Shiny Bauble +25                              lure (green) and buffs (orange) with their value
• Shiny Silver Coin +10
Shift + Double right click to cast the fishing rod
----------------------------
Glimpse: Statistics                             counters of this character, if Glimpse: Statistics is installed
   Casts: 72  today 72 · 7 days 72
----------------------------
Character statistics
   Fish caught                    19
```

While a line is cast, the tooltip of the fishing bobber shows the skill line and the counters.

* **Bonus:** the client reports one total bonus. The lure is a temporary enchant of the rod in your main hand and its
  value is read from the tooltip of the rod. Buffs with a fishing bonus (for example the Shiny Silver Coin) are found by
  the fishing line in their tooltip. What remains is the bonus of your equipment (green lure, orange buffs, blue
  equipment). "Show the bonuses" switches the display off, "separately" switches between the colored parts with the list
  and one combined total.
* **Profession tier:** the heading is the tier (Apprentice, Journeyman, Expert, ...), read from the client in the language
  of the game; the addon's own translation is only the fallback.
* **Statistics of the game:** the numbers Blizzard keeps (fish caught, fish and other things caught, daily fishing
  quests), names from the client; values that are still `--` are never shown. Each one can be switched on or off.
* **Glimpse: Statistics:** if [Glimpse: Statistics](https://github.com/N3zr0k/Glimpse_Statistics) 0.1.51 or newer is
  installed, its counters of this character (casts, catches, casts without catch, catch rate in total and per tier, fish
  caught, since when it counts) are shown too. They are read through its data API, never from its database. The Fishing
  tab shows a frame with the addon, its version and a switch.
* **Cast with a shortcut:** hold the chosen key (Shift, Ctrl, Alt or none) and double right-click the game world to cast.
  Without a rod in your hand your weapons (main hand and off hand) are put away and the rod is equipped; the next double
  click casts. After you moved more than 5 meters your weapons are equipped again (in combat: after the combat). Without
  room in your bags for the weapons, or in combat, a message appears and nothing is changed.
* **Apply the best lure automatically:** if the rod has no lure, the double click applies the best lure from your bags (a
  list of known lures, otherwise read from the item tooltip) and a green message names the lure, the rod and the bonus. The
  next double click casts.
* **Fishing Buddy:** with [Fishing Buddy](https://www.curseforge.com/wow/addons/fishingbuddy) loaded only the tooltip is
  extended. The weapon change, the cast shortcut, the lure and their options are switched off; the Fishing tab says so.

## Options

Open them with `/gli config`, then Glimpse > Professions. A "General" tab and one tab per profession.

* **Fishing:** show the bonuses, lure, buff and equipment bonus separately, game statistics (each on its own), counters of
  Glimpse: Statistics, cast shortcut key, apply the best lure automatically.

Settings are stored in `GlimpseProfessionsDB`.

## Commands

| Command | Does |
| --- | --- |
| `/gli prof` | The professions with their skill and whether the tooltip is extended |
| `/gli prof probe [profession]` | What the client reports for a profession, e.g. `/gli prof probe fishing` |
| `/gli prof cast` | State of the fishing shortcut and a log of the last steps |
| `/gli prof buffs` | Your buffs with tooltip lines and which count as a fishing bonus |
| `/gli prof lure` | The rod, the lure on it and the lures found in your bags |

The last four are for troubleshooting.

## Installation

Install [Glimpse](https://github.com/N3zr0k/Glimpse/releases) first, then unpack this addon next to it into the AddOns
folder of the Forever client, during the beta for example `D:\Games\World of Warcraft\_classic_beta_\Interface\AddOns`.
The folder must be called `Glimpse_Professions`. Optional: Glimpse: Statistics, Fishing Buddy.

## For developers

A profession is one folder in `Modules/` (main file plus helpers, e.g. `Modules/Fishing/`), listed in `Modules/Modules.xml`; the main file calls `Glimpse.Professions:RegisterProfession(key, def)`
(see the comment at the top of `Core/Professions.lua`): label, skill line, spell IDs, default options, the options of the
tab (`options`) and the tooltip lines (`lines`). The tab appears in the options by itself.

The addon lives in the folder `Glimpse_Professions/` of the repository; link that folder into the AddOns folder
(junction) and `/reload` after each change. The tests need the Glimpse repository next to this one (or `GLIMPSE_DIR`).
Checks:

```
lua tests/run.lua
luacheck .
python3 tools/check.py
```

## Credits

Author: N3zr0k. Special thanks to Flovy and sMash for testing.

## License

MIT, see [LICENSE](LICENSE).
