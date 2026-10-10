local ADDON_NAME = ...
local Glimpse = LibStub("AceAddon-3.0"):GetAddon("Glimpse")
local L = LibStub("AceLocale-3.0"):GetLocale(ADDON_NAME)

-- Berufszauber-Tooltips mit Fertigkeit, Berufsstufe und Blizzard-Statistik.
-- Jeder Beruf liegt in Modules/<Beruf>/ (Haupt-Lua <Beruf>.lua plus Helfer) und meldet sich per RegisterProfession(key, def) an:
--   label       Name (lokalisiert), auch Name des Options-Tabs
--   icon        Texturpfad, optional
--   skillLine   Skill-Linien-ID für GetProfessionInfo
--   skillNames  Namen der Skill-Linie für den Fallback über GetSkillLineInfo
--   spells      Zauber-IDs, deren Tooltip erweitert wird
--   reference   einer dieser Zauber, gleichnamige Zauber (Ränge) zählen mit
--   defaults    Account-Standardwerte, z. B. { tooltip = true }
--   options     function(P, def) -> AceConfig-Args des Tabs
--   lines       function(P, def) -> Tooltip-Zeilen oder nil
--   refresh     function(P, def), optional, bei Fertigkeits-/Ausrüstungsänderung
--   login       function(P, def), optional, bei Login und Reload (PLAYER_ENTERING_WORLD)
--   probe       function(P, def) -> Zeilen für /gli prof probe, optional
local P = Glimpse:NewModule("Professions", nil, "AceEvent-3.0")

--- Blizzard-Global (TOTAL, NONE, GENERAL ...) bevorzugen, sonst L[key]
function P.ClientText(name, key)
    local text = _G[name]
    if type(text) == "string" and text ~= "" then return text end
    return L[key]
end
P.L = L

-- einheitlich für Tooltip und Optionen
P.INDENT = "   "

Glimpse.Professions = P

P.professions, P.order = {}, {}

--- Gleicher key ersetzt den Beruf
function P:RegisterProfession(key, def)
    if type(key) ~= "string" or type(def) ~= "table" then return end
    def.key = key
    def.spellSet = {}
    for _, id in ipairs(def.spells or {}) do def.spellSet[id] = true end
    if not self.professions[key] then self.order[#self.order + 1] = key end
    self.professions[key] = def
end

function P:GetProfession(key)
    return self.professions[key]
end

--- global = Account
function P:BuildDefaults()
    local defaults = { global = { enabled = true }, char = {} }
    for key, def in pairs(self.professions) do
        local copy = {}
        for name, value in pairs(def.defaults or {}) do copy[name] = value end
        defaults.global[key] = copy
    end
    return defaults
end

function P:OnInitialize()
    self.store = LibStub("AceDB-3.0"):New("GlimpseProfessionsDB", self:BuildDefaults(), true)
    self.char = self.store.char
    self.account = self.store.global

    Glimpse:RegisterAddonOptions(ADDON_NAME, self:BuildOptions(), true)
end

function P:TooltipsOn()
    return self.account.enabled ~= false
end

--- Fällt auf def.defaults zurück
function P:Opt(key, name)
    local def = self.professions[key]
    local value = self.account[key] and self.account[key][name]
    if value == nil and def and def.defaults then value = def.defaults[name] end
    return value
end

function P:SetOpt(key, name, value)
    self.account[key] = self.account[key] or {}
    self.account[key][name] = value
end

--- Secret-Werte -> nil
function P.Clean(value)
    if value ~= nil and Glimpse:IsSecret(value) then return nil end
    return value
end

--- pcall mit Vermerk in errorCount/lastError ("label: Meldung") für /gli prof
function P.Protected(label, fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then
        P.errorCount = (P.errorCount or 0) + 1
        P.lastError = label .. ": " .. tostring(err)
    end
    return ok
end
