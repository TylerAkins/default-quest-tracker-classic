local ADDON_NAME = ...
local DQTC = _G[ADDON_NAME]
local Loader = DQTC.Loader

local Events = Loader:CreateModule("Events")

local listeners = {}
local frame = CreateFrame("Frame")
local debouncePending = {}
local debounceDelay = 0.15

frame:SetScript("OnEvent", function(_, event, ...)
    local list = listeners[event]
    if not list then
        return
    end
    for i = 1, #list do
        local entry = list[i]
        if entry.debounce then
            debouncePending[entry] = { event, ... }
        else
            pcall(entry.fn, event, ...)
        end
    end
end)

local updater = CreateFrame("Frame")
updater:SetScript("OnUpdate", function(_, elapsed)
    for entry, payload in pairs(debouncePending) do
        entry._elapsed = (entry._elapsed or 0) + elapsed
        if entry._elapsed >= (entry.debounce or debounceDelay) then
            entry._elapsed = 0
            debouncePending[entry] = nil
            pcall(entry.fn, unpack(payload))
        end
    end
end)

function Events:Register(event, fn, debounce)
    if not listeners[event] then
        listeners[event] = {}
        frame:RegisterEvent(event)
    end
    listeners[event][#listeners[event] + 1] = {
        fn = fn,
        debounce = debounce and (type(debounce) == "number" and debounce or debounceDelay) or false,
        _elapsed = 0,
    }
end

function Events:Fire(event, ...)
    local list = listeners[event]
    if not list then
        return
    end
    for i = 1, #list do
        pcall(list[i].fn, event, ...)
    end
end
