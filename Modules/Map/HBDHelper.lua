local ADDON_NAME = ...
local DQTC = _G[ADDON_NAME]
local Loader = DQTC.Loader

-- Resolve HereBeDragons from standalone addon, our embed, or Questie's embed.
local HBDHelper = Loader:CreateModule("HBDHelper")

local CANDIDATES = {
    { "HereBeDragons-2.0", "HereBeDragons-Pins-2.0" },                 -- standalone Lib: HereBeDragons
    { "HereBeDragons-DQTC-2.0", "HereBeDragons-DQTC-Pins-2.0" },       -- embedded in DQTC
    { "HereBeDragonsQuestie-2.0", "HereBeDragonsQuestie-Pins-2.0" },   -- Questie embed
}

local cachedHBD, cachedPins, cachedName, cachedError

function HBDHelper:ResetCache()
    cachedHBD, cachedPins, cachedName, cachedError = nil, nil, nil, nil
end

function HBDHelper:Get()
    if cachedPins and cachedPins.AddWorldMapIconMap and cachedPins.AddMinimapIconMap then
        return cachedHBD, cachedPins, cachedName
    end

    if not LibStub then
        cachedError = "LibStub missing"
        return nil, nil, nil
    end

    local tried = {}
    for _, pair in ipairs(CANDIDATES) do
        local hbdName, pinsName = pair[1], pair[2]
        local hbd = LibStub(hbdName, true)
        local pins = LibStub(pinsName, true)
        tried[#tried + 1] = pinsName
        if hbd and pins and pins.AddWorldMapIconMap and pins.AddMinimapIconMap
            and pins.RemoveAllWorldMapIcons and pins.RemoveAllMinimapIcons then
            cachedHBD, cachedPins, cachedName, cachedError = hbd, pins, pinsName, nil
            return cachedHBD, cachedPins, cachedName
        end
    end

    cachedError = "No usable HBD pins lib (tried " .. table.concat(tried, ", ") .. ")"
    return nil, nil, nil
end

function HBDHelper:GetStatus()
    local hbd, pins, name = self:Get()
    return {
        ok = pins ~= nil,
        name = name,
        error = cachedError,
        hasAddWorld = pins and pins.AddWorldMapIconMap and true or false,
        hasAddMini = pins and pins.AddMinimapIconMap and true or false,
    }
end

function HBDHelper:GetShowParentFlag()
    return HBD_PINS_WORLDMAP_SHOW_PARENT or 1
end

function HBDHelper:GetShowCurrentFlag()
    return HBD_PINS_WORLDMAP_SHOW_CURRENT or -1
end
