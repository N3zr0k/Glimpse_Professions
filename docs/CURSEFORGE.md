# Glimpse: Professions

> ## ⚠ Requires the Glimpse core addon
> **Glimpse: Professions only works together with [Glimpse](https://www.curseforge.com/wow/addons/glimpse).** Install Glimpse first (version 0.2.3 or newer), otherwise this addon does not load.
> 👉 https://www.curseforge.com/wow/addons/glimpse

Fishing in the tooltip, and a cast button for the lazy: **Glimpse: Professions** extends the tooltips of your professions with what you really want to know. Every profession has its own tab in the options. Fishing is first; more professions follow.

## What you get for fishing

**Tooltip of the Fishing spell and of the bobber**

- Your **profession tier** as heading (Apprentice, Journeyman, Expert ...), in the language of your game
- Your **fishing skill with every bonus**: `Fishing skill: 39 (+25)(+10)(+30)/75 · Total: 104`
  - lure in green, buffs (for example the Shiny Silver Coin) in orange, equipment in blue
  - a list below names the lure and each buff with its value
- The **statistics of the game** (fish caught, fish and other things caught, daily fishing quests)
- With **Glimpse: Statistics** installed: your casts, catches, casts without catch, catch rate (in total and per tier) and since when it counts

**Cast with a shortcut**

Hold a key (Shift, Ctrl, Alt or none) and double right-click the game world: the rod is cast. Without a rod in your hand your weapons are put away and the rod is equipped; when you move on, they come back.

**Apply the best lure automatically**

No lure on your rod? The double click applies the best lure from your bags and tells you what it brought: *"Apply Shiny Bauble to Fishing Pole. Your fishing skill increases by 25."* The next double click casts.

## Good to know

- Everything can be switched on or off in the options (Glimpse options, tab *Fishing*).
- Works together with **Fishing Buddy**: if it is loaded, only the tooltip is extended; the weapon change, cast shortcut and lure are switched off.
- Statistics are only read through the data API of Glimpse: Statistics, never from its database.
- German and English.

## Commands

`/gli prof` shows your professions. For troubleshooting: `/gli prof probe fishing`, `/gli prof cast`, `/gli prof buffs`, `/gli prof lure`.

## Links

- Core addon: [Glimpse on CurseForge](https://www.curseforge.com/wow/addons/glimpse) · [GitHub](https://github.com/N3zr0k/Glimpse)
- Source and issues: [GitHub](https://github.com/N3zr0k/Glimpse_Professions)
- MIT license
