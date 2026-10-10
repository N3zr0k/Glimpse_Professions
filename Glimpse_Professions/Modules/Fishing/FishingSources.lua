local Glimpse = LibStub("AceAddon-3.0"):GetAddon("Glimpse")
local P = Glimpse:GetModule("Professions")

-- Woher die Angeldaten kommen, für /gli probe db sources (Core)

local api = P.api

function P:FishingSourceLines()
    local blocked = self:CastBlockedBy()
    return {
        "fishing counters: namespace " .. self.FISHING_NAMESPACE .. " (" .. (self.fishingNs and "writer" or "not registered") .. ")",
        "game statistics: " .. (api.GetStatistic and "read live from the client (GetStatistic)" or "not available"),
        "casting: " .. (blocked and ("left to " .. blocked) or "Glimpse double-click (handler fishing)"),
    }
end

if Glimpse.RegisterDataSource then
    Glimpse:RegisterDataSource("Glimpse_Professions", function() return P:FishingSourceLines() end)
end
