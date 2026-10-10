local Glimpse = LibStub("AceAddon-3.0"):GetAddon("Glimpse")
local P = Glimpse:GetModule("Professions")

-- Angel und Köder: Angel in der Waffenhand erkennen, Köder als temporäre Verzauberung der Waffenhand.
-- Die API-Einträge kommen in P.api, damit /gli prof probe und die Tests sie wie die übrigen ersetzen können.

local api = P.api
api.GetWeaponEnchantInfo = GetWeaponEnchantInfo
api.GetInventoryItemID = GetInventoryItemID
api.GetItemInfoInstant = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant

-- Fallback-Werte, falls die Enums fehlen
local ItemClass = Enum and Enum.ItemClass or {}
local WEAPON = ItemClass.Weapon or 2
local WeaponSubclass = Enum and Enum.ItemWeaponSubclass or {}
local FISHING_POLE = WeaponSubclass.Fishingpole or 20
local MAIN_HAND = 16 -- Inventarslot Waffenhand

function P:IsPoleItem(itemID)
    if not (itemID and api.GetItemInfoInstant) then return false end
    local _, _, _, _, _, classID, subClassID = api.GetItemInfoInstant(itemID)
    return classID == WEAPON and subClassID == FISHING_POLE
end

function P:IsPoleEquipped()
    if not api.GetInventoryItemID then return false end
    local ok, id = pcall(api.GetInventoryItemID, "player", MAIN_HAND)
    if not ok or not id then return false end
    return self:IsPoleItem(id)
end

--- Köder an der Angel: aktiv, enchantID, Restzeit in ms
function P:GetMainHandEnchant()
    if not api.GetWeaponEnchantInfo then return false end
    local ok, has, expiration, _, enchantID = pcall(api.GetWeaponEnchantInfo)
    if not ok then return false end
    return has == true or has == 1, enchantID, expiration
end
