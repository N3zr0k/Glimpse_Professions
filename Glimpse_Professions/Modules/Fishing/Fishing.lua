local Glimpse = LibStub("AceAddon-3.0"):GetAddon("Glimpse")
local P = Glimpse:GetModule("Professions")
local L = P.L

-- Angeln. Der Tooltip des Zaubers "Fischen" (alle Ränge) bekommt:
--   Geselle                            Berufsstufe (Client-Text)
--   Angelfertigkeit: 20 (+25)(+5)/75 · Gesamt: 50
--                                      Köder grün, Ausrüstung blau
--   ----------------
--   Auswerfen                          nur wenn aktiviert (FishingCast.lua)
--   Umschalt + Doppelter Rechtsklick, um die Angel auszuwerfen.
--   ----------------
--   Gefangene Fische   19              Blizzard-Statistik, nur Werte mit Inhalt
--
-- Schwimmer-Tooltip (Objekt ohne ID) zeigt nur die Fertigkeitszeile.
--
-- Der Client liefert nur den Gesamtbonus (skillModifier). Ohne Köder ist alles Ausrüstungsbonus, der wird je Charakter
-- gemerkt (nur mit Angel in der Hand). Mit Köder ist der Rest darüber der Köder. Ohne gemerkten Wert: alles zusammen (grün).

local COLOR = { lure = "|cff1eff00", buff = "|cffff8000", gear = "|cff4da6ff", total = "|cff1eff00", head = "|cffffd100", value = "|cffffffff" }

-- { statID, Fallback-Locale-Key } in Anzeigereihenfolge
local STATS = {
    { 1518, "Fish caught" },
    { 1456, "Fish and other things caught" },
    { 1526, "Daily fishing quests completed" },
}

--- Gesamtbonus -> Köder, Ausrüstung. gear = gemerkter Ausrüstungsbonus oder nil.
-- 3. Rückgabe true, wenn nicht trennbar.
function P.SplitBonus(total, lureActive, gear)
    total = math.max(tonumber(total) or 0, 0)
    if total == 0 then return 0, 0 end
    if not lureActive then return 0, total end
    if type(gear) ~= "number" then return 0, total, true end

    gear = math.min(math.max(gear, 0), total)
    return total - gear, gear
end

-- Köder = temporäre Verzauberung auf der Angel
local function LureActive(self)
    local has = self:GetMainHandEnchant()
    return has and self:IsPoleEquipped() or false
end

--- Ausrüstungsbonus merken (Angel ohne Köder). Ohne Angel verwerfen, die Angel selbst bringt oft Bonus.
local function Learn(self, def, buffs)
    buffs = buffs or self:FishingBuffs() -- def.refresh ruft ohne Liste auf
    if not self.char then return end
    if not self:IsPoleEquipped() then
        self.char.fishingGear = nil
        return
    end
    if LureActive(self) or #buffs > 0 then return end

    local skill = self:GetSkill(def)
    if skill then self.char.fishingGear = skill.modifier end
end

-- compact = nur Fertigkeitszeile (Schwimmer)
local function Lines(self, def, compact)
    local skill = self:GetSkill(def)
    if not skill then return nil end
    local buffs = self:FishingBuffs() -- teuer (Buff-Tooltips), nur einmal je Tooltip
    Learn(self, def, buffs)

    local key = def.key
    local lines = {}

    if not compact and self:Opt(key, "tier") then
        local tier = self:TierName(skill.max, def)
        if tier then lines[#lines + 1] = format("%s%s|r", COLOR.head, tier) end
    end

    -- Buffs (z. B. Glänzende Silbermünze) stecken im Gesamtbonus, sind aber weder Köder noch Ausrüstung
    local buffTotal = 0
    for _, buff in ipairs(buffs) do buffTotal = buffTotal + buff.value end
    buffTotal = math.min(buffTotal, math.max(tonumber(skill.modifier) or 0, 0))
    local lureOn = LureActive(self)
    local rest = (tonumber(skill.modifier) or 0) - buffTotal
    local lure, gear, combined = P.SplitBonus(rest, lureOn, self.char and self.char.fishingGear)
    -- Kennt der Angel-Tooltip den Köderwert, hat der Vorrang
    local lureEntry = lureOn and self:FishingLureEntry(lure) or nil
    if lureEntry and lureEntry.fromTooltip then
        lure = math.min(lureEntry.value, math.max(rest, 0))
        gear, combined = math.max(rest, 0) - lure, nil
        if self.char and #buffs == 0 then self.char.fishingGear = gear end
    end
    local text = format("%s: %s%d|r", L["Fishing skill"], COLOR.value, skill.rank)
    local showBonus = self:Opt(key, "bonus") ~= false
    if showBonus and self:Opt(key, "split") and not combined then
        local first = true
        local function Part(color, value) text = text .. format("%s%s(+%d)|r", first and " " or "", color, value) first = false end
        if lure > 0 then Part(COLOR.lure, lure) end
        if buffTotal > 0 then Part(COLOR.buff, buffTotal) end
        if gear > 0 then Part(COLOR.gear, gear) end
    elseif showBonus and lure + gear + buffTotal > 0 then
        text = text .. format(" %s(+%d)|r", COLOR.total, lure + gear + buffTotal)
    end
    text = text .. format("%s/%d|r", COLOR.value, skill.max)
    local bonus = lure + gear + buffTotal
    if showBonus and bonus > 0 then
        text = text .. format(" %s\194\183|r %s: %s%d|r", COLOR.value, P.ClientText("TOTAL", "Total"), COLOR.value, skill.rank + bonus)
    end
    lines[#lines + 1] = text

    -- Köder grün, Buffs orange
    if showBonus and self:Opt(key, "split") then
        if lureOn and lure > 0 then
            local entry = lureEntry
            if entry and entry.name then lines[#lines + 1] = format("%s\226\128\162|r %s%s|r %s+%d|r", COLOR.lure, COLOR.value, entry.name, COLOR.lure, entry.value) end
        end
        for _, buff in ipairs(buffs) do
            lines[#lines + 1] = format("%s\226\128\162|r %s%s|r %s+%d|r", COLOR.buff, COLOR.value, buff.name, COLOR.buff, buff.value)
        end
    end
    local counters = self:CounterLines() or {}
    if compact then
        for _, line in ipairs(counters) do lines[#lines + 1] = line end
        return lines
    end

    local journal = self.JournalLine and self:JournalLine()
    if journal then lines[#lines + 1] = journal end

    if self:CastEnabled() and self.CastShortcutLines then
        for _, line in ipairs(self:CastShortcutLines()) do lines[#lines + 1] = line end
    end

    -- eigene Zähler vor der Blizzard-Statistik
    for _, line in ipairs(counters) do lines[#lines + 1] = line end

    if self:Opt(key, "stats") then
        local rows = {}
        for _, stat in ipairs(STATS) do
            if self:Opt(key, "stat" .. stat[1]) then
                local value = self:ReadStatistic(stat[1])
                if not P.IsEmptyStatistic(value) then
                    rows[#rows + 1] = { self:BlizzardStatName(stat[1]) or L[stat[2]], value, 0.8, 0.8, 0.8 }
                end
            end
        end
        if #rows > 0 then
            lines[#lines + 1] = { separator = true }
            lines[#lines + 1] = format("%s%s|r", COLOR.head, L["Character statistics"])
            for _, row in ipairs(rows) do
                row[1] = P.INDENT .. row[1]
                lines[#lines + 1] = row
            end
        end
    end
    return lines
end

-- Gleiche Optik wie die Erweiterungsliste von Glimpse
local function Notice(name, version, ...)
    if not name then return "" end
    version = version and format("(%s) ", version:find("^[vV]") and version or ("v" .. version)) or ""
    return format("|cffffd100%s|r |cff33ff33%s|r|cffffffff%s|r\n|cff999999%s|r", name, version, L["installed"], table.concat({ ... }, "\n"))
end

local function Options(self, def)
    local key = def.key
    local statsOff = function() return not self:Opt(key, "stats") end
    -- Fishing Buddy oder Better Fishing übernimmt das Auswerfen
    local castHidden = function() return self:CastBlockedBy() ~= nil end

    local args = {
        tooltip = self:Toggle(key, "tooltip", 1, L["Extend the Fishing tooltip"],
            L["Adds your fishing skill, profession tier and Blizzard's statistics to the tooltip of the Fishing spell."]),
        displayHeader = { type = "header", order = 1.5, name = L["Tooltip display"] },
        bonus = self:Toggle(key, "bonus", 3, L["Show the bonuses"],
            L["Shows the bonuses on your fishing skill (lure, buffs, equipment) in the tooltip. When switched off, only the skill itself is shown."]),
        split = self:Toggle(key, "split", 3.5, L["Show lure, buff and equipment bonus separately"],
            L["Shows the lure bonus in green, buffs in orange and the bonus from your equipment in blue, and a list of lure and buffs below the skill. When switched off, one combined total is shown."],
            function() return not self:Opt(key, "bonus") end),
        tier = self:Toggle(key, "tier", 2, L["Show the profession tier"],
            L["Shows the tier of the profession (Apprentice, Journeyman ...) as the heading of the tooltip."]),
        stats = self:Toggle(key, "stats", 4, L["Show statistics"],
            L["Shows the statistics below a separator line: those Blizzard keeps for fishing and the counters Glimpse records. When switched off, both are hidden."]),
        journalHeader = { type = "header", order = 30, name = function() return self:JournalName() end },
        findFish = self:Toggle(key, "findFish", 31, L["Switch on Find Fish automatically"],
            L["After login or reload, and after reading the Weather-Beaten Journal, switches on Find Fish in the minimap tracking if it is off."]),
        castHeader = { type = "header", order = 20, name = L["Cast the fishing rod"] },
        castBlocked = {
            type = "description", order = 20.5, width = "full", fontSize = "medium",
            image = function() return select(3, self:CastBlockedByInfo()) end, imageWidth = 16, imageHeight = 16,
            hidden = function() return not castHidden() end,
            name = function()
                local name, version = self:CastBlockedByInfo()
                return Notice(name, version, "   " .. L["Casting with a shortcut and the weapon change are switched off."],
                    "   " .. L["Only the tooltip is used."])
            end,
        },
        cast = self:Toggle(key, "cast", 21, L["Cast with a shortcut"],
            L["Casts the fishing rod with a double click on the game world, using the modifier key and mouse button chosen below. Only while standing still and out of combat. If you do not hold a fishing rod, your weapons are put away and the rod is equipped (the next double click casts); after you moved more than 5 meters, your weapons are equipped again. Needs free bag space."]),
        lure = self:Toggle(key, "lure", 21.5, L["Apply the best lure automatically"],
            L["If the equipped fishing rod has no lure, the double click applies the best lure from your bags to it. The next double click casts."]),
    }
    args.cast.hidden = castHidden
    args.lure.hidden = castHidden
    args.lure.disabled = function() return not self:CastEnabled() end
    -- Zusatztaste und Maustaste wie in allen Glimpse-Addons, bei zentraler Taste vom Core ausgegraut
    if Glimpse.AddDoubleClickKeyOptions then
        self.account[key] = self.account[key] or {}
        Glimpse:AddDoubleClickKeyOptions(args, self.account[key], 22, { modifier = "castKey", button = "castButton",
            disabled = function() return not self:CastEnabled() end })
        args.doubleClickModifier.hidden, args.doubleClickButton.hidden = castHidden, castHidden
    end
    -- beide in einer Zeile
    args.bonus.width, args.split.width = 1, 2
    for index, stat in ipairs(STATS) do
        args["stat" .. stat[1]] = self:Toggle(key, "stat" .. stat[1], 5 + index, self:BlizzardStatName(stat[1]) or L[stat[2]],
            format(L["Blizzard statistic %d."], stat[1]), statsOff)
    end
    -- Unter "Statistiken" zwei Inline-Gruppen: Blizzard (Charakter) und die eigenen Zähler (FishingStats.lua)
    args.statHeader = { type = "header", order = 4.9, name = P.ClientText("STATISTICS", "Statistics") }
    local blizzard = { type = "group", inline = true, order = 5, name = P.ClientText("CHARACTER", "Character"), args = {} }
    for _, stat in ipairs(STATS) do
        local name = "stat" .. stat[1]
        blizzard.args[name], args[name] = args[name], nil
    end
    args.statBlizzard = blizzard

    args.statAddon = { type = "group", inline = true, order = 9,
        hidden = function() return self:FishingCounters() == nil end,
        disabled = statsOff,
        name = format("|cffffd100%s|r", L["Glimpse counters"]),
        args = {
            description = { type = "description", order = 1, width = "full", fontSize = "medium",
                name = format("|cff999999%s|r", L["Fishing counters of this character can be shown in the tooltip."]) },
            own = self:Toggle(key, "own", 3, L["Show the fishing counters"],
                L["Shows the fishing counters Glimpse records for this character in the tooltips of the Fishing spell and of the fishing bobber."], statsOff),
        },
    }
    return args
end

-- /gli prof probe: Angel und Köder
local function Probe(self, def)
    local lines = {}
    lines[#lines + 1] = format("fishing pole equipped: %s", tostring(self:IsPoleEquipped()))
    local has, id, expiration = self:GetMainHandEnchant()
    lines[#lines + 1] = format("main hand temporary enchant: %s (id %s, %s ms left)", tostring(has), tostring(id), tostring(expiration))
    lines[#lines + 1] = format("remembered equipment bonus: %s", tostring(self.char and self.char.fishingGear))
    local skill = self:GetSkill(def)
    if skill then
        local lure, gear, combined = P.SplitBonus(skill.modifier, LureActive(self), self.char and self.char.fishingGear)
        lines[#lines + 1] = format("split: lure %d, equipment %d%s", lure, gear, combined and " (not separable yet)" or "")
    end
    if self.JournalProbeLines then
        for _, line in ipairs(self:JournalProbeLines()) do lines[#lines + 1] = line end
    end
    for _, stat in ipairs(STATS) do
        lines[#lines + 1] = format("statistic %d (%s): %s", stat[1], tostring(self:BlizzardStatName(stat[1])), tostring(self:ReadStatistic(stat[1])))
    end
    return lines
end

P:RegisterProfession("fishing", {
    label = L["Fishing"],
    icon = "Interface\\Icons\\Trade_Fishing",
    skillLine = 356,
    skillNames = { L["Fishing"] },
    spells = { 7620, 7731, 7732, 18248, 33095, 51294 }, -- Fischen, Ränge 1 bis 6
    reference = 7620,
    defaults = { tooltip = true, bonus = true, split = true, tier = true, stats = true, stat1518 = true, stat1456 = true, stat1526 = true,
        own = true, cast = true, lure = true, castKey = "SHIFT", castButton = "RightButton", findFish = true },
    options = Options,
    lines = Lines,
    objectLines = function(self, def) return Lines(self, def, true) end,
    refresh = Learn,
    login = function(self) if self.EnableFindFish then self:EnableFindFish() end end,
    probe = Probe,
})
