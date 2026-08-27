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
    -- Auto-wrap is off: Classic still breaks on "/" even with SetNonSpaceWrap(false).
    -- FitLine inserts newlines at spaces so counts like "0/10" stay together.
    line.text:SetWordWrap(false)
    line.text:SetNonSpaceWrap(false)
    line.text:SetPoint("TOPLEFT", line, "TOPLEFT", 0, 0)
    line.text:SetPoint("TOPRIGHT", line, "TOPRIGHT", 0, 0)

    line.poiFrame = CreateFrame("Button", nil, line)
    line.poiFrame:SetSize(18, 18)
    line.poiFrame:SetPoint("TOPLEFT", line, "TOPLEFT", 0, 0)
    line.poiFrame:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    line.poiFrame:EnableMouse(true)
    line.poiFrame:Hide()
    line.poiFrame:SetScript("OnEnter", function(self)
        local parent = self:GetParent()
        if parent and parent.questId then
            Loader:ImportModule("WorldMapPins"):SetHoverQuest(parent.questId)
        end
    end)
    line.poiFrame:SetScript("OnLeave", function()
        Loader:ImportModule("WorldMapPins"):ClearHoverQuest()
    end)
    line.poiFrame:SetScript("OnClick", function(self, button)
        local parent = self:GetParent()
        if parent and parent:GetScript("OnClick") then
            parent:GetScript("OnClick")(parent, button)
        end
    end)

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
            GameTooltip:SetText(self._rawText or self.text:GetText() or "", nil, nil, nil, nil, true)
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
        line._rawText = nil
        line._indent = nil
        TrackerLines:ClearPoi(line)
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

-- 18px hit frame; PinArt draws a 27px Blizzard POI around its center.
-- Artwork is allowed to overlap following *objective* indent, but not the
-- next quest's circle (quests with no objectives, e.g. Find Bingles).
local POI_SIZE = 18
local POI_ART_SIZE = 27
local POI_PAD = 2

local function MeasureUnbounded(fs, s)
    -- Measure unconstrained so SetWidth doesn't clip GetStringWidth.
    fs:SetWidth(10000)
    fs:SetText(s)
    return fs:GetStringWidth() or 0
end

function TrackerLines:ClearPoi(line)
    if line.poiFrame then
        line.poiFrame:Hide()
    end
    if line.poi then
        line.poi:Hide()
    end
    line._hasPoi = false
    line.text:ClearAllPoints()
    line.text:SetPoint("TOPLEFT", line, "TOPLEFT", 0, 0)
    line.text:SetPoint("TOPRIGHT", line, "TOPRIGHT", 0, 0)
end

function TrackerLines:IndentAsObjective(line)
    self:ClearPoi(line)
    line._indent = POI_SIZE + POI_PAD
    line.text:ClearAllPoints()
    line.text:SetPoint("TOPLEFT", line, "TOPLEFT", line._indent, 0)
    line.text:SetPoint("TOPRIGHT", line, "TOPRIGHT", 0, 0)
end

function TrackerLines:SetQuestPoi(line, questId, isEmphasized, isTurnin)
    if not line.poiFrame then
        return
    end
    local PinArt = Loader:ImportModule("PinArt")
    PinArt:EnsureLayers(line.poiFrame)
    line.poiFrame.questId = questId
    line.poiFrame.kind = isTurnin and "turnin" or "objective"
    PinArt:SetupNumberedPoi(line.poiFrame, questId, isEmphasized, POI_SIZE, line.poiFrame.kind)
    if line.poiFrame.Highlight then
        line.poiFrame.Highlight:Hide()
    end
    if line.poiFrame.HighlightBorder then
        line.poiFrame.HighlightBorder:Hide()
    end
    line._hasPoi = true
    line.text:ClearAllPoints()
    line.text:SetPoint("TOPLEFT", line, "TOPLEFT", POI_SIZE + POI_PAD, 0)
    line.text:SetPoint("TOPRIGHT", line, "TOPRIGHT", 0, 0)
    line.poiFrame:ClearAllPoints()
    line.poiFrame:SetSize(POI_SIZE, POI_SIZE)
    line.poiFrame:SetPoint("RIGHT", line.text, "LEFT", -POI_PAD, -1)
    line.poiFrame:Show()
end

function TrackerLines:ApplyWrapFlags(fs)
    -- Do not let FontString auto-wrap. Classic treats "/" as a break, which
    -- splits "0/10" so "10" sits alone on the next line.
    fs:SetWordWrap(false)
    fs:SetNonSpaceWrap(false)
end

function TrackerLines:SetLineText(line, text)
    line._rawText = text or ""
    line.text:SetText(line._rawText)
end

--- Insert newlines at spaces only. Keep in sync with tests/test_wrap_at_spaces.py.
function TrackerLines.WrapAtSpaces(text, width, measure)
    if not text or text == "" then
        return text or ""
    end
    if measure(text) <= width then
        return text
    end
    local lines = {}
    local rest = text
    while rest ~= "" do
        if measure(rest) <= width then
            lines[#lines + 1] = rest
            break
        end
        local bestEnd = nil
        local searchFrom = 1
        while true do
            local spaceAt = rest:find(" ", searchFrom, true)
            if not spaceAt then
                break
            end
            local candidate = rest:sub(1, spaceAt - 1)
            if candidate ~= "" and measure(candidate) <= width then
                bestEnd = spaceAt
                searchFrom = spaceAt + 1
            else
                break
            end
        end
        if not bestEnd then
            lines[#lines + 1] = rest
            break
        end
        lines[#lines + 1] = rest:sub(1, bestEnd - 1)
        rest = rest:sub(bestEnd + 1):gsub("^ +", "")
    end
    return table.concat(lines, "\n")
end

--- Size the line to wrapped text width.
function TrackerLines:FitLine(line, width)
    width = width or (self.parent and self.parent:GetWidth()) or 235
    line:SetWidth(width)
    local indent = 0
    if line._hasPoi then
        indent = POI_SIZE + POI_PAD
    elseif line._indent then
        indent = line._indent
    end
    local textWidth = math.max(20, width - indent)
    self:ApplyWrapFlags(line.text)

    local raw = line._rawText
    local wrapped = raw
    if raw and raw ~= "" then
        local measured = MeasureUnbounded(line.text, raw)
        -- GetStringWidth can return 0 before a font is fully applied; don't
        -- force a single clipped line in that case.
        if measured > 0 then
            wrapped = self.WrapAtSpaces(raw, textWidth, function(s)
                return MeasureUnbounded(line.text, s)
            end)
        end
        line.text:SetText(wrapped)
    end
    line.text:SetWidth(textWidth)

    -- Force layout so GetStringHeight is accurate. WordWrap is off, so also
    -- size from explicit newlines in case GetStringHeight ignores them.
    local h = line.text:GetStringHeight() or 0
    local lineCount = 1
    if wrapped and wrapped ~= "" then
        for _ in wrapped:gmatch("\n") do
            lineCount = lineCount + 1
        end
    end
    local _, fontSize = line.text:GetFont()
    if not fontSize or fontSize < 1 then
        fontSize = (line.kind == "objective") and 13 or 14
    end
    h = math.max(h, fontSize * lineCount)
    if h < 1 then
        h = fontSize
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
        local gap = spacing
        if line._hasPoi then
            local nxt = pool[i + 1]
            local nextIsOwnObjective = nxt and nxt.kind == "objective" and nxt.questId == line.questId
            if not nextIsOwnObjective then
                -- Leave room for the overflowing 27px circle before the next quest.
                gap = gap + math.max(0, math.ceil((POI_ART_SIZE - line:GetHeight()) / 2) + 1)
            end
        end
        y = y - line:GetHeight() - gap
    end
    return -y
end
