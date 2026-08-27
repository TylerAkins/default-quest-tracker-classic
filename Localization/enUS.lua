local ADDON_NAME = ...

_G[ADDON_NAME] = _G[ADDON_NAME] or {}
local DQTC = _G[ADDON_NAME]
DQTC.name = ADDON_NAME
DQTC.version = "1.1.0"

local L = {}
DQTC.L = L

L["ADDON_NAME"] = "Default Quest Tracker"
L["OBJECTIVES"] = "Quests" -- legacy key
L["QUESTS"] = "Quests"
L["SHOW_QUEST_LEVEL"] = "Show quest levels"
L["TRACKER_LOCKED"] = "Tracker position locked"
L["TRACKER_UNLOCKED"] = "Tracker position unlocked — drag to move"
L["LOCK_TRACKER"] = "Lock tracker position"
L["UNLOCK_TRACKER"] = "Unlock tracker position"
L["RESET_POSITION"] = "Reset tracker position"
L["SEND_TO_GPS"] = "Send to GPS"
L["GPS_MISSING"] = "No GPS addon detected. Install TomTom or Zygor Guides to use this feature."
L["GPS_CLICK_HINT"] = "Right-click: Send to GPS (TomTom / Zygor)"
-- Legacy keys (kept so older refs still resolve)
L["SEND_TO_TOMTOM"] = L["SEND_TO_GPS"]
L["TOMTOM_MISSING"] = L["GPS_MISSING"]

L["COPY_WOWHEAD"] = "Copy Wowhead URL"
L["COPY_WOWHEAD_HINT"] = "Press Ctrl+C to copy the Wowhead link."
L["WOWHEAD_COPIED"] = "Copied URL to clipboard"
L["UNTRACK"] = "Untrack"
L["SHOW_IN_QUEST_LOG"] = "Show in Quest Log"
L["FOCUS_QUEST"] = "Focus quest"
L["UNFOCUS_QUEST"] = "Clear focus"
L["OPTIONS_TITLE"] = "Default Quest Tracker"
L["ENABLE_TRACKER"] = "Enable tracker"
L["HIDE_DURING_COMBAT"] = "Hide tracker during combat"
L["AUTO_TRACK"] = "Auto-track quests"
L["SHOW_MARKERS"] = "Show quest markers"
L["SHOW_AVAILABLE"] = "Show available quest givers"
L["HIDE_AQ_WAR_EFFORT"] = "Hide AQ War Effort Quests"
L["SHOW_OBJECTIVES"] = "Show numbered objective areas"
L["SHOW_TURNINS"] = "Show numbered turn-in areas"
L["SHOW_AREA_HIGHLIGHTS"] = "Highlight objective areas on the world map"
L["SHOW_TRIVIAL"] = "Show trivial (grey) quests"
L["SHOW_WORLDMAP"] = "Show on world map"
L["SHOW_MINIMAP"] = "Show on minimap"
L["SHOW_NAMEPLATES"] = "Show nameplate icons"
L["SHOW_UNIT_TOOLTIPS"] = "Show quest info on NPC/mob tooltips"
L["HIDE_COMPLETED"] = "Hide completed objectives"
L["SUPPRESS_IF_QUESTIE"] = "Suppress map/nameplate markers if Questie is loaded"
L["OPEN_OPTIONS"] = "Open options"
