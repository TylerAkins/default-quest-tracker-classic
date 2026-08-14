local ADDON_NAME = ...
local DQTC = _G[ADDON_NAME]

DQTC.DB_VERSION = 2

-- Compact schema documentation (runtime tables live in Database/Classic/*.lua)
-- Quests[questId] = {
--   n = "title",
--   l = questLevel,
--   rl = requiredLevel, -- min level to accept
--   f = faction, -- 0 both, 1 alliance, 2 horde
--   r = requiredRaces bitmask (optional; 0/nil = any)
--   c = requiredClasses bitmask (optional; 0/nil = any)
--   sk = { skillLineId, minimumRank }, -- required profession/skill (optional)
--   s = { starterNpcIds... },
--   e = { enderNpcIds... },
--   o = { { t = "monster"|"object"|"item", i = id }, ... },
--   pq = { preQuestSingle ids... }, -- any one completed
--   pg = { preQuestGroup ids... }, -- all completed (if no pq)
--   ex = { exclusiveTo ids... },
--   nq = nextQuestInChain id,
-- }
-- itemDrops[itemId] = { npcId, ... }  -- NPCs that drop quest items
-- itemObjectDrops[itemId] = { objectId, ... }
-- EventQuests[questId] = { e = "Winter Veil", sd?, ed?, sh?, eh? }  -- holiday gate
-- AQWarEffortQuests[questId] = true  -- matches Questie's available-quest filter
-- SoftPrereqs[questId] = true  -- ignore preQuestSingle (server does not enforce)
-- Npcs[npcId] = { n = name, sp = { { m = uiMapId, x = 0-100, y = 0-100 }, ... } }
-- Objects[objectId] = { n = name, sp = { ... } }
