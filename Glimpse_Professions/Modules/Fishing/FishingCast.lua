local Glimpse = LibStub("AceAddon-3.0"):GetAddon("Glimpse")
local P = Glimpse:GetModule("Professions")
local L = P.L

-- Auswerfen per Modifier + doppeltem Rechtsklick über den Doppelklick-Verteiler des Cores (Glimpse:RegisterDoubleClick).
-- Erkennung, Secure-Button und Kampfsperre liegen im Core; hier nur, was der Klick tut:
--   * ohne Angel: Waffen merken und ablegen, Angel anlegen. Geworfen wird erst beim nächsten Doppelklick.
--   * Angel ohne Köder (Option): bester Köder aus dem Rucksack, der nächste Doppelklick wirft.
--   * mit Angel: "Fischen" wirken.
-- Nur im Stehen (when.standing). Nach mehr als RADIUS Metern Bewegung kommen die Waffen zurück (im Kampf danach).
-- Zu wenig Taschenplatz für die Waffen: Meldung, kein Wechsel.
-- Fishing Buddy oder Better Fishing geladen: alles aus, nur der Tooltip bleibt.

local KEY = "fishing"
local MAIN_HAND, OFF_HAND = 16, 17
local RADIUS = 5 -- Meter
local TICK = 0.2 -- Sekunden je Bewegungsprüfung
local MODIFIERS = { SHIFT = true, CTRL = true, ALT = true, NONE = true } -- NONE = Doppelklick ohne Modifier
local BUTTONS = { RightButton = true, LeftButton = true, MiddleButton = true, Button4 = true, Button5 = true }
-- Übernehmen Auswerfen und Waffenwechsel selbst, dann bleibt hier nur der Tooltip
local EXTERNAL = { "FishingBuddy", "BetterFishing" }
local DISPLAY = { FishingBuddy = "Fishing Buddy", BetterFishing = "Better Fishing" }

-- Blizzard-API gebündelt, damit Tests sie ersetzen können
local bag = C_Container or {}
P.castApi = {
    InCombatLockdown = InCombatLockdown,
    GetInventoryItemLink = GetInventoryItemLink,
    EquipItemByName = (C_Item and C_Item.EquipItemByName) or EquipItemByName,
    NumBags = NUM_BAG_SLOTS or 4,
    GetContainerNumSlots = bag.GetContainerNumSlots or GetContainerNumSlots,
    GetContainerItemID = bag.GetContainerItemID or GetContainerItemID,
    GetContainerNumFreeSlots = bag.GetContainerNumFreeSlots or GetContainerNumFreeSlots,
    GetUnitSpeed = GetUnitSpeed,
    IsAddOnLoaded = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded,
    GetAddOnMetadata = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata,
    NewTicker = C_Timer and C_Timer.NewTicker,
    After = C_Timer and C_Timer.After,
    Notice = function(text)
        if UIErrorsFrame then UIErrorsFrame:AddMessage(text, 0.1, 1, 0.1, 1) end
    end,
    Alert = function(text)
        if UIErrorsFrame then UIErrorsFrame:AddMessage(text, 1, 0.2, 0.2, 1) end
        Glimpse:Print(text)
    end,
}
local api = P.castApi

--- "SHIFT", "CTRL", "ALT" oder "NONE"
function P:CastModifier()
    local value = self:Opt(KEY, "castKey")
    return MODIFIERS[value] and value or "SHIFT"
end

--- Maustaste für den Doppelklick, Standard RightButton
function P:CastButton()
    local value = self:Opt(KEY, "castButton")
    return BUTTONS[value] and value or "RightButton"
end

--- lokalisierter Tastenname
function P:CastModifierName(modifier)
    modifier = modifier or self:CastModifier()
    local names = { SHIFT = SHIFT_KEY_TEXT, CTRL = CTRL_KEY_TEXT, ALT = ALT_KEY_TEXT, NONE = P.ClientText("NONE", "None") }
    return names[modifier] or modifier
end

--- Addon aus EXTERNAL, das geladen ist, sonst nil. Jedes Mal prüfen, die Ladereihenfolge ist beliebig.
function P:CastBlockedBy()
    if not api.IsAddOnLoaded then return nil end
    for _, name in ipairs(EXTERNAL) do
        local ok, loaded = pcall(api.IsAddOnLoaded, name)
        if ok and (loaded == true or loaded == 1) then return name end
    end
end

--- name, version, icon für den Optionen-Hinweis
function P:CastBlockedByInfo()
    local name = self:CastBlockedBy()
    if not name then return nil end
    -- aus der TOC des fremden Addons
    local function Field(field)
        if not api.GetAddOnMetadata then return nil end
        local ok, value = pcall(api.GetAddOnMetadata, name, field)
        if ok and type(value) == "string" and value ~= "" then return value end
    end
    return DISPLAY[name] or name, Field("Version"), Field("IconTexture")
end

--- false schaltet Button, Waffenwechsel und Anzeige komplett ab
function P:CastEnabled()
    return self:Opt(KEY, "cast") == true and not self:CastBlockedBy()
end

--- bag, slot, itemID der ersten Angel oder nil
function P:FindPoleInBags()
    if not (api.GetContainerNumSlots and api.GetContainerItemID) then return nil end
    for container = 0, api.NumBags do
        for slot = 1, tonumber(api.GetContainerNumSlots(container)) or 0 do
            local id = api.GetContainerItemID(container, slot)
            if id and self:IsPoleItem(id) then return container, slot, id end
        end
    end
end

--- Spezialtaschen zählen nicht
function P:FreeBagSlots()
    if not api.GetContainerNumFreeSlots then return 0 end
    local free = 0
    for container = 0, api.NumBags do
        local count, family = api.GetContainerNumFreeSlots(container)
        if (family or 0) == 0 then free = free + (tonumber(count) or 0) end
    end
    return free
end

--- Nebenhand braucht immer einen Platz, Waffenhand nur, wenn die Angel nicht aus dem Rucksack kommt
function P:SlotsNeeded(poleInBags)
    local needed = 0
    if api.GetInventoryItemLink("player", OFF_HAND) then needed = needed + 1 end
    if api.GetInventoryItemLink("player", MAIN_HAND) and not poleInBags then needed = needed + 1 end
    return needed
end

-- Ringpuffer für /gli prof cast
local LOG_MAX = 25
P.castLog = {}
local function Log(text)
    local log = P.castLog
    log[#log + 1] = format("%.1f %s", GetTime and GetTime() or 0, text)
    if #log > LOG_MAX then table.remove(log, 1) end
end

function P:CastLines()
    local lines = {}
    local blocked = self:CastBlockedBy()
    if blocked then lines[#lines + 1] = "cast shortcut off: " .. blocked .. " is loaded and handles casting and weapon changes" end
    lines[#lines + 1] = format("cast shortcut: %s, key %s, registered with Glimpse %s", tostring(self:CastEnabled()),
        self:CastShortcutText(), tostring(self.castRegistered == true))
    local state = self:CastDebugState()
    lines[#lines + 1] = format("pole equipped %s, saved weapons %s, moved %.1f m", tostring(self:IsPoleEquipped()),
        tostring(state.saved ~= nil), state.moved)
    if #self.castLog == 0 then lines[#lines + 1] = "log empty (no click seen yet)" end
    for _, line in ipairs(self.castLog) do lines[#lines + 1] = line end
    return lines
end

-- je Charakter, übersteht /reload: { [16] = Link, [17] = Link }
local function Saved(self) return self.char and self.char.fishingSaved end

--- Meter seit dem Auswerfen, aus der Geschwindigkeit integriert (funktioniert auch in Instanzen)
local moved = 0

local ticker
local function StopWatching()
    if ticker then ticker:Cancel() ticker = nil end
end

--- im Kampf erst nach Kampfende
function P:RestoreWeapons()
    local saved = Saved(self)
    if not saved then StopWatching() return end
    if api.InCombatLockdown() then self.restorePending = true return end

    self.restorePending = nil
    -- Waffenhand zuerst, sonst nimmt eine Zweihandwaffe die Nebenhand wieder mit
    for _, slot in ipairs({ MAIN_HAND, OFF_HAND }) do
        if saved[slot] then api.EquipItemByName(saved[slot], slot) end
    end
    self.char.fishingSaved = nil
    moved = 0
    StopWatching()
end

local function Watch(self)
    if ticker or not api.NewTicker then return end
    ticker = api.NewTicker(TICK, function()
        if not Saved(self) then StopWatching() return end
        local speed = api.GetUnitSpeed and tonumber((api.GetUnitSpeed("player"))) or 0
        moved = moved + (speed > 0 and speed * TICK or 0)
        if moved > RADIUS then self:RestoreWeapons() end
    end)
end

--- true, wenn die Angel schon in der Hand ist
function P:PreparePole()
    if self:IsPoleEquipped() then
        moved = 0
        return true
    end
    if api.InCombatLockdown() then
        api.Alert(L["You cannot change your weapons in combat."])
        return false
    end

    local container, _, poleID = self:FindPoleInBags()
    if not container then
        api.Alert(L["No fishing pole found in your bags."])
        return false
    end
    local needed, free = self:SlotsNeeded(true), self:FreeBagSlots()
    if free < needed then
        api.Alert(format(L["Not enough bag space to put away your weapons. Additional space needed: %d."], needed - free))
        return false
    end

    -- Bereits Gemerktes nicht überschreiben, das sind die Originalwaffen
    if not Saved(self) and self.char then
        self.char.fishingSaved = {
            [MAIN_HAND] = api.GetInventoryItemLink("player", MAIN_HAND),
            [OFF_HAND] = api.GetInventoryItemLink("player", OFF_HAND),
        }
    end
    moved = 0
    api.EquipItemByName(poleID)
    Watch(self)
    api.Notice(L["Fishing rod equipped. Double right click again to cast."])
    return false
end

--- Nach Login/Reload Bewegung weiter prüfen, wenn noch Waffen gemerkt sind
function P:CastResume()
    if Saved(self) then Watch(self) end
end

--- Prepare des Doppelklick-Handlers: Aktion für den Secure-Button des Cores oder nil
function P:CastPrepare()
    local name = P.SpellName(self:GetProfession(KEY).reference)
    local ready = self:PreparePole()
    -- ohne Köder: dieser Klick ködert, der nächste wirft
    local lureMacro = ready and self.LureMacro and self:LureMacro() or nil
    if lureMacro then
        Log("applying lure: " .. lureMacro:gsub("\n", " | "))
        return { type = "macro", macrotext = lureMacro }
    end
    Log(format("double click: spell %s, pole ready %s -> %s", tostring(name), tostring(ready), (ready and name) and "cast" or "no cast"))
    if ready and name then return { type = "spell", spell = name } end
end

local handler = {
    title = "Professions: " .. L["Fishing"],
    modifier = function() return P:CastModifier() end,
    button = function() return P:CastButton() end,
    priority = 10,
    when = { standing = true },
    -- Schalter und Fishing Buddy erst beim Klick prüfen, die Ladereihenfolge ist beliebig
    Match = function() return P:CastEnabled() end,
    Prepare = function() return P:CastPrepare() end,
}

function P:CastEnable()
    if Glimpse.RegisterDoubleClick then
        Glimpse:RegisterDoubleClick(KEY, handler)
        self.castRegistered = true
    end
    self:RegisterEvent("PLAYER_REGEN_ENABLED", "CastOnRegen")
    self:RegisterEvent("UNIT_SPELLCAST_SENT", "CastOnSpell")
    self:RegisterEvent("UNIT_SPELLCAST_FAILED", "CastOnSpell")
    self:RegisterEvent("UI_ERROR_MESSAGE", "CastOnSpell")
    self:CastResume()
end

function P:CastDisable()
    if self.castRegistered and Glimpse.UnregisterDoubleClick then Glimpse:UnregisterDoubleClick(KEY) end
    self.castRegistered = nil
    self:UnregisterEvent("PLAYER_REGEN_ENABLED")
    self:UnregisterEvent("UNIT_SPELLCAST_SENT")
    self:UnregisterEvent("UNIT_SPELLCAST_FAILED")
    self:UnregisterEvent("UI_ERROR_MESSAGE")
    StopWatching()
end

--- Wurfergebnis ins Log, Zauber nur solange der Button scharf war
function P:CastOnSpell(event, a, b, c, d)
    if #self.castLog == 0 then return end
    if event == "UI_ERROR_MESSAGE" then
        Log(format("error message: %s", tostring(b)))
    elseif a == "player" then
        Log(format("%s spell %s", event, tostring(d or c or b)))
    end
end

function P:CastOnRegen()
    if self.restorePending then self:RestoreWeapons() end
    if self.findFishPending and self.EnableFindFish then self:EnableFindFish() end
end

--- "Umschalt + Doppelter Rechtsklick" bzw. "Doppelter Rechtsklick", bei zentraler Taste die des Cores
function P:CastShortcutText()
    if self.castRegistered and Glimpse.GetDoubleClickText then return Glimpse:GetDoubleClickText(KEY) end
    if self:CastModifier() == "NONE" then return L["Double right click"] end
    return format("%s + %s", self:CastModifierName(), L["Double right click"])
end

-- Blizzard-Blau für Tasten in Tooltips
local KEY_COLOR = "|cff42b1fe"

--- Satz mit dem Kürzel in KEY_COLOR
function P:CastShortcutLines()
    return { KEY_COLOR .. format(L["%s to cast the fishing rod"], self:CastShortcutText()) .. "|r" }
end

-- für Tests und /gli prof probe
function P:CastDebugState()
    return { saved = Saved(self), moved = moved, watching = ticker ~= nil, pending = self.restorePending }
end
