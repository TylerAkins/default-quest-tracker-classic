local ADDON_NAME = ...
local DQTC = _G[ADDON_NAME]
local Loader = DQTC.Loader
local L = DQTC.L

local TrackerPosition = Loader:CreateModule("TrackerPosition")

-- Classic default UI: MultiBarRight / MultiBarLeft are the vertical bars on the
-- right (often labeled Action Bars 4 & 5 in the interface options).
local RIGHT_BARS = { "MultiBarRight", "MultiBarLeft" }
-- One vertical column is ~36–40px; parent frames can report huge widths.
local MAX_BAR_COLUMN_WIDTH = 44

local function GetFrame()
    local TrackerFrame = Loader:ImportModule("TrackerFrame")
    return TrackerFrame and TrackerFrame.frame
end

local function DurabilityOffset()
    if DurabilityFrame and DurabilityFrame:IsShown() then
        return -56
    end
    return 0
end

--- Width to reserve for visible right-side vertical multi-action bars.
function TrackerPosition:GetRightActionBarInset()
    local inset = 0
    local gap = 4
    for _, name in ipairs(RIGHT_BARS) do
        local bar = _G[name]
        if bar and bar.IsShown and bar:IsShown() then
            local w = (bar.GetWidth and bar:GetWidth()) or 0
            if w > MAX_BAR_COLUMN_WIDTH then
                w = MAX_BAR_COLUMN_WIDTH
            end
            if w > 0 then
                inset = inset + w + gap
            end
        end
    end
    return inset
end

local function DefaultOffsets(self)
    return -4 - self:GetRightActionBarInset(), -28 + DurabilityOffset()
end

--- Default layout anchored to UIParent (stable). MinimapCluster is only sampled
--- for screen coords — not used as a live parent (cluster moves / layout churn
--- was making the tracker jump "randomly").
function TrackerPosition:ApplyDefault(frame)
    frame = frame or GetFrame()
    if not frame then
        return
    end

    local offsetX, offsetY = DefaultOffsets(self)
    local screenW, screenH = GetScreenWidth(), GetScreenHeight()
    local xOfs, yOfs

    local cluster = MinimapCluster
    if cluster and cluster.GetRight and cluster.GetBottom then
        local right = cluster:GetRight()
        local bottom = cluster:GetBottom()
        if right and bottom then
            -- Place tracker TOPRIGHT near cluster BOTTOMRIGHT, then scoot for bars.
            xOfs = right - screenW + offsetX
            yOfs = bottom - screenH + offsetY
        end
    end
    if not xOfs then
        xOfs = -100 - self:GetRightActionBarInset()
        yOfs = -200
    end

    local sig = string.format("%.1f:%.1f", xOfs, yOfs)
    if self._lastDefaultSig == sig then
        local _, rel = frame:GetPoint(1)
        if rel == UIParent then
            return
        end
    end
    self._lastDefaultSig = sig

    frame:ClearAllPoints()
    frame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", xOfs, yOfs)
end

function TrackerPosition:ApplySaved(frame)
    frame = frame or GetFrame()
    if not frame then
        return
    end
    local pos = DQTC.Config:GetChar("trackerPosition")
    if not pos then
        self:ApplyDefault(frame)
        return
    end
    frame:ClearAllPoints()
    local ok = pcall(frame.SetPoint, frame, unpack(pos))
    if not ok then
        DQTC.Config:SetChar("trackerPosition", nil)
        self._lastDefaultSig = nil
        self:ApplyDefault(frame)
    end
end

function TrackerPosition:Apply(frame)
    frame = frame or GetFrame()
    if not frame then
        return
    end
    -- Only auto-scoot for the default (undragged) layout; respect saved positions
    if DQTC.Config:GetChar("trackerPosition") then
        self:ApplySaved(frame)
    else
        self:ApplyDefault(frame)
    end
end

function TrackerPosition:Reset()
    DQTC.Config:SetChar("trackerPosition", nil)
    self._lastDefaultSig = nil
    self:ApplyDefault()
end

local function ClampFrame(frame)
    local left, bottom, width, height = frame:GetRect()
    if not left then
        return
    end
    local screenW, screenH = GetScreenWidth(), GetScreenHeight()
    local right = left + width
    local top = bottom + height
    local pad = 4
    local dx, dy = 0, 0
    if left < pad then
        dx = pad - left
    elseif right > screenW - pad then
        dx = (screenW - pad) - right
    end
    if bottom < pad then
        dy = pad - bottom
    elseif top > screenH - pad then
        dy = (screenH - pad) - top
    end
    if dx ~= 0 or dy ~= 0 then
        local point, relativeTo, relativePoint, xOfs, yOfs = frame:GetPoint(1)
        frame:ClearAllPoints()
        frame:SetPoint(point, relativeTo, relativePoint, (xOfs or 0) + dx, (yOfs or 0) + dy)
    end
end

function TrackerPosition:SaveFromFrame(frame)
    frame = frame or GetFrame()
    if not frame then
        return
    end
    ClampFrame(frame)

    local left = frame:GetLeft() or 0
    local right = frame:GetRight() or 0
    local top = frame:GetTop() or 0
    local bottom = frame:GetBottom() or 0
    local screenW, screenH = GetScreenWidth(), GetScreenHeight()

    local dist = {
        TOPLEFT = left + (screenH - top),
        TOPRIGHT = (screenW - right) + (screenH - top),
        BOTTOMLEFT = left + bottom,
        BOTTOMRIGHT = (screenW - right) + bottom,
    }
    local best, bestDist = "TOPRIGHT", dist.TOPRIGHT
    for corner, d in pairs(dist) do
        if d < bestDist then
            best, bestDist = corner, d
        end
    end

    local pos
    if best == "TOPLEFT" then
        pos = { "TOPLEFT", "UIParent", "TOPLEFT", left, -(screenH - top) }
    elseif best == "TOPRIGHT" then
        pos = { "TOPRIGHT", "UIParent", "TOPRIGHT", -(screenW - right), -(screenH - top) }
    elseif best == "BOTTOMLEFT" then
        pos = { "BOTTOMLEFT", "UIParent", "BOTTOMLEFT", left, bottom }
    else
        pos = { "BOTTOMRIGHT", "UIParent", "BOTTOMRIGHT", -(screenW - right), bottom }
    end

    DQTC.Config:SetChar("trackerPosition", pos)
    self._lastDefaultSig = nil
    frame:ClearAllPoints()
    frame:SetPoint(unpack(pos))
end

function TrackerPosition:CanDrag()
    if not DQTC.Config:Get("trackerLocked") then
        return true
    end
    return IsControlKeyDown() and true or false
end

function TrackerPosition:HookLayout()
    if self._layoutHooked then
        return
    end
    self._layoutHooked = true

    local function Relayout()
        -- Default layout only: re-sample when bars / durability / UI layout settle
        if DQTC.Config:GetChar("trackerPosition") then
            return
        end
        self._lastDefaultSig = nil
        TrackerPosition:ApplyDefault()
    end

    -- Debounce: UIParent_ManageFramePositions fires very often
    local pending
    local function RelayoutDebounced()
        if pending then
            return
        end
        pending = true
        C_Timer.After(0.15, function()
            pending = false
            Relayout()
        end)
    end

    if UIParent_ManageFramePositions then
        hooksecurefunc("UIParent_ManageFramePositions", RelayoutDebounced)
    end

    local Events = Loader:ImportModule("Events")
    -- Do NOT hook ACTIONBAR_SHOWGRID / HIDEGRID — those fire while dragging
    -- abilities and made the tracker scoot left/right "randomly".
    Events:Register("PLAYER_ENTERING_WORLD", Relayout, 0.35)
    Events:Register("PLAYER_REGEN_ENABLED", Relayout, 0.1)
    if C_EventUtils and C_EventUtils.IsEventValid and C_EventUtils.IsEventValid("UPDATE_MULTI_BARS") then
        Events:Register("UPDATE_MULTI_BARS", Relayout, 0.1)
    else
        pcall(function()
            Events:Register("UPDATE_MULTI_BARS", Relayout, 0.1)
        end)
    end
end
