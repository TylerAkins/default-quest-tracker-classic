local ADDON_NAME = ...
local DQTC = _G[ADDON_NAME]

DQTC.Loader = DQTC.Loader or {}
local Loader = DQTC.Loader

local modules = {}

function Loader:CreateModule(name)
    if modules[name] then
        return modules[name]
    end
    local mod = {}
    modules[name] = mod
    DQTC[name] = mod
    return mod
end

function Loader:ImportModule(name)
    return modules[name] or DQTC[name]
end

function Loader:GetModules()
    return modules
end
