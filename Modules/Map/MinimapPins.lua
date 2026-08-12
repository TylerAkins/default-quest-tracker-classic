local ADDON_NAME = ...
local DQTC = _G[ADDON_NAME]
local Loader = DQTC.Loader
local L = DQTC.L

local MinimapPins = Loader:CreateModule("MinimapPins")

local REF = "DQTC"
local pinPool = {}
local active = {}
local pending = {}
local lastError
local lastShown = 0

local function GetPins()
    local HBDHelper = Loader:ImportModule("HBDHelper")
    local _, pins = HBDHelper:Get()
    if not pins then
        lastError = HBDHelper:GetStatus().error or "FAIL_NO_HBD"
        return nil
    end
    return pins
end

local function Norm(x, y)
    if x == nil or y == nil then
        return nil, nil
    end
    if x > 1 or y > 1 then
        return x / 100, y / 100
    end
    return x, y
end

local function AcquireIcon()
    local icon = table.remove(pinPool)
    if icon then
        return icon
    end
    icon = CreateFrame("Button", nil, Minimap)
    icon:SetSize(16, 16)
    icon:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    icon:SetScript("OnEnter", function(self)
        if self.tooltip then
            GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
            GameTooltip:SetText(self.tooltip)
            local Gps = Loader:ImportModule("TomTomIntegration")
            if Gps:IsAvailable() then
                GameTooltip:AddLine(L["GPS_CLICK_HINT"], 0.6, 0.6, 0.6)
            end
            GameTooltip:Show()
        end
    end)
    icon:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    icon:SetScript("OnClick", function(self, button)
        if button == "RightButton" then
            local Gps = Loader:ImportModule("TomTomIntegration")
            if self.uiMapId and self.x and self.y then
                Gps:SetWaypoint(self.uiMapId, self.x, self.y, self.tooltip, { silent = true })
            elseif self.questId then
                Gps:SetWaypointForQuest(self.questId, { silent = true })
            end
            return
        end
        if not self.questId then
            return
        end
        DQTC.Config:SetChar("superTrackedQuestId", self.questId)
        DQTC:RefreshAll()
    end)
    return icon
end

local function ReleaseIcon(icon)
    icon:Hide()
    icon:ClearAllPoints()
    icon.questId = nil
    icon.tooltip = nil
    icon.kind = nil
    icon.uiMapId = nil
    icon.x = nil
    icon.y = nil
    pinPool[#pinPool + 1] = icon
end

local function StyleIcon(icon, data)
    local PinArt = Loader:ImportModule("PinArt")
    local scale = (DQTC.Config:Get("minimapScale") or 1) * 18
    local super = data.questId and data.questId == DQTC.Config:GetChar("superTrackedQuestId")
    PinArt:SetupPin(icon, data.kind or "objective", data.questId, super, scale)
    icon:Show()
end

function MinimapPins:Clear()
    local pins = GetPins()
    if pins and pins.RemoveAllMinimapIcons then
        pcall(function()
            pins:RemoveAllMinimapIcons(REF)
        end)
    end
    for _, icon in ipairs(active) do
        ReleaseIcon(icon)
    end
    wipe(active)
    wipe(pending)
    lastShown = 0
    lastError = nil
end

function MinimapPins:AddPin(data, tooltip)
    if not data or not data.uiMapId or data.x == nil or data.y == nil then
        return
    end
    if data.x < 0 or data.y < 0 then
        return
    end
    pending[#pending + 1] = {
        uiMapId = data.uiMapId,
        x = data.x,
        y = data.y,
        kind = data.kind,
        questId = data.questId,
        tooltip = tooltip,
    }
end

function MinimapPins:UpdatePositions()
    local pins = GetPins()
    if not pins then
        return
    end
    if not DQTC.Config:Get("showMinimap") or not DQTC.Config:Get("showQuestMarkers") then
        pcall(function()
            pins:RemoveAllMinimapIcons(REF)
        end)
        for _, icon in ipairs(active) do
            ReleaseIcon(icon)
        end
        wipe(active)
        lastShown = 0
        return
    end

    pcall(function()
        pins:RemoveAllMinimapIcons(REF)
    end)
    for _, icon in ipairs(active) do
        ReleaseIcon(icon)
    end
    wipe(active)

    local shown = 0
    for _, data in ipairs(pending) do
        local x, y = Norm(data.x, data.y)
        if x and y then
            local icon = AcquireIcon()
            icon.questId = data.questId
            icon.tooltip = data.tooltip
            icon.kind = data.kind
            icon.uiMapId = data.uiMapId
            icon.x = data.x
            icon.y = data.y
            StyleIcon(icon, data)
            local ok, err = pcall(function()
                pins:AddMinimapIconMap(REF, icon, data.uiMapId, x, y, true, true)
            end)
            if ok then
                active[#active + 1] = icon
                shown = shown + 1
            else
                ReleaseIcon(icon)
                lastError = "AddMinimapIconMap: " .. tostring(err)
            end
        end
    end

    lastShown = shown
    if shown == 0 and #pending > 0 then
        lastError = lastError or "FAIL_ZERO_MINIMAP"
    elseif shown > 0 then
        lastError = nil
    end
end

function MinimapPins:GetLastError()
    return lastError
end

function MinimapPins:GetStatus()
    local st = Loader:ImportModule("HBDHelper"):GetStatus()
    return {
        pending = #pending,
        shown = lastShown,
        lastError = lastError or st.error,
        hbd = st.ok,
        lib = st.name,
    }
end
