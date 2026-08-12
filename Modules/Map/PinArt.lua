local ADDON_NAME = ...
local DQTC = _G[ADDON_NAME]
local Loader = DQTC.Loader

local PinArt = Loader:CreateModule("PinArt")

-- Quest POI atlas used for available/turn-in rings; objectives use simple dots
local NUMBER_ICONS = "Interface\\WorldMap\\UI-QuestPoi-NumberIcons"
local AVAILABLE_ICON = "Interface\\GossipFrame\\AvailableQuestIcon"
local COMPLETE_ICON = "Interface\\GossipFrame\\ActiveQuestIcon"
local OBJECTIVE_ICON = "Interface\\QuestFrame\\UI-Quest-BulletPoint"

function PinArt:CalculateNumericTexCoords(index, yellow)
    local QUEST_POI_ICONS_PER_ROW = 8
    local QUEST_POI_ICON_SIZE = 256 / QUEST_POI_ICONS_PER_ROW
    local color = yellow and 0 or (QUEST_POI_ICON_SIZE * 4)
    local iconIndex = math.max((index or 1) - 1, 0) % 50
    local yOffset = color + math.floor(iconIndex / QUEST_POI_ICONS_PER_ROW) * QUEST_POI_ICON_SIZE
    local xOffset = (iconIndex % QUEST_POI_ICONS_PER_ROW) * QUEST_POI_ICON_SIZE
    return xOffset / 256, (xOffset + QUEST_POI_ICON_SIZE) / 256, yOffset / 256, (yOffset + QUEST_POI_ICON_SIZE) / 256
end

-- Ensure pin has the layered textures PinArt expects
function PinArt:EnsureLayers(pin)
    if not pin.Texture then
        pin.Texture = pin:CreateTexture(nil, "ARTWORK")
        pin.Texture:SetAllPoints(pin)
    end
    if not pin.Number then
        pin.Number = pin:CreateTexture(nil, "OVERLAY")
        pin.Number:SetPoint("CENTER")
        pin.Number:SetSize(18, 18)
    end
    -- Hide legacy single texture if present
    if pin.texture and pin.texture ~= pin.Texture then
        pin.texture:Hide()
    end
end

function PinArt:SetupPin(pin, kind, questId, isSuperTracked, size)
    self:EnsureLayers(pin)
    size = size or 22

    pin.Texture:Show()
    pin.Texture:SetVertexColor(1, 1, 1, 1)

    if kind == "available" or kind == "turnin" then
        -- Circular POI ring + ! (available) or ? (turn-in)
        pin:SetSize(size, size)
        pin.Texture:SetTexture(NUMBER_ICONS)
        if isSuperTracked then
            pin.Texture:SetTexCoord(0.500, 0.625, 0.375, 0.5) -- yellow glow ring
        else
            pin.Texture:SetTexCoord(0.875, 1, 0.375, 0.5) -- brown ring
        end
        pin.Number:SetTexture(kind == "available" and AVAILABLE_ICON or COMPLETE_ICON)
        pin.Number:SetTexCoord(0, 1, 0, 1)
        pin.Number:SetSize(size * 0.55, size * 0.55)
        pin.Number:Show()
    else
        -- Objectives: small unmarked dots (Dugi-style) — numbers clutter dense spawn clusters
        local dotSize = isSuperTracked and (size * 0.72) or (size * 0.55)
        pin:SetSize(dotSize, dotSize)
        pin.Number:Hide()
        pin.Texture:SetTexture(OBJECTIVE_ICON)
        pin.Texture:SetTexCoord(0, 1, 0, 1)
        if isSuperTracked then
            pin.Texture:SetVertexColor(1, 0.92, 0.25, 1)
        else
            pin.Texture:SetVertexColor(1, 0.82, 0.10, 0.92)
        end
    end

    if pin.Texture.SetSnapToPixelGrid then
        pin.Texture:SetSnapToPixelGrid(false)
        pin.Texture:SetTexelSnappingBias(0)
        pin.Number:SetSnapToPixelGrid(false)
        pin.Number:SetTexelSnappingBias(0)
    end

    -- Fallback if POI atlas missing on this client (available/turnin only)
    if (kind == "available" or kind == "turnin") and not pin.Texture:GetTexture() then
        pin.Texture:SetTexture(kind == "available" and AVAILABLE_ICON or COMPLETE_ICON)
        pin.Texture:SetTexCoord(0, 1, 0, 1)
        pin.Number:Hide()
    end
end

function PinArt:GetNameplateIcon(kind)
    if kind == "available" then
        return AVAILABLE_ICON
    end
    if kind == "turnin" then
        return COMPLETE_ICON
    end
    return OBJECTIVE_ICON
end

--- Nameplates need simpler art than map pins — one clear glyph, no stacked layers.
function PinArt:SetupNameplate(frame, kind, questId, size)
    self:EnsureLayers(frame)
    size = size or 24
    frame:SetSize(size, size)
    frame.Number:Hide()
    frame.Texture:Show()
    frame.Texture:SetVertexColor(1, 1, 1, 1)
    frame.Texture:ClearAllPoints()
    frame.Texture:SetAllPoints(frame)

    if kind == "available" then
        frame.Texture:SetTexture(AVAILABLE_ICON)
        frame.Texture:SetTexCoord(0, 1, 0, 1)
    elseif kind == "turnin" then
        frame.Texture:SetTexture(COMPLETE_ICON)
        frame.Texture:SetTexCoord(0, 1, 0, 1)
    else
        -- Yellow numbered POI cell already includes ring + digit (readable at small size)
        frame.Texture:SetTexture(NUMBER_ICONS)
        local DB = Loader:ImportModule("DB")
        local num = DB:GetQuestNumber(questId or 0)
        frame.Texture:SetTexCoord(self:CalculateNumericTexCoords(num, true))
    end

    if frame.Texture.SetSnapToPixelGrid then
        frame.Texture:SetSnapToPixelGrid(false)
        frame.Texture:SetTexelSnappingBias(0)
    end
end
