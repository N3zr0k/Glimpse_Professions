-- luacheck: ignore 111 113 122 143 432
local stub = require("wowstub")

-- Berufe (Core/*.lua, Modules/Fishing/Fishing.lua): Fertigkeit, Köder und Ausrüstung, Berufsstufe, Statistik von Blizzard, Tooltip
local function setup()
    local Glimpse = stub.newGlimpse()
    _G.Enum = { TooltipDataType = { Spell = 1, Object = 2 }, ItemClass = { Weapon = 2 }, ItemWeaponSubclass = { Fishingpole = 20 } }
    for _, file in ipairs({ "Core/Professions.lua", "Core/Skills.lua", "Core/Blizzard.lua", "Core/Tooltip.lua", "Core/Probe.lua",
        "Core/Events.lua", "Core/Options.lua", "Modules/Fishing/Fishing.lua", "Modules/Fishing/FishingRecord.lua", "Modules/Fishing/FishingStats.lua", "Modules/Fishing/FishingBuffs.lua", "Modules/Fishing/FishingCast.lua", "Modules/Fishing/FishingJournal.lua", "Modules/Fishing/FishingSources.lua", "Commands/Prof.lua" }) do
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
    eq(args.statAddon.args.own.disabled(), true, "und den Schalter der Zähler")
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

-- Glimpse: Database im Kleinen: ein Namespace, Zeiträume zählen wie gesamt
local function FakeDatabase()
    local data = { counts = {}, zones = {}, seen = {} }
    local function Ids(kind) data.counts[kind] = data.counts[kind] or {} return data.counts[kind] end
    local ns = {}
    function ns:Count(kind, id, mapID, amount)
        local ids = Ids(kind)
        ids[id or 0] = (ids[id or 0] or 0) + (amount or 1)
        if mapID then data.zones[kind .. "/" .. tostring(id or 0) .. "/" .. mapID] = (data.zones[kind .. "/" .. tostring(id or 0) .. "/" .. mapID] or 0) + (amount or 1) end
        data.seen[kind] = data.seen[kind] or 1767225600
        return true
    end
    function ns:GetCount(kind, id)
        local total = 0
        for key, n in pairs(Ids(kind)) do if id == nil or key == id then total = total + n end end
        return total
    end
    function ns:GetCounts(kind) return Ids(kind) end
    function ns:GetSeen(kind) return data.seen[kind] end
    local DB = { data = data, ns = ns }
    function DB:Register(name, options) self.registered = { name = name, options = options } return ns end
    function DB:Get() return self.registered and ns or nil end
    return DB
end

test("Professions: Angeln wird in Glimpse: Database gezählt, ein Fang nur nach einem Wurf", function()
    local e = setup()
    local P, Glimpse = e.P, e.Glimpse
    local DB = FakeDatabase()
    _G.GlimpseDB = DB
    Glimpse.IDs = { ZoneKey = function() return 1429 end }
    local events = {}
    P.RegisterEvent = function(_, event, func) events[event] = func end
    P:FishingRecordEnable()
    eq(DB.registered.name, "fishing", "Namespace")
    eq(DB.registered.options.area, "Professions", "Bereich")

    local loot = { fishing = true, items = { "item:6303", "item:6358" } }
    P.recordApi.IsFishingLoot = function() return loot.fishing end
    P.recordApi.GetNumLootItems = function() return #loot.items end
    P.recordApi.GetLootSlotType = function() return 1 end
    P.recordApi.GetLootSlotLink = function(slot) return loot.items[slot] end
    P.recordApi.GetLootSlotInfo = function(slot) return nil, nil, slot == 1 and 2 or 1 end

    events.LOOT_OPENED("LOOT_OPENED")
    eq(DB.ns:GetCount("catch"), 0, "ohne Wurf kein Fang")
    events.UNIT_SPELLCAST_SUCCEEDED("UNIT_SPELLCAST_SUCCEEDED", "target", "guid", 7620)
    events.UNIT_SPELLCAST_SUCCEEDED("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", 133)
    eq(DB.ns:GetCount("cast"), 0, "fremde Einheit oder anderer Zauber")
    events.UNIT_SPELLCAST_SUCCEEDED("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", 7620)
    events.LOOT_OPENED("LOOT_OPENED")
    events.LOOT_OPENED("LOOT_OPENED")
    eq(DB.ns:GetCount("cast"), 1, "Wurf")
    eq(DB.ns:GetCount("casttier", 75), 1, "Wurf je Stufe")
    eq(DB.ns:GetCount("catch"), 1, "Fang nur einmal")
    eq(DB.ns:GetCount("fish", 6303), 2, "Menge")
    eq(DB.ns:GetCount("drop:1429", 6303), 1, "Fenster mit Item")
    eq(DB.ns:GetCount("loot:1429", 6303), 2, "Menge je Zone")
    eq(DB.ns:GetCount("looted", 1429), 1, "Fenster je Zone")
    eq(DB.data.zones["cast/0/1429"], 1, "Wurf mit Zone")

    events.UNIT_SPELLCAST_SUCCEEDED("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", 7620)
    loot.fishing = false
    events.LOOT_OPENED("LOOT_OPENED")
    eq(DB.ns:GetCount("catch"), 0 + 1, "anderes Beutefenster zählt nicht")

    -- Abbruch durch Bewegung: zählt als castabort, nicht als Wurf ohne Fang
    local waiting, speed, falling = {}, 0, false
    P.recordApi.After = function(_, func) waiting[#waiting + 1] = func end
    P.recordApi.GetUnitSpeed = function() return speed end
    P.recordApi.IsFalling = function() return falling end
    local function stop(spell) events.UNIT_SPELLCAST_CHANNEL_STOP("UNIT_SPELLCAST_CHANNEL_STOP", "player", "guid", spell or 7620) end
    local function flush() local list = waiting waiting = {} for _, func in ipairs(list) do func() end end

    events.UNIT_SPELLCAST_SUCCEEDED("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", 7620)
    stop(); flush()
    eq(DB.ns:GetCount("castabort"), 0, "stehend: Ende des Kanals ist kein Abbruch")

    speed = 7
    stop(133); flush()
    eq(DB.ns:GetCount("castabort"), 0, "anderer Zauber")
    stop(); flush()
    eq(DB.ns:GetCount("castabort"), 1, "Bewegung ohne Beutefenster")
    eq(DB.ns:GetCount("aborttier", 75), 1, "Abbruch je Stufe")
    eq(DB.data.zones["castabort/0/1429"], 1, "Abbruch mit Zone")
    stop(); flush()
    eq(DB.ns:GetCount("castabort"), 1, "ein Wurf nur einmal")

    speed = 0; falling = true
    events.UNIT_SPELLCAST_SUCCEEDED("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", 7620)
    stop(); flush()
    eq(DB.ns:GetCount("castabort"), 2, "Fallen zählt wie Bewegung")

    falling = false; speed = 7
    loot.fishing = true
    events.UNIT_SPELLCAST_SUCCEEDED("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", 7620)
    stop(); events.LOOT_OPENED("LOOT_OPENED"); flush()
    eq(DB.ns:GetCount("castabort"), 2, "Beutefenster nach dem Ende: Fang, kein Abbruch")

    events.UNIT_SPELLCAST_SUCCEEDED("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", 7620)
    stop()
    events.UNIT_SPELLCAST_SUCCEEDED("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", 7620)
    flush()
    eq(DB.ns:GetCount("castabort"), 2, "neuer Wurf vor Ablauf der Wartezeit")
    _G.GlimpseDB, Glimpse.IDs = nil, nil
end)

test("Professions: Schwimmer: Zähler aus Glimpse: Database, nur dieser Charakter", function()
    local e = setup()
    local P = e.P
    P.api.UnitChannelInfo = function() return "Angeln" end
    local function bobber() return text(P:ObjectLines({ name = "Schwimmer" })) end
    eq(#bobber(), 1, "ohne Database nur die Fertigkeit")
    eq(P:BuildOptions().fishing.args.statAddon.hidden(), true, "Rahmen fehlt ohne Database")

    local DB = FakeDatabase()
    _G.GlimpseDB = DB
    DB:Register("fishing", {})
    eq(#bobber(), 1, "nichts gezählt: keine Zeilen")
    for _ = 1, 60 do DB.ns:Count("casttier", 75) end
    for _ = 1, 12 do DB.ns:Count("casttier", 150) end
    for _ = 1, 40 do DB.ns:Count("catchtier", 75) end
    for _ = 1, 12 do DB.ns:Count("catchtier", 150) end
    DB.ns:Count("cast", 0, nil, 72)
    DB.ns:Count("catch", 0, nil, 52)
    DB.ns:Count("fish", 6303, nil, 52)
    DB.ns:Count("castabort", 0, nil, 4)   -- 4 Abbrüche durch Bewegung: 68 gültige Würfe
    for _ = 1, 4 do DB.ns:Count("aborttier", 75) end

    local lines = bobber()
    eq(lines[2], "---", "Trennlinie")
    eq(lines[3], "|cffffd100Glimpse counters|r", "Überschrift")
    eq(lines[4], "|cff999999Recorded since " .. os.date("%d/%m/%Y", 1767225600) .. "|r", "seit wann")
    eq(lines[5], "   Casts: |cffffffff72|r  |cff66ccfftoday 72 · 7 days 72|r", "Würfe mit heute und 7 Tagen, eingerückt")
    eq(lines[6], "   Catches: |cffffffff52|r  |cff66ccfftoday 52 · 7 days 52|r", "Fänge")
    eq(lines[7], "   Casts without catch: |cffffffff16|r", "ohne Fang, Abbrüche zählen nicht")
    eq(lines[8], "   Catch rate: |cffffffff76 %|r", "Quote gesamt ohne Abbrüche")
    eq(lines[9]:find("Catch rate .-: |cffffffff71 %%|r  |cff999999%(40/56%)|r") ~= nil, true, "Quote je Stufe ohne Abbrüche")
    eq(lines[11]:find("Fish caught", 1, true) ~= nil, true, "Fische")
    eq(#lines, 11, "Zeilen")
    local spell = text(P:SpellLines({ id = 7620 }))
    eq(table.concat(spell, "\n"):find("Catch rate: |cffffffff76 %|r", 1, true) ~= nil, true, "auch im Tooltip des Zaubers")

    eq(P:BuildOptions().fishing.args.statAddon.hidden(), false, "Rahmen da")
    P:SetOpt("fishing", "own", false)
    eq(#bobber(), 1, "ausgeschaltet")
    _G.GlimpseDB = nil
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
    local args = P:BuildOptions().fishing.args
    args.doubleClickModifier.set(nil, "CTRL")
    eq(P:CastModifier(), "CTRL", "Auswahl des Cores schreibt castKey")
    args.doubleClickButton.set(nil, "Button4")
    eq(P:CastButton(), "Button4", "Maustaste")
    P.account.fishing.castButton = "x"
    eq(P:CastButton(), "RightButton", "ungültig: Rechtsklick")
    P.account.fishing.cast = false
    eq(args.doubleClickModifier.disabled(), true, "Kürzel aus: Auswahl grau")
    P.account.fishing.cast, P.account.fishing.castKey = true, "SHIFT"
    eq(P:CastShortcutText(), "SHIFT + Double right click", "Tooltip: Taste und Rechtsklick")

    -- ohne Taste: nur der doppelte Rechtsklick
    P.account.fishing.castKey = "NONE"
    eq(P:CastModifier(), "NONE", "keine Taste wählbar")
    eq(P:CastShortcutText(), "Double right click", "Tooltip ohne Taste")
    P.account.fishing.castKey = "SHIFT"
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
    eq(args.cast.hidden(), false, "Option sichtbar"); eq(args.doubleClickModifier.hidden(), false, "Taste sichtbar")

    loaded.FishingBuddy = true
    eq(P:CastBlockedBy(), "FishingBuddy", "erkannt"); eq(P:CastEnabled(), false, "aus")
    eq(joined():find("Double right click", 1, true), nil, "kein Kürzel im Tooltip")
    eq(joined():find("Fishing skill", 1, true) ~= nil, true, "der Rest des Tooltips bleibt")
    eq(args.cast.hidden(), true, "Schalter versteckt"); eq(args.doubleClickModifier.hidden(), true, "Taste versteckt")
    eq(args.doubleClickButton.hidden(), true, "Maustaste versteckt"); eq(P:CastLines()[1]:find("FishingBuddy", 1, true) ~= nil, true, "Hinweis in /gli prof cast")

    -- Hinweis in den Optionen: nur mit Fishing Buddy, mit Version
    eq(args.castBlocked.hidden(), false, "Hinweis sichtbar")
    eq(args.castBlocked.name(), "|cffffd100Fishing Buddy|r |cff33ff33|r|cffffffffinstalled|r\n|cff999999   Casting with a shortcut and the weapon change are switched off.\n   Only the tooltip is used.|r", "ohne Version")
    P.castApi.GetAddOnMetadata = function(name, field) if name == "FishingBuddy" and field == "Version" then return "1.9.3" end end
    local name, version = P:CastBlockedByInfo()
    eq(name, "Fishing Buddy", "Name"); eq(version, "1.9.3", "Version")
    eq(args.castBlocked.name():find("|cffffd100Fishing Buddy|r |cff33ff33(v1.9.3) |r|cffffffffinstalled|r\n|cff999999", 1, true) ~= nil, true, "Name gelb, Version grün, installiert weiß, Text grau")
    eq(args.castHeader.hidden, nil, "die Überschrift bleibt sichtbar")
    eq(args.castBlocked.image(), nil, "kein Symbol, wenn das Addon keins angibt")
    P.castApi.GetAddOnMetadata = function(_name, field)
        if field == "IconTexture" then return "Interface\\Icons\\Trade_Fishing" end
        if field == "Version" then return "1.9.3" end
    end
    eq(args.castBlocked.image(), "Interface\\Icons\\Trade_Fishing", "das Symbol des Addons")
    loaded.FishingBuddy = nil
    eq(args.castBlocked.hidden(), true, "ohne Fishing Buddy kein Hinweis")

    loaded.BetterFishing = true
    eq(P:CastBlockedBy(), "BetterFishing", "Better Fishing erkannt"); eq(P:CastEnabled(), false, "aus")
    eq(select(1, P:CastBlockedByInfo()), "Better Fishing", "Anzeigename")
    eq(args.castBlocked.hidden(), false, "Hinweis sichtbar")
    loaded.BetterFishing = nil
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
    la.Good = function(msg) e.good[#e.good + 1] = msg end
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

test("Angel auswerfen: Doppelklick über den Verteiler im Core, nur im Stehen", function()
    local e = castSetup()
    local P, Glimpse = e.P, e.Glimpse
    P.RegisterEvent, P.UnregisterEvent = function() end, function() end
    P:CastEnable()
    local h = Glimpse.doubleClicks.fishing
    eq(h ~= nil, true, "angemeldet"); eq(h.when.standing, true, "nur im Stehen"); eq(h.button(), "RightButton", "Rechtsklick")
    eq(h.modifier(), "SHIFT", "Taste aus den Optionen")
    P.account.fishing.castKey = "ALT"; eq(h.modifier(), "ALT", "geänderte Taste"); P.account.fishing.castKey = "SHIFT"
    eq(h.Match(), true, "an")

    -- ohne Angel: Angel anlegen, nichts wirken
    eq(h.Prepare({}), nil, "erst die Angel"); eq(e.equips[1][1], 6256, "Angel angelegt")
    -- Angel in der Hand: Fischen
    local action = h.Prepare({})
    eq(action.type, "spell", "Zauber"); eq(action.spell, "Angeln", "Fischen")
    -- ohne Köder: Makro
    P.LureMacro = function() return "/use 0 3\n/use 16" end
    action = h.Prepare({})
    eq(action.type, "macro", "Köder"); eq(action.macrotext, "/use 0 3\n/use 16", "Makro")
    P.LureMacro = nil

    P.account.fishing.cast = false
    eq(h.Match(), false, "Schalter aus")
    P.account.fishing.cast = true
    P.castApi.IsAddOnLoaded = function(name) return name == "FishingBuddy" end
    eq(h.Match(), false, "Fishing Buddy übernimmt")
    P.castApi.IsAddOnLoaded = function() return false end

    -- zentrale Taste im Core: eigene Auswahl grau, Text vom Core
    Glimpse.doubleClickCentral = true
    local args = P:BuildOptions().fishing.args
    eq(args.doubleClickModifier.disabled(), true, "Taste grau"); eq(args.doubleClickButton.disabled(), true, "Maustaste grau")
    eq(P:CastShortcutText(), "ALT + Double right click", "Text vom Core")
    Glimpse.doubleClickCentral = false
    eq(args.doubleClickModifier.disabled(), false, "eigene Taste wieder wählbar")
    P.account.fishing.castButton = "Button4"
    eq(P:CastShortcutText(), "SHIFT + Double Button4", "eigene Maustaste im Text")

    P:CastDisable()
    eq(Glimpse.doubleClicks.fishing, nil, "abgemeldet")
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

test("Professions: Datenquellen für /gli probe db sources", function()
    local e = setup()
    local P, Glimpse = e.P, e.Glimpse
    local lines = table.concat(Glimpse.dataSources.Glimpse_Professions(), "\n")
    assert(lines:find("namespace fishing (not registered)", 1, true), "ohne Database kein Schreiber")
    assert(lines:find("read live from the client", 1, true), "Spiel-Statistik")
    assert(lines:find("Glimpse double-click", 1, true), "Auswerfen über den Core")

    P.fishingNs = {}
    P.castApi.IsAddOnLoaded = function(name) return name == "FishingBuddy" end
    lines = table.concat(P:FishingSourceLines(), "\n")
    assert(lines:find("namespace fishing (writer)", 1, true), "Schreiber")
    assert(lines:find("left to FishingBuddy", 1, true), "Fishing Buddy")
end)

test("Angeln: Verwittertes Tagebuch im Tooltip, Fischsuche wird beim Login eingeschaltet", function()
    local e = setup()
    local P, Glimpse = e.P, e.Glimpse
    local ja = P.journalApi
    local known, tracking, set = false, { { name = "Kräutersuche", active = true, spellID = 2383 }, { name = "Fischsuche", active = false, spellID = 43308 } }, {}
    ja.IsPlayerSpell = function(id) return id == 43308 and known end
    ja.GetNumTrackingTypes = function() return #tracking end
    ja.GetTrackingInfo = function(index) return tracking[index] end
    ja.SetTracking = function(index, on) set[#set + 1] = index; tracking[index].active = on end
    ja.InCombatLockdown = function() return e.combat end
    local function joined() return table.concat(text(P:SpellLines({ id = 7620 })), "\n") end

    -- Name aus den Locales, solange der Client ihn nicht kennt
    eq(joined():find("Weather-Beaten Journal: |cffff2020not learned|r", 1, true) ~= nil, true, "nicht gelernt, rot")
    eq(P:EnableFindFish(), "journal not learned", "ohne Tagebuch nichts")

    known = true
    P.journalName, P.journalRequested = nil, nil
    Glimpse.IDs = { DescribeItem = function(_, id, callback) callback("x", id == 34109 and "Verwittertes Tagebuch" or nil) end }
    eq(joined():find("Verwittertes Tagebuch: |cff20ff20learned|r", 1, true) ~= nil, true, "gelernt, grün, Name vom Client")

    -- Login: einschalten, andere Verfolgung bleibt unberührt
    P:OnSkillEvent("PLAYER_ENTERING_WORLD")
    eq(set[1], 2, "Fischsuche eingeschaltet"); eq(#set, 1, "nur sie"); eq(tracking[1].active, true, "Kräutersuche bleibt")
    eq(Glimpse.printed[#Glimpse.printed], "Find Fish switched on.", "Meldung")
    eq(P:EnableFindFish(), "already on", "schon an")

    -- im Kampf erst danach
    tracking[2].active, e.combat = false, true
    eq(P:EnableFindFish(), "in combat, after combat", "im Kampf vorgemerkt")
    e.combat = false
    P:CastOnRegen()
    eq(tracking[2].active, true, "nach dem Kampf")

    -- ältere Clients: einzelne Werte statt Tabelle
    tracking[2].active = false
    ja.GetTrackingInfo = function(index) local t = tracking[index] return t.name, "tex", t.active, "spell", nil, t.spellID end
    eq(P:EnableFindFish(), "switched on", "auch mit einzelnen Werten")

    -- Option aus
    tracking[2].active = false
    P:SetOpt("fishing", "findFish", false)
    eq(P:EnableFindFish(), "option off", "abschaltbar"); eq(tracking[2].active, false, "bleibt aus")
    eq(P:BuildOptions().fishing.args.findFish ~= nil, true, "Schalter in den Optionen")
end)
