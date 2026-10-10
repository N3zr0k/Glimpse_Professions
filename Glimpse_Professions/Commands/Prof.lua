local Glimpse = LibStub("AceAddon-3.0"):GetAddon("Glimpse")
local P = Glimpse:GetModule("Professions")
local L = P.L

-- /gli prof                         Berufe, Fertigkeit, Tooltip an/aus
-- /gli prof probe [key]             Client-Rohdaten zu einem Beruf, z. B. fishing
-- /gli prof <name>                  Unterbefehle der Berufe (Angeln: cast, lure, buffs, record)
local function PrintLines(lines)
    for _, line in ipairs(lines) do Glimpse:Print(line) end
end

local function OnCommand(_, args)
    local word, rest = strmatch(strtrim(args or ""), "^(%S*)%s*(.-)$")
    word = strlower(word)

    for _, key in ipairs(P.order) do
        local def = P.professions[key]
        local command = def.commands and def.commands[word]
        if command then
            PrintLines(command(P, def))
            return
        end
    end
    if word == "probe" then
        PrintLines(P:ProbeLines(rest ~= "" and strlower(rest) or nil))
        return
    end
    PrintLines(P:OverviewLines())
end

Glimpse:RegisterCommand("prof", L["Shows your professions and whether their tooltips are extended: /gli prof, what the client reports about a profession: /gli prof probe [profession], the steps of the fishing shortcut: /gli prof cast, the buffs with a fishing bonus: /gli prof buffs, the lure: /gli prof lure, the steps of the cast counting: /gli prof record"], OnCommand)
