local ADDON_NAME = ...
local DQTC = _G[ADDON_NAME]

DQTC.Compat = DQTC.Compat or {}
local Compat = DQTC.Compat

Compat.WatchFrame = QuestWatchFrame or WatchFrame

function Compat.IsQuestieLoaded()
    return (C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("Questie"))
        or (IsAddOnLoaded and IsAddOnLoaded("Questie"))
        or false
end

function Compat.IsDugiLoaded()
    return (C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("DugisGuideViewerZ"))
        or (IsAddOnLoaded and IsAddOnLoaded("DugisGuideViewerZ"))
        or (_G.DugisGuideViewer ~= nil)
end

function Compat.GetCreatureIdFromGUID(guid)
    if not guid then
        return nil
    end
    local unitType, _, _, _, _, npcId = strsplit("-", guid)
    if unitType == "Creature" or unitType == "Vehicle" then
        return tonumber(npcId)
    end
    return nil
end

function Compat.GetQuestLogIndexByID(questId)
    if C_QuestLog and C_QuestLog.GetLogIndexForQuestID then
        local index = C_QuestLog.GetLogIndexForQuestID(questId)
        if index then
            return index
        end
    end
    for i = 1, GetNumQuestLogEntries() do
        local _, _, _, _, _, _, _, id = GetQuestLogTitle(i)
        if id == questId then
            return i
        end
    end
    return nil
end

function Compat.ShowQuestInLog(questId)
    local index = Compat.GetQuestLogIndexByID(questId)
    if not index or not QuestLogFrame then
        return false
    end

    if not QuestLogFrame:IsShown() then
        if ToggleQuestLog then
            ToggleQuestLog()
        elseif ShowUIPanel then
            ShowUIPanel(QuestLogFrame)
        else
            return false
        end
    end

    if QuestLog_SetSelection then
        QuestLog_SetSelection(index)
    elseif SelectQuestLogEntry then
        SelectQuestLogEntry(index)
    else
        return false
    end

    if QuestLog_UpdateQuestDetails then
        QuestLog_UpdateQuestDetails()
    end
    if QuestLog_Update then
        QuestLog_Update()
    end

    return true
end

function Compat.IsQuestFlaggedCompleted(questId)
    if not questId then
        return false
    end
    if C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted then
        return C_QuestLog.IsQuestFlaggedCompleted(questId) and true or false
    end
    if IsQuestFlaggedCompleted then
        return IsQuestFlaggedCompleted(questId) and true or false
    end
    return false
end
