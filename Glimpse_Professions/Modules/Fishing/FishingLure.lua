local Glimpse = LibStub("AceAddon-3.0"):GetAddon("Glimpse")
local P = Glimpse:GetModule("Professions")
local L = P.L

-- Auto-Köder: Hat die Angel beim Auswerfen (FishingCast.lua) keinen Köder, wendet der Klick den besten aus dem Rucksack an
-- (Makro: Item benutzen, dann Waffenhand), der nächste Klick wirft aus.
-- Bonus aus KNOWN, sonst aus dem Item-Tooltip (Zeile mit dem Fertigkeitsnamen), je Item gecacht.

local KEY = "fishing"
local MAIN_HAND = 16
local WEAPON, ARMOR, CONTAINER = 2, 4, 1 -- Itemklassen, die nie Köder sind

-- Tooltip nennt Angelfertigkeit nur als Voraussetzung
local NOT_LURES = { [279967] = true } -- Fischglas

-- itemID -> Bonus, Rest erkennt der Tooltip
local KNOWN = { [6529] = 25, [6530] = 50, [6532] = 75, [6533] = 100, [6811] = 50, [7307] = 75, [34861] = 100 }

local bag = C_Container or {}
P.lureApi = {
    GetContainerItemLink = bag.GetContainerItemLink or GetContainerItemLink,
    -- Liste der Tooltip-Texte eines Rucksack-Items oder nil
    TooltipLines = function(container, slot)
        if not (C_TooltipInfo and C_TooltipInfo.GetBagItem) then return nil end
        local ok, data = pcall(C_TooltipInfo.GetBagItem, container, slot)
        if not ok or type(data) ~= "table" or type(data.lines) ~= "table" then return nil end
        local lines = {}
        for _, line in ipairs(data.lines) do
            local text = type(line) == "table" and line.leftText
            if type(text) == "string" then lines[#lines + 1] = text end
        end
        return lines
    end,
    Good = function(text)
        if UIErrorsFrame then UIErrorsFrame:AddMessage(text, 0.1, 1, 0.1, 1) end
    end,
}
local api = P.lureApi

local cache = {} -- itemID -> Bonus oder false (kein Köder)

-- "Angeln" soll "Angelfertigkeit" finden: die ersten vier Buchstaben, sonst der ganze Name
local function Stem(name)
    if type(name) ~= "string" or name == "" then return nil end
    local first = name:sub(1, 4)
    return first:match("^%a%a%a%a$") and first or name
end

-- "Benötigt Angeln (20)" (ITEM_MIN_SKILL) ist kein Bonus
local function IsRequirement(text)
    local pattern = _G.ITEM_MIN_SKILL
    if type(pattern) ~= "string" then return false end
    pattern = "^" .. pattern:gsub("[%^%$%(%)%.%[%]%*%+%-%?]", "%%%0"):gsub("%%s", ".+"):gsub("%%d", "%%d+") .. "$"
    return text:find(pattern) ~= nil
end

local function BonusFromLines(lines, stem)
    if not (lines and stem) then return nil end
    return (P.SkillBonus(lines, stem, IsRequirement))
end

--- Angelbonus des Items, nil wenn kein Köder
function P:LureBonus(itemID, container, slot)
    if NOT_LURES[itemID] then return nil end
    if KNOWN[itemID] then return KNOWN[itemID] end
    if cache[itemID] ~= nil then return cache[itemID] or nil end

    local classID = self.api.GetItemInfoInstant and select(6, self.api.GetItemInfoInstant(itemID))
    local bonus
    if classID ~= WEAPON and classID ~= ARMOR and classID ~= CONTAINER then
        local skill = self:GetSkill(self:GetProfession(KEY))
        bonus = BonusFromLines(api.TooltipLines(container, slot), Stem(skill and skill.name))
    end
    -- Tooltip noch nicht geladen: nicht cachen
    if bonus or classID then cache[itemID] = bonus or false end
    return bonus
end

--- bag, slot, itemID, link, bonus oder nil
function P:FindBestLure()
    local castApi = self.castApi
    if not (castApi.GetContainerNumSlots and castApi.GetContainerItemID) then return nil end
    local best
    for container = 0, castApi.NumBags do
        for slot = 1, tonumber(castApi.GetContainerNumSlots(container)) or 0 do
            local id = castApi.GetContainerItemID(container, slot)
            local bonus = id and self:LureBonus(id, container, slot)
            if bonus and (not best or bonus > best.bonus) then
                best = { container = container, slot = slot, id = id, bonus = bonus }
            end
        end
    end
    if best then best.link = api.GetContainerItemLink and api.GetContainerItemLink(best.container, best.slot) or ("item:" .. best.id) end
    return best
end

--- Makrotext für den Secure-Button in FishingCast.lua (Items benutzen ist geschützt), nil wenn nicht nötig.
-- Meldung kommt schon hier, der Button klickt direkt danach.
function P:LureMacro()
    if self:Opt(KEY, "lure") ~= true or not self:CastEnabled() then return nil end
    if self.castApi.InCombatLockdown() or not self:IsPoleEquipped() or self:GetMainHandEnchant() then return nil end

    local best = self:FindBestLure()
    if not best then return nil end

    local pole = self.castApi.GetInventoryItemLink("player", MAIN_HAND) or ""
    self.lureName = GetItemInfo and GetItemInfo(best.link) or nil
    api.Good(format(L["Apply %s to %s."], best.link, pole))
    api.Good(format(L["Your fishing skill increases by %d."], best.bonus))
    return format("/use %d %d\n/use %d", best.container, best.slot, MAIN_HAND)
end

--- /gli prof lure (Fehlersuche)
function P:LureLines()
    local has, enchantID, left = self:GetMainHandEnchant()
    local out = {
        format("pole equipped=%s, main hand enchant=%s (id %s, %s ms left), switch=%s, cast function=%s", tostring(self:IsPoleEquipped()),
            tostring(has), tostring(enchantID), tostring(left), tostring(self:Opt(KEY, "lure")), tostring(self:CastEnabled())),
        "main hand tooltip:",
    }
    for _, line in ipairs(self.buffApi.MainHandLines()) do out[#out + 1] = "    " .. line end
    local entry = self:FishingLureEntry(0)
    out[#out + 1] = format("lure entry: name=%s, value=%s, remembered=%s", tostring(entry.name), tostring(entry.value), tostring(self.lureName))
    out[#out + 1] = "bag lures:"
    local castApi = self.castApi
    for container = 0, castApi.NumBags or 0 do
        for slot = 1, tonumber(castApi.GetContainerNumSlots(container)) or 0 do
            local id = castApi.GetContainerItemID(container, slot)
            local bonus = id and self:LureBonus(id, container, slot)
            if bonus then out[#out + 1] = format("    %d:%d item %d bonus %d", container, slot, id, bonus) end
        end
    end
    return out
end
