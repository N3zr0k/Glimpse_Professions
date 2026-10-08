local Glimpse = LibStub("AceAddon-3.0"):GetAddon("Glimpse")
local P = Glimpse:GetModule("Professions")
local L = P.L


local function BuildGeneral(self)
    return {
        enabled = {
            type = "toggle", order = 1, width = "full", name = L["Extend profession tooltips"],
            desc = L["Switches the extension of all profession tooltips on or off."],
            get = function() return self:TooltipsOn() end,
            set = function(_, value) self.account.enabled = value and true or false end,
        },
    }
end

--- Tab "Allgemein" plus ein Tab je Beruf (def.options) in Anmeldereihenfolge
function P:BuildOptions()
    local options = { general = { type = "group", order = 1, name = P.ClientText("GENERAL", "General"), args = BuildGeneral(self) } }
    for index, key in ipairs(self.order) do
        local def = self.professions[key]
        options[key] = { type = "group", order = 1 + index, name = def.label,
            args = def.options and def.options(self, def) or {} }
    end
    return options
end

--- Toggle für eine Berufsoption (Account) über P:Opt / P:SetOpt
function P:Toggle(key, name, order, label, desc, disabled)
    return {
        type = "toggle", order = order, width = "full", name = label, desc = desc,
        get = function() return self:Opt(key, name) == true end,
        set = function(_, value) self:SetOpt(key, name, value and true or false) end,
        disabled = disabled,
    }
end
