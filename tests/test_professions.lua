-- luacheck: ignore 111 113 122 143 432
local stub = require("wowstub")

-- Berufe (Core/*.lua, Modules/Fishing/Fishing.lua): Fertigkeit, Köder und Ausrüstung, Berufsstufe, Statistik von Blizzard, Tooltip
local function setup()
    local Glimpse = stub.newGlimpse()
    _G.Enum = { TooltipDataType = { Spell = 1, Object = 2 }, ItemClass = { Weapon = 2 }, ItemWeaponSubclass = { Fishingpole = 20 } }
    for _, file in ipairs({ "Core/Professions.lua", "Core/Skills.lua", "Core/Blizzard.lua", "Core/Tooltip.lua", "Core/Probe.lua",
        "Core/Events.lua", "Core/Options.lua", "Modules/Fishing/Fishing.lua", "Modules/Fishing/FishingStats.lua", "Modules/Fishing/FishingBuffs.lua", "Modules/Fishing/FishingCast.lua", "Commands/Prof.lua" }) do
        stub.load(file, "Glimpse_Professions")
    end
    local P = Glimpse:GetModule("Professions")
    P.account, P.char = P:BuildDefaults().global, {}

    -- Der Zustand des Spiels, vom Test gesteuert
    local env = { P = P, Glimpse = Glimpse, fishing = { rank = 20, max = 75, modifier = 0 }, pole = false, lure = false,
        stats = { [1518] = "19", [1456] = "21", [1526] = "--" }, learned = true }
    local api = P.api
    api.GetProfessions = function() if env.learned then return nil, nil, nil, 1, nil end end
    api.GetProfessionInfo = function()
        local s = env.fishing
        return "Angeln", "icon", s.rank, s.max, 1, 0, 356, s.modifier
    end
    api.GetWeaponEnchantInfo = function() return env.lure, 600000, 0, 264 end
    api.GetInventoryItemID = function() return env.pole and 6256 or nil end
    api.GetItemInfoInstant = function(id) return id, "", "", "", "", 2, 20 end
    api.GetSpellName = function(id) if id == 7620 or id == 7731 or id == 99999 then return "Angeln" end return "Anderes" end
    api.GetStatistic = function(id) return env.stats[id] end
    api.GetStatisticsCategoryList = function() return { 1 } end
    api.GetCategoryNumAchievements = function() return 2, 0 end -- Zahl der Statistiken und eine zweite Rückgabe
    api.GetAchievementInfo = function(_, index) return ({ 1518, 1456 })[index], ({ "Gefangene Fische", "Fische und mehr" })[index] end
    return env
end

local function text(lines)
    local out = {}
    for _, line in ipairs(lines or {}) do
        out[#out + 1] = type(line) == "string" and line or (line.separator and "---" or (line[1] .. (line[2] and (" = " .. line[2]) or "")))
    end
    return out
end

test("Professions: der Bonus wird in Köder und Ausrüstung getrennt", function()
    setup()
    local P = LibStub():GetAddon():GetModule("Professions")
    local lure, gear, combined = P.SplitBonus(30, true, 5)
    eq(lure, 25, "Köder"); eq(gear, 5, "Ausrüstung"); eq(combined, nil, "getrennt")
    lure, gear = P.SplitBonus(5, false, 5)
    eq(lure, 0, "kein Köder"); eq(gear, 5, "alles Ausrüstung")
    lure, gear, combined = P.SplitBonus(30, true, nil)
    eq(lure, 0, "ohne gemerkten Wert"); eq(gear, 30, "alles zusammen"); eq(combined, true, "nicht trennbar")
    lure, gear = P.SplitBonus(3, true, 5)
    eq(lure, 0, "gemerkter Wert größer als der Bonus"); eq(gear, 3, "höchstens der Bonus")
    lure, gear = P.SplitBonus(0, true, 5)
    eq(lure + gear, 0, "kein Bonus")
end)

test("Professions: Fertigkeit über GetProfessions, sonst über die Skill-Linien, nicht gelernt ist nil", function()
    local e = setup()
    local P = e.P
    local def = P:GetProfession("fishing")
    local skill = P:GetSkill(def)
    eq(skill.rank, 20, "Stufe"); eq(skill.max, 75, "Maximum"); eq(skill.via, "GetProfessionInfo", "Weg")

    P.api.GetProfessions = nil
    P.api.GetNumSkillLines = function() return 2 end
    P.api.GetSkillLineInfo = function(index)
        if index == 1 then return "Waffen", true end
        return "Angeln", false, true, 33, 0, 4, 150
    end
    skill = P:GetSkill(def)
    eq(skill.rank, 33, "Stufe über die Skill-Linien"); eq(skill.max, 150, "Maximum"); eq(skill.modifier, 4, "Bonus")
    eq(skill.via, "GetSkillLineInfo", "Ersatzweg")

    P.api.GetNumSkillLines = nil
    eq(P:GetSkill(def), nil, "ohne Schnittstelle")
end)

test("Professions: Texte des Spiels gehen vor, sonst der eigene Text", function()
    local P = setup().P
    eq(P.ClientText("TOTAL", "Total"), "Total", "ohne globalen Text: eigener")
    _G.TOTAL = "Gesamt"
    eq(P.ClientText("TOTAL", "Total"), "Gesamt", "Text des Spiels")
    _G.TOTAL = nil
end)

test("Professions: Berufsstufe vom Client (Zusatztext des Zaubers), sonst der eigene Text", function()
    local P = setup().P
    local def = P:GetProfession("fishing")
    eq(P:TierName(75), "Apprentice", "ohne Beruf: eigener Text"); eq(P:TierName(150), "Journeyman", "150"); eq(P:TierName(300), "Artisan", "300")
    eq(P:TierName(77), nil, "unbekanntes Maximum")
    eq(P:TierName(75, def), "Apprentice", "Client liefert nichts: eigener Text")

    local subtext = { [7620] = "Lehrling", [7731] = "Geselle" }
    P.api.GetSpellSubtext = function(id) return subtext[id] end
    eq(P:TierName(75, def), "Lehrling", "Zusatztext von Rang 1"); eq(P:TierName(150, def), "Geselle", "Rang 2")
    eq(P:TierName(225, def), "Expert", "kein Text für Rang 3: eigener Text")

    -- Classic: der Zusatztext ist die zweite Rückgabe von GetSpellInfo
    P.api.GetSpellSubtext = nil
    P.api.GetSpellInfo = function(id) return "Angeln", subtext[id] end
    eq(P:TierName(75, def), "Lehrling", "über GetSpellInfo")

end)

test("Professions: Zauber werden über die ID und über den Namen erkannt", function()
    local P = setup().P
    eq(P:ProfessionForSpell(7620).key, "fishing", "Rang 1")
    eq(P:ProfessionForSpell(18248).key, "fishing", "ein höherer Rang über die ID")
    eq(P:ProfessionForSpell(99999).key, "fishing", "unbekannte ID, aber derselbe Name")
    eq(P:ProfessionForSpell(1234), nil, "anderer Zauber")
    eq(P:ProfessionForSpell(nil), nil, "keine ID")
end)

test("Professions: Tooltip: Fertigkeit, Berufsstufe, Stufe und Statistik von Blizzard", function()
    local e = setup()
    local P = e.P
    e.fishing.modifier = 5
    local lines = text(P:SpellLines({ id = 7620 }))
    eq(lines[1], "|cffffd100Apprentice|r", "Überschrift: nur die Berufsstufe")
    eq(lines[2], "Fishing skill: |cffffffff20|r |cff4da6ff(+5)|r|cffffffff/75|r |cffffffff\194\183|r Total: |cffffffff25|r", "Fertigkeit, Ausrüstung blau, Maximum, Gesamt")
    eq(lines[3], "|cff42b1feSHIFT + Double right click to cast the fishing rod|r", "der ganze Satz im Blau der Tasten, direkt unter der Fertigkeit, ohne Trennlinie")
    eq(lines[4], "---", "Trennlinie vor der Statistik")
    eq(lines[5], "|cffffd100Character statistics|r", "gelbe Überschrift der Statistik von Blizzard")
    eq(lines[6], "   Gefangene Fische = 19", "Name von Blizzard, Wert")
    eq(lines[7], "   Fische und mehr = 21", "zweiter Wert")
    eq(#lines, 7, "die leere Statistik (--) fehlt")

    P.api.GetSpellSubtext = function(id) return id == 7620 and "Lehrling" or nil end
    eq(text(P:SpellLines({ id = 7620 }))[1], "|cffffd100Lehrling|r", "Stufe in der Sprache des Clients")

    e.fishing.modifier = 0
    eq(text(P:SpellLines({ id = 7620 }))[2], "Fishing skill: |cffffffff20|r|cffffffff/75|r", "ohne Bonus keine Rechnung")
end)

test("Professions: Köder grün, Ausrüstung blau, der Bonus der Ausrüstung wird ohne Köder gelernt", function()
    local e = setup()
    local P = e.P
    e.pole, e.fishing.modifier = true, 5
    P:SpellLines({ id = 7620 })
    eq(P.char.fishingGear, 5, "ohne Köder gelernt")

    e.lure, e.fishing.modifier = true, 30
    local lines = text(P:SpellLines({ id = 7620 }))
    eq(lines[2], "Fishing skill: |cffffffff20|r |cff1eff00(+25)|r|cff4da6ff(+5)|r|cffffffff/75|r |cffffffff\194\183|r Total: |cffffffff50|r", "Köder grün, Ausrüstung blau")
    eq(P.char.fishingGear, 5, "mit Köder wird nichts neu gelernt")

    P.account.fishing.split = false
    eq(text(P:SpellLines({ id = 7620 }))[2], "Fishing skill: |cffffffff20|r |cff1eff00(+30)|r|cffffffff/75|r |cffffffff\194\183|r Total: |cffffffff50|r", "nicht getrennt: eine Summe")
end)

test("Professions: ohne gemerkten Wert oder ohne Angel steht der Bonus zusammen", function()
    local e = setup()
    local P = e.P
    e.pole, e.lure, e.fishing.modifier = true, true, 30
    eq(text(P:SpellLines({ id = 7620 }))[2], "Fishing skill: |cffffffff20|r |cff1eff00(+30)|r|cffffffff/75|r |cffffffff\194\183|r Total: |cffffffff50|r", "noch nie ohne Köder gelesen")

    P.char.fishingGear = 5
    e.pole = false
    P:SpellLines({ id = 7620 })
    eq(P.char.fishingGear, nil, "ohne Angel gilt der gemerkte Wert nicht mehr")
end)

test("Professions: Statistik: leere Werte nie, Auswahl, Ersatzname, ausschaltbar", function()
    local e = setup()
    local P = e.P
    local joined = table.concat(text(P:SpellLines({ id = 7620 })), "\n")
    eq(joined:find("Daily fishing quests", 1, true), nil, "leerer Wert (--) wird nie gezeigt")

    e.stats[1526] = "3"
    joined = table.concat(text(P:SpellLines({ id = 7620 })), "\n")
    eq(joined:find("Daily fishing quests completed = 3", 1, true) ~= nil, true, "mit Wert, Ersatzname")

    P.account.fishing.stat1526 = false
    joined = table.concat(text(P:SpellLines({ id = 7620 })), "\n")
    eq(joined:find("Daily fishing quests", 1, true), nil, "abgeschaltete Statistik")

    P.account.fishing.stats = false
    eq(#text(P:SpellLines({ id = 7620 })), 3, "ohne Statistik: Überschrift, Fertigkeit, Kürzel")

    P.account.fishing.cast = false
    eq(#text(P:SpellLines({ id = 7620 })), 2, "ohne Kürzel: Überschrift, Fertigkeit")

    P.account.fishing.tier = false
    eq(#text(P:SpellLines({ id = 7620 })), 1, "ohne Berufsstufe")
end)

test("Professions: nichts, wenn ausgeschaltet, kein Beruf gelernt oder ein fremder Zauber", function()
    local e = setup()
    local P = e.P
    eq(P:SpellLines({ id = 1234 }), nil, "fremder Zauber")
    eq(P:SpellLines({}), nil, "ohne ID")
    P.account.fishing.tooltip = false
    eq(P:SpellLines({ id = 7620 }), nil, "Tooltip des Berufs aus")
    P.account.fishing.tooltip = true
    P.account.enabled = false
    eq(P:SpellLines({ id = 7620 }), nil, "alles aus")
    P.account.enabled = true
    e.learned = false
    eq(P:SpellLines({ id = 7620 }), nil, "Angeln nicht gelernt")
end)

test("Professions: ein Fehler im Beruf stört nicht und wird vermerkt", function()
    local e = setup()
    local P = e.P
    P:GetProfession("fishing").lines = function() error("kaputt") end
    eq(P:SpellLines({ id = 7620 }), nil, "keine Zeilen")
    eq(P.errorCount, 1, "gezählt")
    eq(P.lastError:find("fishing: ", 1, true) ~= nil and P.lastError:find("kaputt", 1, true) ~= nil, true, "Meldung")
end)

test("Professions: Optionen: Tab Allgemein und ein Tab je Beruf, Schalter speichern im Account", function()
    local e = setup()
    local P = e.P
    local options = P:BuildOptions()
    eq(options.general.name, "General", "Tab Allgemein")
    eq(options.general.args.text, nil, "keine Beschreibung unter Allgemein")
    eq(options.fishing.name, "Fishing", "Tab Angeln")

    local args = options.fishing.args
    eq(args.displayHeader.name, "Tooltip display", "Überschrift unter dem Schalter für den Tooltip")
    eq(args.displayHeader.order > args.tooltip.order and args.displayHeader.order < args.split.order, true, "zwischen Tooltip und den Einstellungen")
    eq(args.split.get(), true, "Standard: getrennt"); eq(args.bonus.get(), true, "Standard: Boni zeigen")
    args.bonus.set(nil, false); eq(args.split.disabled(), true, "Boni aus: Art der Anzeige ausgegraut"); args.bonus.set(nil, true)
    eq(args.split.disabled(), false, "Boni an: Art wählbar")
    args.split.set(nil, false)
    eq(P.account.fishing.split, false, "gespeichert")
    eq(args.split.get(), false, "gelesen")
    eq(args.statBlizzard.args.stat1518.disabled(), false, "Statistik an")
    args.stats.set(nil, false)
    eq(args.statBlizzard.args.stat1518.disabled(), true, "Statistik aus sperrt die Auswahl")
    eq(args.statAddon.args.own.disabled(), true, "und den Schalter von Glimpse: Statistics")
    eq(args.example, nil, "kein Beispiel mehr")
    eq(args.showEmpty, nil, "keine Option für leere Werte")

    options.general.args.enabled.set(nil, false)
    eq(P:TooltipsOn(), false, "alles aus")
end)

test("Professions: Schwimmer: Objekt ohne ID während des Angelns zeigt die Zeile mit der Fertigkeit", function()
    local e = setup()
    local P = e.P
    e.fishing.modifier = 5
    local channel
    P.api.UnitChannelInfo = function() return channel end

    eq(P:ObjectLines({ name = "Schwimmer" }), nil, "ohne Wurf nichts")
    channel = "Angeln"
    local bobber = text(P:ObjectLines({ name = "Schwimmer" }))
    eq(#bobber, 1, "nur eine Zeile, ohne Stufe, Kürzel und Statistik")
    eq(bobber[1], "Fishing skill: |cffffffff20|r |cff4da6ff(+5)|r|cffffffff/75|r |cffffffff\194\183|r Total: |cffffffff25|r", "Fertigkeit, Bonus, Gesamt")
    eq(P:ObjectLines({ id = 1731 }), nil, "Objekt mit ID (Sammelknoten) bleibt unberührt")
    channel = "Anderes"
    eq(P:ObjectLines({ name = "Schwimmer" }), nil, "anderer Kanalzauber")
    channel = "Angeln"
    P:SetOpt("fishing", "tooltip", false)
    eq(P:ObjectLines({ name = "Schwimmer" }), nil, "Schalter aus")
end)

test("Professions: Schwimmer: Zähler von Glimpse: Statistics über die Schnittstelle, nur dieser Charakter", function()
    local e = setup()
    local P, Glimpse = e.P, e.Glimpse
    P.api.UnitChannelInfo = function() return "Angeln" end
    local function bobber() return text(P:ObjectLines({ name = "Schwimmer" })) end
    eq(#bobber(), 1, "ohne Statistics nur die Fertigkeit")
    eq(P:StatisticsAddonInfo(), nil, "kein Hinweis")
    eq(P:BuildOptions().fishing.args.statAddon.hidden(), true, "Rahmen fehlt ohne Addon")

    local asked, answer
    Glimpse.Statistics = { GetInfo = function() return { api = 4, available = true, version = "0.1.50-alpha.1" } end,
        Query = function(_, request) asked = request return answer end }
    P.statsApi.GetAddOnMetadata = function(_, field) return ({ IconTexture = "Interface\\Icons\\X" })[field] end
    answer = { ok = true, sinceText = "07.10.2026",
        labels = { since = "Erfasst seit", periods = { [1] = "heute", [7] = "7 Tage" } },
        topics = { fishing = { hasData = true,
            metrics = { casts = { label = "Angelwürfe", total = 72, periods = { [1] = 72, [7] = 72 } },
                catches = { label = "Angelfänge", total = 57, periods = { [1] = 53, [7] = 53 } },
                fish = { label = "Gefangene Fische", total = 52, periods = { [1] = 0, [7] = 0 } } },
            derived = { missed = { label = "Würfe ohne Fang", value = 15 },
                rate = { label = "Fangquote", value = 0.79, tiers = { { name = "Lehrling", value = 40 / 60, numerator = 40, denominator = 60 },
                    { name = "Geselle", value = 1, numerator = 12, denominator = 12 } } } } } } }
    local lines = bobber()
    eq(lines[2], "---", "Trennlinie")
    eq(lines[3], "|cffffd100Glimpse: Statistics|r", "gelbe Überschrift mit dem Namen des Addons")
    eq(lines[4], "|cff999999Erfasst seit 07.10.2026|r", "seit wann aufgezeichnet wird")
    eq(lines[5], "   Angelwürfe: |cffffffff72|r  |cff66ccffheute 72 · 7 Tage 72|r", "Würfe mit heute und 7 Tagen, eingerückt")
    eq(lines[6], "   Angelfänge: |cffffffff57|r  |cff66ccffheute 53 · 7 Tage 53|r", "Fänge")
    eq(lines[7], "   Würfe ohne Fang: |cffffffff15|r", "ohne Fang"); eq(lines[8], "   Fangquote: |cffffffff79 %|r", "Quote gesamt")
    eq(lines[9], "   Fangquote Lehrling: |cffffffff67 %|r  |cff999999(40/60)|r", "Quote je Stufe")
    eq(lines[10], "   Fangquote Geselle: |cffffffff100 %|r  |cff999999(12/12)|r", "zweite Stufe")
    eq(lines[11], "   Gefangene Fische: |cffffffff52|r", "Fische ohne Summen, wenn es keine gibt"); eq(#lines, 11, "Zeilen")
    eq(asked.scope, "char", "nur dieser Charakter"); eq(asked.topics[1], "fishing", "nur Angeln")
    answer.topics.fishing.derived.rate.tiers = { answer.topics.fishing.derived.rate.tiers[1] }
    eq(#bobber(), 9, "mit nur einer Stufe keine Zeilen je Stufe")
    local spell = text(P:SpellLines({ id = 7620 }))
    eq(table.concat(spell, "\n"):find("Fangquote: |cffffffff79 %|r", 1, true) ~= nil, true, "auch im Tooltip des Zaubers")
    answer.topics.fishing.hasData = false
    eq(#bobber(), 1, "nichts gezählt: keine Zeilen")
    answer.topics.fishing.hasData = true
    local name, version, icon = P:StatisticsAddonInfo()
    eq(name, "Glimpse: Statistics", "Name"); eq(version, "0.1.50-alpha.1", "Version"); eq(icon, "Interface\\Icons\\X", "Symbol")
    local args = P:BuildOptions().fishing.args
    eq(args.statAddon.hidden(), false, "Rahmen da")
    eq(args.statAddon.name():find("Glimpse: Statistics", 1, true) ~= nil and args.statAddon.name():find("v0.1.50-alpha.1", 1, true) ~= nil, true, "Überschrift mit Name und Version")
    eq(args.statAddon.args.installed.name:find("installed", 1, true) ~= nil, true, "installiert"); eq(args.statAddon.args.own.name, "Show the counters of Glimpse: Statistics", "Schalter")

    P:SetOpt("fishing", "own", false)
    eq(#bobber(), 1, "ausgeschaltet")
    P:SetOpt("fishing", "own", true)
    Glimpse.Statistics.GetInfo = function() return { api = 3, available = true } end
    eq(P:StatisticsAddon(), nil, "API 3 hat keine Datenschnittstelle: nicht erkannt")
    Glimpse.Statistics.GetInfo = function() return { api = 4, available = false } end
    eq(P:StatisticsAddon(), nil, "Daten nicht lesbar: nicht erkannt")
    Glimpse.Statistics.GetInfo = function() return { api = 4, available = true } end
    Glimpse.Statistics.Query = function() return "Unsinn" end
    eq(#bobber(), 1, "Antwort unbrauchbar: keine Zeilen")
    Glimpse.Statistics.Query = function() error("kaputt") end
    eq(#bobber(), 1, "Schnittstelle wirft einen Fehler: keine Zeilen")
    Glimpse.Statistics = nil
end)

test("Professions: Tooltip und Ereignisse werden angemeldet", function()
    local e = setup()
    local P = e.P
    local registered, events = {}, {}
    P.RegisterTooltipLine = function(_, dataType, provider) registered[#registered + 1] = { dataType, provider } end
    P.RegisterEvent = function(_, event) events[event] = true end
    P:OnEnable()
    eq(registered[1][1], 1, "Typ Zauber"); eq(registered[1][2], "SpellLines", "Anbieter")
    eq(registered[2][1], 2, "Typ Objekt"); eq(registered[2][2], "ObjectLines", "Anbieter")
    eq(events.SKILL_LINES_CHANGED and events.PLAYER_EQUIPMENT_CHANGED and events.UNIT_INVENTORY_CHANGED, true, "Ereignisse")

    -- Änderung der Ausrüstung: der Bonus wird neu gelernt, fremde Einheiten werden ignoriert
    e.pole, e.fishing.modifier = true, 7
    P:OnSkillEvent("UNIT_INVENTORY_CHANGED", "target")
    eq(P.char.fishingGear, nil, "andere Einheit")
    P:OnSkillEvent("PLAYER_EQUIPMENT_CHANGED")
    eq(P.char.fishingGear, 7, "gelernt")
end)

test("Professions: Befehl: Übersicht und probe", function()
    local e = setup()
    local P, Glimpse = e.P, e.Glimpse
    e.pole = true
    local overview = P:OverviewLines()
    eq(overview[1], "Fishing: 20/75, tooltip on", "Übersicht")

    Glimpse.commands.prof.func(nil, "probe")
    local printed = table.concat(Glimpse.printed, "\n")
    eq(printed:find("GetProfessions #4 -> index 1: Angeln | icon | 20 | 75 | 1 | 0 | 356 | 0", 1, true) ~= nil, true, "Rückgaben von GetProfessionInfo")
    eq(printed:find("fishing pole equipped: true", 1, true) ~= nil, true, "Angel erkannt")
    eq(printed:find("statistic 1518 (Gefangene Fische): 19", 1, true) ~= nil, true, "Statistik")
    eq(printed:find("API: ", 1, true) ~= nil, true, "Schnittstelle")

    local lines = P:ProbeLines("gibtsnicht")
    eq(lines[1], "Unknown profession.", "unbekannter Beruf")
end)

-- Angel auswerfen per Tastenkürzel (Modules/Fishing/FishingCast.lua)
local function castSetup()
    local e = setup()
    local P = e.P
    e.equipped = { [16] = "|Hitem:100|h[Schwert]|h", [17] = "|Hitem:101|h[Schild]|h" }
    e.bags = { [0] = { 6256 }, [1] = {} }
    e.free = { [0] = 0, [1] = 2 }
    e.combat, e.alerts, e.equips, e.speed, e.tickers = false, {}, {}, 0, {}
    local api = P.castApi
    api.NumBags = 1
    api.InCombatLockdown = function() return e.combat end
    api.GetInventoryItemLink = function(_, slot) return e.equipped[slot] end
    api.EquipItemByName = function(item, slot)
        e.equips[#e.equips + 1] = { item, slot }
        if item == 6256 then e.pole = true; e.equipped[16] = nil elseif slot then e.equipped[slot] = item end
    end
    api.GetContainerNumSlots = function(bag) return #(e.bags[bag] or {}) end
    api.GetContainerItemID = function(bag, slot) return e.bags[bag][slot] end
    api.GetContainerNumFreeSlots = function(bag) return e.free[bag] or 0, 0 end
    api.GetUnitSpeed = function() return e.speed end
    api.NewTicker = function(_, func)
        local t = { func = func, Cancel = function(self) self.cancelled = true end }
        e.tickers[#e.tickers + 1] = t
        return t
    end
    api.Alert = function(msg) e.alerts[#e.alerts + 1] = msg end
    e.notices = {}
    api.Notice = function(msg) e.notices[#e.notices + 1] = msg end
    -- 6256 ist die Angel, alles andere eine normale Waffe
    P.api.GetItemInfoInstant = function(id) return id, "", "", "", "", 2, id == 6256 and 20 or 7 end
    return e
end

test("Angel auswerfen: Waffen merken, Angel anlegen, Platz für beide Waffen nötig", function()
    local e = castSetup()
    local P = e.P
    -- Waffenhand und Zweitwaffe: die Angel nimmt den Platz der Waffenhand, die Zweitwaffe braucht einen freien Platz
    eq(P:SlotsNeeded(true), 1, "Angel aus dem Rucksack: nur die Zweitwaffe")
    eq(P:SlotsNeeded(false), 2, "Angel nicht im Rucksack: beide")
    e.free = { [0] = 0, [1] = 0 }
    eq(P:PreparePole(), false, "kein Platz")
    eq(e.alerts[1]:find("Additional space needed: 1", 1, true) ~= nil, true, "Meldung nennt den fehlenden Platz")
    eq(#e.equips, 0, "nichts gewechselt"); eq(P.char.fishingSaved, nil, "nichts gemerkt")

    e.free = { [0] = 0, [1] = 1 }
    eq(P:PreparePole(), false, "gewechselt, der nächste Klick wirft aus")
    eq(e.equips[1][1], 6256, "Angel angelegt")
    eq(P.char.fishingSaved[16], "|Hitem:100|h[Schwert]|h", "Waffenhand gemerkt")
    eq(P.char.fishingSaved[17], "|Hitem:101|h[Schild]|h", "Zweitwaffe gemerkt")
    eq(#e.tickers, 1, "Bewegung wird überwacht")
    eq(#e.notices, 1, "Hinweis: nochmal doppelklicken")

    eq(P:PreparePole(), true, "Angel in der Hand: auswerfen")
end)

test("Angel auswerfen: nach mehr als 5 Metern Bewegung kommen die Waffen zurück", function()
    local e = castSetup()
    local P = e.P
    P:PreparePole()
    e.speed = 7 -- Meter pro Sekunde
    e.tickers[1].func(); e.tickers[1].func(); e.tickers[1].func() -- 3 x 0,2 s = 4,2 m
    eq(#e.equips, 1, "noch nicht")
    e.tickers[1].func() -- 5,6 m
    eq(e.equips[2][2], 16, "Waffenhand zuerst"); eq(e.equips[3][2], 17, "dann die Zweitwaffe")
    eq(P.char.fishingSaved, nil, "nichts mehr gemerkt"); eq(e.tickers[1].cancelled, true, "Überwachung beendet")

    -- im Kampf wird nach dem Kampf zurückgewechselt
    e.equips = {}
    P.char.fishingSaved = { [16] = "|Hitem:100|h[Schwert]|h" }
    e.combat = true
    P:RestoreWeapons()
    eq(#e.equips, 0, "im Kampf nicht"); eq(P.restorePending, true, "vorgemerkt")
    e.combat = false
    P:CastOnRegen()
    eq(#e.equips, 1, "nach dem Kampf")
end)

test("Angel auswerfen: Meldungen im Kampf und ohne Angel, Angel schon in der Hand, Taste", function()
    local e = castSetup()
    local P = e.P
    e.combat = true
    eq(P:PreparePole(), false, "Kampf"); eq(#e.alerts, 1, "Meldung im Kampf")
    e.combat, e.bags = false, { [0] = {}, [1] = {} }
    eq(P:PreparePole(), false, "keine Angel"); eq(#e.alerts, 2, "Meldung ohne Angel")

    e.pole = true
    eq(P:PreparePole(), true, "Angel schon in der Hand: nichts wechseln"); eq(#e.equips, 0, "nichts gewechselt")

    eq(P:CastModifier(), "SHIFT", "Standard"); P.account.fishing.castKey = "ALT"
    eq(P:CastModifier(), "ALT", "gewählt"); P.account.fishing.castKey = "x"
    eq(P:CastModifier(), "SHIFT", "ungültig: Standard")
    eq(P:BuildOptions().fishing.args.castKey.get(), "SHIFT", "Option")
    eq(P:BuildOptions().fishing.args.castClick.name(), "   + Double right click", "neben der Taste nur der feste Teil, mit Abstand")
    P.account.fishing.cast = false
    eq(P:BuildOptions().fishing.args.castClick.name(), "|cff808080   + Double right click|r", "Kürzel aus: Text grau")
    P.account.fishing.cast = true
    eq(P:CastShortcutText(), "SHIFT + Double right click", "Tooltip: Taste und Rechtsklick")

    -- ohne Taste: nur der doppelte Rechtsklick
    P.account.fishing.castKey = "NONE"
    eq(P:CastModifier(), "NONE", "keine Taste wählbar")
    eq(P:CastBindingKey(), "BUTTON2", "Belegung ohne Taste"); eq(P:CastShortcutText(), "Double right click", "Tooltip ohne Taste")
    eq(P:BuildOptions().fishing.args.castClick.name(), "   Double right click", "Text ohne Plus")
    eq(P:BuildOptions().fishing.args.castKey.values().NONE, "None", "Eintrag Keine")
    local down = { shift = false, ctrl = false, alt = false }
    _G.IsShiftKeyDown, _G.IsControlKeyDown, _G.IsAltKeyDown = function() return down.shift end, function() return down.ctrl end, function() return down.alt end
    local original = P.castApi.IsModifierDown
    -- die echte Funktion aus FishingCast.lua prüfen
    stub.load("Modules/Fishing/FishingCast.lua", "Glimpse_Professions")
    local real = P.castApi.IsModifierDown
    eq(real("NONE"), true, "ohne Taste: Rechtsklick allein gilt")
    down.shift = true
    eq(real("NONE"), false, "mit gedrückter Umschalttaste gilt er nicht")
    eq(real("SHIFT"), true, "Umschalt")
    P.castApi.IsModifierDown = original
    P.account.fishing.castKey = "SHIFT"
    eq(P:CastBindingKey(), "SHIFT-BUTTON2", "Belegung mit Taste")
end)

test("Angel auswerfen: /gli prof cast zeigt Zustand und Protokoll", function()
    local e = castSetup()
    local P = e.P
    eq(P:CastLines()[3], "log empty (no click seen yet)", "leeres Protokoll")
    P:CastOnSpell("UNIT_SPELLCAST_SENT", "player", "target", "guid", 7620)
    eq(#P.castLog, 0, "ohne Klick wird nichts protokolliert")
    P.castLog[1] = "x"
    P:CastOnSpell("UI_ERROR_MESSAGE", 1, "Nicht genug Platz")
    eq(P.castLog[2]:find("error message: Nicht genug Platz", 1, true) ~= nil, true, "Fehlermeldung")
    eq(#P:CastLines() >= 4, true, "Zeilen")
    eq(e.Glimpse.commands.prof ~= nil, true, "Befehl da")
end)

test("Angel auswerfen: mit Fishing Buddy nur der Tooltip, keine Anzeige und keine Optionen für das Kürzel", function()
    local e = castSetup()
    local P = e.P
    local loaded = {}
    P.castApi.IsAddOnLoaded = function(name) return loaded[name] end
    eq(P:CastEnabled(), true, "ohne Fishing Buddy an")
    local function joined() return table.concat(text(P:SpellLines({ id = 7620 })), "\n") end
    eq(joined():find("Double right click", 1, true) ~= nil, true, "Kürzel im Tooltip")
    local args = P:BuildOptions().fishing.args
    eq(args.cast.hidden(), false, "Option sichtbar"); eq(args.castKey.hidden(), false, "Taste sichtbar")

    loaded.FishingBuddy = true
    eq(P:CastBlockedBy(), "FishingBuddy", "erkannt"); eq(P:CastEnabled(), false, "aus")
    eq(joined():find("Double right click", 1, true), nil, "kein Kürzel im Tooltip")
    eq(joined():find("Fishing skill", 1, true) ~= nil, true, "der Rest des Tooltips bleibt")
    eq(args.cast.hidden(), true, "Schalter versteckt"); eq(args.castKey.hidden(), true, "Taste versteckt")
    eq(args.castClick.hidden(), true, "Text versteckt");     eq(P:CastLines()[1]:find("FishingBuddy", 1, true) ~= nil, true, "Hinweis in /gli prof cast")

    -- Hinweis in den Optionen: nur mit Fishing Buddy, mit Version
    eq(args.castBlocked.hidden(), false, "Hinweis sichtbar")
    eq(args.castBlocked.name(), "|cffffd100Fishing Buddy|r |cff33ff33|r|cffffffffinstalled|r\n|cff999999   Casting with a shortcut and the weapon change are switched off.\n   Only the tooltip is used.|r", "ohne Version")
    P.castApi.GetAddOnMetadata = function(name, field) if name == "FishingBuddy" and field == "Version" then return "1.9.3" end end
    local name, version = P:CastBlockedByInfo()
    eq(name, "Fishing Buddy", "Name"); eq(version, "1.9.3", "Version")
    eq(args.castBlocked.name():find("|cffffd100Fishing Buddy|r |cff33ff33(v1.9.3) |r|cffffffffinstalled|r\n|cff999999", 1, true) ~= nil, true, "Name gelb, Version grün, installiert weiß, Text grau")
    eq(args.castHeader.hidden, nil, "die Überschrift bleibt sichtbar")
    eq(args.castBlocked.image(), nil, "kein Symbol, wenn das Addon keins angibt")
    P.castApi.GetAddOnMetadata = function(name, field)
        if field == "IconTexture" then return "Interface\\Icons\\Trade_Fishing" end
        if field == "Version" then return "1.9.3" end
    end
    eq(args.castBlocked.image(), "Interface\\Icons\\Trade_Fishing", "das Symbol des Addons")
    loaded.FishingBuddy = nil
    eq(args.castBlocked.hidden(), true, "ohne Fishing Buddy kein Hinweis")
end)

test("Buffs: Glänzende Silbermünze zählt zum Gesamtbonus und steht als eigener Wert und in der Liste", function()
    local e = setup()
    local P = e.P
    P.buffApi.Buffs = function() return { { name = "Tarnung", lines = { "Unsichtbar" } }, { name = "Silbermünze", lines = { "Name", "Increases Fishing skill by 10." } } } end
    P.buffApi.MainHandLines = function() return {} end
    P.buffApi.QualityColor = function(name) return name == "Silbermünze" and "|cffa335ee" or nil end
    P.GetSkill = function() return { name = "Fishing", rank = 50, max = 75, modifier = 40 }, nil end
    P.char.fishingGear = nil
    local buffs = P:FishingBuffs()
    eq(#buffs, 1, "nur der Buff mit Angelbonus"); eq(buffs[1].value, 10, "Wert aus dem Tooltip")
    local joined = table.concat(text(P:SpellLines({ id = 7620 })), "\n")
    eq(joined:find("|cffff8000(+10)|r", 1, true) ~= nil, true, "Buff als eigener Wert in Orange")
    eq(joined:find("|cffff8000\226\128\162|r |cffffffffSilbermünze|r |cffff8000+10|r", 1, true) ~= nil, true, "Liste: Punkt und Wert in Orange")
    eq(joined:find("Total: |cffffffff90|r", 1, true) ~= nil, true, "Gesamt enthält den Buff")
    P.account.fishing.bonus = false
    local plain = table.concat(text(P:SpellLines({ id = 7620 })), "\n")
    eq(plain:find("(+", 1, true) == nil and plain:find("Silbermünze", 1, true) == nil and plain:find("Total", 1, true) == nil, true, "Boni aus: nur die Fertigkeit")
    P.account.fishing.bonus = true
end)

test("Köder auf der Angel: Wert aus dem Tooltip der Angel, Rest ist Ausrüstung, Liste unter der Fertigkeit", function()
    local e = setup()
    local P = e.P
    P.buffApi.Buffs = function() return {} end
    P.buffApi.MainHandLines = function() return { "Angel", "Fishing Lure +25 (8 min)" } end
    P.api.GetInventoryItemID = function() return 6256 end
    P.api.GetItemInfoInstant = function(id) return id, "", "", "", "", 2, 20 end
    P.api.GetWeaponEnchantInfo = function() return true, 1000, 0, 263 end
    P.GetSkill = function() return { name = "Fishing", rank = 50, max = 75, modifier = 30 } end
    P.char.fishingGear = 30 -- veralteter Wert
    local joined = table.concat(text(P:SpellLines({ id = 7620 })), "\n")
    eq(joined:find("(+25)|r", 1, true) ~= nil, true, "Köder 25 aus dem Tooltip")
    eq(joined:find("(+5)|r", 1, true) ~= nil, true, "Rest 5 ist Ausrüstung")
    eq(joined:find("Fishing Lure|r |cff1eff00+25|r", 1, true) ~= nil, true, "Liste")
    eq(P.char.fishingGear, 5, "Ausrüstung neu gemerkt")
end)

test("Köder: bester Köder aus dem Rucksack wird auf die Angel ohne Köder angewendet", function()
    local e = castSetup()
    local P = e.P
    stub.load("Modules/Fishing/FishingLure.lua", "Glimpse_Professions")
    local la = P.lureApi
    e.used, e.picked, e.good = {}, 0, {}
    la.GetContainerItemLink = function(bag, slot) return "[Item" .. e.bags[bag][slot] .. "]" end
    la.TooltipLines = function(bag, slot) return e.bags[bag][slot] == 9999 and { "Name", "Equip: Fishing +40" } or {} end
    la.Good = function(text) e.good[#e.good + 1] = text end
        P.api.GetInventoryItemID = function() return 6256 end
    P.api.GetItemInfoInstant = function(id) return id, "", "", "", "", id == 6256 and 2 or 0, id == 6256 and 20 or 0 end
    P.api.GetWeaponEnchantInfo = function() return false end
    P.GetSkill = function() return { name = "Fishing", rank = 50, max = 75, modifier = 0 } end
    e.equipped[16] = "[Angel]"
    e.bags = { [0] = { 6529, 9999, 6533 }, [1] = { 6530 } }

    local best = P:FindBestLure()
    eq(best.id, 6533, "höchster Bonus aus der Liste"); eq(best.bonus, 100, "Bonus")
    eq(P:LureMacro(), "/use 0 3\n/use 16", "Makro: Köder benutzen, dann Waffenhand")
    eq(#e.good, 2, "zwei Zeilen"); eq(e.good[1], "Apply [Item6533] to [Angel].", "Zeile 1"); eq(e.good[2], "Your fishing skill increases by 100.", "Zeile 2")

    -- Fischglas: "Benötigt Angeln (20)" ist kein Bonus
    _G.ITEM_MIN_SKILL = "Requires %s (%d)"
    la.TooltipLines = function() return { "Fish bowl", "Requires Fishing (20)" } end
    eq(P:LureBonus(555, 0, 1), nil, "Voraussetzung ist kein Köder")
    eq(P:LureBonus(279967, 0, 1), nil, "Fischglas ausgenommen")
    _G.ITEM_MIN_SKILL = nil
    la.TooltipLines = function(bag, slot) return e.bags[bag][slot] == 9999 and { "Name", "Equip: Fishing +40" } or {} end

    -- unbekannter Köder über den Tooltip
    e.bags = { [0] = { 9999 }, [1] = {} }
    eq(P:LureBonus(9999, 0, 1), 40, "Tooltip: erste Zahl in der Zeile mit dem Namen der Fertigkeit")

    -- schon ein Köder dran, Schalter aus, Kampf, keine Köder
    P.api.GetWeaponEnchantInfo = function() return true, 1000, 0, 123 end
    eq(P:LureMacro(), nil, "Köder schon dran")
    P.api.GetWeaponEnchantInfo = function() return false end
    P.account.fishing.lure = false; eq(P:LureMacro(), nil, "Schalter aus"); P.account.fishing.lure = true
    e.combat = true; eq(P:LureMacro(), nil, "Kampf"); e.combat = false
    e.bags = { [0] = { 6256 }, [1] = {} }
    eq(P:LureMacro(), nil, "kein Köder im Rucksack")
end)

test("Angel auswerfen: Doppelklick wird beim zweiten Drücken erkannt, der erste Klick bleibt unberührt", function()
    local e = castSetup()
    local P = e.P
    local now, bound, cleared, stops = 0, {}, 0, 0
    _G.GetTime = function() return now end
    _G.UIParent = {}
    _G.CreateFrame = function()
        local f = { attrs = {}, scripts = {} }
        function f:RegisterForClicks() end
        function f:SetAttribute(k, v) self.attrs[k] = v end
        function f:SetScript(name, fn) self.scripts[name] = fn end
        return f
    end
    _G.SetOverrideBindingClick = function(_, _, key, name) bound[#bound + 1] = key .. ">" .. name end
    _G.ClearOverrideBindings = function() cleared = cleared + 1 end
    _G.IsMouselooking = function() return true end
    _G.MouselookStop = function() stops = stops + 1 end
    _G.IsMouseButtonDown = function() return true end -- die rechte Taste ist beim zweiten Drücken unten
    e.mod = true
    P.castApi.IsModifierDown = function() return e.mod end
    local after = {}
    P.castApi.After = function(_, fn) after[#after + 1] = fn end
    local function press(button, at) now = at; P:CastOnMouseDown("GLOBAL_MOUSE_DOWN", button or "RightButton") end

    press("RightButton", 10)
    eq(#bound, 0, "der erste Klick legt nichts an"); eq(stops, 0, "und beendet nichts")
    press("RightButton", 10.02)
    eq(#bound, 0, "zu schnell zählt nicht als zweiter Klick")
    press("RightButton", 10.2)
    eq(bound[1], "SHIFT-BUTTON2>GlimpseProfessionsCastButton", "der zweite Klick belegt den Knopf")
    eq(stops, 1, "die Maussteuerung endet, auch wenn die Maustaste gedrückt ist")
    eq(#after, 1, "Zeitgeber zum Aufräumen")
    after[1]()
    eq(cleared, 1, "Belegung wird wieder gelöscht")

    press("RightButton", 20); press("RightButton", 20.6)
    eq(#bound, 1, "zu spät: wieder ein erster Klick")
    press("LeftButton", 20.8)
    eq(#bound, 1, "linke Maustaste zählt nicht")
    e.mod = false
    press("RightButton", 30); press("RightButton", 30.2)
    eq(#bound, 1, "ohne die Taste nichts")
    e.mod, e.combat = true, true
    press("RightButton", 40); press("RightButton", 40.2)
    eq(#bound, 1, "im Kampf nichts")
    e.combat = false
    P.account.fishing.cast = false
    press("RightButton", 50); press("RightButton", 50.2)
    eq(#bound, 1, "ausgeschaltet nichts")
end)

test("Professions: Zahlen aus Farbcodes oder Symbolen sind kein Angelbonus, lange Texte werden je Zeile gelesen", function()
    local P = setup().P
    P.buffApi.Buffs = function() return {
        { name = "Farbe", lines = { "Farbe", "|cff20ff20Gekleidet in Angelausrüstung.|r" } },
        { name = "Symbol", lines = { "|TInterface\\Icons\\Trade_Fishing:20|t Angelausrüstung" } },
        { name = "Silbermünze", lines = { "Name", "|cffffffffErhöht Angeln um 10.|r" } },
        { name = "Lang", lines = { "Lang", "Ein Text ohne Bezug.\n\n+15 Angeln\n\nBis zu einem Maximum von 100." } },
    } end
    P.buffApi.MainHandLines = function() return {} end
    P.buffApi.QualityColor = function() return nil end
    P.api.GetProfessions = function() return nil, nil, nil, 1 end
    P.api.GetProfessionInfo = function() return "Angeln", "", 5, 75, 0, 0, 356, 25 end
    local buffs = P:FishingBuffs()
    eq(#buffs, 2, "nur die echten Boni"); eq(buffs[1].value, 10, "Wert ohne Farbcode"); eq(buffs[2].value, 15, "+15 aus der eigenen Zeile")
    eq(P.PlainText("|cffffd200Noch 40 |4Minute:Minuten;|r"), "Noch 40 ", "Text ohne Codes")
end)
