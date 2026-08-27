local ADDON_NAME = ...
local DQTC = _G[ADDON_NAME]
local Loader = DQTC.Loader

local PinArt = Loader:CreateModule("PinArt")

-- Quest POI atlas: numbered rings for tracked quests; ! / ? for available / leftover fallbacks
local NUMBER_ICONS = "Interface\\WorldMap\\UI-QuestPoi-NumberIcons"
local AVAILABLE_ICON = "Interface\\GossipFrame\\AvailableQuestIcon"
local COMPLETE_ICON = "Interface\\GossipFrame\\ActiveQuestIcon"
local OBJECTIVE_ICON = "Interface\\QuestFrame\\UI-Quest-BulletPoint"
local AREA_HIGHLIGHT = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"

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
    if not pin.Highlight then
        pin.Highlight = pin:CreateTexture(nil, "BACKGROUND")
        pin.Highlight:SetPoint("CENTER")
        pin.Highlight:SetTexture(AREA_HIGHLIGHT)
        pin.Highlight:Hide()
    end
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

local function ApplySnap(tex)
    if tex and tex.SetSnapToPixelGrid then
        tex:SetSnapToPixelGrid(false)
        tex:SetTexelSnappingBias(0)
    end
end

function PinArt:SetupNumberedPoi(pin, questId, isSuperTracked, size)
    local DB = Loader:ImportModule("DB")
    local num = DB:GetQuestNumber(questId or 0)
    pin:SetSize(size, size)
    pin.Texture:Show()
    pin.Texture:SetTexture(NUMBER_ICONS)
    pin.Texture:SetTexCoord(self:CalculateNumericTexCoords(num, isSuperTracked))
    pin.Texture:SetVertexColor(1, 1, 1, 1)
    pin.Number:Hide()
end

function PinArt:SetupPin(pin, kind, questId, isSuperTracked, size, data)
    self:EnsureLayers(pin)
    size = size or 22
    data = data or {}

    pin.Texture:Show()
    pin.Texture:SetVertexColor(1, 1, 1, 1)
    pin.radius = nil

    if kind == "available" then
        -- Untracked offers stay as bangs; they are not tracker steps
        pin:SetSize(size, size)
        pin.Texture:SetTexture(NUMBER_ICONS)
        if isSuperTracked then
            pin.Texture:SetTexCoord(0.500, 0.625, 0.375, 0.5)
        else
            pin.Texture:SetTexCoord(0.875, 1, 0.375, 0.5)
        end
        pin.Number:SetTexture(AVAILABLE_ICON)
        pin.Number:SetTexCoord(0, 1, 0, 1)
        pin.Number:SetSize(size * 0.55, size * 0.55)
        pin.Number:Show()
        if pin.Highlight then
            pin.Highlight:Hide()
        end
        if not pin.Texture:GetTexture() then
            pin.Texture:SetTexture(AVAILABLE_ICON)
            pin.Texture:SetTexCoord(0, 1, 0, 1)
            pin.Number:Hide()
        end
    else
        -- Tracked objectives / turn-ins: numbered POI matching the tracker (1) (2) (3)
        self:SetupNumberedPoi(pin, questId, isSuperTracked or kind == "turnin", size)
        self:SetupAreaHighlight(pin, kind, isSuperTracked, data.radius)
    end

    ApplySnap(pin.Texture)
    ApplySnap(pin.Number)
    ApplySnap(pin.Highlight)
end

--- Geographic blob behind a numbered pin. `radius` is map-percent (same units as spawn x/y).
function PinArt:SetupAreaHighlight(pin, kind, isSuperTracked, radius)
    self:EnsureLayers(pin)
    if not radius or radius <= 0 or not DQTC.Config:Get("showAreaHighlights") then
        pin.radius = nil
        pin.Highlight:Hide()
        return
    end
    pin.radius = radius
    pin.Highlight:SetTexture(AREA_HIGHLIGHT)
    pin.Highlight:Show()
    if kind == "turnin" then
        if isSuperTracked then
            pin.Highlight:SetVertexColor(0.35, 1, 0.35, 0.45)
        else
            pin.Highlight:SetVertexColor(0.25, 0.95, 0.30, 0.35)
        end
    else
        if isSuperTracked then
            pin.Highlight:SetVertexColor(1, 0.92, 0.20, 0.48)
        else
            pin.Highlight:SetVertexColor(1, 0.78, 0.12, 0.36)
        end
    end
    -- Fallback size until the world map reports canvas pixels (minimap / unopened map)
    local fallback = math.max(40, radius * 6)
    pin.Highlight:SetSize(fallback, fallback)
end

function PinArt:GetMapPixelsPerPercent()
    local map = WorldMapFrame
    if not map or not map:IsShown() then
        return nil
    end
    local width, height
    if map.GetCanvasSize then
        width, height = map:GetCanvasSize()
    end
    if (not width or width <= 0) and map.ScrollContainer then
        local canvas = map.ScrollContainer.GetCanvas and map.ScrollContainer:GetCanvas()
        if canvas then
            width, height = canvas:GetWidth(), canvas:GetHeight()
        else
            width, height = map.ScrollContainer:GetWidth(), map.ScrollContainer:GetHeight()
        end
    end
    if not width or width <= 0 then
        width, height = map:GetWidth(), map:GetHeight()
    end
    local scale = 1
    if map.GetCanvasScale then
        scale = map:GetCanvasScale() or 1
    elseif map.ScrollContainer and map.ScrollContainer.GetCanvasScale then
        scale = map.ScrollContainer:GetCanvasScale() or 1
    end
    -- Canvas size is typically unscaled map pixels; multiply by zoom so the blob covers geography.
    if width and width > 0 then
        return (width * scale) / 100, (height * scale) / 100
    end
    return nil
end

function PinArt:UpdateAreaHighlightSize(pin)
    if not pin or not pin.Highlight or not pin.radius then
        return
    end
    local px, py = self:GetMapPixelsPerPercent()
    if not px then
        return
    end
    local diameter = pin.radius * 2 * px
    -- Keep the blob round using X scale; clamp so it stays usable at extreme zooms
    if diameter < 28 then
        diameter = 28
    elseif diameter > 900 then
        diameter = 900
    end
    pin.Highlight:SetSize(diameter, diameter * ((py and px > 0) and (py / px) or 1))
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

function PinArt:PaintNameplateTexture(texture, kind, questId)
    if not texture then
        return
    end
    texture:SetVertexColor(1, 1, 1, 1)
    if kind == "available" then
        texture:SetTexture(AVAILABLE_ICON)
        texture:SetTexCoord(0, 1, 0, 1)
        return
    end
    -- Tracked objectives and turn-ins use the same (1) (2) (3) as the tracker
    texture:SetTexture(NUMBER_ICONS)
    local DB = Loader:ImportModule("DB")
    local num = DB:GetQuestNumber(questId or 0)
    texture:SetTexCoord(self:CalculateNumericTexCoords(num, true))
    ApplySnap(texture)
end

--- Nameplates need simpler art than map pins — one clear glyph, no stacked layers.
function PinArt:SetupNameplate(frame, kind, questId, size)
    self:EnsureLayers(frame)
    size = size or 24
    frame:SetSize(size, size)
    frame.Number:Hide()
    if frame.Highlight then
        frame.Highlight:Hide()
    end
    frame.Texture:Show()
    frame.Texture:ClearAllPoints()
    frame.Texture:SetAllPoints(frame)
    self:PaintNameplateTexture(frame.Texture, kind, questId)
end
