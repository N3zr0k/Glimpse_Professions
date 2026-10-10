-- luacheck-Konfiguration für alle Glimpse-Addons (WoW Forever, Lua 5.1-Dialekt)
std = "lua51"
max_line_length = false
codes = true
exclude_files = { "**/Libs/**", ".glimpse/**" }
ignore = {
    "212/self",   -- ungenutztes self
    "212/_.*",    -- ungenutzte Argumente mit Unterstrich
    "211/ADDON_NAME",
}

-- Globale, die die Addons selbst setzen
globals = { "Glimpse", "GlimpseDB", "GlimpseGatheringDB", "GlimpseStatisticsDB", "GlimpseProfessionsDB", "SLASH_GLIMPSE1", "StaticPopupDialogs" }

-- Blizzard-API und Mixins (nur lesen)
read_globals = {
    "LibStub", "CreateFrame", "C_Timer", "C_Item", "C_Loot", "C_AddOns", "C_ClickBindings", "C_Spell",
    "C_Container", "C_TooltipInfo", "C_ActionBar", "Enum", "TooltipDataProcessor",
    "GameTooltip", "ItemRefTooltip", "ShoppingTooltip1", "ShoppingTooltip2", "UIParent", "BackdropTemplateMixin", "Settings",
    "GetTime", "UnitGUID", "UnitName", "UnitLevel", "GetLocale", "GetAddOnMetadata", "IsAddOnLoaded",
    "IsShiftKeyDown", "IsControlKeyDown", "IsAltKeyDown", "issecretvalue", "hooksecurefunc",
    "GetProfessions", "GetProfessionInfo", "GetItemInfoInstant", "GetNumLootItems", "GetLootSlotType",
    "GetLootSlotLink", "GetLootSlotInfo", "GetLootSourceInfo", "GetBindingKey", "GetBindingText", "GetBindingAction",
    "GetActionInfo", "GetMacroInfo", "GetMacroBody", "GetShapeshiftForm", "GetBonusBarOffset",
    "GetActionBarPage", "GetOverrideBarIndex", "HasVehicleActionBar", "HasOverrideActionBar",
    "HasBonusActionBar", "GetNumShapeshiftForms", "InCombatLockdown", "GetCVar",
    "CanLootUnit", "UnitIsDead", "UnitIsTapDenied", "IsFishingLoot", "UnitGUID",
    "GetNumSkillLines", "GetSkillLineInfo", "GetWeaponEnchantInfo", "GetInventoryItemID", "UnitChannelInfo", "UnitAura", "UnitBuff", "C_UnitAuras", "TOTAL", "NONE", "GENERAL", "GetStatistic",
    "GetStatisticsCategoryList", "GetCategoryNumAchievements", "GetAchievementInfo",
    "GetBindingAction", "GetAddOnMetadata", "IsAddOnLoaded", "C_AddOns", "IsMouselooking", "MouselookStop", "IsMouseButtonDown", "InCombatLockdown", "C_Minimap", "IsPlayerSpell", "IsSpellKnown", "GetNumTrackingTypes", "GetTrackingInfo", "SetTracking", "GetInventoryItemLink", "EquipItemByName", "C_Item", "C_Container", "NUM_BAG_SLOTS",
    "GetContainerNumSlots", "GetContainerItemID", "GetContainerNumFreeSlots", "GetUnitSpeed", "IsFalling", "UnitAffectingCombat", "C_Timer",
    "IsControlKeyDown", "IsAltKeyDown", "IsShiftKeyDown", "UIErrorsFrame", "UIParent", "WorldFrame",
    "SetOverrideBindingClick", "ClearOverrideBindings", "SHIFT_KEY_TEXT", "CTRL_KEY_TEXT", "ALT_KEY_TEXT", "GetSpellInfo", "UnitCreatureType", "C_CreatureInfo",
    "tinsert", "tremove", "wipe", "format", "strsplit", "strjoin", "strmatch", "strtrim", "strlower",
    "strupper", "strfind", "gsub", "strsub", "tostringall", "date", "time", "ceil", "floor",
    "tContains", "CopyTable", "Mixin", "_G",
    "SlashCmdList", "NUM_ACTIONBAR_BUTTONS", "bit", "geterrorhandler", "issecrettable", "TooltipUtil",
    "GetBuildInfo", "GetNumAddOns", "GetAddOnInfo", "GetAddOnDependencies", "MAX_ACCOUNT_MACROS",
    "GetNumBindings", "GetBinding", "GetShapeshiftFormInfo", "GetNumMacros", "GetMacroItem",
    "GetMacroSpell", "ITEM_QUALITY_COLORS", "GetItemInfo", "GetContainerItemLink",
    -- Orte, Wegpunkte und Fehlerfenster (Modul Locations, GatheringTooltip); TomTom ist optional
    "C_Map", "C_SuperTrack", "UiMapPoint", "CreateVector2D", "IsInInstance", "GetInstanceInfo", "TomTom",
    "StaticPopup_Show", "OKAY", "UISpecialFrames", "YES", "NO",
}

