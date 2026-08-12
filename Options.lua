local ADDON_NAME = ...
local DQTC = _G[ADDON_NAME]
local L = DQTC.L

local Options = {}
DQTC.Options = Options

local category

local TOGGLES = {
    { key = "enableTracker", label = "ENABLE_TRACKER" },
    { key = "autoTrackQuests", label = "AUTO_TRACK" },
    { key = "trackerLocked", label = "LOCK_TRACKER" },
    { key = "showQuestLevel", label = "SHOW_QUEST_LEVEL" },
    { key = "hideCompletedObjectives", label = "HIDE_COMPLETED" },
    { key = "showQuestMarkers", label = "SHOW_MARKERS" },
    { key = "showAvailable", label = "SHOW_AVAILABLE" },
    { key = "showObjectives", label = "SHOW_OBJECTIVES" },
    { key = "showTurnins", label = "SHOW_TURNINS" },
    { key = "showTrivial", label = "SHOW_TRIVIAL" },
    { key = "showWorldMap", label = "SHOW_WORLDMAP" },
    { key = "showMinimap", label = "SHOW_MINIMAP" },
    { key = "showNameplates", label = "SHOW_NAMEPLATES" },
    { key = "showUnitTooltips", label = "SHOW_UNIT_TOOLTIPS" },
    { key = "suppressIfQuestie", label = "SUPPRESS_IF_QUESTIE" },
}

function Options:BuildCanvas(panel)
    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText(L["OPTIONS_TITLE"])

    local y = -48
    for _, entry in ipairs(TOGGLES) do
        local cb = CreateFrame("CheckButton", "DQTC_Opt_" .. entry.key, panel, "InterfaceOptionsCheckButtonTemplate")
        cb:SetPoint("TOPLEFT", 16, y)
        cb.Text:SetText(L[entry.label])
        cb:SetChecked(DQTC.Config:Get(entry.key) and true or false)
        cb:SetScript("OnClick", function(self)
            DQTC.Config:Set(entry.key, self:GetChecked() and true or false)
        end)
        y = y - 26
    end

    local reset = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    reset:SetSize(180, 24)
    reset:SetPoint("TOPLEFT", 16, y - 12)
    reset:SetText(L["RESET_POSITION"])
    reset:SetScript("OnClick", function()
        DQTC.Loader:ImportModule("TrackerPosition"):Reset()
    end)

    local hint = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    hint:SetPoint("TOPLEFT", reset, "BOTTOMLEFT", 0, -12)
    hint:SetWidth(400)
    hint:SetJustifyH("LEFT")
    hint:SetText("Slash: /dqtc  |  unlock  |  lock  |  reset  |  markers\nTracker: mouse wheel to scroll when content exceeds ~55% screen height.")
end

function Options:Initialize()
    if self._init then
        return
    end

    local panel = CreateFrame("Frame")
    panel.name = L["OPTIONS_TITLE"]
    self:BuildCanvas(panel)
    self.panel = panel
    self._init = true

    if Settings and Settings.RegisterCanvasLayoutCategory then
        category = Settings.RegisterCanvasLayoutCategory(panel, L["OPTIONS_TITLE"])
        category.ID = L["OPTIONS_TITLE"]
        Settings.RegisterAddOnCategory(category)
        self.category = category
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(panel)
    end
end

function Options:Open()
    if Settings and Settings.OpenToCategory and self.category then
        Settings.OpenToCategory(self.category.ID or L["OPTIONS_TITLE"])
        return
    end
    if InterfaceOptionsFrame_OpenToCategory and self.panel then
        InterfaceOptionsFrame_OpenToCategory(self.panel)
        InterfaceOptionsFrame_OpenToCategory(self.panel)
    end
end
