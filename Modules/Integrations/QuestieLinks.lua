local ADDON_NAME = ...
local DQTC = _G[ADDON_NAME]
local Loader = DQTC.Loader

local QuestieLinks = Loader:CreateModule("QuestieLinks")

local initialized = false

local function HasModifierKeyDown()
    return IsShiftKeyDown() or IsControlKeyDown() or IsAltKeyDown()
end

function QuestieLinks:HandleHyperlinkClick(link, button)
    if button ~= "LeftButton" or HasModifierKeyDown() or type(link) ~= "string" then
        return false
    end

    local questId = tonumber(link:match("^questie:(%d+):.+$"))
    if not questId or not DQTC.Compat.ShowQuestInLog(questId) then
        return false
    end

    if ItemRefTooltip and ItemRefTooltip.Hide then
        ItemRefTooltip:Hide()
    end

    return true
end

local function HookChatFrame(chatFrame)
    if not chatFrame or chatFrame._dqtcQuestieLinksHooked then
        return
    end

    chatFrame._dqtcQuestieLinksHooked = true
    chatFrame:HookScript("OnHyperlinkClick", function(_, link, _, button)
        QuestieLinks:HandleHyperlinkClick(link, button)
    end)
end

function QuestieLinks:Initialize()
    if initialized then
        return
    end
    initialized = true

    if ChatFrameMixin and ChatFrameMixin.OnHyperlinkClick then
        for i = 1, (NUM_CHAT_WINDOWS or 10) do
            HookChatFrame(_G["ChatFrame" .. i])
        end
    elseif ChatFrame_OnHyperlinkShow and hooksecurefunc then
        hooksecurefunc("ChatFrame_OnHyperlinkShow", function(_, link, _, button)
            QuestieLinks:HandleHyperlinkClick(link, button)
        end)
    end
end
