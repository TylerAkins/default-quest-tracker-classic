local ADDON_NAME = ...
local DQTC = _G[ADDON_NAME]
local Loader = DQTC.Loader

local PinArt = Loader:CreateModule("PinArt")

-- Circular fills/rings we ship. Do not use TempPortraitAlphaMask as a texture:
-- that file is a mask (circular alpha, square RGB) and draws as a numbered box.
local MEDIA = "Interface\\AddOns\\" .. ADDON_NAME .. "\\Media\\"
local FILLED_CIRCLE = MEDIA .. "FilledCircle"
local THIN_RING = MEDIA .. "ThinRing"
local POI_ATLAS = MEDIA .. "PoiAtlas"
local POI_BADGE = MEDIA .. "PoiBadge"
local POI_BADGE_ACTIVE = MEDIA .. "PoiBadgeActive"
local ATLAS_COLS = 8

-- Same atlas the available-quest bangs use: brown/gold ring + overlay
local NUMBER_ICONS = "Interface\\WorldMap\\UI-QuestPoi-NumberIcons"
local AVAILABLE_ICON = "Interface\\GossipFrame\\AvailableQuestIcon"
local COMPLETE_ICON = "Interface\\GossipFrame\\ActiveQuestIcon"
local OBJECTIVE_ICON = "Interface\\QuestFrame\\UI-Quest-BulletPoint"
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

local function ClearMask(tex)
    if tex and tex.SetMask then
        pcall(function()
            tex:SetMask("")
        end)
    end
end

local function PaintBadge(tex, path)
    ClearMask(tex)
    tex:SetTexture(path)
    tex:SetTexCoord(0, 1, 0, 1)
    tex:SetBlendMode("BLEND")
    tex:SetVertexColor(1, 1, 1, 1)
    tex:Show()
    ApplySnap(tex)
end

local function PaintDisc(tex, path, r, g, b, a)
    ClearMask(tex)
    tex:SetTexture(path)
    tex:SetTexCoord(0, 1, 0, 1)
    tex:SetBlendMode("BLEND")
    tex:SetVertexColor(r, g, b, a or 1)
    tex:Show()
    ApplySnap(tex)
end

--- Idle 1-20: 0-19; idle ?: 20; active 1-20: 21-40; active ?: 41
local function AtlasIndex(kind, num, active)
    if kind == "turnin" then
        return active and 41 or 20
    end
    local n = tonumber(num) or 1
    if n < 1 then
        n = 1
    end
    if n > 20 then
        return nil
    end
    if active then
        return 20 + n
    end
    return n - 1
end

local function SetAtlasCell(tex, index)
    local col = index % ATLAS_COLS
    local row = math.floor(index / ATLAS_COLS)
    local s = 1 / ATLAS_COLS
    ClearMask(tex)
    tex:SetTexture(POI_ATLAS)
    tex:SetTexCoord(col * s, (col + 1) * s, row * s, (row + 1) * s)
    tex:SetBlendMode("BLEND")
    tex:SetVertexColor(1, 1, 1, 1)
    tex:Show()
    ApplySnap(tex)
end

local function SetRing(texture, selected)
    ClearMask(texture)
    texture:SetTexture(NUMBER_ICONS)
    local c = selected and RING_SELECTED or RING_NORMAL
    texture:SetTexCoord(c[1], c[2], c[3], c[4])
    texture:SetVertexColor(1, 1, 1, 1)
    texture:Show()
end

local function SetNumberLabel(fs, num, size, r, g, b)
    if not fs then
        return
    end
    num = tonumber(num) or 1
    local fontSize = math.max(11, math.floor(size * (num >= 10 and 0.42 or 0.56) + 0.5))
    fs:SetFont(FRIZ, fontSize, "OUTLINE")
    fs:SetText(tostring(num))
    fs:SetTextColor(r or 1, g or 0.82, b or 0)
    fs:SetShadowColor(0, 0, 0, 0)
    fs:SetShadowOffset(0, 0)
    fs:SetJustifyH("CENTER")
    fs:SetJustifyV("MIDDLE")
    fs:SetWidth(size)
    fs:SetHeight(size)
    fs:Show()
end

function PinArt:EnsureLayers(pin)
    if not pin.HighlightBorder then
        pin.HighlightBorder = pin:CreateTexture(nil, "BACKGROUND")
        pin.HighlightBorder:SetPoint("CENTER")
        pin.HighlightBorder:SetDrawLayer("BACKGROUND", 0)
        pin.HighlightBorder:Hide()
    end
    if not pin.Highlight then
        pin.Highlight = pin:CreateTexture(nil, "BACKGROUND")
        pin.Highlight:SetPoint("CENTER")
        pin.Highlight:SetDrawLayer("BACKGROUND", 1)
        pin.Highlight:Hide()
    end
    if not pin.PinRing then
        pin.PinRing = pin:CreateTexture(nil, "ARTWORK")
        pin.PinRing:SetPoint("CENTER")
        pin.PinRing:SetDrawLayer("ARTWORK", 0)
    end
    if not pin.Texture then
        pin.Texture = pin:CreateTexture(nil, "ARTWORK")
        pin.Texture:SetDrawLayer("ARTWORK", 1)
        pin.Texture:SetPoint("CENTER")
    end
    if not pin.Number then
        pin.Number = pin:CreateTexture(nil, "OVERLAY")
        pin.Number:SetPoint("CENTER")
        pin.Number:SetSize(18, 18)
    end
    if not pin.NumberText then
        pin.NumberText = pin:CreateFontString(nil, "OVERLAY")
        pin.NumberText:SetPoint("CENTER", pin, "CENTER", 0, -1)
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

--- Numbered disc from PoiAtlas (digit baked in, gold rim baked in).
function PinArt:SetupNumberedPoi(pin, questId, isEmphasized, size, kind)
    local DB = Loader:ImportModule("DB")
    local num = DB:GetQuestNumber(questId or 0)
    size = size or 22
    kind = kind or "objective"
    pin:SetSize(size, size)
    pin._poiSize = size
    pin._poiKind = kind
    self:EnsureLayers(pin)

    if pin.PinRing then
        pin.PinRing:Hide()
    end
    pin.Texture:ClearAllPoints()
    pin.Texture:SetPoint("CENTER")
    pin.Texture:SetSize(size, size)
    pin.Number:Hide()

    local index = AtlasIndex(kind, num, isEmphasized)
    if index ~= nil then
        SetAtlasCell(pin.Texture, index)
        self:HideNumberLabel(pin)
        return
    end

    PaintBadge(pin.Texture, isEmphasized and POI_BADGE_ACTIVE or POI_BADGE)
    local r, g, b
    if isEmphasized then
        r, g, b = 0.08, 0.06, 0.04
    else
        r, g, b = 1.0, 0.86, 0.22
    end
    SetNumberLabel(pin.NumberText, num, size, r, g, b)
    pin.NumberText:ClearAllPoints()
    pin.NumberText:SetPoint("CENTER", pin, "CENTER", 0, -1)
end

function PinArt:SetPinEmphasis(pin, emphasized)
    if not pin or pin.kind == "available" then
        return
    end
    self:SetupNumberedPoi(pin, pin.questId, emphasized, pin._poiSize or 22, pin.kind or pin._poiKind)
end

function PinArt:SetNumericBadge(texture, num)
    if not texture then
        return
    end
    PaintBadge(texture, POI_BADGE)
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
        if pin.PinRing then
            pin.PinRing:Hide()
        end
        pin.Texture:ClearAllPoints()
        pin.Texture:SetAllPoints(pin)
        SetRing(pin.Texture, isSuperTracked)
        pin.Number:SetTexture(AVAILABLE_ICON)
        pin.Number:SetTexCoord(0, 1, 0, 1)
        pin.Number:SetSize(size * 0.55, size * 0.55)
        pin.Number:Show()
        self:HideNumberLabel(pin)
        if pin.Highlight then
            pin.Highlight:Hide()
        end
        if pin.HighlightBorder then
            pin.HighlightBorder:Hide()
        end
        if not pin.Texture:GetTexture() then
            pin.Texture:SetTexture(AVAILABLE_ICON)
            pin.Texture:SetTexCoord(0, 1, 0, 1)
            pin.Number:Hide()
        end
    else
        self:SetupNumberedPoi(pin, questId, isSuperTracked, size, kind)
        self:SetupAreaHighlight(pin, kind, isSuperTracked, data.radius)
        if pin.Highlight then
            pin.Highlight:Hide()
        end
        if pin.HighlightBorder then
            pin.HighlightBorder:Hide()
        end
    end

    ApplySnap(pin.Texture)
    ApplySnap(pin.Number)
    ApplySnap(pin.Highlight)
end

--- Hover-only light-blue wash (QuestHelper-style area, retail icy blob) + thin black rim.
function PinArt:SetupAreaHighlight(pin, kind, isSuperTracked, radius)
    self:EnsureLayers(pin)
    if not radius or radius <= 0 or not DQTC.Config:Get("showAreaHighlights") then
        pin.radius = nil
        pin.Highlight:Hide()
        if pin.HighlightBorder then
            pin.HighlightBorder:Hide()
        end
        return
    end
    pin.radius = radius
    PaintDisc(pin.Highlight, FILLED_CIRCLE, 0.72, 0.90, 1.0, 0.22)
    PaintDisc(pin.HighlightBorder, THIN_RING, 0, 0, 0, 0.85)
    pin.Highlight:Hide()
    pin.HighlightBorder:Hide()
    local fallback = math.max(52, math.min(radius * 5, 120))
    pin.HighlightBorder:SetSize(fallback, fallback)
    pin.Highlight:SetSize(fallback, fallback)
end

function PinArt:ShowAreaHighlight(pin)
    if not pin or not pin.Highlight or not pin.radius then
        return
    end
    if not DQTC.Config:Get("showAreaHighlights") then
        return
    end
    self:UpdateAreaHighlightSize(pin)
    pin.Highlight:Show()
    if pin.HighlightBorder then
        pin.HighlightBorder:Show()
    end
end

function PinArt:HideAreaHighlight(pin)
    if pin and pin.Highlight then
        pin.Highlight:Hide()
    end
    if pin and pin.HighlightBorder then
        pin.HighlightBorder:Hide()
    end
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
    pin.Highlight:SetSize(diameter, diameter)
    if pin.HighlightBorder then
        pin.HighlightBorder:SetSize(diameter, diameter)
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

function PinArt:PaintNameplate(frame, icon, kind, questId, size)
    if not frame then
        if icon then
            SetRing(icon, false)
            icon:Show()
        end
        return
    end
    size = size or 16
    self:EnsureLayers(frame)
    if icon and icon ~= frame.Texture then
        icon:Hide()
    end
    if kind == "available" then
        self:SetupPin(frame, "available", questId, false, size, {})
        return
    end
    self:SetupNumberedPoi(frame, questId, false, size, kind)
    if frame.Highlight then
        frame.Highlight:Hide()
    end
end

function PinArt:PaintNameplateTexture(texture, kind, questId)
    self:PaintNameplate(nil, texture, kind, questId, 16)
end

--- Nameplates: same ring + gold number as map pins.
function PinArt:SetupNameplate(frame, kind, questId, size)
    self:EnsureLayers(frame)
    size = size or 24
    frame:SetSize(size, size)
    if frame.Number then
        frame.Number:Hide()
    end
    if frame.Highlight then
        frame.Highlight:Hide()
    end
    frame.Texture:Show()
    frame.Texture:ClearAllPoints()
    frame.Texture:SetAllPoints(frame)
    self:PaintNameplate(frame, frame.Texture, kind, questId, size)
end
