local Glimpse = LibStub("AceAddon-3.0"):GetAddon("Glimpse")
local P = Glimpse:GetModule("Professions")

-- Fertigkeits- und Ausrüstungsänderungen lösen def.refresh jedes Berufs aus

local EVENTS = { "PLAYER_ENTERING_WORLD", "SKILL_LINES_CHANGED", "PLAYER_EQUIPMENT_CHANGED", "UNIT_INVENTORY_CHANGED" }

function P:OnSkillEvent(event, unit)
    if event == "UNIT_INVENTORY_CHANGED" and unit ~= "player" then return end
    if event == "PLAYER_ENTERING_WORLD" then self:ResetBlizzardNames() end

    for _, key in ipairs(self.order) do
        local def = self.professions[key]
        if def.refresh then self.Protected(key .. " refresh", def.refresh, self, def) end
        if event == "PLAYER_ENTERING_WORLD" and def.login then self.Protected(key .. " login", def.login, self, def) end
    end
end

function P:OnEnable()
    self:RegisterTooltips()
    if self.CastEnable then self:CastEnable() end
    if self.FishingRecordEnable then self:FishingRecordEnable() end
    if self.FishingJournalEnable then self:FishingJournalEnable() end
    for _, event in ipairs(EVENTS) do self:RegisterEvent(event, "OnSkillEvent") end
end

function P:OnDisable()
    if self.CastDisable then self:CastDisable() end
    for _, event in ipairs(EVENTS) do self:UnregisterEvent(event) end
end
