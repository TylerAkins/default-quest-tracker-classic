local ADDON_NAME = ...
local DQTC = _G[ADDON_NAME]
local Loader = DQTC.Loader

local CombatQueue = Loader:CreateModule("CombatQueue")

local queue = {}
local frame = CreateFrame("Frame")
local ticker = 0

frame:SetScript("OnUpdate", function(_, elapsed)
    if InCombatLockdown() then
        return
    end
    if #queue == 0 then
        return
    end
    ticker = ticker + elapsed
    if ticker < 0.05 then
        return
    end
    ticker = 0
    local fn = table.remove(queue, 1)
    if fn then
        pcall(fn)
    end
end)

function CombatQueue:Queue(fn)
    if type(fn) ~= "function" then
        return
    end
    if not InCombatLockdown() and #queue == 0 then
        pcall(fn)
        return
    end
    queue[#queue + 1] = fn
end

function CombatQueue:Clear()
    wipe(queue)
end
