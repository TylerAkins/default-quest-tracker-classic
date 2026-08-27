-- Offline check for DB:ClusterSpawns grouping (no WoW APIs).
-- Run: lua tools/test_cluster_spawns.lua

local function ClusterSpawns(spawns, gap)
    gap = gap or 18
    local gapSq = gap * gap
    local byMap = {}
    for _, sp in ipairs(spawns or {}) do
        if sp and sp.uiMapId and sp.x ~= nil and sp.y ~= nil then
            local list = byMap[sp.uiMapId]
            if not list then
                list = {}
                byMap[sp.uiMapId] = list
            end
            list[#list + 1] = sp
        end
    end

    local clusters = {}
    for uiMapId, points in pairs(byMap) do
        local groups = {}
        for _, p in ipairs(points) do
            local best, bestD
            for _, g in ipairs(groups) do
                local dx, dy = p.x - g.cx, p.y - g.cy
                local d = dx * dx + dy * dy
                if d <= gapSq and (not bestD or d < bestD) then
                    best, bestD = g, d
                end
            end
            if best then
                best.points[#best.points + 1] = p
                local n = #best.points
                best.cx = best.cx + (p.x - best.cx) / n
                best.cy = best.cy + (p.y - best.cy) / n
            else
                groups[#groups + 1] = { cx = p.x, cy = p.y, points = { p } }
            end
        end
        for _, g in ipairs(groups) do
            local r = 0
            for _, p in ipairs(g.points) do
                local dx, dy = p.x - g.cx, p.y - g.cy
                local d = math.sqrt(dx * dx + dy * dy)
                if d > r then
                    r = d
                end
            end
            r = math.max(4, r * 1.05 + 1)
            if r > 12 then
                r = 12
            end
            local sample = g.points[1]
            clusters[#clusters + 1] = {
                uiMapId = uiMapId,
                x = g.cx,
                y = g.cy,
                radius = r,
                kind = sample.kind,
                questId = sample.questId,
                count = #g.points,
            }
        end
    end
    return clusters
end

local function assertEq(a, b, msg)
    if a ~= b then
        error((msg or "assertEq") .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2)
    end
end

-- Nearby spawns on one map collapse to a single area
local tight = ClusterSpawns({
    { uiMapId = 1426, x = 40, y = 40, kind = "objective", questId = 1 },
    { uiMapId = 1426, x = 42, y = 41, kind = "objective", questId = 1 },
    { uiMapId = 1426, x = 39, y = 43, kind = "objective", questId = 1 },
})
assertEq(#tight, 1, "tight cluster count")
assertEq(tight[1].count, 3, "tight cluster members")
assert(tight[1].radius >= 4)

-- Far camps stay as two areas
local split = ClusterSpawns({
    { uiMapId = 1426, x = 20, y = 20, kind = "objective", questId = 2 },
    { uiMapId = 1426, x = 21, y = 19, kind = "objective", questId = 2 },
    { uiMapId = 1426, x = 80, y = 80, kind = "objective", questId = 2 },
    { uiMapId = 1426, x = 81, y = 79, kind = "objective", questId = 2 },
})
assertEq(#split, 2, "split cluster count")

-- Different maps never merge
local maps = ClusterSpawns({
    { uiMapId = 1426, x = 50, y = 50, kind = "objective", questId = 3 },
    { uiMapId = 1432, x = 50, y = 50, kind = "objective", questId = 3 },
})
assertEq(#maps, 2, "map split")

print("cluster spawn tests ok")
