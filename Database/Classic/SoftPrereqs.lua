-- Quests whose preQuestSingle is NOT server-enforced (optional breadcrumbs).
-- Riverpaw Gnoll Bounty (11) is NOT listed — Westbrook Garrison (239) is required.
local ADDON_NAME = ...
local DQTC = _G[ADDON_NAME]
DQTC.Data = DQTC.Data or {}
DQTC.Data.softPrereqs = {
    [353] = true, -- Stormpike's Delivery: Elmore's Task (1097) is optional
}
