local ADDON_NAME = ...
local DQTC = _G[ADDON_NAME]

DQTC.Config = DQTC.Config or {}
local Config = DQTC.Config

local defaults = {
    profile = {
        enableTracker = true,
        hideDuringCombat = false,
        autoTrackQuests = true,
        trackerLocked = true,
        trackerScale = 1.0,
        -- Retail-like: tracker viewport max height as fraction of screen (scroll beyond this)
        trackerMaxHeightPct = 0.55,
        hideCompletedObjectives = false,
        showQuestLevel = false,
        sortMode = "log", -- log | zone | level | proximity
        showQuestMarkers = true,
        showAvailable = true,
        showObjectives = true,
        showTurnins = true,
        showTrivial = false,
        showWorldMap = true,
        showMinimap = true,
        showNameplates = true,
        showUnitTooltips = true,
        mapScale = 1.0,
        minimapScale = 1.0,
        nameplateScale = 1.0,
        nameplateX = -2,
        nameplateY = 0,
        -- Default off so markers work even when Questie is installed but unused for maps
        suppressIfQuestie = false,
        tomTomOnFocus = false,
    },
    char = {
        autoUntracked = {},
        trackedQuests = {},
        trackerPosition = nil,
        superTrackedQuestId = nil,
        collapsed = false,
    },
}

local function DeepCopy(src)
    if type(src) ~= "table" then
        return src
    end
    local dst = {}
    for k, v in pairs(src) do
        dst[k] = DeepCopy(v)
    end
    return dst
end

local function MergeDefaults(target, source)
    for k, v in pairs(source) do
        if type(v) == "table" then
            if type(target[k]) ~= "table" then
                target[k] = DeepCopy(v)
            else
                MergeDefaults(target[k], v)
            end
        elseif target[k] == nil then
            target[k] = v
        end
    end
end

function Config:Initialize()
    DQTC_DB = DQTC_DB or {}
    DQTC_CharDB = DQTC_CharDB or {}
    MergeDefaults(DQTC_DB, { profile = defaults.profile })
    MergeDefaults(DQTC_CharDB, defaults.char)

    -- One-time migrations for existing SavedVariables
    if not DQTC_DB._migrated_v2 then
        DQTC_DB.profile = DQTC_DB.profile or {}
        -- Markers were blocked for anyone with Questie installed; re-enable by default
        DQTC_DB.profile.suppressIfQuestie = false
        if DQTC_DB.profile.sortMode == "zone" then
            DQTC_DB.profile.sortMode = "log"
        end
        if DQTC_DB.profile.showQuestLevel == nil then
            DQTC_DB.profile.showQuestLevel = false
        end
        DQTC_DB._migrated_v2 = true
    end

    -- Nameplate icon moved from above-name to left-of-name
    if not DQTC_DB._migrated_nameplate_left then
        DQTC_DB.profile = DQTC_DB.profile or {}
        if DQTC_DB.profile.nameplateX == -17 and DQTC_DB.profile.nameplateY == -7 then
            DQTC_DB.profile.nameplateX = -2
            DQTC_DB.profile.nameplateY = 0
        end
        DQTC_DB._migrated_nameplate_left = true
    end

    self.db = DQTC_DB
    self.char = DQTC_CharDB
end

function Config:Get(key)
    return self.db.profile[key]
end

function Config:Set(key, value)
    self.db.profile[key] = value
    if DQTC.OnConfigChanged then
        DQTC:OnConfigChanged(key, value)
    end
end

function Config:GetChar(key)
    return self.char[key]
end

function Config:SetChar(key, value)
    self.char[key] = value
    if DQTC.OnCharConfigChanged then
        DQTC:OnCharConfigChanged(key, value)
    end
end

function Config:GetDefaults()
    return defaults
end
