local Glimpse = LibStub("AceAddon-3.0"):GetAddon("Glimpse")
local P = Glimpse:GetModule("Professions")
local L = P.L

-- /gli prof                         Berufe, Fertigkeit, Tooltip an/aus
-- /gli prof probe [key]             Client-Rohdaten zu einem Beruf, z. B. fishing
-- /gli prof cast | lure | buffs | record     Angel-Details
local function PrintLines(lines)
    for _, line in ipairs(lines) do Glimpse:Print(line) end
end

local function OnCommand(_, args)
    local word, rest = strmatch(strtrim(args or ""), "^(%S*)%s*(.-)$")
    word = strlower(word)

    if word == "cast" then
        PrintLines(P:CastLines())
        return
    end
    if word == "record" then
        PrintLines(P:FishingRecordLines())
        return
    end
    if word == "lure" then
        PrintLines(P:LureLines())
        return
    end
    if word == "buffs" then
        PrintLines(P:BuffLines())
        return
    end
    if word == "probe" then
        PrintLines(P:ProbeLines(rest ~= "" and strlower(rest) or nil))
        return
    end
    PrintLines(P:OverviewLines())
end

Glimpse:RegisterCommand("prof", L["Shows your professions and whether their tooltips are extended: /gli prof, what the client reports about a profession: /gli prof probe [profession], the steps of the fishing shortcut: /gli prof cast, the buffs with a fishing bonus: /gli prof buffs, the lure: /gli prof lure, the steps of the cast counting: /gli prof record"], OnCommand)
