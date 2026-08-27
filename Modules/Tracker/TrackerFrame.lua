local ADDON_NAME = ...
local DQTC = _G[ADDON_NAME]
local Loader = DQTC.Loader
local L = DQTC.L

local TrackerFrame = Loader:CreateModule("TrackerFrame")

local TITLE_WIDTH = 235
local SCROLL_STEP = 36

function TrackerFrame:Initialize()
    if self.frame then
        return
    end

    local frame = CreateFrame("Frame", "DQTC_TrackerFrame", UIParent)
    frame:SetSize(TITLE_WIDTH, 40)
    frame:SetFrameStrata("MEDIUM")
    frame:SetFrameLevel(10)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:EnableMouseWheel(true)
    frame:RegisterForDrag("LeftButton")
    frame:Hide()

    frame.bg = frame:CreateTexture(nil, "BACKGROUND")
    frame.bg:SetAllPoints()
    frame.bg:SetColorTexture(0, 0, 0, 0)

    -- Retail-like: fixed max height viewport + scrollable content
    local scroll = CreateFrame("ScrollFrame", "DQTC_TrackerScroll", frame)
    scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    scroll:EnableMouse(true)
    scroll:EnableMouseWheel(true)
    frame.scroll = scroll

    local content = CreateFrame("Frame", "DQTC_TrackerContent", scroll)
    content:SetSize(TITLE_WIDTH, 40)
    scroll:SetScrollChild(content)
    frame.content = content

    local TrackerLines = Loader:ImportModule("TrackerLines")
    TrackerLines:Initialize(content)

    local TrackerPosition = Loader:ImportModule("TrackerPosition")

    local function OnWheel(_, delta)
        TrackerFrame:OnMouseWheel(delta)
    end
    frame:SetScript("OnMouseWheel", OnWheel)
    scroll:SetScript("OnMouseWheel", OnWheel)

    local function OnDragStart()
        if TrackerPosition:CanDrag() then
            frame:StartMoving()
            frame._dragging = true
        end
    end
    local function OnDragStop()
        frame:StopMovingOrSizing()
        if frame._dragging then
            frame._dragging = false
            TrackerPosition:SaveFromFrame(frame)
        end
    end

    frame:RegisterForDrag("LeftButton")
    scroll:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", OnDragStart)
    frame:SetScript("OnDragStop", OnDragStop)
    scroll:SetScript("OnDragStart", OnDragStart)
    scroll:SetScript("OnDragStop", OnDragStop)

    self.frame = frame
    TrackerPosition:Apply(frame)
    TrackerPosition:HookLayout()
    self:UpdateLockVisual()
end

function TrackerFrame:GetMaxHeight()
    local pct = DQTC.Config:Get("trackerMaxHeightPct") or 0.55
    if pct < 0.25 then
        pct = 0.25
    elseif pct > 0.9 then
        pct = 0.9
    end
    return GetScreenHeight() * pct
end

function TrackerFrame:OnMouseWheel(delta)
    local frame = self.frame
    if not frame or not frame.scroll then
        return
    end
    local scroll = frame.scroll
    local content = frame.content
    local viewH = scroll:GetHeight() or 0
    local contentH = content:GetHeight() or 0
    local maxScroll = math.max(0, contentH - viewH)
    if maxScroll <= 0 then
        return
    end
    local cur = scroll:GetVerticalScroll() or 0
    local nextScroll = cur - (delta * SCROLL_STEP)
    if nextScroll < 0 then
        nextScroll = 0
    elseif nextScroll > maxScroll then
        nextScroll = maxScroll
    end
    scroll:SetVerticalScroll(nextScroll)
end

function TrackerFrame:UpdateLockVisual()
    local frame = self.frame
    if not frame then
        return
    end
    local locked = DQTC.Config:Get("trackerLocked")
    if locked then
        frame.bg:SetColorTexture(0, 0, 0, 0)
    else
        frame.bg:SetColorTexture(0, 0, 0, 0.35)
    end
end

local function DifficultyColor(level)
    local c = GetQuestDifficultyColor(level or 1)
    return c.r, c.g, c.b
end

local function ApplyWrapFlags(fs)
    -- SetFontObject copies wrap flags from the font object; Classic auto-wrap
    -- also breaks on "/", which splits "0/10". FitLine wraps at spaces instead.
    fs:SetWordWrap(false)
    fs:SetNonSpaceWrap(false)
end

local function StyleTitle(fs)
    fs:SetFontObject(GameFontNormal)
    fs:SetShadowColor(0, 0, 0, 1)
    fs:SetShadowOffset(1, -1)
    ApplyWrapFlags(fs)
end

local function StyleObjective(fs)
    fs:SetFontObject(GameFontHighlight)
    fs:SetShadowColor(0, 0, 0, 1)
    fs:SetShadowOffset(1, -1)
    ApplyWrapFlags(fs)
end

local function SortQuestIds(ids)
    local QuestLogCache = Loader:ImportModule("QuestLogCache")
    local mode = DQTC.Config:Get("sortMode") or "log"

    if mode == "log" then
        local order = {}
        for i, questId in ipairs(QuestLogCache:GetOrderedIds()) do
            order[questId] = i
        end
        table.sort(ids, function(a, b)
            return (order[a] or 9999) < (order[b] or 9999)
        end)
        return
    end

    local px, py, pmap
    if mode == "proximity" and C_Map and C_Map.GetPlayerMapPosition then
        pmap = C_Map.GetBestMapForUnit("player")
        local pos = pmap and C_Map.GetPlayerMapPosition(pmap, "player")
        if pos then
            px, py = pos:GetXY()
            if px then
                px, py = px * 100, py * 100
            end
        end
    end
    local DB = Loader:ImportModule("DB")
    table.sort(ids, function(a, b)
        local qa = QuestLogCache:GetQuest(a)
        local qb = QuestLogCache:GetQuest(b)
        if not qa then
            return false
        end
        if not qb then
            return true
        end
        if mode == "level" then
            if qa.level ~= qb.level then
                return qa.level < qb.level
            end
            return (qa.title or "") < (qb.title or "")
        end
        if mode == "proximity" and px and py then
            local function dist(questId)
                local sp = DB:GetBestWaypointSpawn(questId)
                if not sp or (pmap and sp.uiMapId ~= pmap) then
                    return 999999
                end
                local dx, dy = (sp.x or 0) - px, (sp.y or 0) - py
                return dx * dx + dy * dy
            end
            local da, dbd = dist(a), dist(b)
            if da ~= dbd then
                return da < dbd
            end
        end
        local za, zb = qa.zone or "", qb.zone or ""
        if za ~= zb then
            return za < zb
        end
        return (qa.title or "") < (qb.title or "")
    end)
end

function TrackerFrame:SortQuestIds(ids)
    SortQuestIds(ids)
    return ids
end

function TrackerFrame:GetSortedTrackedQuestIds()
    local WatchState = Loader:ImportModule("WatchState")
    return self:SortQuestIds(WatchState:GetTrackedQuestIds())
end

function TrackerFrame:Update()
    self:Initialize()
    local frame = self.frame
    if DQTC.Config:Get("hideDuringCombat") and InCombatLockdown() then
        frame:Hide()
        return
    end
    local TrackerLines = Loader:ImportModule("TrackerLines")
    local WatchState = Loader:ImportModule("WatchState")
    local QuestLogCache = Loader:ImportModule("QuestLogCache")
    local CombatQueue = Loader:ImportModule("CombatQueue")

    CombatQueue:Queue(function()
        if not DQTC.Config:Get("enableTracker") then
            frame:Hide()
            return
        end

        TrackerLines:Reset()

        local tracked = WatchState:GetTrackedQuestIds()
        SortQuestIds(tracked)

        local header = TrackerLines:Acquire()
        header.kind = "header"
        header.questId = nil
        local count = #tracked
        TrackerLines:SetLineText(header, string.format("%s (%d)", L["QUESTS"], count))
        header.text:SetTextColor(1, 0.82, 0)
        StyleTitle(header.text)

        if not DQTC.Config:GetChar("collapsed") then
            local hideCompleted = DQTC.Config:Get("hideCompletedObjectives")
            local showLevel = DQTC.Config:Get("showQuestLevel")
            local focusId = DQTC.Config:GetChar("superTrackedQuestId")

            for _, questId in ipairs(tracked) do
                local quest = QuestLogCache:GetQuest(questId)
                if quest then
                    local qLine = TrackerLines:Acquire()
                    qLine.kind = "quest"
                    qLine.questId = questId
                    local title = quest.title or ("Quest " .. questId)
                    if showLevel and quest.level and quest.level > 0 then
                        title = string.format("[%d] %s", quest.level, title)
                    end
                    TrackerLines:SetLineText(qLine, title)
                    TrackerLines:SetQuestPoi(qLine, questId, focusId == questId, quest.isComplete == 1)
                    StyleTitle(qLine.text)
                    local r, g, b = DifficultyColor(quest.level)
                    if focusId == questId then
                        qLine.text:SetTextColor(1, 1, 0)
                    else
                        qLine.text:SetTextColor(r, g, b)
                    end

                    local showedObjective = false
                    for _, obj in ipairs(quest.objectives or {}) do
                        if not (hideCompleted and obj.finished) then
                            local oLine = TrackerLines:Acquire()
                            oLine.kind = "objective"
                            oLine.questId = questId
                            TrackerLines:SetLineText(oLine, "- " .. (obj.text or ""))
                            TrackerLines:IndentAsObjective(oLine)
                            StyleObjective(oLine.text)
                            if obj.finished or quest.isComplete == 1 then
                                oLine.text:SetTextColor(0, 1, 0)
                            else
                                oLine.text:SetTextColor(0.87, 0.87, 0.87)
                            end
                            showedObjective = true
                        end
                    end

                    if not showedObjective and quest.isComplete == 1 then
                        local oLine = TrackerLines:Acquire()
                        oLine.kind = "objective"
                        oLine.questId = questId
                        TrackerLines:SetLineText(oLine, "- " .. (QUEST_WATCH_QUEST_READY or "Ready for turn-in"))
                        TrackerLines:IndentAsObjective(oLine)
                        StyleObjective(oLine.text)
                        oLine.text:SetTextColor(0, 1, 0)
                    end
                end
            end
        end

        local scale = DQTC.Config:Get("trackerScale") or 1
        local width = TITLE_WIDTH * scale
        frame:SetWidth(width)
        frame.content:SetWidth(width)

        local contentHeight = TrackerLines:LayoutFromTop(0, 1)
        contentHeight = math.max(contentHeight, 14)
        frame.content:SetHeight(contentHeight)

        local maxH = self:GetMaxHeight()
        local viewH = math.min(contentHeight, maxH)
        frame:SetHeight(viewH)
        frame.scroll:SetVerticalScroll(0)

        -- Keep scroll in range if content shrank
        local maxScroll = math.max(0, contentHeight - viewH)
        local cur = frame.scroll:GetVerticalScroll() or 0
        if cur > maxScroll then
            frame.scroll:SetVerticalScroll(maxScroll)
        end

        if #tracked > 0 then
            frame:Show()
            -- Position once when becoming visible; do not re-Apply on every
            -- quest-log refresh (that was jumping the default layout).
            if not frame._dqtcPosApplied then
                frame._dqtcPosApplied = true
                Loader:ImportModule("TrackerPosition"):Apply(frame)
            end
        else
            frame:Hide()
            frame._dqtcPosApplied = false
        end
        TrackerFrame:UpdateLockVisual()
    end)
end
