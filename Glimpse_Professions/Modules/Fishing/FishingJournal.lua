local Glimpse = LibStub("AceAddon-3.0"):GetAddon("Glimpse")
local P = Glimpse:GetModule("Professions")
local L = P.L

-- Verwittertes Tagebuch (Item 34109) lehrt "Fischsuche" (Zauber 43308).
--   Tooltip: Zeile, ob das Tagebuch gelernt ist; Name des Items aus dem Client, sonst aus den Locales.
--   Login/Reload und nach dem Lernen: Fischsuche in der Minimap-Verfolgung einschalten (Option findFish).
-- Im Kampf wird erst nach Kampfende eingeschaltet (FishingCast.lua, CastOnRegen).

local KEY = "fishing"
local JOURNAL_ITEM = 34109
local FIND_FISH = 43308

-- Blizzard-API gebündelt, damit Tests sie ersetzen können
local minimap = C_Minimap or {}
P.journalApi = {
    IsPlayerSpell = IsPlayerSpell or IsSpellKnown,
    GetNumTrackingTypes = minimap.GetNumTrackingTypes or GetNumTrackingTypes,
    GetTrackingInfo = minimap.GetTrackingInfo or GetTrackingInfo,
    SetTracking = minimap.SetTracking or SetTracking,
    InCombatLockdown = InCombatLockdown,
}
local api = P.journalApi

--- true/false, nil ohne API
function P:JournalLearned()
    if not api.IsPlayerSpell then return nil end
    local ok, known = pcall(api.IsPlayerSpell, FIND_FISH)
    if not ok then return nil end
    return P.Clean(known) == true
end

--- Name aus dem Client, solange der Item-Cache leer ist der aus den Locales
function P:JournalName()
    if self.journalName then return self.journalName end
    if not self.journalRequested and Glimpse.IDs and Glimpse.IDs.DescribeItem then
        self.journalRequested = true
        Glimpse.IDs:DescribeItem(JOURNAL_ITEM, function(_, name) if name then P.journalName = name end end)
        if self.journalName then return self.journalName end
    end
    return L["Weather-Beaten Journal"]
end

function P:JournalLine()
    local learned = self:JournalLearned()
    if learned == nil then return nil end
    local state = learned and ("|cff20ff20" .. L["learned"]) or ("|cffff2020" .. L["not learned"])
    return format("%s: %s|r", self:JournalName(), state)
end

-- Neuere Clients liefern eine Tabelle, ältere einzelne Werte (name, texture, active, category, nested, spellID)
local function TrackingInfo(index)
    local ok, a, _, c, _, _, f = pcall(api.GetTrackingInfo, index)
    if not ok then return nil end
    if type(a) == "table" then return a.name, a.active, a.spellID end
    return a, c, f
end

--- Index und aktiv-Stand der Fischsuche in der Minimap-Verfolgung, nil ohne Eintrag oder API
function P:FindFishTracking()
    if not (api.GetNumTrackingTypes and api.GetTrackingInfo) then return nil end
    local spellName = P.SpellName(FIND_FISH)
    local ok, count = pcall(api.GetNumTrackingTypes)
    for index = 1, ok and tonumber(count) or 0 do
        local name, active, spellID = TrackingInfo(index)
        if spellID == FIND_FISH or (spellName and name == spellName) then return index, active == true end
    end
end

--- Schaltet die Fischsuche ein, wenn Tagebuch gelernt, Option an und noch aus. Gibt den Grund fürs Log zurück.
function P:EnableFindFish()
    self.findFishPending = nil
    if self:Opt(KEY, "findFish") == false then return "option off" end
    if not self:JournalLearned() then return "journal not learned" end
    local index, active = self:FindFishTracking()
    if not index then return "no tracking entry" end
    if active then return "already on" end
    if api.InCombatLockdown and api.InCombatLockdown() then
        self.findFishPending = true
        return "in combat, after combat"
    end
    if not api.SetTracking then return "no SetTracking" end
    local ok = pcall(api.SetTracking, index, true)
    if not ok then return "SetTracking failed" end
    Glimpse:Print(L["Find Fish switched on."])
    return "switched on"
end

function P:FishingJournalEnable()
    -- nach dem Lesen des Tagebuchs; ältere Clients kennen das Ereignis eventuell nicht
    pcall(self.RegisterEvent, self, "LEARNED_SPELL_IN_TAB", function(_, spellID)
        if spellID == nil or spellID == FIND_FISH then self:EnableFindFish() end
    end)
end

function P:JournalProbeLines()
    local index, active = self:FindFishTracking()
    return {
        format("journal %d learned: %s (spell %d), name: %s", JOURNAL_ITEM, tostring(self:JournalLearned()), FIND_FISH,
            self:JournalName()),
        format("find fish tracking: index %s, active %s, SetTracking %s, option %s", tostring(index), tostring(active),
            tostring(api.SetTracking ~= nil), tostring(self:Opt(KEY, "findFish") ~= false)),
    }
end
