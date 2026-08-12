local ADDON_NAME = ...
local DQTC = _G[ADDON_NAME]
local Loader = DQTC.Loader

local function RefreshAll(opts)
    opts = opts or {}
    local QuestLogCache = Loader:ImportModule("QuestLogCache")
    local QuestAvailability = Loader:ImportModule("QuestAvailability")
    local WatchState = Loader:ImportModule("WatchState")
    local TrackerFrame = Loader:ImportModule("TrackerFrame")
    local MarkerController = Loader:ImportModule("MarkerController")
    local QuestNameplates = Loader:ImportModule("QuestNameplates")

    QuestLogCache:Refresh()
    QuestAvailability:EnsureBuilt()
    -- Full offerable rebuild is expensive; only when quest progress may unlock/lock pins
    if opts.refreshOfferable then
        QuestAvailability:RefreshOfferable()
    end
    WatchState:HideBlizzardTracker()
    TrackerFrame:Update()
    MarkerController:Refresh()
    QuestNameplates:RefreshAll()
end

function DQTC:RefreshAll()
    RefreshAll()
end

function DQTC:OnConfigChanged(key, value)
    if key == "trackerLocked" then
        Loader:ImportModule("TrackerFrame"):UpdateLockVisual()
    end
    if key == "enableTracker" then
        local WatchState = Loader:ImportModule("WatchState")
        if value then
            WatchState:HookBlizzard()
        end
    end
    RefreshAll()
end

function DQTC:OnCharConfigChanged(key, value)
    if key == "trackerPosition" or key == "collapsed" or key == "superTrackedQuestId" then
        RefreshAll()
    end
end

local function Initialize()
    DQTC.Config:Initialize()
    local DataProvider = Loader:ImportModule("DataProvider")
    DataProvider:Initialize()

    local ok, err = pcall(function()
        DQTC.Options:Initialize()
    end)
    if not ok then
        print("|cffff0000DQTC:|r Options failed to load: " .. tostring(err))
    end

    local WatchState = Loader:ImportModule("WatchState")
    local Events = Loader:ImportModule("Events")
    local QuestNameplates = Loader:ImportModule("QuestNameplates")
    Loader:ImportModule("QuestTooltip"):Initialize()

    if DQTC.Config:Get("enableTracker") then
        WatchState:HookBlizzard()
    end

    -- Hook world map so pins refresh when the map opens
    Loader:ImportModule("WorldMapPins"):HookMap()

    local hbdStatus = Loader:ImportModule("HBDHelper"):GetStatus()
    if hbdStatus.ok then
        print("|cff00ff00DQTC:|r Map library ready (" .. tostring(hbdStatus.name) .. ").")
    else
        print("|cffff0000DQTC:|r Map library missing — " .. tostring(hbdStatus.error)
            .. ". Enable the |cffffff00HereBeDragons|r addon or reinstall DQTC.")
    end

    if DQTC.Compat.IsQuestieLoaded() and DQTC.Config:Get("suppressIfQuestie") then
        print("|cff00ff00DQTC:|r Questie detected — map/nameplate markers suppressed (toggle in options).")
    end

    Events:Register("PLAYER_ENTERING_WORLD", function()
        Loader:ImportModule("QuestAvailability"):Rebuild()
        RefreshAll({ refreshOfferable = true })
    end, 0.2)

    Events:Register("QUEST_LOG_UPDATE", function()
        RefreshAll()
    end, 0.35)

    Events:Register("QUEST_ACCEPTED", function()
        RefreshAll({ refreshOfferable = true })
    end, 0.15)

    Events:Register("QUEST_REMOVED", function()
        RefreshAll({ refreshOfferable = true })
    end, 0.15)

    Events:Register("QUEST_TURNED_IN", function(_, questId)
        Loader:ImportModule("QuestAvailability"):MarkCompleted(questId)
        RefreshAll({ refreshOfferable = true })
    end, 0.15)

    Events:Register("QUEST_WATCH_UPDATE", function()
        RefreshAll()
    end, 0.1)

    Events:Register("ZONE_CHANGED_NEW_AREA", function()
        Loader:ImportModule("MarkerController"):Refresh()
    end, 0.3)

    Events:Register("PLAYER_LEVEL_UP", function()
        Loader:ImportModule("MarkerController"):Refresh()
    end, 0.2)

    Events:Register("PLAYER_REGEN_DISABLED", function()
        Loader:ImportModule("TrackerFrame"):Update()
    end)

    Events:Register("PLAYER_REGEN_ENABLED", function()
        Loader:ImportModule("TrackerFrame"):Update()
    end)

    Events:Register("NAME_PLATE_UNIT_ADDED", function(_, unit)
        QuestNameplates:OnAdded(unit)
    end)

    Events:Register("NAME_PLATE_UNIT_REMOVED", function(_, unit)
        QuestNameplates:OnRemoved(unit)
    end)

    RefreshAll()
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
        self:UnregisterEvent("ADDON_LOADED")
        Initialize()
    end
end)

SLASH_DQTC1 = "/dqtc"
SLASH_DQTC2 = "/defaultquesttracker"
SlashCmdList["DQTC"] = function(msg)
    msg = strtrim(msg or "")
    local cmd, arg = msg:match("^(%S+)%s*(.*)$")
    cmd = string.lower(cmd or "")
    arg = strtrim(arg or "")

    if cmd == "reset" then
        Loader:ImportModule("TrackerPosition"):Reset()
        print("|cff00ff00DQTC:|r Tracker position reset.")
    elseif cmd == "unlock" then
        DQTC.Config:Set("trackerLocked", false)
        print("|cff00ff00DQTC:|r " .. DQTC.L["TRACKER_UNLOCKED"])
    elseif cmd == "lock" then
        DQTC.Config:Set("trackerLocked", true)
        print("|cff00ff00DQTC:|r " .. DQTC.L["TRACKER_LOCKED"])
    elseif cmd == "refresh" then
        Loader:ImportModule("QuestAvailability"):Rebuild()
        RefreshAll()
        local s = Loader:ImportModule("QuestAvailability"):GetStats()
        print("|cff00ff00DQTC:|r Refreshed. completed=" .. tostring(s.completed)
            .. " offerable=" .. tostring(s.offerable)
            .. " race=" .. tostring(s.raceMask)
            .. " class=" .. tostring(s.classMask))
        local hs = Loader:ImportModule("HolidayEvents"):GetStats()
        print("|cff00ff00DQTC events:|r active=" .. tostring(hs.events)
            .. " quests=" .. tostring(hs.quests)
            .. (hs.names[1] and (" (" .. table.concat(hs.names, ", ") .. ")") or " (none)"))
    elseif cmd == "testpin" then
        Loader:ImportModule("WorldMapPins"):DebugPlayerPin()
    elseif cmd == "tooltip" then
        local npcId = tonumber(arg) or 1254
        if not DQTC.Config:Get("showUnitTooltips") then
            DQTC.Config:Set("showUnitTooltips", true)
            print("|cffffcc00DQTC:|r showUnitTooltips was OFF — enabling.")
        end
        Loader:ImportModule("QuestLogCache"):Refresh()
        local DB = Loader:ImportModule("DB")
        local lines = DB:GetNpcTooltipLines(npcId)
        local npc = DB:GetNpc(npcId)
        print("|cff00ff00DQTC tooltip:|r npc=" .. tostring(npcId)
            .. " name=" .. tostring(npc and npc.n)
            .. " lines=" .. tostring(#lines)
            .. " showUnitTooltips=" .. tostring(DQTC.Config:Get("showUnitTooltips")))
        for i, line in ipairs(lines) do
            print("  " .. i .. " [" .. tostring(line.kind) .. "] " .. tostring(line.text))
        end
        if #lines == 0 then
            print("|cffffcc00DQTC:|r No lines — try a quest giver (1254 Stonebrow) or a mob for a quest in your log.")
        end
    elseif cmd == "markers" then
        if not DQTC.Config:Get("showQuestMarkers") then
            print("|cffffcc00DQTC:|r showQuestMarkers was OFF — enabling for test.")
            DQTC.Config:Set("showQuestMarkers", true)
        end
        if not DQTC.Config:Get("showWorldMap") then
            print("|cffffcc00DQTC:|r showWorldMap was OFF — enabling for test.")
            DQTC.Config:Set("showWorldMap", true)
        end
        if not DQTC.Config:Get("showMinimap") then
            print("|cffffcc00DQTC:|r showMinimap was OFF — enabling for test.")
            DQTC.Config:Set("showMinimap", true)
        end
        if DQTC.Config:Get("suppressIfQuestie") then
            print("|cffffcc00DQTC:|r suppressIfQuestie was ON — disabling for test.")
            DQTC.Config:Set("suppressIfQuestie", false)
        end
        local mapId = C_Map.GetBestMapForUnit("player")
        if WorldMapFrame and mapId then
            if not WorldMapFrame:IsShown() then
                ShowUIPanel(WorldMapFrame)
            end
            if WorldMapFrame.SetMapID then
                WorldMapFrame:SetMapID(mapId)
            end
        end
        RefreshAll()
        C_Timer.After(0.15, function()
            Loader:ImportModule("WorldMapPins"):Paint()
            local stats = Loader:ImportModule("MarkerController"):GetStats()
            local ws = Loader:ImportModule("WorldMapPins"):GetStatus()
            local ms = Loader:ImportModule("MinimapPins"):GetStatus()
            local ZoneMap = Loader:ImportModule("ZoneMap")
            local QuestLogCache = Loader:ImportModule("QuestLogCache")
            local DB = Loader:ImportModule("DB")

            local id = QuestLogCache:GetOrderedIds()[1]
            local spawns = id and DB:GetObjectiveSpawns(id) or {}
            local turnins = id and DB:GetTurninSpawns(id) or {}
            local sp = spawns[1] or turnins[1]
            local spawnMap = sp and sp.uiMapId
            local playerMap = stats.currentMap
            local viewedMap = ws.viewedMap
            local relevant = spawnMap and playerMap and ZoneMap:IsMapRelevant(spawnMap, playerMap)
            local chain = playerMap and table.concat(ZoneMap:GetMapParentChain(playerMap), ">") or "?"

            local mode = "OK"
            if not ws.hbd or not ws.pins then
                mode = "FAIL_NO_HBD"
            elseif stats.suppressed or stats.reason == "suppressIfQuestie" then
                mode = "FAIL_SUPPRESSED"
            elseif stats.reason == "showQuestMarkers off" then
                mode = "FAIL_MARKERS_OFF"
            elseif (stats.added or 0) == 0 then
                mode = "FAIL_NO_PENDING"
            elseif spawnMap and playerMap and not relevant and (ws.matchingView or 0) == 0 and (ws.count or 0) == 0 then
                mode = "FAIL_MAP_MISMATCH"
            elseif (ws.count or 0) == 0 then
                mode = "FAIL_ZERO_PAINTED"
            end

            print("|cff00ff00DQTC markers:|r mode=" .. mode
                .. " queued=" .. tostring(stats.added)
                .. " worldPainted=" .. tostring(ws.count)
                .. " miniShown=" .. tostring(ms and ms.shown)
                .. " pending=" .. tostring(ws.pending)
                .. " matchView=" .. tostring(ws.matchingView))
            print("|cff00ff00DQTC maps:|r player=" .. tostring(playerMap)
                .. " viewed=" .. tostring(viewedMap)
                .. " sampleSpawn=" .. tostring(spawnMap)
                .. " relevant=" .. tostring(relevant)
                .. " chain=" .. chain)
            print("|cff00ff00DQTC libs:|r hbd=" .. tostring(ws.hbd)
                .. " lib=" .. tostring(ws.lib)
                .. " pins=" .. tostring(ws.pins)
                .. " pinMode=" .. tostring(ws.mode)
                .. " questie=" .. tostring(DQTC.Compat.IsQuestieLoaded())
                .. " suppress=" .. tostring(DQTC.Config:Get("suppressIfQuestie"))
                .. " reason=" .. tostring(stats.reason or ws.lastError or (ms and ms.lastError) or "ok"))

            if id then
                local q = QuestLogCache:GetQuest(id)
                print("|cff00ff00DQTC sample:|r quest=" .. tostring(id) .. " " .. tostring(q and q.title)
                    .. " obj=" .. tostring(#spawns) .. " turnin=" .. tostring(#turnins)
                    .. (sp and (" map=" .. tostring(sp.uiMapId) .. " x=" .. tostring(sp.x) .. " y=" .. tostring(sp.y)) or " (no spawns in DB)"))
            else
                print("|cffffcc00DQTC:|r No quests in log to sample.")
            end
        end)
    else
        DQTC.Options:Open()
    end
end

print("|cff00ff00Default Quest Tracker Classic|r loaded. Type |cffffff00/dqtc|r for options.")
