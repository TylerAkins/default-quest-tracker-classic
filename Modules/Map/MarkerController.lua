local ADDON_NAME = ...
local DQTC = _G[ADDON_NAME]
local Loader = DQTC.Loader

local MarkerController = Loader:CreateModule("MarkerController")

local MAX_PINS = 500
local lastStats = { added = 0, suppressed = false, reason = nil }

local function ShouldSuppress()
    if DQTC.Config:Get("suppressIfQuestie") and DQTC.Compat.IsQuestieLoaded() then
        return true, "suppressIfQuestie"
    end
    return false, nil
end

local function DedupKey(data)
    return string.format("%s:%d:%.1f:%.1f:%s", tostring(data.uiMapId), data.questId or 0, data.x or 0, data.y or 0, data.kind or "")
end

function MarkerController:GetStats()
    return lastStats
end

function MarkerController:Refresh()
    local WorldMapPins = Loader:ImportModule("WorldMapPins")
    local MinimapPins = Loader:ImportModule("MinimapPins")
    local DB = Loader:ImportModule("DB")
    local QuestLogCache = Loader:ImportModule("QuestLogCache")
    local ZoneMap = Loader:ImportModule("ZoneMap")

    -- Always refresh log so OnShow / zone changes still have quests
    QuestLogCache:Refresh()

    WorldMapPins:Clear()
    MinimapPins:Clear()

    lastStats = { added = 0, suppressed = false, reason = nil, logQuests = QuestLogCache:GetQuestCount() }

    if not DQTC.Config:Get("showQuestMarkers") then
        lastStats.reason = "showQuestMarkers off"
        DB:RebuildNpcIndex()
        return
    end

    local suppressed, reason = ShouldSuppress()
    if suppressed then
        lastStats.suppressed = true
        lastStats.reason = reason
        DB:RebuildNpcIndex()
        return
    end

    DB:RebuildNpcIndex()

    local showWorld = DQTC.Config:Get("showWorldMap")
    local showMini = DQTC.Config:Get("showMinimap")
    local currentMap = ZoneMap:GetPlayerMapId()
    local seen = {}
    local count = 0

    local function Add(data, tooltip)
        if count >= MAX_PINS then
            return
        end
        if not data or not data.uiMapId or data.x == nil or data.y == nil then
            return
        end
        local key = DedupKey(data)
        if seen[key] then
            return
        end
        seen[key] = true
        count = count + 1
        if showWorld then
            WorldMapPins:AddPin(data, tooltip)
        end
        if showMini then
            MinimapPins:AddPin(data, tooltip)
        end
    end

    -- Log quest objectives + turn-ins
    for questId, quest in pairs(QuestLogCache:GetQuests()) do
        if quest.isComplete == 1 then
            if DQTC.Config:Get("showTurnins") then
                for _, sp in ipairs(DB:GetTurninSpawns(questId)) do
                    Add(sp, DB:FormatMapPinTooltip(questId, "(Turn-in)"))
                end
            end
        else
            -- Incomplete: objectives only — never show complete (?) until isComplete == 1
            if DQTC.Config:Get("showObjectives") then
                for _, sp in ipairs(DB:GetObjectiveSpawns(questId)) do
                    Add(sp, DB:FormatMapPinTooltip(questId))
                end
            end
        end
    end

    -- Available quest givers:
    --  - World map: currently viewed map (open another zone to see that zone's ! pins)
    --  - Minimap: player map only (keeps pin count / FPS sane)
    if DQTC.Config:Get("showAvailable") then
        local playerLevel = UnitLevel("player") or 1
        local viewedMap = WorldMapFrame and WorldMapFrame:IsShown() and WorldMapFrame.GetMapID and WorldMapFrame:GetMapID()
        local worldFilter = viewedMap or currentMap

        local function AddFiltered(spawns, allowWorld, allowMini)
            for _, sp in ipairs(spawns) do
                if count >= MAX_PINS then
                    break
                end
                if sp and sp.uiMapId and sp.x ~= nil and sp.y ~= nil then
                    local key = DedupKey(sp)
                    if not seen[key] then
                        seen[key] = true
                        count = count + 1
                        local tip = DB:FormatMapPinTooltip(sp.questId)
                        if allowWorld and showWorld then
                            WorldMapPins:AddPin(sp, tip)
                        end
                        if allowMini and showMini then
                            MinimapPins:AddPin(sp, tip)
                        end
                    end
                end
            end
        end

        if worldFilter and currentMap and worldFilter == currentMap then
            AddFiltered(DB:GetAvailableSpawns(playerLevel, currentMap), true, true)
        else
            if worldFilter then
                AddFiltered(DB:GetAvailableSpawns(playerLevel, worldFilter), true, false)
            end
            if currentMap then
                AddFiltered(DB:GetAvailableSpawns(playerLevel, currentMap), false, true)
            end
        end
    end

    if showWorld then
        WorldMapPins:Finalize()
    end
    if showMini then
        MinimapPins:UpdatePositions()
    end

    lastStats.added = count
    lastStats.currentMap = currentMap
    lastStats.worldStatus = WorldMapPins:GetStatus()
    lastStats.minimapStatus = MinimapPins:GetStatus()
end
