#!/usr/bin/env python3
"""Keep in sync with TrackerFrame zone helpers in Modules/Tracker/TrackerFrame.lua."""

from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def zone_name_for_quest(quest: dict | None, unknown_zone: str = "Unknown Zone") -> str:
    zone = quest.get("zone") if quest else None
    if isinstance(zone, str) and zone != "":
        return zone
    return unknown_zone


def group_ids_by_zone(ids: list, get_zone) -> list:
    buckets: dict[str, list] = {}
    zone_order: list[str] = []
    for quest_id in ids:
        zone = get_zone(quest_id)
        if zone not in buckets:
            buckets[zone] = []
            zone_order.append(zone)
        buckets[zone].append(quest_id)
    zone_order.sort()
    out: list = []
    for zone in zone_order:
        out.extend(buckets[zone])
    return out


def build_display_rows(ids, get_zone, organize_by_zone, collapsed_zones=None):
    collapsed_zones = collapsed_zones or {}
    rows = []
    if not organize_by_zone:
        for quest_id in ids:
            rows.append({"kind": "quest", "questId": quest_id})
        return rows
    last_zone = None
    last_zone_set = False
    for quest_id in ids:
        zone = get_zone(quest_id)
        if (not last_zone_set) or zone != last_zone:
            last_zone = zone
            last_zone_set = True
            collapsed = bool(collapsed_zones.get(zone))
            rows.append({"kind": "zone", "zone": zone, "collapsed": collapsed})
        if not collapsed_zones.get(zone):
            rows.append({"kind": "quest", "questId": quest_id, "zone": zone})
    return rows


QUESTS = {
    1: {"zone": "Westfall", "title": "The Defias Brotherhood"},
    2: {"zone": "Elwynn Forest", "title": "Kobold Camp Cleanup"},
    3: {"zone": "Westfall", "title": "Patrolling Westfall"},
    4: {"zone": None, "title": "Unknown"},
    5: {"zone": "", "title": "Also unknown"},
    6: {"zone": "Elwynn Forest", "title": "Wolves at Our Heels"},
}


def _get_zone(quest_id):
    return zone_name_for_quest(QUESTS[quest_id])


def test_zone_name_fallback() -> None:
    assert zone_name_for_quest({"zone": "Westfall"}) == "Westfall"
    assert zone_name_for_quest({"zone": ""}) == "Unknown Zone"
    assert zone_name_for_quest({"zone": None}) == "Unknown Zone"
    assert zone_name_for_quest(None) == "Unknown Zone"
    assert zone_name_for_quest({"zone": ""}, "Missing") == "Missing"


def test_group_sorts_zones_alphabetically_and_keeps_within_zone_order() -> None:
    # Log order: Westfall, Elwynn, Westfall, Unknown, Unknown, Elwynn
    grouped = group_ids_by_zone([1, 2, 3, 4, 5, 6], _get_zone)
    assert grouped == [2, 6, 4, 5, 1, 3]
    # Elwynn (2, 6), Unknown Zone (4, 5), Westfall (1, 3)


def test_rows_insert_headers_and_omit_collapsed_quests() -> None:
    ids = group_ids_by_zone([1, 2, 3, 6], _get_zone)
    rows = build_display_rows(ids, _get_zone, True, {"Westfall": True})
    kinds = []
    for row in rows:
        if row["kind"] == "zone":
            kinds.append(("zone", row["zone"]))
        else:
            kinds.append(("quest", row["questId"]))
    assert kinds == [
        ("zone", "Elwynn Forest"),
        ("quest", 2),
        ("quest", 6),
        ("zone", "Westfall"),
    ]
    westfall = next(row for row in rows if row["kind"] == "zone" and row["zone"] == "Westfall")
    assert westfall["collapsed"] is True


def test_disabled_organize_is_flat_quest_list() -> None:
    rows = build_display_rows([1, 2, 3], _get_zone, False, {})
    assert rows == [
        {"kind": "quest", "questId": 1},
        {"kind": "quest", "questId": 2},
        {"kind": "quest", "questId": 3},
    ]


def test_single_zone_still_gets_a_header() -> None:
    rows = build_display_rows([1, 3], _get_zone, True, {})
    assert [row["kind"] for row in rows] == ["zone", "quest", "quest"]
    assert rows[0]["zone"] == "Westfall"
    assert rows[0]["collapsed"] is False


def test_empty_ids() -> None:
    assert group_ids_by_zone([], _get_zone) == []
    assert build_display_rows([], _get_zone, True, {}) == []


def test_lua_helpers_and_option_exist() -> None:
    tracker = (ROOT / "Modules" / "Tracker" / "TrackerFrame.lua").read_text(encoding="utf-8")
    lines = (ROOT / "Modules" / "Tracker" / "TrackerLines.lua").read_text(encoding="utf-8")
    options = (ROOT / "Options.lua").read_text(encoding="utf-8")
    config = (ROOT / "Config.lua").read_text(encoding="utf-8")
    loc = (ROOT / "Localization" / "enUS.lua").read_text(encoding="utf-8")
    assert "function TrackerFrame.ZoneNameForQuest" in tracker
    assert "function TrackerFrame.GroupIdsByZone" in tracker
    assert "function TrackerFrame.BuildDisplayRows" in tracker
    assert "function TrackerFrame:ToggleZoneCollapsed" in tracker
    assert "OrganizeByZoneEnabled()" in tracker
    assert 'kind == "zone"' in lines
    assert 'key = "organizeByZone"' in options
    assert "organizeByZone = true" in config
    assert "collapsedZones = {}" in config
    assert 'L["ORGANIZE_BY_ZONE"]' in loc
    toc = (ROOT / "DefaultQuestTrackerClassic.toc").read_text(encoding="utf-8")
    assert "## Version: 1.2.0" in toc


def main() -> None:
    test_zone_name_fallback()
    test_group_sorts_zones_alphabetically_and_keeps_within_zone_order()
    test_rows_insert_headers_and_omit_collapsed_quests()
    test_disabled_organize_is_flat_quest_list()
    test_single_zone_still_gets_a_header()
    test_empty_ids()
    test_lua_helpers_and_option_exist()
    print("ok")


if __name__ == "__main__":
    main()
