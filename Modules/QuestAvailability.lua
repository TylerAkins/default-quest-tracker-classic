local ADDON_NAME = ...
local DQTC = _G[ADDON_NAME]
local Loader = DQTC.Loader

-- Built once at login/reload (and refreshed on turn-in): which quests this
-- character can still be offered. Encrypted Rune etc. are race/class locked.
local QuestAvailability = Loader:CreateModule("QuestAvailability")

local bit_band = bit.band

-- Questie raceKeys / UnitRace raceFile
local RACE_BITS = {
    Human = 1,
    Orc = 2,
    Dwarf = 4,
    NightElf = 8,
    Scourge = 16, -- Undead
    Tauren = 32,
    Gnome = 64,
    Troll = 128,
    Goblin = 256,
    BloodElf = 512,
    Draenei = 1024,
    Worgen = 2097152,
    Pandaren = 8388608,
}

-- Questie classKeys / UnitClass englishClass
local CLASS_BITS = {
    WARRIOR = 1,
    PALADIN = 2,
    HUNTER = 4,
    ROGUE = 8,
    PRIEST = 16,
    DEATHKNIGHT = 32,
    SHAMAN = 64,
    MAGE = 128,
    WARLOCK = 256,
    MONK = 512,
    DRUID = 1024,
    DEMONHUNTER = 2048,
    EVOKER = 4096,
}

local completed = {} -- [questId] = true
local offerable = {} -- [questId] = true (available ! candidates)
local playerRaceMask = 0
local playerClassMask = 0
local built = false

local function GetPlayerMasks()
    local _, raceFile = UnitRace("player")
    local _, classFile = UnitClass("player")
    playerRaceMask = (raceFile and RACE_BITS[raceFile]) or 0
    playerClassMask = (classFile and CLASS_BITS[classFile]) or 0
end

local function ScanCompleted()
    wipe(completed)
    local gotBulk = false

    if GetQuestsCompleted then
        local bulk = GetQuestsCompleted()
        if type(bulk) == "table" then
            for questId, v in pairs(bulk) do
                if v and type(questId) == "number" then
                    completed[questId] = true
                    gotBulk = true
                end
            end
        end
    end

    if C_QuestLog and C_QuestLog.GetAllCompletedQuestIDs then
        local ids = C_QuestLog.GetAllCompletedQuestIDs()
        if type(ids) == "table" and #ids > 0 then
            for _, questId in ipairs(ids) do
                completed[questId] = true
            end
            gotBulk = true
        end
    end

    -- Fallback only when bulk APIs unavailable (slow path)
    if not gotBulk then
        local quests = DQTC.Data and DQTC.Data.quests
        if quests then
            for questId in pairs(quests) do
                if DQTC.Compat.IsQuestFlaggedCompleted(questId) then
                    completed[questId] = true
                end
            end
        end
    end
end

local function RaceOk(requiredRaces)
    if not requiredRaces or requiredRaces == 0 then
        return true
    end
    if playerRaceMask == 0 then
        return true
    end
    return bit_band(requiredRaces, playerRaceMask) ~= 0
end

local function ClassOk(requiredClasses)
    if not requiredClasses or requiredClasses == 0 then
        return true
    end
    if playerClassMask == 0 then
        return true
    end
    return bit_band(requiredClasses, playerClassMask) ~= 0
end

local function IsCompleted(questId)
    if not questId then
        return false
    end
    if completed[questId] then
        return true
    end
    -- Live check + cache (bulk login scan can miss some Classic IDs)
    if DQTC.Compat.IsQuestFlaggedCompleted(questId) then
        completed[questId] = true
        return true
    end
    return false
end

local function AnyCompleted(list)
    if not list then
        return false
    end
    for _, id in ipairs(list) do
        if IsCompleted(id) then
            return true
        end
    end
    return false
end

local function AllCompleted(list)
    if not list or not list[1] then
        return true
    end
    for _, id in ipairs(list) do
        if not IsCompleted(id) then
            return false
        end
    end
    return true
end

local function IsInLog(questId)
    local QuestLogCache = Loader:ImportModule("QuestLogCache")
    return QuestLogCache:IsQuestInLog(questId)
end

-- Explicit allowlist only (see Database/Classic/SoftPrereqs.lua). Do NOT infer from
-- empty-objective breadcrumbs — that falsely unlocks Riverpaw Gnoll Bounty etc.
local function HasSoftPrereqs(questId)
    local soft = DQTC.Data and DQTC.Data.softPrereqs
    return soft and soft[questId] == true
end

-- preQuestSingle = OR of completed prereqs (unless softPrereqs allowlist).
local function PreQuestSingleOk(questId, pq)
    if not pq or not pq[1] then
        return true
    end
    if HasSoftPrereqs(questId) then
        return true
    end
    return AnyCompleted(pq)
end

--- Core doability (ignores level band / faction — those stay in DB getters).
local function IsDoable(questId, q)
    if not q then
        return false
    end
    if IsCompleted(questId) then
        return false
    end
    if IsInLog(questId) then
        return false
    end
    local HolidayEvents = Loader:ImportModule("HolidayEvents")
    if not HolidayEvents:IsQuestAllowed(questId) then
        return false
    end
    if not RaceOk(q.r) then
        return false
    end
    if not ClassOk(q.c) then
        return false
    end
    -- nextQuestInChain already done/in log → this breadcrumb is obsolete
    if q.nq and q.nq ~= 0 then
        if IsCompleted(q.nq) or IsInLog(q.nq) then
            return false
        end
    end
    -- exclusiveTo: another of the group is active or finished
    if q.ex then
        for _, exId in ipairs(q.ex) do
            if IsCompleted(exId) or IsInLog(exId) then
                return false
            end
        end
    end
    -- preQuestSingle: at least one completed (softPrereqs quests skip this gate)
    if q.pq and q.pq[1] then
        if not PreQuestSingleOk(questId, q.pq) then
            return false
        end
    elseif q.pg and q.pg[1] then
        -- preQuestGroup only when no preQuestSingle
        if not AllCompleted(q.pg) then
            return false
        end
    end
    -- Min required level to accept
    local req = q.rl or 1
    local playerLevel = UnitLevel("player") or 1
    if playerLevel < req then
        return false
    end
    return true
end

function QuestAvailability:Rebuild()
    Loader:ImportModule("HolidayEvents"):Refresh()
    GetPlayerMasks()
    ScanCompleted()
    wipe(offerable)
    local quests = DQTC.Data and DQTC.Data.quests
    if quests then
        for questId, q in pairs(quests) do
            if IsDoable(questId, q) then
                offerable[questId] = true
            end
        end
    end
    built = true
end

function QuestAvailability:EnsureBuilt()
    if not built then
        self:Rebuild()
    end
end

function QuestAvailability:RefreshOfferable()
    self:EnsureBuilt()
    wipe(offerable)
    local quests = DQTC.Data and DQTC.Data.quests
    if not quests then
        return
    end
    for questId, q in pairs(quests) do
        if IsDoable(questId, q) then
            offerable[questId] = true
        end
    end
end

function QuestAvailability:MarkCompleted(questId)
    if not questId then
        return
    end
    completed[questId] = true
    offerable[questId] = nil
    -- Re-evaluate quests that may unlock from this completion (prereqs)
    local quests = DQTC.Data and DQTC.Data.quests
    if not quests then
        return
    end
    for id, q in pairs(quests) do
        if not offerable[id] and not completed[id] and IsDoable(id, q) then
            offerable[id] = true
        elseif offerable[id] and not IsDoable(id, q) then
            offerable[id] = nil
        end
    end
end

function QuestAvailability:IsCompleted(questId)
    self:EnsureBuilt()
    return IsCompleted(questId)
end

function QuestAvailability:IsOfferable(questId)
    self:EnsureBuilt()
    -- offerable{} is the source of truth after Rebuild/RefreshOfferable.
    -- Do NOT re-run IsDoable for every DB scan — that hitchs the whole UI.
    return questId and offerable[questId] == true
end

function QuestAvailability:GetStats()
    self:EnsureBuilt()
    local nCompleted, nOfferable = 0, 0
    for _ in pairs(completed) do
        nCompleted = nCompleted + 1
    end
    for _ in pairs(offerable) do
        nOfferable = nOfferable + 1
    end
    return {
        completed = nCompleted,
        offerable = nOfferable,
        raceMask = playerRaceMask,
        classMask = playerClassMask,
    }
end

function QuestAvailability:GetOfferableSet()
    self:EnsureBuilt()
    return offerable
end
