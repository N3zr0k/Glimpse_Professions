local Glimpse = LibStub("AceAddon-3.0"):GetAddon("Glimpse")
local P = Glimpse:GetModule("Professions")

-- Angeln zählen, in den Namespace "fishing" von Glimpse: Database (Bereich Professions). Ohne Database wird nichts
-- gezählt. Zonen = uiMapID, in Instanzen -instanceID (Glimpse.IDs:ZoneKey).
--   cast            0           gezählte Würfe (Fang oder stehend ausgelaufen), je Zone
--   catch           0           Würfe mit Beute, je Zone
--   casttier        Stufe       Würfe je Berufsstufe (ID = höchste Fertigkeit der Stufe, z. B. 75)
--   catchtier       Stufe       Fänge je Berufsstufe
--   castabort       0           Würfe, die Bewegung, Fall oder Kampf abgebrochen hat, je Zone (nicht in cast, wird nicht verrechnet)
--   aborttier       Stufe       Abbrüche je Berufsstufe
--   fish            Item        Menge der Angelbeute, je Zone
--   looted          Zone        Beutefenster in der Zone (Weltwissen, Nenner der Fangchance)
--   loot:<Zone>     Item        Menge (Weltwissen)
--   drop:<Zone>     Item        Beutefenster mit dem Item (Weltwissen)
-- Ein Fang zählt nur nach einem offenen Wurf, damit ein zweites Beutefenster nicht doppelt zählt.

P.FISHING_NAMESPACE = "fishing"

P.recordApi = {
    IsFishingLoot = IsFishingLoot,
    GetNumLootItems = (C_Loot and C_Loot.GetNumLootItems) or GetNumLootItems,
    GetLootSlotType = (C_Loot and C_Loot.GetLootSlotType) or GetLootSlotType,
    GetLootSlotLink = (C_Loot and C_Loot.GetLootSlotLink) or GetLootSlotLink,
    GetLootSlotInfo = GetLootSlotInfo,
    GetUnitSpeed = GetUnitSpeed,
    IsFalling = IsFalling,
    InCombat = UnitAffectingCombat,
    After = C_Timer and C_Timer.After,
}

local api = P.recordApi
local LOOT_ITEM = Enum and Enum.LootSlotType and Enum.LootSlotType.Item or 1

-- Ringpuffer für /gli prof record
local LOG_MAX = 40
P.recordLog = {}
local function Log(text)
    local log = P.recordLog
    log[#log + 1] = format("%.1f %s", GetTime and GetTime() or 0, text)
    if #log > LOG_MAX then table.remove(log, 1) end
end

local ABORT_WAIT = 0.5 -- Sekunden: Das Beutefenster kann kurz nach dem Ende des Kanals kommen

local function Zone()
    if not (Glimpse.IDs and Glimpse.IDs.ZoneKey) then return nil end
    local ok, zone = pcall(Glimpse.IDs.ZoneKey, Glimpse.IDs)
    return ok and zone or nil
end

local function Tier(self)
    local skill = self:GetSkill(self:GetProfession("fishing"))
    return skill and skill.max
end

-- { [itemID] = Menge } des offenen Beutefensters
local function ReadLoot()
    local items = {}
    for slot = 1, api.GetNumLootItems() do
        if api.GetLootSlotType(slot) == LOOT_ITEM then
            local link = P.Clean(api.GetLootSlotLink(slot))
            local itemID = type(link) == "string" and tonumber(link:match("item:(%d+)"))
            if itemID then
                local quantity = api.GetLootSlotInfo and select(3, api.GetLootSlotInfo(slot))
                items[itemID] = (items[itemID] or 0) + (tonumber(P.Clean(quantity)) or 1)
            end
        end
    end
    return items
end

-- Gezählt wird ein Wurf erst, wenn er ausgeht (Zone und Stufe vom Wurf):
--   Beutefenster                      -> cast + catch
--   Kanal läuft stehend aus           -> cast (Wurf ohne Fang)
--   Bewegung, Fall oder Kampf         -> nur castabort/aborttier, der Wurf zählt nicht
local pending -- { zone, tier, outcome }

local function CountCast(self, zone, tier)
    self.fishingNs:Count("cast", 0, zone)
    if tier then self.fishingNs:Count("casttier", tier) end
end

-- schließt den offenen Wurf ohne Beutefenster ab
local function Resolve(self)
    local open = pending
    if not (open and open.outcome) then return end
    pending = nil
    Log("counted as " .. open.outcome)
    if open.outcome == "abort" then
        self.fishingNs:Count("castabort", 0, open.zone)
        if open.tier then self.fishingNs:Count("aborttier", open.tier) end
    else
        CountCast(self, open.zone, open.tier)
    end
end

function P:FishingOnSpell(_, unit, _, spellID)
    if unit ~= "player" or not self.fishingNs then return end
    local def = self:ProfessionForSpell(spellID)
    if not def or def.key ~= "fishing" then return end

    -- ein Wurf ohne Ereignis zum Ende zählt als ausgelaufen
    if pending then pending.outcome = pending.outcome or "miss" Resolve(self) end
    pending = { zone = Zone(), tier = Tier(self) }
    Log(format("cast started (spell %s), zone %s, tier %s", tostring(spellID), tostring(pending.zone), tostring(pending.tier)))
end

-- true, wenn sich der Spieler bewegt, fällt oder im Kampf ist
local function Disturbed()
    local ok, speed = pcall(api.GetUnitSpeed, "player")
    if ok and (tonumber(P.Clean(speed)) or 0) > 0 then return true end
    if api.IsFalling then
        local fine, falling = pcall(api.IsFalling)
        if fine and P.Clean(falling) == true then return true end
    end
    if api.InCombat then
        local fine, combat = pcall(api.InCombat, "player")
        if fine and P.Clean(combat) == true then return true end
    end
    return false
end

--- Ende des Kanals: das Beutefenster kann kurz danach kommen, darum wird erst nach ABORT_WAIT abgeschlossen
function P:FishingOnStop(_, unit, _, spellID)
    if unit ~= "player" or not (self.fishingNs and pending and not pending.outcome) then return end
    local def = self:ProfessionForSpell(spellID)
    if not def or def.key ~= "fishing" then return end

    local open = pending
    open.outcome = Disturbed() and "abort" or "miss"
    Log(format("channel stop (spell %s): %s, speed %s, falling %s, combat %s", tostring(spellID), open.outcome,
        tostring(api.GetUnitSpeed and api.GetUnitSpeed("player")), tostring(api.IsFalling and api.IsFalling()),
        tostring(api.InCombat and api.InCombat("player"))))
    if api.After then
        api.After(ABORT_WAIT, function() if pending == open then Resolve(self) end end)
    else
        Resolve(self)
    end
end

function P:FishingOnLoot()
    if not (self.fishingNs and pending) then return end
    local ok, fishing = pcall(api.IsFishingLoot)
    if not ok or P.Clean(fishing) ~= true then return end
    local open = pending
    pending = nil
    Log("loot window: catch")

    local ns, zone, tier = self.fishingNs, open.zone, open.tier
    CountCast(self, zone, tier)
    ns:Count("catch", 0, zone)
    if tier then ns:Count("catchtier", tier) end
    if zone then ns:Count("looted", zone) end
    for itemID, amount in pairs(ReadLoot()) do
        ns:Count("fish", itemID, zone, amount)
        if zone then
            ns:Count("loot:" .. zone, itemID, nil, amount)
            ns:Count("drop:" .. zone, itemID)
        end
    end
end

--- Rohdaten aller Kanal-Ereignisse des Spielers für /gli prof record
function P:FishingOnChannel(event, unit, _, spellID)
    if unit ~= "player" then return end
    Log(format("%s (spell %s)%s", event, tostring(spellID), self:ProfessionForSpell(spellID) and " fishing" or ""))
end

function P:FishingRecordLines()
    local lines = { format("fishing record: namespace %s, open cast %s", self.FISHING_NAMESPACE, tostring(pending ~= nil)) }
    if #self.recordLog == 0 then lines[#lines + 1] = "log empty (no fishing event seen yet)" end
    for _, line in ipairs(self.recordLog) do lines[#lines + 1] = line end
    return lines
end

function P:FishingRecordEnable()
    local DB = GlimpseDB
    if not DB then return end
    local ns = DB:Register(self.FISHING_NAMESPACE, { area = "Professions", zones = true,
        world = { looted = true, loot = true, drop = true } })
    if not ns then return end

    self.fishingNs = ns
    self:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED", function(...) self.Protected("fishing record", self.FishingOnSpell, self, ...) end)
    self:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP", function(...) self.Protected("fishing record", self.FishingOnStop, self, ...) end)
    for _, event in ipairs({ "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_FAILED" }) do
        pcall(self.RegisterEvent, self, event, function(...) self.Protected("fishing record", self.FishingOnChannel, self, ...) end)
    end
    self:RegisterEvent("LOOT_OPENED", function(...) self.Protected("fishing record", self.FishingOnLoot, self, ...) end)
end
