local Glimpse = LibStub("AceAddon-3.0"):GetAddon("Glimpse")
local P = Glimpse:GetModule("Professions")
local L = P.L

-- Angelzähler aus Glimpse: Statistics (nur dieser Charakter), ausschließlich über dessen API (:GetInfo, :Query).
-- Ohne das Addon fehlen Zeilen und Optionen.

local KEY = "fishing"
local NEEDED_API = 4 -- erste API_VERSION mit GetInfo/Query

P.statsApi = {
    GetAddOnMetadata = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata,
}

--- Glimpse.Statistics, wenn die API antwortet, sonst nil
function P:StatisticsAddon()
    local S = Glimpse.Statistics
    if type(S) ~= "table" or type(S.GetInfo) ~= "function" or type(S.Query) ~= "function" then return nil end

    local ok, info = pcall(S.GetInfo, S)
    if not ok or type(info) ~= "table" or info.available ~= true then return nil end
    if type(info.api) ~= "number" or info.api < NEEDED_API then return nil end
    return S
end

--- name, version, icon für den Optionen-Hinweis
function P:StatisticsAddonInfo()
    local S = self:StatisticsAddon()
    if not S then return nil end
    local _, info = pcall(S.GetInfo, S)
    local function Field(field)
        local get = self.statsApi.GetAddOnMetadata
        if not get then return nil end
        local ok, value = pcall(get, "Glimpse_Statistics", field)
        if ok and type(value) == "string" and value ~= "" then return value end
    end
    return "Glimpse: Statistics", type(info) == "table" and type(info.version) == "string" and info.version or Field("Version"), Field("IconTexture")
end

local GREY, BLUE, WHITE = "|cff999999", "|cff66ccff", "|cffffffff"

local function Percent(rate)
    if type(rate) ~= "number" then return "-" end
    return format("%d %%", math.floor(rate * 100 + 0.5))
end

-- "Name: 72  heute 72 · 7 Tage 72", Zeiträume blau
local function CounterLine(metric, labels)
    local text = format("%s: %s%d|r", metric.label, WHITE, metric.total)
    local week = metric.periods[7] or 0
    if week > 0 then
        text = text .. format("  %s%s %d · %s %d|r", BLUE, labels.periods[1] or "", metric.periods[1] or 0, labels.periods[7] or "", week)
    end
    return text
end

--- Tooltip-Zeilen aus Statistics:Query. Layout von hier, Namen und Zahlen von Statistics. nil, wenn nichts da ist.
function P:StatisticsLines()
    if self:Opt(KEY, "own") == false or self:Opt(KEY, "stats") == false then return nil end
    local S = self:StatisticsAddon()
    if not S then return nil end

    local ok, answer = pcall(S.Query, S, { topics = { "fishing" }, scope = "char", periods = { 1, 7 }, tiers = true })
    local fishing = ok and type(answer) == "table" and answer.ok and type(answer.topics) == "table" and answer.topics.fishing
    if not (fishing and fishing.hasData and type(fishing.metrics) == "table") then return nil end

    local labels = type(answer.labels) == "table" and answer.labels or {}
    labels.periods = type(labels.periods) == "table" and labels.periods or {}
    local derived = type(fishing.derived) == "table" and fishing.derived or {}
    local missed, rate = derived.missed or {}, derived.rate or {}

    local lines = { { separator = true } }
    local addonName = self:StatisticsAddonInfo()
    if addonName then lines[#lines + 1] = format("|cffffd100%s|r", addonName) end
    if type(answer.sinceText) == "string" then lines[#lines + 1] = format("%s%s %s|r", GREY, labels.since or "", answer.sinceText) end

    local first = #lines + 1
    local function Add(name)
        local metric = fishing.metrics[name]
        if metric and metric.total > 0 then lines[#lines + 1] = CounterLine(metric, labels) end
    end
    Add("casts")
    Add("catches")
    if fishing.metrics.catches and fishing.metrics.catches.total > 0 then
        lines[#lines + 1] = format("%s: %s%d|r", missed.label or "", WHITE, missed.value or 0)
        lines[#lines + 1] = format("%s: %s%s|r", rate.label or "", WHITE, Percent(rate.value))
        if type(rate.tiers) == "table" and #rate.tiers >= 2 then
            for _, tier in ipairs(rate.tiers) do
                lines[#lines + 1] = format("%s %s: %s%s|r  %s(%d/%d)|r", rate.label or "", tier.name, WHITE, Percent(tier.value), GREY,
                    tier.numerator or 0, tier.denominator or 0)
            end
        end
    end
    Add("fish")
    Add("fishByZone")
    for index = first, #lines do
        if type(lines[index]) == "string" then lines[index] = P.INDENT .. lines[index] end
    end
    return #lines > 1 and lines or nil
end
