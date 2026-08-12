local ADDON_NAME = ...
local DQTC = _G[ADDON_NAME]
local Loader = DQTC.Loader

-- Switches which baked POI tables back DQTC.Data (Questie Classic vs Wowhead).
-- Until Wowhead is baked, leave TOC-loaded Classic tables alone.
local DataProvider = Loader:CreateModule("DataProvider")

local SOURCES = { "questie", "wowhead" }

function DataProvider:GetSources()
    return SOURCES
end

function DataProvider:CaptureQuestieFromLoadedData()
    self.sources = self.sources or {}
    -- Only capture if Classic data actually loaded
    if not DQTC.Data or not DQTC.Data.quests or not next(DQTC.Data.quests) then
        return
    end
    self.sources.questie = {
        quests = DQTC.Data.quests,
        npcs = DQTC.Data.npcs or {},
        objects = DQTC.Data.objects or {},
        itemDrops = DQTC.Data.itemDrops or {},
        itemObjectDrops = DQTC.Data.itemObjectDrops or {},
        itemNames = DQTC.Data.itemNames or {},
        areaToUiMap = DQTC.Data.areaToUiMap or {},
    }
end

function DataProvider:CaptureWowheadFromLoadedData()
    self.sources = self.sources or {}
    local wh = DQTC.DataSources and DQTC.DataSources.wowhead
    if not wh then
        self.sources.wowhead = {
            quests = {},
            npcs = {},
            objects = {},
            itemDrops = {},
            itemObjectDrops = {},
            itemNames = {},
            areaToUiMap = {},
        }
        return
    end
    self.sources.wowhead = {
        quests = wh.quests or {},
        npcs = wh.npcs or {},
        objects = wh.objects or {},
        itemDrops = wh.itemDrops or {},
        itemObjectDrops = wh.itemObjectDrops or {},
        itemNames = wh.itemNames or {},
        areaToUiMap = wh.areaToUiMap or {},
    }
end

function DataProvider:HasWowheadData()
    local wh = self.sources and self.sources.wowhead
    return wh and type(wh.quests) == "table" and next(wh.quests) ~= nil
end

function DataProvider:GetActive()
    return self.active or "questie"
end

function DataProvider:InvalidateCaches()
    local DB = Loader:ImportModule("DB")
    if DB then
        DB._npcStarts = nil
        DB._npcEnds = nil
        DB._npcObjectives = nil
        DB._npcIndex = nil
        DB._questNumbers = nil
    end
end

function DataProvider:Apply(source, opts)
    opts = opts or {}
    self.sources = self.sources or {}
    if not self.sources.questie then
        self:CaptureQuestieFromLoadedData()
    end
    if not self.sources.wowhead then
        self:CaptureWowheadFromLoadedData()
    end

    source = source or "questie"
    if source == "wowhead" and not self:HasWowheadData() then
        if not opts.silent then
            print("|cff00ff00DQTC:|r Wowhead POI data is not baked yet — using Questie.")
        end
        source = "questie"
    end

    -- Questie is already loaded via TOC — do not reassign (avoids wiping live tables)
    if source == "questie" then
        if self.sources.questie and next(self.sources.questie.quests or {}) then
            -- Only restore if something emptied DQTC.Data (e.g. prior bad Wowhead apply)
            if not DQTC.Data.quests or not next(DQTC.Data.quests) then
                local src = self.sources.questie
                DQTC.Data.quests = src.quests
                DQTC.Data.npcs = src.npcs
                DQTC.Data.objects = src.objects
                DQTC.Data.itemDrops = src.itemDrops
                DQTC.Data.itemObjectDrops = src.itemObjectDrops
                DQTC.Data.itemNames = src.itemNames or DQTC.Data.itemNames
                if src.areaToUiMap and next(src.areaToUiMap) then
                    DQTC.Data.areaToUiMap = src.areaToUiMap
                end
            end
        end
        self.active = "questie"
        self:InvalidateCaches()
        return "questie"
    end

    local src = self.sources.wowhead
    if not src or not next(src.quests or {}) then
        self.active = "questie"
        self:InvalidateCaches()
        return "questie"
    end

    DQTC.Data.quests = src.quests or {}
    DQTC.Data.npcs = src.npcs or {}
    DQTC.Data.objects = src.objects or {}
    DQTC.Data.itemDrops = src.itemDrops or {}
    DQTC.Data.itemObjectDrops = src.itemObjectDrops or {}
    DQTC.Data.itemNames = src.itemNames or {}
    if src.areaToUiMap and next(src.areaToUiMap) then
        DQTC.Data.areaToUiMap = src.areaToUiMap
    end

    self.active = "wowhead"
    self:InvalidateCaches()
    return "wowhead"
end

function DataProvider:Initialize()
    if self._init then
        return
    end
    self._init = true
    self:CaptureQuestieFromLoadedData()
    self:CaptureWowheadFromLoadedData()

    -- Always use Classic (Questie-derived) bake; Wowhead switch UI was removed.
    self:Apply("questie", { silent = true })
end
