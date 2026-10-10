local Glimpse = LibStub("AceAddon-3.0"):GetAddon("Glimpse")
local P = Glimpse:GetModule("Professions")
local L = P.L

-- Angelzähler dieses Charakters aus Glimpse: Database (Namespace fishing, FishingRecord.lua) für die Tooltips.
-- Ohne Database fehlen Zeilen und Optionen.

local KEY = "fishing"

--- Leser des Namespace fishing, nil ohne Database oder ohne Daten
function P:FishingCounters()
    local DB = GlimpseDB
    if type(DB) ~= "table" or type(DB.Get) ~= "function" then return nil end
    local ok, reader = pcall(DB.Get, DB, self.FISHING_NAMESPACE)
    if ok and type(reader) == "table" then return reader end
end

local GREY, BLUE, WHITE = "|cff999999", "|cff66ccff", "|cffffffff"

local function Percent(part, whole)
    if not whole or whole <= 0 then return "-" end
    return format("%d %%", math.floor(part / whole * 100 + 0.5))
end

-- "Würfe: 72  heute 72 · 7 Tage 72", Zeiträume blau
local function CounterLine(reader, label, kind)
    local total = reader:GetCount(kind)
    if total <= 0 then return nil end
    local text = format("%s: %s%d|r", label, WHITE, total)
    local week = reader:GetCount(kind, nil, { range = "week" })
    if week > 0 then
        text = text .. format("  %s%s %d · %s %d|r", BLUE, L["today"], reader:GetCount(kind, nil, { range = "today" }),
            L["7 days"], week)
    end
    return text
end

local function TierLines(self, reader, lines)
    local casts, catches = reader:GetCounts("casttier"), reader:GetCounts("catchtier")
    local aborts = reader:GetCounts("aborttier")
    local tiers = {}
    for max in pairs(casts) do tiers[#tiers + 1] = max end
    if #tiers < 2 then return end
    table.sort(tiers)

    local def = self:GetProfession(KEY)
    for _, max in ipairs(tiers) do
        local caught = catches[max] or 0
        local valid = math.max(casts[max] - (aborts[max] or 0), 0)
        lines[#lines + 1] = format("%s %s: %s%s|r  %s(%d/%d)|r", L["Catch rate"], self:TierName(max, def) or tostring(max),
            WHITE, Percent(caught, valid), GREY, caught, valid)
    end
end

--- Tooltip-Zeilen der Zähler, nil wenn nichts da ist
function P:CounterLines()
    if self:Opt(KEY, "own") == false or self:Opt(KEY, "stats") == false then return nil end
    local reader = self:FishingCounters()
    if not reader then return nil end

    local casts, catches = reader:GetCount("cast"), reader:GetCount("catch")
    local valid = math.max(casts - reader:GetCount("castabort"), 0) -- ohne durch Bewegung abgebrochene Würfe
    if casts <= 0 and catches <= 0 then return nil end

    local lines = { { separator = true }, format("|cffffd100%s|r", L["Glimpse counters"]) }
    local since = reader:GetSeen("cast", 0)
    if since then lines[#lines + 1] = format("%s%s %s|r", GREY, L["Recorded since"], date(L["%d/%m/%Y"], since)) end

    local first = #lines + 1
    lines[#lines + 1] = CounterLine(reader, L["Casts"], "cast")
    lines[#lines + 1] = CounterLine(reader, L["Catches"], "catch")
    if catches > 0 then
        lines[#lines + 1] = format("%s: %s%d|r", L["Casts without catch"], WHITE, math.max(valid - catches, 0))
        lines[#lines + 1] = format("%s: %s%s|r", L["Catch rate"], WHITE, Percent(catches, valid))
        TierLines(self, reader, lines)
    end
    lines[#lines + 1] = CounterLine(reader, L["Fish caught"], "fish")
    for index = first, #lines do lines[index] = P.INDENT .. lines[index] end
    return lines
end
