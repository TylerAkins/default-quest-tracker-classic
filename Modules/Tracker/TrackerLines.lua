local ADDON_NAME = ...
local DQTC = _G[ADDON_NAME]
local Loader = DQTC.Loader

local TrackerLines = Loader:CreateModule("TrackerLines")

local pool = {}
local used = 0

local function CreateLine(parent, index)
    local line = CreateFrame("Button", "DQTC_TrackerLine" .. index, parent)
    line:SetHeight(16)
    line:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    line:EnableMouseWheel(true)

    line.text = line:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    line.text:SetJustifyH("LEFT")
    line.text:SetJustifyV("TOP")
    line.text:SetWordWrap(true)
    line.text:SetNonSpaceWrap(true)
    line.text:SetPoint("TOPLEFT", line, "TOPLEFT", 0, 0)
    line.text:SetPoint("TOPRIGHT", line, "TOPRIGHT", 0, 0)

    line:Hide()
    line.questId = nil
    line.kind = nil -- header | quest | objective

    line:SetScript("OnClick", function(self, button)
        local TrackerMenu = Loader:ImportModule("TrackerMenu")
        if button == "RightButton" then
            if self.kind == "quest" and self.questId then
                TrackerMenu:OpenForQuest(self.questId)
            elseif self.kind == "header" then
                TrackerMenu:OpenForHeader()
            end
            return
        end
        if self.kind == "quest" and self.questId then
            if IsShiftKeyDown() then
                local WatchState = Loader:ImportModule("WatchState")
                WatchState:SetTracked(self.questId, false)
                DQTC:RefreshAll()
            else
                DQTC.Config:SetChar("superTrackedQuestId", self.questId)
                if DQTC.Config:Get("tomTomOnFocus") then
                    local TomTom = Loader:ImportModule("TomTomIntegration")
                    if TomTom then
                        TomTom:SetWaypointForQuest(self.questId)
                    end
                end
                DQTC:RefreshAll()
            end
        elseif self.kind == "header" then
            local collapsed = not DQTC.Config:GetChar("collapsed")
            DQTC.Config:SetChar("collapsed", collapsed)
            DQTC:RefreshAll()
        end
    end)

    line:SetScript("OnMouseWheel", function(_, delta)
        local TrackerFrame = Loader:ImportModule("TrackerFrame")
        TrackerFrame:OnMouseWheel(delta)
    end)

    line:SetScript("OnEnter", function(self)
        if self.kind == "quest" and self.questId then
            GameTooltip:SetOwner(self, "ANCHOR_LEFT")
            GameTooltip:SetText(self.text:GetText() or "", nil, nil, nil, nil, true)
            GameTooltip:AddLine("Left-click: focus  |  Shift-click: untrack  |  Right-click: menu", 0.7, 0.7, 0.7, true)
            GameTooltip:Show()
        elseif self.kind == "header" then
            GameTooltip:SetOwner(self, "ANCHOR_LEFT")
            GameTooltip:SetText(DQTC.L["QUESTS"] or DQTC.L["OBJECTIVES"])
            if DQTC.Config:Get("trackerLocked") then
                GameTooltip:AddLine(DQTC.L["TRACKER_LOCKED"], 0.7, 0.7, 0.7, true)
                GameTooltip:AddLine("Ctrl+drag to move", 0.7, 0.7, 0.7, true)
            else
                GameTooltip:AddLine(DQTC.L["TRACKER_UNLOCKED"], 0.7, 0.7, 0.7, true)
            end
            GameTooltip:AddLine("Mouse wheel: scroll tracker", 0.7, 0.7, 0.7, true)
            GameTooltip:Show()
        end
    end)

    line:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    return line
end

function TrackerLines:Initialize(parent)
    self.parent = parent
    used = 0
end

function TrackerLines:Reset()
    for i = 1, used do
        local line = pool[i]
        line:Hide()
        line:ClearAllPoints()
        line.questId = nil
        line.kind = nil
        line.text:SetText("")
    end
    used = 0
end

function TrackerLines:Acquire()
    used = used + 1
    if not pool[used] then
        pool[used] = CreateLine(self.parent, used)
    end
    local line = pool[used]
    line:Show()
    return line, used
end

function TrackerLines:GetUsedCount()
    return used
end

--- Size the line to wrapped text width.
function TrackerLines:FitLine(line, width)
    width = width or (self.parent and self.parent:GetWidth()) or 235
    line:SetWidth(width)
    line.text:SetWidth(width)
    -- Force layout so GetStringHeight is accurate
    local h = line.text:GetStringHeight()
    if not h or h < 1 then
        h = (line.kind == "objective") and 13 or 14
    end
    line:SetHeight(h + 2)
    return line:GetHeight()
end

function TrackerLines:LayoutFromTop(startY, spacing)
    spacing = spacing or 1
    local y = startY or 0
    local width = (self.parent and self.parent:GetWidth()) or 235
    for i = 1, used do
        local line = pool[i]
        self:FitLine(line, width)
        line:ClearAllPoints()
        line:SetPoint("TOPLEFT", self.parent, "TOPLEFT", 0, y)
        line:SetPoint("TOPRIGHT", self.parent, "TOPRIGHT", 0, y)
        y = y - line:GetHeight() - spacing
    end
    return -y
end
