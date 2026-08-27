local ADDON_NAME = ...
local DQTC = _G[ADDON_NAME]
local Loader = DQTC.Loader

local DB = Loader:CreateModule("DB")

-- Populated by Database/Classic/*.lua into DQTC.Data
DQTC.Data = DQTC.Data or {
    quests = {},
    npcs = {},
    objects = {},
    areaToUiMap = {},
    itemDrops = {},
    itemObjectDrops = {},
}

function DB:GetQuest(questId)
    local quests = DQTC.Data and DQTC.Data.quests
    return quests and quests[questId] or nil
end

function DB:GetNpc(npcId)
    local npcs = DQTC.Data and DQTC.Data.npcs
    return npcs and npcs[npcId] or nil
end

function DB:GetObject(objectId)
    local objects = DQTC.Data and DQTC.Data.objects
    return objects and objects[objectId] or nil
end

function DB:GetItemDropNpcIds(itemId)
    local drops = DQTC.Data and DQTC.Data.itemDrops
    return drops and drops[itemId] or {}
end

function DB:GetItemDropObjectIds(itemId)
    local drops = DQTC.Data and DQTC.Data.itemObjectDrops
    return drops and drops[itemId] or {}
end

function DB:AreaToUiMap(areaId)
    if not areaId then
        return nil
    end
    local mapped = DQTC.Data.areaToUiMap and DQTC.Data.areaToUiMap[areaId]
    if mapped then
        return mapped
    end
    -- Already a Classic Era uiMapId (14xx) or known starting-area map
    if areaId >= 1400 and areaId < 1500 then
        return areaId
    end
    if areaId >= 425 and areaId <= 469 then
        return areaId
    end
    return areaId
end

local function NormalizeSpawns(spawns)
    -- spawns may be {[areaId] = {{x,y},...}} or already {{m=,x=,y=},...}
    if not spawns then
        return {}
    end
    if spawns[1] and spawns[1].m then
        return spawns
    end
    local out = {}
    for areaId, coords in pairs(spawns) do
        if type(coords) == "table" then
            local uiMapId = DB:AreaToUiMap(areaId)
            for _, pair in ipairs(coords) do
                if type(pair) == "table" and pair[1] and pair[2] then
                    out[#out + 1] = { m = uiMapId, x = pair[1], y = pair[2] }
                end
            end
        end
    end
    return out
end

function DB:GetNpcSpawns(npcId)
    local npc = self:GetNpc(npcId)
    if not npc then
        return {}
    end
    if npc._sp then
        return npc._sp
    end
    npc._sp = NormalizeSpawns(npc.sp)
    return npc._sp
end

function DB:GetObjectSpawns(objectId)
    local obj = self:GetObject(objectId)
    if not obj then
        return {}
    end
    if obj._sp then
        return obj._sp
    end
    obj._sp = NormalizeSpawns(obj.sp)
    return obj._sp
end

function DB:GetFaction()
    local faction = UnitFactionGroup("player")
    if faction == "Alliance" then
        return 1
    end
    if faction == "Horde" then
        return 2
    end
    return 0
end

function DB:QuestMatchesFaction(quest)
    if not quest then
        return false
    end
    local f = quest.f or 0
    if f == 0 then
        return true
    end
    return f == self:GetFaction()
end

function DB:GetStarterNpcIds(questId)
    local q = self:GetQuest(questId)
    return q and q.s or {}
end

function DB:GetEnderNpcIds(questId)
    local q = self:GetQuest(questId)
    return q and q.e or {}
end

function DB:GetObjectiveTargets(questId)
    local q = self:GetQuest(questId)
    return q and q.o or {}
end

function DB:GetObjectiveSpawns(questId)
    local results = {}
    for _, obj in ipairs(self:GetObjectiveTargets(questId)) do
        if obj.t == "monster" then
            for _, sp in ipairs(self:GetNpcSpawns(obj.i)) do
                results[#results + 1] = {
                    uiMapId = sp.m,
                    x = sp.x,
                    y = sp.y,
                    kind = "objective",
                    sub = "monster",
                    id = obj.i,
                    questId = questId,
                }
            end
        elseif obj.t == "object" then
            for _, sp in ipairs(self:GetObjectSpawns(obj.i)) do
                results[#results + 1] = {
                    uiMapId = sp.m,
                    x = sp.x,
                    y = sp.y,
                    kind = "objective",
                    sub = "object",
                    id = obj.i,
                    questId = questId,
                }
            end
        elseif obj.t == "item" then
            -- Cap dropper NPCs so one item objective can't zero the map via script timeout
            local maxDroppers = 25
            local n = 0
            for _, npcId in ipairs(self:GetItemDropNpcIds(obj.i)) do
                n = n + 1
                if n > maxDroppers then
                    break
                end
                for _, sp in ipairs(self:GetNpcSpawns(npcId)) do
                    results[#results + 1] = {
                        uiMapId = sp.m,
                        x = sp.x,
                        y = sp.y,
                        kind = "objective",
                        sub = "item",
                        id = npcId,
                        itemId = obj.i,
                        questId = questId,
                    }
                end
            end
            local maxObjects = 15
            local o = 0
            for _, objectId in ipairs(self:GetItemDropObjectIds(obj.i)) do
                o = o + 1
                if o > maxObjects then
                    break
                end
                for _, sp in ipairs(self:GetObjectSpawns(objectId)) do
                    results[#results + 1] = {
                        uiMapId = sp.m,
                        x = sp.x,
                        y = sp.y,
                        kind = "objective",
                        sub = "itemObject",
                        id = objectId,
                        itemId = obj.i,
                        questId = questId,
                    }
                end
            end
        end
    end
    return results
end

function DB:GetTurninSpawns(questId)
    local results = {}
    for _, npcId in ipairs(self:GetEnderNpcIds(questId)) do
        for _, sp in ipairs(self:GetNpcSpawns(npcId)) do
            results[#results + 1] = {
                uiMapId = sp.m,
                x = sp.x,
                y = sp.y,
                kind = "turnin",
                id = npcId,
                questId = questId,
            }
        end
    end
    return results
end

function DB:GetAvailableSpawns(playerLevel, uiMapId)
    local results = {}
    local faction = self:GetFaction()
    local ZoneMap = Loader:ImportModule("ZoneMap")
    local QuestAvailability = Loader:ImportModule("QuestAvailability")
    QuestAvailability:EnsureBuilt()
    playerLevel = playerLevel or UnitLevel("player") or 1
    local showTrivial = DQTC.Config:Get("showTrivial")

    -- Iterate only the precomputed offerable set (not every quest in the DB)
    for questId in pairs(QuestAvailability:GetOfferableSet()) do
        local q = DQTC.Data.quests[questId]
        if q then
            local f = q.f or 0
            if f == 0 or f == faction then
                local level = q.l or 1
                local tooHigh = level > playerLevel + 3
                local tooLow = (not showTrivial) and level < playerLevel - 7
                if not tooHigh and not tooLow then
                    for _, npcId in ipairs(q.s or {}) do
                        for _, sp in ipairs(self:GetNpcSpawns(npcId)) do
                            if not uiMapId or ZoneMap:IsMapRelevant(sp.m, uiMapId) then
                                results[#results + 1] = {
                                    uiMapId = sp.m,
                                    x = sp.x,
                                    y = sp.y,
                                    kind = "available",
                                    id = npcId,
                                    questId = questId,
                                    level = level,
                                }
                            end
                        end
                    end
                end
            end
        end
    end
    return results
end

function DB:GetNpcIconType(npcId)
    -- Returns available | turnin | objective | nil based on current log + DB
    local QuestLogCache = Loader:ImportModule("QuestLogCache")
    local index = self._npcIndex
    if not index then
        return nil
    end
    local entry = index[npcId]
    return entry and entry.kind or nil
end

function DB:RebuildNpcIndex()
    local QuestLogCache = Loader:ImportModule("QuestLogCache")
    local index = {}

    -- Objectives / turn-ins for quests in log
    for questId, quest in pairs(QuestLogCache:GetQuests()) do
        if quest.isComplete == 1 then
            for _, npcId in ipairs(self:GetEnderNpcIds(questId)) do
                index[npcId] = { kind = "turnin", questId = questId }
            end
        else
            for _, obj in ipairs(self:GetObjectiveTargets(questId)) do
                if obj.t == "monster" then
                    index[obj.i] = { kind = "objective", questId = questId }
                elseif obj.t == "item" then
                    for _, npcId in ipairs(self:GetItemDropNpcIds(obj.i)) do
                        index[npcId] = { kind = "objective", questId = questId }
                    end
                end
            end
            -- Do not mark enders as turnin until the quest is complete
        end
    end

    -- Available starters (not in log)
    if DQTC.Config:Get("showAvailable") then
        local playerLevel = UnitLevel("player") or 1
        local faction = self:GetFaction()
        local QuestAvailability = Loader:ImportModule("QuestAvailability")
        for questId in pairs(QuestAvailability:GetOfferableSet()) do
            local q = DQTC.Data.quests[questId]
            if q then
                local f = q.f or 0
                if f == 0 or f == faction then
                    local level = q.l or 1
                    if (DQTC.Config:Get("showTrivial") or level >= playerLevel - 7) and level <= playerLevel + 3 then
                        for _, npcId in ipairs(q.s or {}) do
                            if not index[npcId] then
                                index[npcId] = { kind = "available", questId = questId }
                            end
                        end
                    end
                end
            end
        end
    end

    self._npcIndex = index
    return index
end

-- Group nearby spawn points into numbered areas (centroid + radius in map %).
-- Points farther than `gap` map-percent from a cluster center start a new area.
function DB:ClusterSpawns(spawns, gap)
    gap = gap or 18
    local gapSq = gap * gap
    local byMap = {}
    for _, sp in ipairs(spawns or {}) do
        if sp and sp.uiMapId and sp.x ~= nil and sp.y ~= nil then
            local list = byMap[sp.uiMapId]
            if not list then
                list = {}
                byMap[sp.uiMapId] = list
            end
            list[#list + 1] = sp
        end
    end

    local clusters = {}
    for uiMapId, points in pairs(byMap) do
        local groups = {}
        for _, p in ipairs(points) do
            local best, bestD
            for _, g in ipairs(groups) do
                local dx, dy = p.x - g.cx, p.y - g.cy
                local d = dx * dx + dy * dy
                if d <= gapSq and (not bestD or d < bestD) then
                    best, bestD = g, d
                end
            end
            if best then
                best.points[#best.points + 1] = p
                local n = #best.points
                best.cx = best.cx + (p.x - best.cx) / n
                best.cy = best.cy + (p.y - best.cy) / n
            else
                groups[#groups + 1] = { cx = p.x, cy = p.y, points = { p } }
            end
        end
        for _, g in ipairs(groups) do
            local r = 0
            for _, p in ipairs(g.points) do
                local dx, dy = p.x - g.cx, p.y - g.cy
                local d = math.sqrt(dx * dx + dy * dy)
                if d > r then
                    r = d
                end
            end
            -- Padding so the blob covers the hunting ground; floor so a single NPC still glows.
            r = math.max(7, r * 1.3 + 2)
            if r > 32 then
                r = 32
            end
            local sample = g.points[1]
            clusters[#clusters + 1] = {
                uiMapId = uiMapId,
                x = g.cx,
                y = g.cy,
                radius = r,
                kind = sample.kind,
                questId = sample.questId,
                count = #g.points,
            }
        end
    end
    return clusters
end

function DB:GetBestWaypointSpawn(questId)
    local QuestLogCache = Loader:ImportModule("QuestLogCache")
    local quest = QuestLogCache:GetQuest(questId)
    local spawns
    if quest and quest.isComplete == 1 then
        spawns = self:GetTurninSpawns(questId)
    else
        spawns = self:GetObjectiveSpawns(questId)
        if not spawns[1] then
            spawns = self:GetTurninSpawns(questId)
        end
    end
    if not spawns or not spawns[1] then
        return nil
    end
    local clusters = self:ClusterSpawns(spawns)
    if not clusters[1] then
        return spawns[1]
    end
    local pmap = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    local px, py
    if pmap and C_Map.GetPlayerMapPosition then
        local pos = C_Map.GetPlayerMapPosition(pmap, "player")
        if pos then
            px, py = pos:GetXY()
            if px then
                px, py = px * 100, py * 100
            end
        end
    end
    local best, bestD
    for _, c in ipairs(clusters) do
        local d = 999999
        if px and py and pmap and c.uiMapId == pmap then
            local dx, dy = (c.x or 0) - px, (c.y or 0) - py
            d = dx * dx + dy * dy
        elseif pmap and c.uiMapId ~= pmap then
            d = 888888
        end
        if not bestD or d < bestD then
            best, bestD = c, d
        end
    end
    return best or clusters[1]
end

--- Numbers match tracker order: (1), (2), (3) …
function DB:AssignQuestNumbers(orderedIds)
    self._questNumbers = {}
    for i, questId in ipairs(orderedIds or {}) do
        if questId then
            self._questNumbers[questId] = ((i - 1) % 50) + 1
        end
    end
end

function DB:GetQuestNumber(questId)
    self._questNumbers = self._questNumbers or {}
    if questId and self._questNumbers[questId] then
        return self._questNumbers[questId]
    end
    return 1
end

function DB:GetQuestLevel(questId)
    if not questId then
        return nil
    end
    local QuestLogCache = Loader:ImportModule("QuestLogCache")
    local logged = QuestLogCache:GetQuest(questId)
    if logged and logged.level then
        return logged.level
    end
    local q = self:GetQuest(questId)
    return q and q.l or nil
end

--- Map/minimap pin tooltip text. Always includes [level] (not tied to tracker option).
function DB:FormatMapPinTooltip(questId, suffix)
    local title = self:GetQuestTitle(questId) or ("Quest " .. tostring(questId))
    local level = self:GetQuestLevel(questId)
    local text
    if level then
        text = string.format("[%d] %s", level, title)
    else
        text = title
    end
    if suffix and suffix ~= "" then
        text = text .. " " .. suffix
    end
    return text
end

function DB:GetQuestTitle(questId)
    if not questId then
        return nil
    end
    local QuestLogCache = Loader:ImportModule("QuestLogCache")
    local logged = QuestLogCache:GetQuest(questId)
    if logged and logged.title then
        return logged.title
    end
    if C_QuestLog and C_QuestLog.GetTitleForQuestID then
        local title = C_QuestLog.GetTitleForQuestID(questId)
        if title and title ~= "" then
            return title
        end
    end
    local q = self:GetQuest(questId)
    if q and q.n and q.n ~= "" then
        return q.n
    end
    if DQTC.Data.questTitles and DQTC.Data.questTitles[questId] then
        return DQTC.Data.questTitles[questId]
    end
    return "Quest " .. tostring(questId)
end

function DB:BuildNpcQuestMaps()
    if self._npcStarts then
        return
    end
    local starts, ends, objectives = {}, {}, {}
    for questId, q in pairs(DQTC.Data.quests) do
        for _, npcId in ipairs(q.s or {}) do
            starts[npcId] = starts[npcId] or {}
            starts[npcId][#starts[npcId] + 1] = questId
        end
        for _, npcId in ipairs(q.e or {}) do
            ends[npcId] = ends[npcId] or {}
            ends[npcId][#ends[npcId] + 1] = questId
        end
        for _, obj in ipairs(q.o or {}) do
            if obj.t == "monster" and obj.i then
                objectives[obj.i] = objectives[obj.i] or {}
                objectives[obj.i][#objectives[obj.i] + 1] = questId
            elseif obj.t == "item" and obj.i then
                for _, npcId in ipairs(self:GetItemDropNpcIds(obj.i)) do
                    objectives[npcId] = objectives[npcId] or {}
                    objectives[npcId][#objectives[npcId] + 1] = questId
                end
            end
        end
    end
    self._npcStarts = starts
    self._npcEnds = ends
    self._npcObjectives = objectives
end

-- True if this NPC is a kill target or item dropper for the quest.
function DB:NpcIsQuestObjective(questId, npcId)
    for _, obj in ipairs(self:GetObjectiveTargets(questId)) do
        if obj.t == "monster" and obj.i == npcId then
            return true
        end
        if obj.t == "item" then
            for _, dropNpcId in ipairs(self:GetItemDropNpcIds(obj.i)) do
                if dropNpcId == npcId then
                    return true
                end
            end
        end
    end
    return false
end

--- Item IDs from this quest that the NPC can drop.
function DB:GetQuestItemIdsForNpc(questId, npcId)
    local out = {}
    for _, obj in ipairs(self:GetObjectiveTargets(questId)) do
        if obj.t == "item" and obj.i then
            for _, dropNpcId in ipairs(self:GetItemDropNpcIds(obj.i)) do
                if dropNpcId == npcId then
                    out[#out + 1] = obj.i
                    break
                end
            end
        end
    end
    return out
end

function DB:GetItemName(itemId)
    if not itemId then
        return nil
    end
    local names = DQTC.Data and DQTC.Data.itemNames
    if names and names[itemId] and names[itemId] ~= "" then
        return names[itemId]
    end
    if C_Item and C_Item.GetItemNameByID then
        local n = C_Item.GetItemNameByID(itemId)
        if n and n ~= "" then
            return n
        end
    end
    local n = GetItemInfo(itemId)
    if n and n ~= "" then
        return n
    end
    return nil
end

-- Lines for unit tooltips: objective progress, available quests, turn-ins.
function DB:GetNpcTooltipLines(npcId)
    self:BuildNpcQuestMaps()
    local QuestLogCache = Loader:ImportModule("QuestLogCache")
    local lines = {}
    local seenText = {}

    local npc = self:GetNpc(npcId)
    local npcName = npc and npc.n

    local function AddLine(line)
        local key = (line.kind or "") .. ":" .. tostring(line.questId) .. ":" .. tostring(line.text)
        if seenText[key] then
            return
        end
        seenText[key] = true
        lines[#lines + 1] = line
    end

    -- In-log objectives for this creature (kill targets + correct item drops only)
    for questId, quest in pairs(QuestLogCache:GetQuests()) do
        local itemIds = self:GetQuestItemIdsForNpc(questId, npcId)
        if itemIds[1] then
            for _, itemId in ipairs(itemIds) do
                local itemName = self:GetItemName(itemId)
                local matched = false
                for _, obj in ipairs(quest.objectives or {}) do
                    if obj.type == "item" and obj.text then
                        if itemName and string.find(obj.text, itemName, 1, true) then
                            AddLine({
                                kind = "objective",
                                text = obj.text,
                                finished = obj.finished,
                                questId = questId,
                            })
                            matched = true
                            break
                        end
                    end
                end
                if not matched and itemName then
                    -- Item name known but log text format differed — still show the right item
                    AddLine({
                        kind = "objective",
                        text = itemName,
                        finished = false,
                        questId = questId,
                    })
                end
            end
        elseif self:NpcIsQuestObjective(questId, npcId) then
            -- Monster kill objective: match by NPC name when possible
            local matched = false
            for _, obj in ipairs(quest.objectives or {}) do
                if obj.type == "monster" and obj.text then
                    if (not npcName) or string.find(obj.text, npcName, 1, true) then
                        AddLine({
                            kind = "objective",
                            text = obj.text,
                            finished = obj.finished,
                            questId = questId,
                        })
                        matched = true
                    end
                end
            end
            if not matched then
                for _, obj in ipairs(quest.objectives or {}) do
                    if obj.type == "monster" and obj.text then
                        AddLine({
                            kind = "objective",
                            text = obj.text,
                            finished = obj.finished,
                            questId = questId,
                        })
                        break
                    end
                end
            end
        end
    end

    -- Turn-ins for this NPC
    for _, questId in ipairs(self._npcEnds[npcId] or {}) do
        local quest = QuestLogCache:GetQuest(questId)
        if quest then
            AddLine({
                kind = quest.isComplete == 1 and "turnin_ready" or "turnin_progress",
                text = self:GetQuestTitle(questId),
                questId = questId,
                level = quest.level,
            })
        end
    end

    -- Available quests this NPC starts (not already in log)
    local playerLevel = UnitLevel("player") or 1
    for _, questId in ipairs(self._npcStarts[npcId] or {}) do
        if QuestLogCache:IsQuestOfferable(questId) then
            local q = self:GetQuest(questId)
            if q and self:QuestMatchesFaction(q) then
                local level = q.l or 1
                local showTrivial = DQTC.Config:Get("showTrivial")
                if (showTrivial or level >= playerLevel - 7) and level <= playerLevel + 5 then
                    AddLine({
                        kind = "available",
                        text = self:GetQuestTitle(questId),
                        questId = questId,
                        level = level,
                    })
                end
            end
        end
    end

    return lines
end
