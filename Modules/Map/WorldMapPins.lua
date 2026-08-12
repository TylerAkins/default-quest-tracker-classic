local ADDON_NAME = ...
local DQTC = _G[ADDON_NAME]
local Loader = DQTC.Loader
local L = DQTC.L

local WorldMapPins = Loader:CreateModule("WorldMapPins")

local REF = "DQTC"
local pinPool = {}
local active = {}
local pending = {}
local lastError
local lastPainted = 0
local hooked = false
local libName

local function GetPins()
    local HBDHelper = Loader:ImportModule("HBDHelper")
    local _, pins, name = HBDHelper:Get()
    libName = name
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
    icon = CreateFrame("Button", nil, UIParent)
    icon:SetSize(22, 22)
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
            elseif self.questId and self.questId ~= 0 then
                Gps:SetWaypointForQuest(self.questId, { silent = true })
            end
            return
        end
        if not self.questId or self.questId == 0 then
            return
        end
        DQTC.Config:SetChar("superTrackedQuestId", self.questId)
        DQTC:RefreshAll()
    end)
    return icon
end

local function ReleaseIcon(icon)
    icon:Hide()
    icon:SetParent(UIParent)
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
    local scale = (DQTC.Config:Get("mapScale") or 1) * 24
    local super = data.questId and data.questId == DQTC.Config:GetChar("superTrackedQuestId")
    PinArt:SetupPin(icon, data.kind or "objective", data.questId, super, scale)
    icon:Show()
end

function WorldMapPins:GetStatus()
    local viewed = WorldMapFrame and WorldMapFrame.GetMapID and WorldMapFrame:GetMapID()
    local match = 0
    for _, d in ipairs(pending) do
        if d.uiMapId == viewed then
            match = match + 1
        end
    end
    local st = Loader:ImportModule("HBDHelper"):GetStatus()
    return {
        hbd = st.ok,
        pins = st.ok,
        lib = st.name or libName,
        count = lastPainted,
        pending = #pending,
        matchingView = match,
        mode = st.ok and "hbd-pins" or "none",
        lastError = lastError or st.error,
        viewedMap = viewed,
    }
end

function WorldMapPins:Clear()
    local pins = GetPins()
    if pins and pins.RemoveAllWorldMapIcons then
        pcall(function()
            pins:RemoveAllWorldMapIcons(REF)
        end)
    end
    for _, icon in ipairs(active) do
        ReleaseIcon(icon)
    end
    wipe(active)
    wipe(pending)
    lastPainted = 0
    lastError = nil
end

function WorldMapPins:AddPin(data, tooltip)
    if not data or not data.uiMapId or data.x == nil or data.y == nil then
        return false
    end
    if data.x < 0 or data.y < 0 then
        return false
    end
    pending[#pending + 1] = {
        uiMapId = data.uiMapId,
        x = data.x,
        y = data.y,
        kind = data.kind,
        questId = data.questId,
        tooltip = tooltip,
    }
    return true
end

function WorldMapPins:Paint()
    local pins = GetPins()
    if not pins then
        lastPainted = 0
        return 0
    end

    pcall(function()
        pins:RemoveAllWorldMapIcons(REF)
    end)
    for _, icon in ipairs(active) do
        ReleaseIcon(icon)
    end
    wipe(active)

    local HBDHelper = Loader:ImportModule("HBDHelper")
    -- CURRENT keeps icons on their zone; PARENT still helps micro-dungeons via HBD world math
    local showFlag = HBDHelper:GetShowParentFlag()
    local painted = 0

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
                pins:AddWorldMapIconMap(REF, icon, data.uiMapId, x, y, showFlag)
            end)
            if ok then
                active[#active + 1] = icon
                painted = painted + 1
            else
                ReleaseIcon(icon)
                lastError = "AddWorldMapIconMap: " .. tostring(err)
            end
        end
    end

    if pins.worldmapProvider and pins.worldmapProvider.RefreshAllData then
        pins.worldmapProvider.forceUpdate = true
        pcall(function()
            pins.worldmapProvider:RefreshAllData()
        end)
    end

    lastPainted = painted
    if painted == 0 then
        lastError = lastError or ((#pending == 0) and "FAIL_NO_PENDING" or "FAIL_ZERO_PAINTED")
    else
        lastError = nil
    end
    return painted
end

function WorldMapPins:HookMap()
    if hooked then
        return
    end
    hooked = true
    local lastViewedMap

    local function RefreshForViewedMap()
        if not WorldMapFrame or not WorldMapFrame:IsShown() then
            return
        end
        local viewed = WorldMapFrame.GetMapID and WorldMapFrame:GetMapID()
        if viewed == lastViewedMap then
            -- Same map: just repaint existing pending (HBD visibility)
            WorldMapPins:Paint()
            return
        end
        lastViewedMap = viewed
        -- Rebuild so available ! pins load for the zone you're looking at
        -- (e.g. Dun Morogh → Loch Modan while still standing in Dun Morogh)
        Loader:ImportModule("MarkerController"):Refresh()
    end

    if WorldMapFrame then
        WorldMapFrame:HookScript("OnShow", function()
            lastViewedMap = nil
            C_Timer.After(0.05, RefreshForViewedMap)
        end)
        if WorldMapFrame.OnMapChanged then
            hooksecurefunc(WorldMapFrame, "OnMapChanged", function()
                C_Timer.After(0, RefreshForViewedMap)
            end)
        end
        -- Fallback for clients that fire canvas callbacks instead
        if WorldMapFrame.RegisterCallback then
            pcall(function()
                WorldMapFrame:RegisterCallback("WorldMapOnChangeMapID", function()
                    C_Timer.After(0, RefreshForViewedMap)
                end)
            end)
        end
    end
end

function WorldMapPins:Finalize()
    self:HookMap()
    self:Paint()
end

function WorldMapPins:DebugPlayerPin()
    -- Keep quest pins; add an extra test pin on top
    local mapId = C_Map.GetBestMapForUnit("player")
    local pos = mapId and C_Map.GetPlayerMapPosition(mapId, "player")
    if not pos then
        print("|cffff0000DQTC:|r Could not read player map position.")
        return
    end
    local x, y = pos:GetXY()
    self:AddPin({
        uiMapId = mapId,
        x = x * 100,
        y = y * 100,
        kind = "available",
        questId = 0,
    }, "DQTC test pin (you are here)")

    if WorldMapFrame and WorldMapFrame.SetMapID then
        if not WorldMapFrame:IsShown() then
            ShowUIPanel(WorldMapFrame)
        end
        WorldMapFrame:SetMapID(mapId)
    end

    C_Timer.After(0.1, function()
        local n = self:Paint()
        local st = self:GetStatus()
        print("|cff00ff00DQTC:|r Test pin map=" .. tostring(mapId)
            .. string.format(" (%.1f, %.1f) totalPins=%d", x * 100, y * 100, n)
            .. " pending=" .. tostring(st.pending)
            .. " lib=" .. tostring(st.lib)
            .. (lastError and (" err=" .. lastError) or " OK"))
        print("|cff00ff00DQTC:|r Run |cffffff00/dqtc markers|r if you only see the test bang — that rebuilds quest objective pins.")
    end)
end
