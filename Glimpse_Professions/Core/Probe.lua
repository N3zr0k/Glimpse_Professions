local Glimpse = LibStub("AceAddon-3.0"):GetAddon("Glimpse")
local P = Glimpse:GetModule("Professions")

-- /gli prof probe: Rohdaten des Clients, um zu prüfen, ob die API liefert, was das Addon erwartet

local api = P.api

-- "a | b | c"
local function Join(...)
    local parts = {}
    for index = 1, select("#", ...) do parts[#parts + 1] = tostring((select(index, ...))) end
    return table.concat(parts, " | ")
end

local NAMES = { "GetProfessions", "GetProfessionInfo", "GetNumSkillLines", "GetSkillLineInfo", "GetWeaponEnchantInfo",
    "GetInventoryItemID", "GetItemInfoInstant", "GetStatistic", "GetStatisticsCategoryList", "GetCategoryNumAchievements",
    "GetAchievementInfo" }

--- key = Beruf, Standard der erste
function P:ProbeLines(key)
    local def = self.professions[key or self.order[1]]
    local lines = {}
    if not def then return { "Unknown profession." } end

    local have = {}
    for _, name in ipairs(NAMES) do have[#have + 1] = name .. "=" .. (type(api[name]) == "function" and "yes" or "NO") end
    lines[#lines + 1] = "API: " .. table.concat(have, " ")
    lines[#lines + 1] = format("profession: %s (key %s, skill line %s)", tostring(def.label), def.key, tostring(def.skillLine))

    if api.GetProfessions and api.GetProfessionInfo then
        local ok, err = pcall(function()
            local indexes = { api.GetProfessions() }
            for position = 1, 6 do
                local index = indexes[position]
                if index then
                    lines[#lines + 1] = format("GetProfessions #%d -> index %s: %s", position, tostring(index), Join(api.GetProfessionInfo(index)))
                end
            end
        end)
        if not ok then lines[#lines + 1] = "GetProfessions failed: " .. tostring(err) end
    end

    -- Fallback-Weg über den Namen
    if api.GetNumSkillLines and api.GetSkillLineInfo then
        local ok, err = pcall(function()
            local wanted = {}
            for _, name in ipairs(def.skillNames or {}) do wanted[name] = true end
            local spell = def.reference and P.SpellName(def.reference)
            if spell then wanted[spell] = true end
            for index = 1, api.GetNumSkillLines() do
                local name = api.GetSkillLineInfo(index)
                if name and wanted[name] then lines[#lines + 1] = format("GetSkillLineInfo #%d: %s", index, Join(api.GetSkillLineInfo(index))) end
            end
        end)
        if not ok then lines[#lines + 1] = "GetSkillLineInfo failed: " .. tostring(err) end
    end

    local skill = self:GetSkill(def)
    if skill then
        lines[#lines + 1] = format("GetSkill: %s, rank %d, max %d, bonus %d (via %s), tier %s", tostring(skill.name), skill.rank,
            skill.max, skill.modifier, skill.via, tostring(self:TierName(skill.max, def)))
    else
        lines[#lines + 1] = "GetSkill: nothing (profession not learned or not readable)"
    end

    -- daraus liest TierName die Berufsstufe
    for index, spellID in ipairs(def.spells or {}) do
        lines[#lines + 1] = format("spell %d (max %d): subtext %s", spellID, index * 75, tostring((P.SpellSubtext(spellID))))
    end

    if def.probe then
        local ok, extra = pcall(def.probe, self, def)
        if ok then
            for _, line in ipairs(extra or {}) do lines[#lines + 1] = line end
        else
            lines[#lines + 1] = "probe of the profession failed: " .. tostring(extra)
        end
    end
    return lines
end

--- /gli prof ohne Argument
function P:OverviewLines()
    local lines = {}
    for _, key in ipairs(self.order) do
        local def = self.professions[key]
        local skill = self:GetSkill(def)
        local state = skill and format("%d/%d", skill.rank, skill.max) or "-"
        lines[#lines + 1] = format("%s: %s, tooltip %s", def.label, state,
            (self:TooltipsOn() and self:Opt(key, "tooltip") ~= false) and "on" or "off")
    end
    if self.lastError then lines[#lines + 1] = format("Last error: %s (%d in total)", self.lastError, self.errorCount or 0) end
    return lines
end
