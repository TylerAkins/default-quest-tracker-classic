local ADDON_NAME = ...
local DQTC = _G[ADDON_NAME]
local Loader = DQTC.Loader
local Compat = DQTC.Compat

local WatchState = Loader:CreateModule("WatchState")

local hooked = false
local suppressBlizzard = false

local origAddQuestWatch
local origRemoveQuestWatch
local origIsQuestWatched
local origGetNumQuestWatches

local function Char()
    return DQTC.Config.char
end

local function Profile()
    return DQTC.Config.db.profile
end

local function EnsureTables()
    local char = Char()
    char.autoUntracked = char.autoUntracked or {}
    char.trackedQuests = char.trackedQuests or {}
end

function WatchState:IsTracked(questId)
    EnsureTables()
    local char = Char()
    if Profile().autoTrackQuests then
        return not char.autoUntracked[questId]
    end
    return char.trackedQuests[questId] and true or false
end

function WatchState:SetTracked(questId, tracked)
    EnsureTables()
    local char = Char()
    if Profile().autoTrackQuests then
        if tracked then
            char.autoUntracked[questId] = nil
        else
            char.autoUntracked[questId] = true
        end
    else
        if tracked then
            char.trackedQuests[questId] = true
        else
            char.trackedQuests[questId] = nil
        end
    end
end

function WatchState:ToggleTracked(questId)
    self:SetTracked(questId, not self:IsTracked(questId))
end

function WatchState:GetTrackedQuestIds()
    local QuestLogCache = Loader:ImportModule("QuestLogCache")
    local result = {}
    for _, questId in ipairs(QuestLogCache:GetOrderedIds()) do
        if self:IsTracked(questId) then
            result[#result + 1] = questId
        end
    end
    return result
end

function WatchState:ClearBlizzardWatches()
    if not origGetNumQuestWatches then
        return
    end
    suppressBlizzard = true
    local n = origGetNumQuestWatches()
    for i = n, 1, -1 do
        local questIndex = GetQuestIndexForWatch(i)
        if questIndex then
            origRemoveQuestWatch(questIndex)
        end
    end
    suppressBlizzard = false
end

function WatchState:HideBlizzardTracker()
    local wf = Compat.WatchFrame
    if not wf then
        return
    end
    -- Only touch the frame when it actually shows — constant Hide() thrash
    -- can stall default action-button icon updates until mouseover.
    if wf:IsShown() then
        wf:Hide()
    end
    if not wf._dqtcHooked then
        wf._dqtcHooked = true
        hooksecurefunc(wf, "Show", function(frame)
            if DQTC.Config:Get("enableTracker") then
                frame:Hide()
            end
        end)
    end
end

local function OnAddQuestWatch(index)
    if suppressBlizzard or not index then
        return
    end
    local title, _, _, isHeader, _, _, _, questId = GetQuestLogTitle(index)
    if isHeader or not questId then
        return
    end
    WatchState:SetTracked(questId, true)
    suppressBlizzard = true
    if origRemoveQuestWatch then
        origRemoveQuestWatch(index)
    end
    suppressBlizzard = false
    if DQTC.RefreshAll then
        DQTC:RefreshAll()
    end
end

local function OnRemoveQuestWatch(index)
    if suppressBlizzard or not index then
        return
    end
    local _, _, _, isHeader, _, _, _, questId = GetQuestLogTitle(index)
    if isHeader or not questId then
        return
    end
    -- Blizzard remove can fire when we clear; ignore if auto-track unless shift
end

function WatchState:HookBlizzard()
    if hooked then
        return
    end
    hooked = true

    origAddQuestWatch = AddQuestWatch
    origRemoveQuestWatch = RemoveQuestWatch
    origIsQuestWatched = IsQuestWatched
    origGetNumQuestWatches = GetNumQuestWatches

    AddQuestWatch = function(index, ...)
        OnAddQuestWatch(index)
        -- Do not add to Blizzard watch list
    end

    RemoveQuestWatch = function(index, ...)
        if suppressBlizzard then
            return origRemoveQuestWatch(index, ...)
        end
        if index then
            local _, _, _, isHeader, _, _, _, questId = GetQuestLogTitle(index)
            if questId and not isHeader then
                WatchState:SetTracked(questId, false)
                if DQTC.RefreshAll then
                    DQTC:RefreshAll()
                end
            end
        end
    end

    IsQuestWatched = function(index)
        if not index then
            return false
        end
        local _, _, _, isHeader, _, _, _, questId = GetQuestLogTitle(index)
        if isHeader or not questId then
            return false
        end
        return WatchState:IsTracked(questId)
    end

    GetNumQuestWatches = function()
        return #WatchState:GetTrackedQuestIds()
    end

    self:HideBlizzardTracker()
    self:ClearBlizzardWatches()
end

function WatchState:UnhookBlizzard()
    if not hooked then
        return
    end
    AddQuestWatch = origAddQuestWatch
    RemoveQuestWatch = origRemoveQuestWatch
    IsQuestWatched = origIsQuestWatched
    GetNumQuestWatches = origGetNumQuestWatches
    hooked = false
end
