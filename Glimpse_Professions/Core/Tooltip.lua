local Glimpse = LibStub("AceAddon-3.0"):GetAddon("Glimpse")
local P = Glimpse:GetModule("Professions")

-- Zauber per ProfessionForSpell zuordnen, Zeilen liefert def.lines. { separator = true } braucht Glimpse 0.2.3.

function P:SpellLines(data)
    if not self:TooltipsOn() then return nil end
    local spellID = type(data) == "table" and data.id
    if type(spellID) ~= "number" then return nil end

    local def = self:ProfessionForSpell(spellID)
    if not def or not def.lines then return nil end
    if self:Opt(def.key, "tooltip") == false then return nil end

    local lines
    self.Protected(def.key, function() lines = def.lines(self, def) end)
    return lines
end

--- Der Schwimmer ist ein Objekt ohne ID, Objekte mit ID (Sammelknoten) bleiben unberührt
function P:ObjectLines(data)
    if not self:TooltipsOn() then return nil end
    if type(data) ~= "table" or type(data.id) == "number" then return nil end

    for _, key in ipairs(self.order) do
        local def = self.professions[key]
        if def.objectLines and self:Opt(key, "tooltip") ~= false and self:IsChannelingProfession(def) then
            local lines
            self.Protected(key, function() lines = def.objectLines(self, def) end)
            return lines
        end
    end
end

--- false ohne Tooltip-API
function P:RegisterTooltips()
    if not (Enum and Enum.TooltipDataType and Enum.TooltipDataType.Spell and self.RegisterTooltipLine) then return false end
    local ok = pcall(self.RegisterTooltipLine, self, Enum.TooltipDataType.Spell, "SpellLines")
    if Enum.TooltipDataType.Object then pcall(self.RegisterTooltipLine, self, Enum.TooltipDataType.Object, "ObjectLines") end
    return ok
end
