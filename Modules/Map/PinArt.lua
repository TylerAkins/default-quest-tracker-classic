local ADDON_NAME = ...
local DQTC = _G[ADDON_NAME]
local Loader = DQTC.Loader

local PinArt = Loader:CreateModule("PinArt")

-- Same atlas the available-quest bangs use: brown/gold ring + overlay
local NUMBER_ICONS = "Interface\\WorldMap\\UI-QuestPoi-NumberIcons"
local AVAILABLE_ICON = "Interface\\GossipFrame\\AvailableQuestIcon"
local COMPLETE_ICON = "Interface\\GossipFrame\\ActiveQuestIcon"
local OBJECTIVE_ICON = "Interface\\QuestFrame\\UI-Quest-BulletPoint"
local CIRCLE_MASK = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"
local SOLID_FILL = "Interface\\Buttons\\WHITE8X8"
local FRIZ = "Fonts\\FRIZQT__.TTF"

-- Empty rings from UI-QuestPoi-NumberIcons (Blizzard QuestUtils)
local RING_SELECTED = { 0.500, 0.625, 0.375, 0.5 }
local RING_NORMAL = { 0.875, 1, 0.375, 0.5 }

function PinArt:CalculateNumericTexCoords(index, yellow)
    local QUEST_POI_ICONS_PER_ROW = 8
    local QUEST_POI_ICON_SIZE = 256 / QUEST_POI_ICONS_PER_ROW
    local color = yellow and 0 or (QUEST_POI_ICON_SIZE * 4)
    local iconIndex = math.max((index or 1) - 1, 0) % 50
    local yOffset = color + math.floor(iconIndex / QUEST_POI_ICONS_PER_ROW) * QUEST_POI_ICON_SIZE
    local xOffset = (iconIndex % QUEST_POI_ICONS_PER_ROW) * QUEST_POI_ICON_SIZE
    return xOffset / 256, (xOffset + QUEST_POI_ICON_SIZE) / 256, yOffset / 256, (yOffset + QUEST_POI_ICON_SIZE) / 256
end

local function ApplySnap(tex)
    if tex and tex.SetSnapToPixelGrid then
        tex:SetSnapToPixelGrid(false)
        tex:SetTexelSnappingBias(0)
    end
end

local function SetRing(texture, selected)
    texture:SetTexture(NUMBER_ICONS)
    local c = selected and RING_SELECTED or RING_NORMAL
    texture:SetTexCoord(c[1], c[2], c[3], c[4])
    texture:SetVertexColor(1, 1, 1, 1)
    texture:Show()
end

local function SetNumberLabel(fs, num, size)
    if not fs then
        return
    end
    num = tonumber(num) or 1
    local fontSize = math.max(9, size * (num >= 10 and 0.38 or 0.48))
    fs:SetFont(FRIZ, fontSize, "")
    fs:SetText(tostring(num))
    fs:SetTextColor(1, 0.82, 0)
    fs:SetShadowColor(0, 0, 0, 0.85)
    fs:SetShadowOffset(1, -1)
    fs:SetJustifyH("CENTER")
    fs:SetJustifyV("MIDDLE")
    fs:Show()
end

function PinArt:EnsureLayers(pin)
    if not pin.Highlight then
        pin.Highlight = pin:CreateTexture(nil, "BACKGROUND")
        pin.Highlight:SetPoint("CENTER")
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
    if not pin.NumberText then
        pin.NumberText = pin:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        pin.NumberText:SetPoint("CENTER", pin, "CENTER", 0, 0)
    end
    if pin.texture and pin.texture ~= pin.Texture then
        pin.texture:Hide()
    end
end

function PinArt:HideNumberLabel(pin)
    if pin.NumberText then
        pin.NumberText:Hide()
        pin.NumberText:SetText("")
    end
end

--- Brown/gold circle identical to available-quest bangs, with a gold tracker number on top.
function PinArt:SetupNumberedPoi(pin, questId, isSuperTracked, size)
    local DB = Loader:ImportModule("DB")
    local num = DB:GetQuestNumber(questId or 0)
    pin:SetSize(size, size)
    SetRing(pin.Texture, isSuperTracked)
    pin.Number:Hide()
    SetNumberLabel(pin.NumberText, num, size)
end

function PinArt:SetupPin(pin, kind, questId, isSuperTracked, size, data)
    self:EnsureLayers(pin)
    size = size or 22
    data = data or {}

    pin.Texture:Show()
    pin.Texture:SetVertexColor(1, 1, 1, 1)
    pin.radius = nil

    if kind == "available" then
        pin:SetSize(size, size)
        SetRing(pin.Texture, isSuperTracked)
        pin.Number:SetTexture(AVAILABLE_ICON)
        pin.Number:SetTexCoord(0, 1, 0, 1)
        pin.Number:SetSize(size * 0.55, size * 0.55)
        pin.Number:Show()
        self:HideNumberLabel(pin)
        if pin.Highlight then
            pin.Highlight:Hide()
        end
        if not pin.Texture:GetTexture() then
            pin.Texture:SetTexture(AVAILABLE_ICON)
            pin.Texture:SetTexCoord(0, 1, 0, 1)
            pin.Number:Hide()
        end
    else
        self:SetupNumberedPoi(pin, questId, isSuperTracked, size)
        self:SetupAreaHighlight(pin, kind, isSuperTracked, data.radius)
    end

    ApplySnap(pin.Texture)
    ApplySnap(pin.Number)
    ApplySnap(pin.Highlight)
end

--- Soft round wash behind the POI. Kept small and circular on purpose.
function PinArt:SetupAreaHighlight(pin, kind, isSuperTracked, radius)
    self:EnsureLayers(pin)
    if not radius or radius <= 0 or not DQTC.Config:Get("showAreaHighlights") then
        pin.radius = nil
        pin.Highlight:Hide()
        return
    end
    pin.radius = radius
    pin.Highlight:SetTexture(SOLID_FILL)
    pin.Highlight:SetTexCoord(0, 1, 0, 1)
    if pin.Highlight.SetMask then
        pin.Highlight:SetMask(CIRCLE_MASK)
    else
        pin.Highlight:SetTexture(CIRCLE_MASK)
    end
    -- Gold wash for objectives; slightly greener when the quest is ready to turn in
    if kind == "turnin" then
        pin.Highlight:SetVertexColor(0.45, 0.95, 0.35, isSuperTracked and 0.28 or 0.20)
    else
        pin.Highlight:SetVertexColor(1.0, 0.84, 0.18, isSuperTracked and 0.28 or 0.18)
    end
    pin.Highlight:Show()
    local fallback = math.max(52, math.min(radius * 5, 120))
    pin.Highlight:SetSize(fallback, fallback)
end

function PinArt:GetMapPixelsPerPercent()
    local map = WorldMapFrame
    if not map or not map:IsShown() then
        return nil
    end
    local width
    if map.GetCanvasSize then
        width = map:GetCanvasSize()
    end
    if (not width or width <= 0) and map.ScrollContainer then
        local canvas = map.ScrollContainer.GetCanvas and map.ScrollContainer:GetCanvas()
        if canvas then
            width = canvas:GetWidth()
        else
            width = map.ScrollContainer:GetWidth()
        end
    end
    if not width or width <= 0 then
        width = map:GetWidth()
    end
    if width and width > 0 then
        return width / 100
    end
    return nil
end

function PinArt:UpdateAreaHighlightSize(pin)
    if not pin or not pin.Highlight or not pin.radius then
        return
    end
    local px = self:GetMapPixelsPerPercent()
    local visual = math.min(pin.radius, 11) * 0.7
    local diameter = visual * 2 * (px or 7)
    if diameter < 52 then
        diameter = 52
    elseif diameter > 140 then
        diameter = 140
    end
    -- Always circular — stretching to map aspect made huge ovals
    pin.Highlight:SetSize(diameter, diameter)
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

function PinArt:PaintNameplate(frame, icon, kind, questId, size)
    if not icon then
        return
    end
    size = size or 16
    icon:SetVertexColor(1, 1, 1, 1)
    if kind == "available" then
        icon:SetTexture(AVAILABLE_ICON)
        icon:SetTexCoord(0, 1, 0, 1)
        if frame and frame.NumberText then
            frame.NumberText:Hide()
        end
        return
    end
    SetRing(icon, true)
    if frame then
        if not frame.NumberText then
            frame.NumberText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            frame.NumberText:SetPoint("CENTER", frame, "CENTER", 0, 0)
        end
        local DB = Loader:ImportModule("DB")
        SetNumberLabel(frame.NumberText, DB:GetQuestNumber(questId or 0), size)
    end
    ApplySnap(icon)
end

function PinArt:PaintNameplateTexture(texture, kind, questId)
    self:PaintNameplate(nil, texture, kind, questId, 16)
end

--- Nameplates: same ring + gold number as map pins.
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
    self:PaintNameplate(frame, frame.Texture, kind, questId, size)
end
