local ADDON_NAME = ...
local DQTC = _G[ADDON_NAME]
local Loader = DQTC.Loader

-- Date-gated holiday / world-event quests (Winter Veil, Midsummer, etc.).
local HolidayEvents = Loader:CreateModule("HolidayEvents")

-- European DD/MM windows (Classic Era). Some dates vary yearly; close enough for map pins.
local EVENT_DATES = {
    ["Winter Veil"] = {
        startDate = "15/12", startHour = 10, startMinute = 0,
        endDate = "2/1", endHour = 10, endMinute = 0,
    },
    ["Love is in the Air"] = {
        startDate = "11/2", startHour = 10, startMinute = 0,
        endDate = "15/2", endHour = 10, endMinute = 0,
    },
    ["Noblegarden"] = {
        startDate = "28/3", startHour = 0, startMinute = 1,
        endDate = "28/3", endHour = 23, endMinute = 59,
    },
    ["Children's Week"] = {
        startDate = "27/4", startHour = 10, startMinute = 0,
        endDate = "4/5", endHour = 10, endMinute = 0,
    },
    ["Midsummer"] = {
        startDate = "21/6", startHour = 4, startMinute = 0,
        endDate = "5/7", endHour = 4, endMinute = 0,
    },
    ["Harvest Festival"] = {
        startDate = "21/9", startHour = 0, startMinute = 1,
        endDate = "27/9", endHour = 23, endMinute = 59,
    },
    ["Hallow's End"] = {
        startDate = "18/10", startHour = 10, startMinute = 0,
        endDate = "1/11", endHour = 11, endMinute = 0,
    },
    ["Day of the Dead"] = {
        startDate = "1/11", startHour = 10, startMinute = 0,
        endDate = "3/11", endHour = 10, endMinute = 0,
    },
    ["Lunar Festival"] = {
        -- Approximate; refreshed from year table when possible
        startDate = "20/1", startHour = 6, startMinute = 0,
        endDate = "10/2", endHour = 6, endMinute = 0,
    },
}

-- Classic Era: these holidays did not exist / are disabled
local CLASSIC_DISABLED = {
    ["Brewfest"] = true,
    ["Pilgrim's Bounty"] = true,
}

-- Lunar Festival by 2-digit year (from community schedules)
local LUNAR_BY_YEAR = {
    ["24"] = { startDate = "3/2", startHour = 6, startMinute = 0, endDate = "23/2", endHour = 6, endMinute = 0 },
    ["25"] = { startDate = "28/1", startHour = 6, startMinute = 0, endDate = "17/2", endHour = 6, endMinute = 0 },
    ["26"] = { startDate = "16/2", startHour = 6, startMinute = 0, endDate = "9/3", endHour = 6, endMinute = 0 },
    ["27"] = { startDate = "5/2", startHour = 6, startMinute = 0, endDate = "19/2", endHour = 6, endMinute = 0 },
    ["28"] = { startDate = "24/1", startHour = 6, startMinute = 0, endDate = "14/2", endHour = 6, endMinute = 0 },
}

-- Darkmoon Faire: Monday start day by weekday of the 1st (1=Sunday)
local DMF_START_DAY_BY_FIRST_WEEKDAY = {
    [1] = 9,
    [2] = 8,
    [3] = 7,
    [4] = 6,
    [5] = 5,
    [6] = 4,
    [7] = 10,
}

local activeEvents = {}
local activeQuests = {}
local built = false

local function NowParts()
    local t = date("*t")
    return {
        year = t.year,
        month = t.month,
        monthDay = t.day,
        hour = t.hour,
        minute = t.min,
        wday = t.wday,
    }
end

local function ParseDM(s)
    if not s then
        return nil, nil
    end
    local d, m = strsplit("/", s)
    return tonumber(d), tonumber(m)
end

local function ParseHM(s)
    if not s then
        return nil, nil
    end
    local h, m = strsplit(":", s)
    return tonumber(h), tonumber(m)
end

--- Inclusive window using MMDDHHMM; supports year wrap (Dec→Jan).
local function WithinDates(startDay, startMonth, startHour, startMinute, endDay, endMonth, endHour, endMinute)
    if not startDay and not startMonth and not endDay and not endMonth then
        return true
    end
    local now = NowParts()
    startHour = startHour or 0
    startMinute = startMinute or 0
    endHour = endHour or 23
    endMinute = endMinute or 59

    local current = now.month * 1000000 + now.monthDay * 10000 + now.hour * 100 + now.minute
    local start = startMonth * 1000000 + startDay * 10000 + startHour * 100 + startMinute
    local finish = endMonth * 1000000 + endDay * 10000 + endHour * 100 + endMinute

    if start <= finish then
        return current >= start and current <= finish
    end
    return current >= start or current <= finish
end

local function EventActive(eventName, dates)
    if not dates then
        return false
    end
    local sd, sm = ParseDM(dates.startDate)
    local ed, em = ParseDM(dates.endDate)
    return WithinDates(sd, sm, dates.startHour, dates.startMinute, ed, em, dates.endHour, dates.endMinute)
end

local function IsDarkmoonFaireWeek()
    local now = NowParts()
    local first = date("*t", time({ year = now.year, month = now.month, day = 1, hour = 12 }))
    local startDay = DMF_START_DAY_BY_FIRST_WEEKDAY[first.wday]
    if not startDay then
        return false
    end
    local endDay = startDay + 7
    local day = now.monthDay
    if day == startDay and now.hour < 3 then
        return false
    end
    if day == endDay and now.hour >= 3 then
        return false
    end
    return day >= startDay and day <= endDay
end

function HolidayEvents:Refresh()
    wipe(activeEvents)
    wipe(activeQuests)

    local yearKey = string.format("%02d", NowParts().year % 100)
    if LUNAR_BY_YEAR[yearKey] then
        EVENT_DATES["Lunar Festival"] = LUNAR_BY_YEAR[yearKey]
    end

    for eventName, dates in pairs(EVENT_DATES) do
        if not CLASSIC_DISABLED[eventName] and EventActive(eventName, dates) then
            activeEvents[eventName] = true
        end
    end

    if IsDarkmoonFaireWeek() then
        activeEvents["Darkmoon Faire"] = true
    end

    local map = DQTC.Data and DQTC.Data.eventQuests
    if map then
        for questId, info in pairs(map) do
            local eventName = info.e
            if CLASSIC_DISABLED[eventName] then
                -- stay inactive
            elseif activeEvents[eventName] then
                local sd, sm = ParseDM(info.sd)
                local ed, em = ParseDM(info.ed)
                local sh, smin = ParseHM(info.sh)
                local eh, emin = ParseHM(info.eh)
                if WithinDates(sd, sm, sh, smin, ed, em, eh, emin) then
                    activeQuests[questId] = true
                end
            end
        end
    end

    built = true
end

function HolidayEvents:EnsureBuilt()
    if not built then
        self:Refresh()
    end
end

--- Non-event quests always allowed. Event quests only while their window is active.
function HolidayEvents:IsQuestAllowed(questId)
    self:EnsureBuilt()
    local map = DQTC.Data and DQTC.Data.eventQuests
    if not map or not map[questId] then
        return true
    end
    return activeQuests[questId] == true
end

function HolidayEvents:IsEventQuest(questId)
    local map = DQTC.Data and DQTC.Data.eventQuests
    return map and map[questId] ~= nil
end

function HolidayEvents:GetStats()
    self:EnsureBuilt()
    local nEvents, nQuests = 0, 0
    local names = {}
    for name in pairs(activeEvents) do
        nEvents = nEvents + 1
        names[#names + 1] = name
    end
    for _ in pairs(activeQuests) do
        nQuests = nQuests + 1
    end
    table.sort(names)
    return { events = nEvents, quests = nQuests, names = names }
end
