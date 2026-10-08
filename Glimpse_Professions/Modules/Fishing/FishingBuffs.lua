local Glimpse = LibStub("AceAddon-3.0"):GetAddon("Glimpse")
local P = Glimpse:GetModule("Professions")

-- Angelboni außerhalb der Ausrüstung: Buffs (z. B. Glänzende Silbermünze) und Köder.
-- Ein Buff zählt, wenn eine Tooltip-Zeile den Fertigkeitsnamen und eine Zahl enthält (wie in FishingLure.lua).

local MAX_BUFFS = 40
local MAIN_HAND = 16

local function TextLines(data)
    local lines = {}
    if type(data) == "table" and type(data.lines) == "table" then
        for _, line in ipairs(data.lines) do
            if type(line) == "table" and type(line.leftText) == "string" then lines[#lines + 1] = line.leftText end
        end
    end
    return lines
end

P.buffApi = {
    -- { name, spellID, lines }
    Buffs = function()
        local list = {}
        for index = 1, MAX_BUFFS do
            local name, spellID, lines, _
            local get = C_UnitAuras and (C_UnitAuras.GetBuffDataAtIndex or C_UnitAuras.GetAuraDataByIndex)
            if get then
                local data = get("player", index, "HELPFUL")
                if not data then break end
                name, spellID = data.name, data.spellId
                if C_TooltipInfo and C_TooltipInfo.GetUnitBuffByAuraInstanceID and data.auraInstanceID then
                    local ok, tip = pcall(C_TooltipInfo.GetUnitBuffByAuraInstanceID, "player", data.auraInstanceID)
                    lines = ok and TextLines(tip) or {}
                end
            elseif UnitAura or UnitBuff then
                if UnitAura then
                    name, _, _, _, _, _, _, _, _, spellID = UnitAura("player", index, "HELPFUL")
                else
                    name, _, _, _, _, _, _, _, _, spellID = UnitBuff("player", index)
                end
                if not name then break end
                if C_TooltipInfo and C_TooltipInfo.GetUnitBuff then
                    local ok, tip = pcall(C_TooltipInfo.GetUnitBuff, "player", index)
                    lines = ok and TextLines(tip) or {}
                end
            else
                break
            end
            list[#list + 1] = { name = name, spellID = spellID, lines = lines or {} }
        end
        return list
    end,
    MainHandLines = function()
        if not (C_TooltipInfo and C_TooltipInfo.GetInventoryItem) then return {} end
        local ok, tip = pcall(C_TooltipInfo.GetInventoryItem, "player", MAIN_HAND)
        return ok and TextLines(tip) or {}
    end,
    -- Qualitätsfarbe per Itemname ("|cffa335ee") oder nil
    QualityColor = function(name)
        if not (GetItemInfo and name) then return nil end
        local _, _, quality = GetItemInfo(name)
        local color = quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
        return color and color.hex or nil
    end,
}
local api = P.buffApi

-- Escapes entfernen (|c, |r, |T, |A, |H, |4), sonst landen Zahlen daraus als Bonus im Ergebnis
local function Plain(text)
    return (text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", ""):gsub("|A.-|a", ""):gsub("|H.-|h", "")
        :gsub("|h", ""):gsub("|4[^;]*;", ""))
end
P.PlainText = Plain

-- Erste Teilzeile mit stem und Zahl -> Zahl, Teilzeile. "+30" hat Vorrang vor anderen Zahlen ("Maximum von 100").
-- skip(text) überspringt Teilzeilen (z. B. "Benötigt Angeln (20)").
function P.SkillBonus(lines, stem, skip)
    local search = stem
    if not search then return nil end
    for _, line in ipairs(lines or {}) do
        for part in (type(line) == "string" and Plain(line) or ""):gmatch("[^\r\n]+") do
            if part:find(search, 1, true) and not (skip and skip(part)) then
                local number = tonumber(part:match("%+%s*(%d+)") or part:match("(%d+)"))
                if number and number > 0 then return number, part end
            end
        end
    end
end
local Bonus = P.SkillBonus

local function SkillStem(self)
    local skill = self:GetSkill(self:GetProfession("fishing"))
    local name = skill and skill.name
    if type(name) ~= "string" or name == "" then return nil end
    local first = name:sub(1, 4)
    return first:match("^%a%a%a%a$") and first or name
end

--- { name, value, color (Itemqualität oder nil) } je Buff mit Angelbonus
function P:FishingBuffs()
    local stem, list = SkillStem(self), {}
    if not stem then return list end
    for _, buff in ipairs(api.Buffs()) do
        local value = Bonus(buff.lines, stem)
        if value then list[#list + 1] = { name = buff.name, value = value, color = api.QualityColor(buff.name) } end
    end
    return list
end

--- { name, value } aus dem Waffenhand-Tooltip, sonst der beim Anwenden gemerkte Name. nil ohne Köder.
function P:FishingLureEntry(total)
    local value, text = Bonus(api.MainHandLines(), SkillStem(self))
    local name = self.lureName
    if text and not name then name = text:gsub("%s*%(.-%)%s*", " "):gsub("%s*[%+%-]?%d+.*$", ""):gsub("^%s+", ""):gsub("%s+$", "") end
    return { name = name ~= "" and name or nil, value = value or total, fromTooltip = value ~= nil }
end

--- /gli prof buffs, nur Fehlersuche, daher unübersetzt
function P:BuffLines()
    local stem = SkillStem(self)
    local out = {
        format("APIs: GetBuffDataAtIndex=%s, GetAuraDataByIndex=%s, GetUnitBuffByAuraInstanceID=%s, GetUnitBuff=%s, UnitBuff=%s, UnitAura=%s, search=%s",
            tostring(C_UnitAuras and C_UnitAuras.GetBuffDataAtIndex ~= nil), tostring(C_UnitAuras and C_UnitAuras.GetAuraDataByIndex ~= nil),
            tostring(C_TooltipInfo and C_TooltipInfo.GetUnitBuffByAuraInstanceID ~= nil), tostring(C_TooltipInfo and C_TooltipInfo.GetUnitBuff ~= nil),
            tostring(UnitBuff ~= nil), tostring(UnitAura ~= nil), tostring(stem)),
    }
    local buffs = api.Buffs()
    out[#out + 1] = format("%d buffs", #buffs)
    for _, buff in ipairs(buffs) do
        local value = Bonus(buff.lines, stem)
        out[#out + 1] = format("%s (id %s): %d tooltip lines -> bonus %s", tostring(buff.name), tostring(buff.spellID), #buff.lines, tostring(value))
        for _, line in ipairs(buff.lines) do out[#out + 1] = "    " .. line end
    end
    return out
end
