local ADDON_NAME = ...
local DQTC = _G[ADDON_NAME]
local Loader = DQTC.Loader

local QuestLogCache = Loader:CreateModule("QuestLogCache")

local quests = {} -- [questId] = questData
local ordered = {}

local function ParseObjectives(questLogIndex)
    local objectives = {}
    local num = GetNumQuestLeaderBoards(questLogIndex) or 0
    for i = 1, num do
        local text, objectiveType, finished, numFulfilled, numRequired
        -- Classic Era accepts (objIndex, questLogIndex); fall back to selected entry
        text, objectiveType, finished, numFulfilled, numRequired = GetQuestLogLeaderBoard(i, questLogIndex)
        if not text then
            SelectQuestLogEntry(questLogIndex)
            text, objectiveType, finished, numFulfilled, numRequired = GetQuestLogLeaderBoard(i)
        end
        objectives[#objectives + 1] = {
            index = i,
            text = text,
            type = objectiveType,
            finished = finished and true or false,
            numFulfilled = numFulfilled,
            numRequired = numRequired,
        }
    end
    return objectives
end

function QuestLogCache:Refresh()
    wipe(quests)
    wipe(ordered)

    local numEntries = GetNumQuestLogEntries() or 0
    for i = 1, numEntries do
        local title, level, suggestedGroup, isHeader, isCollapsed, isComplete, frequency, questId =
            GetQuestLogTitle(i)
        if not isHeader and questId and questId > 0 then
            SelectQuestLogEntry(i)
            local data = {
                questId = questId,
                title = title,
                level = level or 0,
                suggestedGroup = suggestedGroup,
                isComplete = isComplete, -- 1 complete, -1 failed, nil incomplete
                frequency = frequency,
                logIndex = i,
                objectives = ParseObjectives(i),
                zone = nil,
            }
            -- Walk backwards for zone header
            for h = i - 1, 1, -1 do
                local hTitle, _, _, hIsHeader = GetQuestLogTitle(h)
                if hIsHeader then
                    data.zone = hTitle
                    break
                end
            end
            quests[questId] = data
            ordered[#ordered + 1] = questId
        end
    end

    return quests
end

function QuestLogCache:GetQuests()
    return quests
end

function QuestLogCache:GetOrderedIds()
    return ordered
end

function QuestLogCache:GetQuest(questId)
    return quests[questId]
end

function QuestLogCache:IsQuestInLog(questId)
    return quests[questId] ~= nil
end

function QuestLogCache:IsQuestCompleted(questId)
    local QuestAvailability = Loader:ImportModule("QuestAvailability")
    return QuestAvailability:IsCompleted(questId)
end

--- True if this quest can still be offered (race/class/prereqs/completed).
function QuestLogCache:IsQuestOfferable(questId)
    local QuestAvailability = Loader:ImportModule("QuestAvailability")
    return QuestAvailability:IsOfferable(questId)
end

function QuestLogCache:GetQuestCount()
    return #ordered
end
