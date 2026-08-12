local ADDON_NAME = ...
local DQTC = _G[ADDON_NAME]
local Loader = DQTC.Loader

local ZoneMap = Loader:CreateModule("ZoneMap")

local parentByMap = {
    [1415] = 947,
    [1414] = 947,
}

function ZoneMap:GetParentMap(uiMapId)
    if not uiMapId then
        return nil
    end
    if parentByMap[uiMapId] then
        return parentByMap[uiMapId]
    end
    if C_Map and C_Map.GetMapInfo then
        local info = C_Map.GetMapInfo(uiMapId)
        return info and info.parentMapID or nil
    end
    return nil
end

function ZoneMap:GetPlayerMapId()
    if C_Map and C_Map.GetBestMapForUnit then
        return C_Map.GetBestMapForUnit("player")
    end
    return nil
end

function ZoneMap:GetMapParentChain(uiMapId)
    local chain = {}
    local seen = {}
    local id = uiMapId
    while id and not seen[id] do
        seen[id] = true
        chain[#chain + 1] = id
        id = self:GetParentMap(id)
    end
    return chain
end

-- True when spawn and current maps are the same, or either is an ancestor of the other
-- (e.g. Dun Morogh 1426 spawn while player is in Coldridge 427).
function ZoneMap:IsMapRelevant(spawnMapId, currentMapId)
    if not spawnMapId or not currentMapId then
        return true
    end
    if spawnMapId == currentMapId then
        return true
    end

    local parent = self:GetParentMap(currentMapId)
    while parent do
        if parent == spawnMapId then
            return true
        end
        parent = self:GetParentMap(parent)
    end

    parent = self:GetParentMap(spawnMapId)
    while parent do
        if parent == currentMapId then
            return true
        end
        parent = self:GetParentMap(parent)
    end

    return false
end
