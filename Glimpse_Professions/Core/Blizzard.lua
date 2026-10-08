local Glimpse = LibStub("AceAddon-3.0"):GetAddon("Glimpse")
local P = Glimpse:GetModule("Professions")

-- Blizzard-Statistiken über GetStatistic(ID), Namen lokalisiert aus den Statistik-Kategorien des Clients.

local api = P.api
local Clean = P.Clean

--- Rohtext des Clients ("19", "55 67", "--"), nil ohne API oder Wert.
function P:ReadStatistic(statID)
    if not api.GetStatistic then return nil end
    local ok, value = pcall(api.GetStatistic, statID)
    value = ok and Clean(value) or nil
    if type(value) == "number" then value = tostring(value) end
    if type(value) ~= "string" or value == "" then return nil end
    return value
end

--- "--" = noch nichts gezählt
function P.IsEmptyStatistic(value)
    return value == nil or value == "--" or value == ""
end

-- statID -> Name, lazy gebaut
local names

local function BuildNames()
    names = {}
    if not (api.GetStatisticsCategoryList and api.GetCategoryNumAchievements and api.GetAchievementInfo) then return end

    pcall(function()
        local categories = api.GetStatisticsCategoryList()
        for _, category in ipairs(type(categories) == "table" and categories or {}) do
            for index = 1, tonumber((api.GetCategoryNumAchievements(category))) or 0 do
                local statID, name = api.GetAchievementInfo(category, index)
                statID, name = Clean(statID), Clean(name)
                if type(statID) == "number" and type(name) == "string" and name ~= "" then names[statID] = name end
            end
        end
    end)
end

function P:BlizzardStatName(statID)
    if not names or next(names) == nil then BuildNames() end -- leer = Daten waren beim letzten Mal noch nicht geladen
    return names[statID]
end

--- Beim Login sind die Statistiken manchmal noch nicht da
function P:ResetBlizzardNames()
    names = nil
end
