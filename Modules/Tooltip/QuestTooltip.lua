local ADDON_NAME = ...
local DQTC = _G[ADDON_NAME]
local Loader = DQTC.Loader

local QuestTooltip = Loader:CreateModule("QuestTooltip")

local COLOR = {
    objective = { 0.85, 0.85, 0.85 },
    objectiveDone = { 0.40, 0.80, 0.40 },
    available = { 1.00, 0.82, 0.00 },
    turninReady = { 0.00, 1.00, 0.00 },
    turninProgress = { 0.65, 0.65, 0.65 },
    header = { 0.55, 0.75, 1.00 },
}

local lastGuid
local lastLineCount = 0

local function ShouldShow()
    return DQTC.Config:Get("showUnitTooltips") and true or false
end

local function FormatLevelPrefix(level, title)
    if DQTC.Config:Get("showQuestLevel") and level then
        return string.format("[%d] %s", level, title)
    end
    return title
end

local function CountTooltipLines(tooltip)
    local n = 0
    for i = 1, 50 do
        local left = _G[tooltip:GetName() .. "TextLeft" .. i]
        if left and left:IsShown() and left:GetText() then
            n = n + 1
        else
            break
        end
    end
    return n
end

function QuestTooltip:AddToTooltip(tooltip, npcId, force)
    if not ShouldShow() or not npcId or not tooltip then
        return false
    end
    if tooltip._dqtcQuestLines and not force then
        return false
    end

    local DB = Loader:ImportModule("DB")
    local lines = DB:GetNpcTooltipLines(npcId)
    if #lines == 0 then
        return false
    end

    tooltip._dqtcQuestLines = true
    tooltip:AddLine(" ")
    tooltip:AddLine("Quests", COLOR.header[1], COLOR.header[2], COLOR.header[3])

    for _, line in ipairs(lines) do
        if line.kind == "objective" then
            local c = line.finished and COLOR.objectiveDone or COLOR.objective
            tooltip:AddLine("  " .. (line.text or ""), c[1], c[2], c[3])
        elseif line.kind == "available" then
            local text = FormatLevelPrefix(line.level, line.text or "")
            tooltip:AddLine("  ! " .. text, COLOR.available[1], COLOR.available[2], COLOR.available[3])
        elseif line.kind == "turnin_ready" then
            local text = FormatLevelPrefix(line.level, line.text or "")
            tooltip:AddLine("  ? " .. text, COLOR.turninReady[1], COLOR.turninReady[2], COLOR.turninReady[3])
        elseif line.kind == "turnin_progress" then
            local text = FormatLevelPrefix(line.level, line.text or "")
            tooltip:AddLine("  ? " .. text, COLOR.turninProgress[1], COLOR.turninProgress[2], COLOR.turninProgress[3])
        end
    end

    tooltip:Show()
    lastLineCount = CountTooltipLines(tooltip)
    return true
end

local function ResolveNpcId(tooltip)
    local _, unit = tooltip:GetUnit()
    local guid = unit and UnitGUID(unit)
    if not guid then
        guid = UnitGUID("mouseover")
    end
    return DQTC.Compat.GetCreatureIdFromGUID(guid), guid
end

local function OnTooltipUnit(tooltip)
    if not ShouldShow() then
        return
    end
    local npcId, guid = ResolveNpcId(tooltip)
    if not npcId then
        return
    end
    -- Re-add if tooltip was rebuilt (line count dropped) or new unit
    local count = CountTooltipLines(tooltip)
    local force = (guid ~= lastGuid) or (count < lastLineCount) or (not tooltip._dqtcQuestLines)
    lastGuid = guid
    if force then
        tooltip._dqtcQuestLines = nil
    end
    QuestTooltip:AddToTooltip(tooltip, npcId, force)
end

function QuestTooltip:Initialize()
    if self._init then
        return
    end
    self._init = true

    if not GameTooltip then
        return
    end

    GameTooltip:HookScript("OnTooltipSetUnit", OnTooltipUnit)

    -- Tooltip can rebuild after OnTooltipSetUnit; cheap periodic re-check (not every frame work)
    local tipElapsed = 0
    GameTooltip:HookScript("OnUpdate", function(self, elapsed)
        tipElapsed = tipElapsed + (elapsed or 0)
        if tipElapsed < 0.2 then
            return
        end
        tipElapsed = 0
        if not ShouldShow() then
            return
        end
        local _, unit = self:GetUnit()
        if not unit then
            return
        end
        local npcId, guid = ResolveNpcId(self)
        if not npcId then
            return
        end
        local count = CountTooltipLines(self)
        if (not self._dqtcQuestLines) or guid ~= lastGuid or count < lastLineCount then
            self._dqtcQuestLines = nil
            lastGuid = guid
            QuestTooltip:AddToTooltip(self, npcId, true)
        end
    end)

    GameTooltip:HookScript("OnTooltipCleared", function(self)
        self._dqtcQuestLines = nil
        lastGuid = nil
        lastLineCount = 0
    end)

    GameTooltip:HookScript("OnHide", function(self)
        self._dqtcQuestLines = nil
        lastGuid = nil
        lastLineCount = 0
    end)
end
