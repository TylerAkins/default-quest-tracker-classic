local ADDON_NAME = ...
local DQTC = _G[ADDON_NAME]
local Loader = DQTC.Loader
local L = DQTC.L

-- Soft GPS bridge for TomTom and Zygor (optional). Module name kept as
-- TomTomIntegration so existing ImportModule call sites keep working.
local Gps = Loader:CreateModule("TomTomIntegration")

local function Norm(x, y)
    if x == nil or y == nil then
        return nil, nil
    end
    if x > 1 or y > 1 then
        return x / 100, y / 100
    end
    return x, y
end

function Gps:HasTomTom()
    return TomTom and TomTom.AddWaypoint and true or false
end

function Gps:HasZygor()
    local zgv = _G.ZGV
    return zgv and zgv.Pointer and zgv.Pointer.SetWaypoint and true or false
end

function Gps:IsAvailable()
    return self:HasTomTom() or self:HasZygor()
end

function Gps:GetProviderName()
    if self:HasTomTom() then
        return "TomTom"
    end
    if self:HasZygor() then
        return "Zygor"
    end
    return nil
end

local function SetTomTomWaypoint(uiMapId, x, y, title)
    local char = DQTC.Config.char
    if char._tomtomWaypoint and TomTom.RemoveWaypoint then
        TomTom:RemoveWaypoint(char._tomtomWaypoint)
    end
    char._tomtomWaypoint = TomTom:AddWaypoint(uiMapId, x, y, {
        title = title or "Quest",
        crazy = true,
        from = "DQTC",
    })
    return true
end

local function SetZygorWaypoint(uiMapId, x, y, title)
    local pointer = _G.ZGV.Pointer
    local data = {
        title = title or "Quest",
        type = "manual",
        cleartype = true,
        findpath = true,
        onminimap = "always",
        overworld = true,
        showonedge = true,
    }
    if pointer.Icons and pointer.Icons.greendotbig then
        data.icon = pointer.Icons.greendotbig
    end
    pointer:SetWaypoint(uiMapId, x, y, data, true)
    return true
end

--- @param opts table|nil { silent = bool }
function Gps:SetWaypoint(uiMapId, x, y, title, opts)
    opts = opts or {}
    if not self:IsAvailable() then
        if not opts.silent then
            print("|cffffcc00" .. L["GPS_MISSING"] .. "|r")
        end
        return false
    end
    if not uiMapId or x == nil or y == nil then
        return false
    end
    x, y = Norm(x, y)
    if not x or not y then
        return false
    end

    if self:HasTomTom() then
        return SetTomTomWaypoint(uiMapId, x, y, title)
    end
    return SetZygorWaypoint(uiMapId, x, y, title)
end

local function GetStarterSpawn(DB, questId)
    local q = DB:GetQuest(questId)
    if not q then
        return nil
    end
    for _, npcId in ipairs(q.s or {}) do
        local spawns = DB:GetNpcSpawns(npcId)
        local sp = spawns and spawns[1]
        if sp and sp.m and sp.x and sp.y then
            return { uiMapId = sp.m, x = sp.x, y = sp.y }
        end
    end
    return nil
end

function Gps:SetWaypointForQuest(questId, opts)
    opts = opts or {}
    local DB = Loader:ImportModule("DB")
    local QuestLogCache = Loader:ImportModule("QuestLogCache")
    local quest = QuestLogCache:GetQuest(questId)
    local title = (quest and quest.title) or DB:GetQuestTitle(questId) or ("Quest " .. tostring(questId))

    local spawn = DB:GetBestWaypointSpawn(questId)
    if not spawn then
        spawn = GetStarterSpawn(DB, questId)
    end
    if not spawn then
        if not opts.silent then
            print("|cffffcc00No waypoint location found for this quest.|r")
        end
        return false
    end
    return self:SetWaypoint(spawn.uiMapId, spawn.x, spawn.y, title, opts)
end
