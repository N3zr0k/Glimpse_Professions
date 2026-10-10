local Glimpse = LibStub("AceAddon-3.0"):GetAddon("Glimpse")
local P = Glimpse:GetModule("Professions")
local L = P.L

-- Blizzard-API gebündelt, damit Tests sie ersetzen können. Fehlende Einträge = Funktion bleibt stumm.
P.api = {
    GetProfessions = GetProfessions,
    GetProfessionInfo = GetProfessionInfo,
    GetNumSkillLines = GetNumSkillLines,
    GetSkillLineInfo = GetSkillLineInfo,
    UnitChannelInfo = UnitChannelInfo,
    GetSpellName = C_Spell and C_Spell.GetSpellName or nil,
    GetSpellInfo = GetSpellInfo,
    GetSpellSubtext = C_Spell and C_Spell.GetSpellSubtext or nil,
    GetStatistic = GetStatistic,
    GetStatisticsCategoryList = GetStatisticsCategoryList,
    GetCategoryNumAchievements = GetCategoryNumAchievements,
    GetAchievementInfo = GetAchievementInfo,
}

local api = P.api

--- nil, solange die Daten nicht geladen sind
function P.SpellName(spellID)
    if api.GetSpellName then
        local ok, name = pcall(api.GetSpellName, spellID)
        if ok and type(name) == "string" and name ~= "" then return name end
    end
    if api.GetSpellInfo then
        local ok, name = pcall(api.GetSpellInfo, spellID)
        if ok and type(name) == "table" then name = name.name end
        if ok and type(name) == "string" and name ~= "" then return name end
    end
end

--- Lokalisierter Zusatztext ("Lehrling" bei Angeln Rang 1), nil wenn nicht verfügbar
function P.SpellSubtext(spellID)
    if api.GetSpellSubtext then
        local ok, text = pcall(api.GetSpellSubtext, spellID)
        if ok and type(text) == "string" and text ~= "" then return text end
    end
    if api.GetSpellInfo then
        -- Classic: 2. Rückgabe ist der Rang-Text
        local ok, _, text = pcall(api.GetSpellInfo, spellID)
        if ok and type(text) == "string" and text ~= "" then return text end
    end
end

-- Maximum -> Locale-Key, nur Fallback für TierName
local TIERS = {
    [75] = "Apprentice", [150] = "Journeyman", [225] = "Expert", [300] = "Artisan", [375] = "Master",
    [450] = "Grand Master",
}

--- Maximum -> Stufenname (75 -> "Lehrling"). Aus dem Zusatztext von def.spells[max / 75], sonst TIERS.
function P:TierName(maximum, def)
    maximum = tonumber(maximum) or 0
    local index = maximum / 75
    if def and def.spells and index >= 1 and index == math.floor(index) and def.spells[index] then
        local text = P.SpellSubtext(def.spells[index])
        if text then return text end
    end
    local key = TIERS[maximum]
    return key and L[key] or nil
end

-- GetProfessionInfo: name, icon, rank, max, numSpells, offset, skillLine, modifier (Ausrüstung + Köder)
local function FromProfessions(def)
    if not (api.GetProfessions and api.GetProfessionInfo and def.skillLine) then return nil end

    local ok, found = pcall(function()
        -- Beruf 1, Beruf 2, Archäologie, Angeln, Kochen, einzelne können nil sein
        local indexes = { api.GetProfessions() }
        for position = 1, 6 do
            local index = indexes[position]
            if index then
                local name, _, rank, maximum, _, _, line, modifier = api.GetProfessionInfo(index)
                if line == def.skillLine then
                    return { name = name, rank = tonumber(rank) or 0, max = tonumber(maximum) or 0,
                        modifier = tonumber(modifier) or 0, via = "GetProfessionInfo" }
                end
            end
        end
    end)
    return ok and found or nil
end

-- Fallback ohne IDs, Suche über Zaubername und def.skillNames.
-- GetSkillLineInfo: name, header, expanded, rank, temp, modifier, max
local function FromSkillLines(def)
    if not (api.GetNumSkillLines and api.GetSkillLineInfo) then return nil end

    local names = {}
    for _, name in ipairs(def.skillNames or {}) do names[name] = true end
    local spell = def.reference and P.SpellName(def.reference)
    if spell then names[spell] = true end

    local ok, found = pcall(function()
        for index = 1, api.GetNumSkillLines() do
            local name, header, _, rank, _, modifier, maximum = api.GetSkillLineInfo(index)
            if name and not header and names[name] then
                return { name = name, rank = tonumber(rank) or 0, max = tonumber(maximum) or 0,
                    modifier = tonumber(modifier) or 0, via = "GetSkillLineInfo" }
            end
        end
    end)
    return ok and found or nil
end

--- { name, rank (ohne Bonus), max, modifier (Ausrüstung + Köder), via } oder nil
function P:GetSkill(def)
    return FromProfessions(def) or FromSkillLines(def)
end

--- Kanalzauber des Berufs aktiv (Angeln: Schwimmer draußen)? Vergleich per Name, gilt für alle Ränge.
function P:IsChannelingProfession(def)
    if not (api.UnitChannelInfo and def and def.reference) then return false end
    local ok, name = pcall(api.UnitChannelInfo, "player")
    name = ok and self.Clean(name) or nil
    if type(name) ~= "string" then return false end
    return name ~= "" and name == self.SpellName(def.reference)
end

--- def zum Zauber, über ID oder Namen (Ränge heißen gleich), sonst nil
local nameMatch = {}
function P:ProfessionForSpell(spellID)
    spellID = tonumber(self.Clean(spellID))
    if not spellID then return nil end

    for _, key in ipairs(self.order) do
        local def = self.professions[key]
        if def.spellSet[spellID] then return def end
    end

    for _, key in ipairs(self.order) do
        local def = self.professions[key]
        local cache = nameMatch[key]
        if not cache then
            cache = {}
            nameMatch[key] = cache
        end
        local known = cache[spellID]
        if known == nil and def.reference then
            local name, reference = P.SpellName(spellID), P.SpellName(def.reference)
            if name and reference then
                known = name == reference
                cache[spellID] = known
            end
        end
        if known then return def end
    end
end
