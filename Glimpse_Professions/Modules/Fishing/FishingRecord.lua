local Glimpse = LibStub("AceAddon-3.0"):GetAddon("Glimpse")
local P = Glimpse:GetModule("Professions")

-- Angeln zählen, in den Namespace "fishing" von Glimpse: Database (Bereich Professions). Ohne Database wird nichts
-- gezählt. Zonen = uiMapID, in Instanzen -instanceID (Glimpse.IDs:ZoneKey).
--   cast            0           Würfe, je Zone
--   catch           0           Würfe mit Beute, je Zone
--   casttier        Stufe       Würfe je Berufsstufe (ID = höchste Fertigkeit der Stufe, z. B. 75)
--   catchtier       Stufe       Fänge je Berufsstufe
--   fish            Item        Menge der Angelbeute, je Zone
--   looted          Zone        Beutefenster in der Zone (Weltwissen, Nenner der Fangchance)
--   loot:<Zone>     Item        Menge (Weltwissen)
--   drop:<Zone>     Item        Beutefenster mit dem Item (Weltwissen)
-- Ein Fang zählt nur nach einem gezählten Wurf, damit ein zweites Beutefenster nicht doppelt zählt.

P.FISHING_NAMESPACE = "fishing"

P.recordApi = {
    IsFishingLoot = IsFishingLoot,
    GetNumLootItems = (C_Loot and C_Loot.GetNumLootItems) or GetNumLootItems,
    GetLootSlotType = (C_Loot and C_Loot.GetLootSlotType) or GetLootSlotType,
    GetLootSlotLink = (C_Loot and C_Loot.GetLootSlotLink) or GetLootSlotLink,
    GetLootSlotInfo = GetLootSlotInfo,
}

local api = P.recordApi
local LOOT_ITEM = Enum and Enum.LootSlotType and Enum.LootSlotType.Item or 1

local castOpen = false

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

function P:FishingOnSpell(_, unit, _, spellID)
    if unit ~= "player" or not self.fishingNs then return end
    local def = self:ProfessionForSpell(spellID)
    if not def or def.key ~= "fishing" then return end

    local ns, tier = self.fishingNs, Tier(self)
    ns:Count("cast", 0, Zone())
    if tier then ns:Count("casttier", tier) end
    castOpen = true
end

function P:FishingOnLoot()
    if not (self.fishingNs and castOpen) then return end
    local ok, fishing = pcall(api.IsFishingLoot)
    if not ok or P.Clean(fishing) ~= true then return end
    castOpen = false

    local ns, zone, tier = self.fishingNs, Zone(), Tier(self)
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

function P:FishingRecordEnable()
    local DB = GlimpseDB
    if not DB then return end
    local ns = DB:Register(self.FISHING_NAMESPACE, { area = "Professions", zones = true,
        world = { looted = true, loot = true, drop = true } })
    if not ns then return end

    self.fishingNs = ns
    self:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED", function(...) self.Protected("fishing record", self.FishingOnSpell, self, ...) end)
    self:RegisterEvent("LOOT_OPENED", function(...) self.Protected("fishing record", self.FishingOnLoot, self, ...) end)
end
