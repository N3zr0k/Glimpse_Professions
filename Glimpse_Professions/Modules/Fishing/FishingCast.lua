local Glimpse = LibStub("AceAddon-3.0"):GetAddon("Glimpse")
local P = Glimpse:GetModule("Professions")
local L = P.L

-- Auswerfen per Modifier + doppeltem Rechtsklick.
--
-- GLOBAL_MOUSE_DOWN: Zweiter Rechtsklick innerhalb WINDOW bindet Rechtsklick für diesen Klick an einen Secure-Button
-- (nur so darf ein Addon zaubern) und beendet Mouselook. Der Button:
--   * ohne Angel: Waffen merken und ablegen, Angel anlegen. Geworfen wird erst beim nächsten Doppelklick.
--   * mit Angel: "Fischen" wirken.
-- Nach mehr als RADIUS Metern Bewegung kommen die Waffen zurück (im Kampf danach).
-- Zu wenig Taschenplatz für die Waffen: Meldung, kein Wechsel.

local KEY = "fishing"
local MAIN_HAND, OFF_HAND = 16, 17
local RADIUS = 5 -- Meter
local TICK = 0.2 -- Sekunden je Bewegungsprüfung
local WINDOW = 0.4 -- Sekunden für den zweiten Klick
local BUTTON_NAME = "GlimpseProfessionsCastButton"
local MODIFIERS = { SHIFT = true, CTRL = true, ALT = true, NONE = true } -- NONE = Doppelklick ohne Modifier
-- Übernehmen Auswerfen und Waffenwechsel selbst, dann bleibt hier nur der Tooltip
local EXTERNAL = { "FishingBuddy" }
local DISPLAY = { FishingBuddy = "Fishing Buddy" }

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
    IsModifierDown = function(modifier)
        if modifier == "CTRL" then return IsControlKeyDown() end
        if modifier == "ALT" then return IsAltKeyDown() end
        if modifier == "NONE" then return not (IsShiftKeyDown() or IsControlKeyDown() or IsAltKeyDown()) end
        return IsShiftKeyDown()
    end,
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

--- "SHIFT-BUTTON2" bzw. "BUTTON2"
function P:CastBindingKey()
    local modifier = self:CastModifier()
    return modifier == "NONE" and "BUTTON2" or (modifier .. "-BUTTON2")
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

local button -- Secure-Button
-- Hängendes Mouselook beenden, außer eine Maustaste ist noch gedrückt (force ignoriert das)
local function StopMouselook(force)
    if force ~= true and IsMouseButtonDown and (IsMouseButtonDown("LeftButton") or IsMouseButtonDown("RightButton")) then return end
    if IsMouselooking and IsMouselooking() and MouselookStop then MouselookStop() end
end

local swapAt -- GetTime() des letzten Waffenwechsels
local armed = 0 -- damit ein alter Timer keine neuere Belegung löscht

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
    local bound = GetBindingAction and GetBindingAction(self:CastBindingKey()) or "?"
    local blocked = self:CastBlockedBy()
    if blocked then lines[#lines + 1] = "cast shortcut off: " .. blocked .. " is loaded and handles casting and weapon changes" end
    lines[#lines + 1] = format("cast shortcut: %s, key %s, hooked %s, button %s, binding now: %s", tostring(self:CastEnabled()),
        self:CastModifier(), tostring(self.castHooked), tostring(button ~= nil), tostring(bound))
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


--- Secure-Button für "Fischen", Attribute nur außerhalb des Kampfes
local function EnsureButton(self)
    if button or not CreateFrame then return button end
    button = CreateFrame("Button", BUTTON_NAME, UIParent, "SecureActionButtonTemplate")
    -- je nach CVar "Aktionstasten beim Drücken auslösen" zaubert der Client bei Down oder Up
    button:RegisterForClicks("AnyDown", "AnyUp")
    button:SetAttribute("type", "spell")

    button:SetScript("PreClick", function(_, mouseButton, down)
        if api.InCombatLockdown() then Log("click on the button in combat") return end
        local name = P.SpellName(P:GetProfession(KEY).reference)
        if name then button:SetAttribute("spell", name) end
        -- Down und Up kommen beide an, nach einem Wechsel nicht gleich nochmal wechseln
        local now = GetTime and GetTime() or 0
        local ready, lureMacro = false, nil
        if swapAt and now - swapAt < 0.6 then
            Log(format("button clicked (%s, down=%s): same click, no cast", tostring(mouseButton), tostring(down)))
        else
            ready = P:PreparePole()
            -- ohne Köder: dieser Klick ködert, der nächste wirft
            lureMacro = ready and P.LureMacro and P:LureMacro() or nil
            if lureMacro then ready = false Log("applying lure: " .. lureMacro:gsub("\n", " | ")) end
            if not ready then swapAt = now end
            Log(format("button clicked (%s, down=%s): spell %s, pole ready %s -> %s", tostring(mouseButton), tostring(down),
                tostring(name), tostring(ready), ready and "cast" or "no cast"))
        end
        if lureMacro then
            button:SetAttribute("macrotext", lureMacro)
            button:SetAttribute("type", "macro")
        else
            button:SetAttribute("type", ready and "spell" or nil)
        end
    end)
    button:SetScript("PostClick", function(_, _, down)
        if down then return end
        -- Up kam beim Spiel nicht an, Mouselook würde hängen bleiben
        StopMouselook()
        if api.After then api.After(0.1, StopMouselook) end
        if api.InCombatLockdown() then return end
        ClearOverrideBindings(button)
    end)
    return button
end

local DOUBLE_MIN = 0.03 -- Sekunden, schneller = Prellen
local lastPress

--- GLOBAL_MOUSE_DOWN: Erst der zweite Klick wird gebunden, der erste bleibt normal beim Spiel (Kamera, Auswahl).
function P:CastOnMouseDown(_, mouseButton)
    if mouseButton ~= "RightButton" or not self:CastEnabled() then return end
    if api.InCombatLockdown() or not api.IsModifierDown(self:CastModifier()) then lastPress = nil return end

    local now = GetTime and GetTime() or 0
    local gap = lastPress and (now - lastPress)
    if not gap or gap <= DOUBLE_MIN or gap >= WINDOW then
        lastPress = now
        return
    end
    lastPress = nil

    local frame = EnsureButton(self)
    if not frame then return end
    SetOverrideBindingClick(frame, true, self:CastBindingKey(), BUTTON_NAME)
    Log("double right click: binding set")
    -- Up gehört jetzt dem Button, Mouselook muss hier enden
    StopMouselook(true)
    armed = armed + 1
    local mine = armed
    if api.After then
        api.After(WINDOW, function()
            if armed == mine and not api.InCombatLockdown() then ClearOverrideBindings(frame) end
        end)
    end
end

function P:CastEnable()
    self:RegisterEvent("GLOBAL_MOUSE_DOWN", "CastOnMouseDown")
    self.castHooked = true
    self:RegisterEvent("PLAYER_REGEN_ENABLED", "CastOnRegen")
    self:RegisterEvent("UNIT_SPELLCAST_SENT", "CastOnSpell")
    self:RegisterEvent("UNIT_SPELLCAST_FAILED", "CastOnSpell")
    self:RegisterEvent("UI_ERROR_MESSAGE", "CastOnSpell")
    self:CastResume()
end

function P:CastDisable()
    self:UnregisterEvent("GLOBAL_MOUSE_DOWN")
    self.castHooked = nil
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
    -- im Kampf nicht löschbare Belegung nachholen
    if button and ClearOverrideBindings then ClearOverrideBindings(button) end
    if self.restorePending then self:RestoreWeapons() end
end

--- "Umschalt + Doppelter Rechtsklick" bzw. "Doppelter Rechtsklick"
function P:CastShortcutText()
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
