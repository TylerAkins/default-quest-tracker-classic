local ADDON_NAME = ...
local DQTC = _G[ADDON_NAME]
local Loader = DQTC.Loader

local QuestNameplates = Loader:CreateModule("QuestNameplates")

local active = {}
local framePool = {}

local function AcquireFrame()
    local f = table.remove(framePool)
    if f then
        return f
    end
    f = CreateFrame("Frame")
    f:SetSize(16, 16)
    f.icon = f:CreateTexture(nil, "OVERLAY")
    f.icon:SetAllPoints()
    return f
end

local function ReleaseFrame(guid)
    local f = active[guid]
    if not f then
        return
    end
    f:Hide()
    f:SetParent(nil)
    active[guid] = nil
    framePool[#framePool + 1] = f
end

function QuestNameplates:Clear()
    for guid in pairs(active) do
        ReleaseFrame(guid)
    end
end

function QuestNameplates:UpdateUnit(unitToken)
    if not DQTC.Config:Get("showNameplates") then
        return
    end
    if DQTC.Config:Get("suppressIfQuestie") and DQTC.Compat.IsQuestieLoaded() then
        return
    end

    local guid = UnitGUID(unitToken)
    if not guid then
        return
    end
    local npcId = DQTC.Compat.GetCreatureIdFromGUID(guid)
    if not npcId then
        ReleaseFrame(guid)
        return
    end

    local DB = Loader:ImportModule("DB")
    local info = DB._npcIndex and DB._npcIndex[npcId]
    local kind = info and info.kind or DB:GetNpcIconType(npcId)
    if not kind then
        ReleaseFrame(guid)
        return
    end

    local nameplate = C_NamePlate.GetNamePlateForUnit(unitToken)
    if not nameplate then
        ReleaseFrame(guid)
        return
    end

    local f = active[guid] or AcquireFrame()
    active[guid] = f
    f:SetParent(nameplate)
    local scale = DQTC.Config:Get("nameplateScale") or 1
    f:SetSize(16 * scale, 16 * scale)
    f:ClearAllPoints()

    -- Left of the name text when possible; otherwise left of the unit frame
    local uf = nameplate.UnitFrame
    local nameRegion = uf and (uf.name or uf.Name)
    if nameRegion then
        f:SetPoint("RIGHT", nameRegion, "LEFT", DQTC.Config:Get("nameplateX") or -2, DQTC.Config:Get("nameplateY") or 0)
    elseif uf then
        f:SetPoint("RIGHT", uf, "LEFT", DQTC.Config:Get("nameplateX") or -2, DQTC.Config:Get("nameplateY") or 0)
    else
        f:SetPoint("RIGHT", nameplate, "LEFT", DQTC.Config:Get("nameplateX") or -2, DQTC.Config:Get("nameplateY") or 0)
    end

    local PinArt = Loader:ImportModule("PinArt")
    PinArt:PaintNameplateTexture(f.icon, kind, info and info.questId)
    f:Show()
end

function QuestNameplates:OnAdded(unitToken)
    self:UpdateUnit(unitToken)
end

function QuestNameplates:OnRemoved(unitToken)
    local guid = UnitGUID(unitToken)
    if guid then
        ReleaseFrame(guid)
    end
end

function QuestNameplates:RefreshAll()
    self:Clear()
    if not DQTC.Config:Get("showNameplates") then
        return
    end
    for _, plate in pairs(C_NamePlate.GetNamePlates() or {}) do
        local unit = plate.namePlateUnitToken or plate.UnitFrame and plate.UnitFrame.unit
        if unit then
            self:UpdateUnit(unit)
        end
    end
end
