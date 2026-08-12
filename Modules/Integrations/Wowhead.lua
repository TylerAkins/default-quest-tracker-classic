local ADDON_NAME = ...
local DQTC = _G[ADDON_NAME]
local Loader = DQTC.Loader
local L = DQTC.L

local Wowhead = Loader:CreateModule("Wowhead")

local popup

local function EnsurePopup()
    if popup then
        return popup
    end

    local f = CreateFrame("Frame", "DQTC_WowheadPopup", UIParent, BackdropTemplateMixin and "BackdropTemplate")
    f:SetSize(480, 110)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetToplevel(true)
    f:EnableMouse(true)
    f:Hide()
    if f.SetBackdrop then
        f:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true,
            tileSize = 32,
            edgeSize = 32,
            insets = { left = 11, right = 12, top = 12, bottom = 11 },
        })
    end

    local title = f:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    title:SetPoint("TOP", 0, -18)
    title:SetWidth(440)
    title:SetText(L["COPY_WOWHEAD_HINT"] or "Press Ctrl+C to copy the Wowhead link.")
    f.title = title

    -- Wide input with insets so text/caret never draw past the border
    local box = CreateFrame("EditBox", "DQTC_WowheadEditBox", f, "InputBoxTemplate")
    box:SetPoint("TOPLEFT", 28, -42)
    box:SetPoint("TOPRIGHT", -28, -42)
    box:SetHeight(24)
    box:SetAutoFocus(true)
    box:SetMaxLetters(256)
    box:SetTextInsets(6, 6, 0, 0)
    box:SetFontObject(ChatFontNormal)
    box:SetScript("OnEscapePressed", function()
        f:Hide()
    end)
    box:SetScript("OnEnterPressed", function()
        f:Hide()
    end)
    box:SetScript("OnEditFocusLost", function(self)
        -- Keep focus while popup is open so Ctrl+C works
        if f:IsShown() then
            self:SetFocus()
            self:HighlightText()
        end
    end)
    box:SetScript("OnKeyDown", function(_, key)
        if key == "C" and IsControlKeyDown() then
            C_Timer.After(0.05, function()
                if f:IsShown() then
                    f:Hide()
                end
                if ActionStatus_DisplayMessage then
                    ActionStatus_DisplayMessage(L["WOWHEAD_COPIED"] or "Copied URL to clipboard", true)
                else
                    print("|cff00ff00DQTC:|r " .. (L["WOWHEAD_COPIED"] or "Copied URL to clipboard"))
                end
            end)
        end
    end)
    f.editBox = box

    local close = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    close:SetSize(100, 22)
    close:SetPoint("BOTTOM", 0, 16)
    close:SetText(CLOSE)
    close:SetScript("OnClick", function()
        f:Hide()
    end)

    f:SetScript("OnShow", function(self)
        PlaySound(SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPEN or 850)
        self.editBox:SetFocus()
        self.editBox:HighlightText()
    end)
    f:SetScript("OnHide", function()
        PlaySound(SOUNDKIT and SOUNDKIT.IG_MAINMENU_CLOSE or 851)
    end)

    table.insert(UISpecialFrames, "DQTC_WowheadPopup")
    popup = f
    return f
end

function Wowhead:GetUrl(questId)
    return "https://www.wowhead.com/classic/quest=" .. tostring(questId)
end

function Wowhead:ShowCopyPopup(questId)
    local f = EnsurePopup()
    local url = self:GetUrl(questId)
    f.editBox:SetText(url)
    f:Show()
    f.editBox:SetFocus()
    f.editBox:HighlightText()
end
