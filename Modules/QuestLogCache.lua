local ADDON_NAME = ...
local DQTC = _G[ADDON_NAME]
local Loader = DQTC.Loader

local QuestLogCache = Loader:CreateModule("QuestLogCache")

local quests = {} -- [questId] = questData
local ordered = {}

local function ParseObjectiveProgress(text)
    if not text then
        return nil, nil
    end
    local _, _, current, required = string.find(text, "(%d+)%s*/%s*(%d+)")
    return tonumber(current), tonumber(required)
end

--- Keep in sync with tests/test_objective_finished.py
local function ObjectiveIsFinished(done, text, numFulfilled, numRequired)
    if done then
        return true
    end
    local current = numFulfilled
    local required = numRequired
    if current == nil or required == nil then
        current, required = ParseObjectiveProgress(text)
    end
    if current and required and required > 0 and current >= required then
        return true
    end
    return false
end

local function ParseObjectives(questLogIndex)
    SelectQuestLogEntry(questLogIndex)
    local objectives = {}
    local num = GetNumQuestLeaderBoards() or GetNumQuestLeaderBoards(questLogIndex) or 0
    for i = 1, num do
        local text, objectiveType, finished, numFulfilled, numRequired =
            GetQuestLogLeaderBoard(i, questLogIndex)
        if not text then
            text, objectiveType, finished, numFulfilled, numRequired = GetQuestLogLeaderBoard(i)
        end
        if (numFulfilled == nil or numRequired == nil) and text then
            local parsedCurrent, parsedRequired = ParseObjectiveProgress(text)
            if numFulfilled == nil then
                numFulfilled = parsedCurrent
            end
            if numRequired == nil then
                numRequired = parsedRequired
            end
        end
        objectives[#objectives + 1] = {
            index = i,
            text = text,
            type = objectiveType,
            finished = ObjectiveIsFinished(finished, text, numFulfilled, numRequired),
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
