local ADDON_NAME = ...
local DQTC = _G[ADDON_NAME]
local Loader = DQTC.Loader
local L = DQTC.L

local TrackerMenu = Loader:CreateModule("TrackerMenu")

local menuFrame
local menuQuestId

local function EnsureMenu()
    if menuFrame then
        return menuFrame
    end
    menuFrame = CreateFrame("Frame", "DQTC_TrackerMenu", UIParent, "UIDropDownMenuTemplate")
    return menuFrame
end

local function InitializeMenu(frame, level)
    if level ~= 1 then
        return
    end
    local info

    if menuQuestId then
        info = UIDropDownMenu_CreateInfo()
        info.text = L["FOCUS_QUEST"]
        info.notCheckable = true
        info.func = function()
            DQTC.Config:SetChar("superTrackedQuestId", menuQuestId)
            DQTC:RefreshAll()
        end
        UIDropDownMenu_AddButton(info, level)

        info = UIDropDownMenu_CreateInfo()
        info.text = L["SEND_TO_GPS"]
        info.notCheckable = true
        info.func = function()
            local Gps = Loader:ImportModule("TomTomIntegration")
            Gps:SetWaypointForQuest(menuQuestId)
        end
        UIDropDownMenu_AddButton(info, level)

        info = UIDropDownMenu_CreateInfo()
        info.text = L["COPY_WOWHEAD"]
        info.notCheckable = true
        info.func = function()
            local Wowhead = Loader:ImportModule("Wowhead")
            Wowhead:ShowCopyPopup(menuQuestId)
        end
        UIDropDownMenu_AddButton(info, level)

        info = UIDropDownMenu_CreateInfo()
        info.text = L["SHOW_IN_QUEST_LOG"]
        info.notCheckable = true
        info.func = function()
            local index = DQTC.Compat.GetQuestLogIndexByID(menuQuestId)
            if not index then
                return
            end
            if QuestLogFrame and not QuestLogFrame:IsShown() then
                if ToggleQuestLog then
                    ToggleQuestLog()
                elseif ShowUIPanel then
                    ShowUIPanel(QuestLogFrame)
                end
            end
            if QuestLog_SetSelection then
                QuestLog_SetSelection(index)
            elseif SelectQuestLogEntry then
                SelectQuestLogEntry(index)
            end
            if QuestLog_Update then
                QuestLog_Update()
            end
        end
        UIDropDownMenu_AddButton(info, level)

        info = UIDropDownMenu_CreateInfo()
        info.text = L["UNTRACK"]
        info.notCheckable = true
        info.func = function()
            local WatchState = Loader:ImportModule("WatchState")
            WatchState:SetTracked(menuQuestId, false)
            DQTC:RefreshAll()
        end
        UIDropDownMenu_AddButton(info, level)

        info = UIDropDownMenu_CreateInfo()
        info.isTitle = true
        info.text = " "
        info.notCheckable = true
        UIDropDownMenu_AddButton(info, level)
    end

    local locked = DQTC.Config:Get("trackerLocked")
    info = UIDropDownMenu_CreateInfo()
    info.text = locked and L["UNLOCK_TRACKER"] or L["LOCK_TRACKER"]
    info.notCheckable = true
    info.func = function()
        DQTC.Config:Set("trackerLocked", not locked)
        local TrackerFrame = Loader:ImportModule("TrackerFrame")
        TrackerFrame:UpdateLockVisual()
    end
    UIDropDownMenu_AddButton(info, level)

    info = UIDropDownMenu_CreateInfo()
    info.text = L["RESET_POSITION"]
    info.notCheckable = true
    info.func = function()
        local TrackerPosition = Loader:ImportModule("TrackerPosition")
        TrackerPosition:Reset()
    end
    UIDropDownMenu_AddButton(info, level)
end

function TrackerMenu:OpenForQuest(questId)
    menuQuestId = questId
    local frame = EnsureMenu()
    UIDropDownMenu_Initialize(frame, InitializeMenu, "MENU")
    ToggleDropDownMenu(1, nil, frame, "cursor", 0, 0)
end

function TrackerMenu:OpenForHeader()
    menuQuestId = nil
    local frame = EnsureMenu()
    UIDropDownMenu_Initialize(frame, InitializeMenu, "MENU")
    ToggleDropDownMenu(1, nil, frame, "cursor", 0, 0)
end
