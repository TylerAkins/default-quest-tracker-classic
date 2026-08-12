#!/usr/bin/env python3
"""
Convert Questie Classic Era DB tables into slim DQTC Database/Classic/*.lua files.

Usage:
  python tools/convert_questie_db.py

Source (read-only): sibling Questie addon classic*DB.lua + areaIdToUiMapId
Output: Database/Classic/Quests.lua, Npcs.lua, Objects.lua + area map embedded in Quests or Zone data

Attribution: Coordinate/quest linkage data derived from Questie Classic community DB
(https://github.com/Questie/Questie — also https://www.curseforge.com/wow/addons/questie).
Review Questie license (GPLv3) before redistributing builds; DQTC ships GPLv3 accordingly.
"""

from __future__ import annotations

import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
QUESTIE = ROOT.parent / "Questie"
OUT = ROOT / "Database" / "Classic"


def extract_return_block(text: str) -> str:
    m = re.search(r"=\s*\[\[return\s*(\{.*\})\s*\]\]", text, re.S)
    if not m:
        raise RuntimeError("Could not find return [[...]] block")
    return m.group(1)


def lua_to_python(expr: str):
    """Minimal Lua table literal evaluator for Questie DB dumps."""
    # Normalize
    s = expr.strip()
    # Quote keys that are barewords inside tables? Questie uses [id] = mostly.
    # Replace nil
    # We'll use a recursive descent / tokenize approach via eval after transforms.

    # Protect strings
    strings: list[str] = []

    def protect(match: re.Match) -> str:
        strings.append(match.group(0))
        return f"__STR{len(strings)-1}__"

    s = re.sub(r'"(?:\\.|[^"\\])*"', protect, s)
    s = re.sub(r"'(?:\\.|[^'\\])*'", protect, s)

    s = s.replace("nil", "None")
    s = re.sub(r"\btrue\b", "True", s)
    s = re.sub(r"\bfalse\b", "False", s)

    # [123] =  ->  123:
    s = re.sub(r"\[(\d+)\]\s*=", r"\1:", s)
    # Convert { } tables: use a custom parser instead of eval for safety/robustness

    def parse(src: str, i: int = 0):
        def skip():
            nonlocal i
            while i < len(src) and src[i] in " \t\r\n,":
                i += 1

        skip()
        if i >= len(src):
            return None, i
        ch = src[i]
        if ch == "{":
            i += 1
            # decide list vs dict
            items = []
            keys = []
            values = []
            is_dict = False
            while True:
                skip()
                if i < len(src) and src[i] == "}":
                    i += 1
                    break
                # look ahead for key:
                skip()
                # number key form already transformed to N:
                m = re.match(r"(\d+)\s*:", src[i:])
                if m:
                    is_dict = True
                    key = int(m.group(1))
                    i += m.end()
                    val, i = parse(src, i)
                    keys.append(key)
                    values.append(val)
                else:
                    val, i = parse(src, i)
                    items.append(val)
                skip()
                if i < len(src) and src[i] == ",":
                    i += 1
                    continue
                if i < len(src) and src[i] == "}":
                    i += 1
                    break
            if is_dict and items:
                # mixed — treat as dict with numeric keys for keyed, and list for rest (shouldn't happen)
                d = {k: v for k, v in zip(keys, values)}
                return d, i
            if is_dict:
                return {k: v for k, v in zip(keys, values)}, i
            return items, i
        if ch == "-" or ch.isdigit():
            m = re.match(r"-?\d+(?:\.\d+)?", src[i:])
            assert m
            num = m.group(0)
            i += len(num)
            if "." in num:
                return float(num), i
            return int(num), i
        if src.startswith("None", i):
            return None, i + 4
        if src.startswith("True", i):
            return True, i + 4
        if src.startswith("False", i):
            return False, i + 5
        if src.startswith("__STR", i):
            m = re.match(r"__STR(\d+)__", src[i:])
            assert m
            raw = strings[int(m.group(1))]
            i += m.end()
            # unwrap quotes
            if raw[0] == '"':
                return bytes(raw[1:-1], "utf-8").decode("unicode_escape", errors="replace"), i
            return raw[1:-1], i
        raise RuntimeError(f"Unexpected at {i}: {src[i:i+40]!r}")

    data, idx = parse(s, 0)
    return data


def race_to_faction(races) -> int:
    # Classic bitmasks used heavily by Questie: 77 Alliance, 178 Horde, 0 both
    if races in (None, 0):
        return 0
    alliance = 1 | 4 | 8 | 64 | 1024  # include Draenei-ish if present
    horde = 2 | 16 | 32 | 128 | 512
    is_a = bool(races & alliance)
    is_h = bool(races & horde)
    if is_a and not is_h:
        return 1
    if is_h and not is_a:
        return 2
    return 0


def load_area_map() -> dict[int, int]:
    """Parse Classic Era areaId -> uiMapId (ignore MoP/retail zone files)."""
    mapping: dict[int, int] = {}
    classic = QUESTIE / "Database" / "Zones" / "data" / "areaIdToUiMapId.lua"
    if classic.exists():
        text = classic.read_text(encoding="utf-8", errors="replace")
        idx_o = text.find("areaIdToUiMapIdOverride")
        idx_m = text.find("ZoneDB.private.areaIdToUiMapId =")
        if idx_o >= 0 and idx_m >= 0:
            for m in re.finditer(r"\[(\d+)\]\s*=\s*(\d+)", text[idx_o:idx_m]):
                mapping[int(m.group(1))] = int(m.group(2))
            for m in re.finditer(r"\[(\d+)\]\s*=\s*(\d+)", text[idx_m:]):
                mapping[int(m.group(1))] = int(m.group(2))
        else:
            for m in re.finditer(r"\[(\d+)\]\s*=\s*(\d+)", text):
                mapping[int(m.group(1))] = int(m.group(2))
        print(f"area map classic: {len(mapping)} keys (12->Elwynn={mapping.get(12)})")
    if mapping.get(12) != 1429 or mapping.get(38) != 1432:
        mapping.update({
            1: 1426, 3: 1418, 4: 1419, 8: 1435, 10: 1431, 11: 1437, 12: 1429,
            14: 1411, 15: 1445, 16: 1447, 17: 1413, 28: 1422, 33: 1434, 36: 1416,
            38: 1432, 40: 1436, 41: 1430, 44: 1433, 45: 1417, 46: 1428, 47: 1425,
            51: 1427, 85: 1420, 130: 1421, 139: 1423, 141: 1438, 148: 1439,
            215: 1412, 267: 1424, 331: 1440, 357: 1444, 361: 1448, 400: 1441,
            405: 1443, 406: 1442, 440: 1446, 490: 1449, 493: 1450, 618: 1452,
            1377: 1451, 1497: 1458, 1519: 1453, 1537: 1455, 1637: 1454,
            1638: 1456, 1657: 1457, 2597: 1459, 3277: 1460, 3358: 1461,
            6170: 425, 6176: 427, 6450: 460, 6451: 461, 6452: 462, 6453: 463,
            6454: 465, 6457: 469,
        })
    return mapping


def write_lua_table(path: pathlib.Path, global_assign: str, data: dict, formatter):
    lines = [
        f"-- AUTO-GENERATED by tools/convert_questie_db.py from Questie Classic DB.",
        f"-- Source: https://github.com/Questie/Questie — do not edit by hand.",
        f"local ADDON_NAME = ...",
        f"local DQTC = _G[ADDON_NAME]",
        f"DQTC.Data = DQTC.Data or {{}}",
        f"{global_assign} = {{}}",
    ]
    # Write in chunks for size
    keys = sorted(data.keys())
    for k in keys:
        lines.append(formatter(k, data[k]))
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"Wrote {path} ({len(keys)} entries)")


def lua_double_quoted(s: str) -> str:
    """Escape a string for use inside Lua "..." literals. NPC names never need "."""
    s = str(s or "")
    # Prefer apostrophe over literal double-quote (Questie sometimes stores ")
    s = s.replace('"', "'")
    s = s.replace("\\", "\\\\")
    return s


def fmt_id_list(ids) -> str:
    if not isinstance(ids, list):
        return "{}"
    nums = [str(x) for x in ids if isinstance(x, int) and x > 0]
    return "{" + ",".join(nums) + "}"


def fmt_quest(qid, q):
    # Questie 1-based keys → 0-based list indices after lua_to_python
    # name=1, startedBy=2, finishedBy=3, requiredLevel=4, questLevel=5,
    # requiredRaces=6, requiredClasses=7, objectives=10,
    # preQuestGroup=12, preQuestSingle=13, exclusiveTo=16, nextQuestInChain=22
    name = q[0] if len(q) > 0 else ""
    started = q[1] if len(q) > 1 else None
    finished = q[2] if len(q) > 2 else None
    req_level = q[3] if len(q) > 3 else 1
    qlevel = q[4] if len(q) > 4 else 1
    races = q[5] if len(q) > 5 else 0
    classes = q[6] if len(q) > 6 else 0
    objectives = q[9] if len(q) > 9 else None
    pre_group = q[11] if len(q) > 11 else None
    pre_single = q[12] if len(q) > 12 else None
    exclusive = q[15] if len(q) > 15 else None
    next_chain = q[21] if len(q) > 21 else None

    starters = []
    if isinstance(started, list) and started:
        creatures = started[0] if len(started) > 0 else None
        if isinstance(creatures, list):
            starters = [c for c in creatures if isinstance(c, int)]

    enders = []
    if isinstance(finished, list) and finished:
        creatures = finished[0] if len(finished) > 0 else None
        if isinstance(creatures, list):
            enders = [c for c in creatures if isinstance(c, int)]

    objs = []
    if isinstance(objectives, list):
        # creatureObjective
        if len(objectives) > 0 and isinstance(objectives[0], list):
            for entry in objectives[0]:
                if isinstance(entry, list) and entry and isinstance(entry[0], int):
                    objs.append({"t": "monster", "i": entry[0]})
                elif isinstance(entry, int):
                    objs.append({"t": "monster", "i": entry})
        # objectObjective
        if len(objectives) > 1 and isinstance(objectives[1], list):
            for entry in objectives[1]:
                if isinstance(entry, list) and entry and isinstance(entry[0], int):
                    objs.append({"t": "object", "i": entry[0]})
                elif isinstance(entry, int):
                    objs.append({"t": "object", "i": entry})
        # itemObjective (bandanas, Hogger claw, etc.)
        if len(objectives) > 2 and isinstance(objectives[2], list):
            for entry in objectives[2]:
                if isinstance(entry, list) and entry and isinstance(entry[0], int):
                    objs.append({"t": "item", "i": entry[0]})
                elif isinstance(entry, int):
                    objs.append({"t": "item", "i": entry})

    race_mask = races if isinstance(races, int) else 0
    class_mask = classes if isinstance(classes, int) else 0
    faction = race_to_faction(race_mask)
    s_lua = "{" + ",".join(str(x) for x in starters) + "}"
    e_lua = "{" + ",".join(str(x) for x in enders) + "}"
    o_parts = []
    for o in objs:
        o_parts.append(f'{{t="{o["t"]}",i={o["i"]}}}')
    o_lua = "{" + ",".join(o_parts) + "}"
    safe = lua_double_quoted(name)

    parts = [
        f'n="{safe}"',
        f"l={qlevel or 1}",
        f"rl={req_level if isinstance(req_level, int) else 1}",
        f"f={faction}",
        f"s={s_lua}",
        f"e={e_lua}",
        f"o={o_lua}",
    ]
    if race_mask and race_mask != 0:
        parts.append(f"r={race_mask}")
    if class_mask and class_mask != 0:
        parts.append(f"c={class_mask}")
    pq = fmt_id_list(pre_single)
    if pq != "{}":
        parts.append(f"pq={pq}")
    pg = fmt_id_list(pre_group)
    if pg != "{}":
        parts.append(f"pg={pg}")
    ex = fmt_id_list(exclusive)
    if ex != "{}":
        parts.append(f"ex={ex}")
    if isinstance(next_chain, int) and next_chain > 0:
        parts.append(f"nq={next_chain}")

    return f'DQTC.Data.quests[{qid}]={{{",".join(parts)}}}'


def fmt_npc(nid, n):
    name = n[0] if len(n) > 0 else ""
    spawns = n[6] if len(n) > 6 else None
    safe = lua_double_quoted(name)
    # serialize spawns as {[area]= {{x,y},...}}
    if not isinstance(spawns, dict):
        return f'DQTC.Data.npcs[{nid}]={{n="{safe}",sp={{}}}}'
    parts = []
    for area, coords in spawns.items():
        if not isinstance(area, int) or not isinstance(coords, list):
            continue
        cparts = []
        # Cap spawns per NPC/area to keep file smaller
        for pair in coords[:12]:
            if isinstance(pair, list) and len(pair) >= 2:
                cparts.append(f"{{{pair[0]},{pair[1]}}}")
        if cparts:
            parts.append(f"[{area}]={{{','.join(cparts)}}}")
    sp_lua = "{" + ",".join(parts) + "}"
    return f'DQTC.Data.npcs[{nid}]={{n="{safe}",sp={sp_lua}}}'


def fmt_object(oid, o):
    name = o[0] if len(o) > 0 else ""
    spawns = o[3] if len(o) > 3 else None  # classic object: name, questStarts, questEnds, spawns? verify
    # Questie objectKeys: name=1, questStarts=2, questEnds=3, spawns=4, zoneID=5...
    # 0-index: name, questStarts, questEnds, spawns
    if len(o) > 3:
        spawns = o[3]
    if not isinstance(spawns, dict):
        # sometimes spawns at different index — try find dict
        for item in o:
            if isinstance(item, dict):
                # could be wrong; only use if values look like coord lists
                ok = True
                for v in item.values():
                    if not isinstance(v, list):
                        ok = False
                        break
                if ok:
                    spawns = item
                    break
    parts = []
    if isinstance(spawns, dict):
        for area, coords in spawns.items():
            if not isinstance(area, int) or not isinstance(coords, list):
                continue
            cparts = []
            for pair in coords[:12]:
                if isinstance(pair, list) and len(pair) >= 2:
                    cparts.append(f"{{{pair[0]},{pair[1]}}}")
            if cparts:
                parts.append(f"[{area}]={{{','.join(cparts)}}}")
    sp_lua = "{" + ",".join(parts) + "}"
    safe = lua_double_quoted(name)
    return f'DQTC.Data.objects[{oid}]={{n="{safe}",sp={sp_lua}}}'


def extract_objective_ids(objectives):
    """Return (npc_ids, object_ids, item_ids) from a Questie objectives block."""
    npcs: set[int] = set()
    objs: set[int] = set()
    items: set[int] = set()
    if not isinstance(objectives, list):
        return npcs, objs, items

    def add_ids(bucket: set[int], entries):
        if not isinstance(entries, list):
            return
        for entry in entries:
            if isinstance(entry, list) and entry and isinstance(entry[0], int):
                bucket.add(entry[0])
            elif isinstance(entry, int):
                bucket.add(entry)

    if objectives and isinstance(objectives[0], list):
        add_ids(npcs, objectives[0])
    if len(objectives) > 1 and isinstance(objectives[1], list):
        add_ids(objs, objectives[1])
    if len(objectives) > 2 and isinstance(objectives[2], list):
        add_ids(items, objectives[2])
    return npcs, objs, items


def fmt_item_drops(item_id: int, npc_ids: list[int]) -> str:
    ids = ",".join(str(n) for n in npc_ids)
    return f"DQTC.Data.itemDrops[{item_id}]={{{ids}}}"


def fmt_item_object_drops(item_id: int, object_ids: list[int]) -> str:
    ids = ",".join(str(o) for o in object_ids)
    return f"DQTC.Data.itemObjectDrops[{item_id}]={{{ids}}}"


def main():
    if not QUESTIE.exists():
        print(f"Questie not found at {QUESTIE}", file=sys.stderr)
        sys.exit(1)

    OUT.mkdir(parents=True, exist_ok=True)

    print("Loading area map...")
    area_map = load_area_map()

    print("Parsing quests...")
    qtext = (QUESTIE / "Database" / "Classic" / "classicQuestDB.lua").read_text(encoding="utf-8", errors="replace")
    quests = lua_to_python(extract_return_block(qtext))
    assert isinstance(quests, dict)

    print("Parsing npcs...")
    ntext = (QUESTIE / "Database" / "Classic" / "classicNpcDB.lua").read_text(encoding="utf-8", errors="replace")
    npcs = lua_to_python(extract_return_block(ntext))
    assert isinstance(npcs, dict)

    print("Parsing objects...")
    otext = (QUESTIE / "Database" / "Classic" / "classicObjectDB.lua").read_text(encoding="utf-8", errors="replace")
    objects = lua_to_python(extract_return_block(otext))
    assert isinstance(objects, dict)

    print("Parsing items...")
    itext = (QUESTIE / "Database" / "Classic" / "classicItemDB.lua").read_text(encoding="utf-8", errors="replace")
    items = lua_to_python(extract_return_block(itext))
    assert isinstance(items, dict)

    # Only keep NPCs/objects referenced by quests (and item drop sources) to slim the DB
    needed_npcs: set[int] = set()
    needed_objects: set[int] = set()
    needed_items: set[int] = set()
    slim_quests = {}
    for qid, q in quests.items():
        if not isinstance(qid, int) or not isinstance(q, list):
            continue
        slim_quests[qid] = q
        started = q[1] if len(q) > 1 else None
        finished = q[2] if len(q) > 2 else None
        objectives = q[9] if len(q) > 9 else None
        for block in (started, finished):
            if isinstance(block, list) and block and isinstance(block[0], list):
                for nid in block[0]:
                    if isinstance(nid, int):
                        needed_npcs.add(nid)
        obj_npcs, obj_objects, obj_items = extract_objective_ids(objectives)
        needed_npcs |= obj_npcs
        needed_objects |= obj_objects
        needed_items |= obj_items

    # Resolve item → NPC/object droppers; pull those entities into the slim DB
    item_npc_drops: dict[int, list[int]] = {}
    item_object_drops: dict[int, list[int]] = {}
    for item_id in sorted(needed_items):
        entry = items.get(item_id)
        if not isinstance(entry, list):
            continue
        # itemKeys: name=1, npcDrops=2, objectDrops=3 → 0-based 0,1,2
        npc_drops = entry[1] if len(entry) > 1 else None
        object_drops = entry[2] if len(entry) > 2 else None
        npc_list: list[int] = []
        if isinstance(npc_drops, list):
            for nid in npc_drops:
                if isinstance(nid, int) and nid > 0:
                    npc_list.append(nid)
                    needed_npcs.add(nid)
        obj_list: list[int] = []
        if isinstance(object_drops, list):
            for oid in object_drops:
                if isinstance(oid, int) and oid > 0:
                    obj_list.append(oid)
                    needed_objects.add(oid)
        if npc_list:
            item_npc_drops[item_id] = npc_list
        if obj_list:
            item_object_drops[item_id] = obj_list

    slim_npcs = {nid: npcs[nid] for nid in needed_npcs if nid in npcs and isinstance(npcs[nid], list)}
    slim_objects = {oid: objects[oid] for oid in needed_objects if oid in objects and isinstance(objects[oid], list)}

    write_lua_table(OUT / "Quests.lua", "DQTC.Data.quests", slim_quests, fmt_quest)
    write_lua_table(OUT / "Npcs.lua", "DQTC.Data.npcs", slim_npcs, fmt_npc)
    write_lua_table(OUT / "Objects.lua", "DQTC.Data.objects", slim_objects, fmt_object)

    # Item drop sources used by quest item objectives
    id_path = OUT / "ItemDrops.lua"
    id_lines = [
        "-- AUTO-GENERATED by tools/convert_questie_db.py from Questie Classic DB.",
        "-- Source: https://github.com/Questie/Questie — do not edit by hand.",
        "local ADDON_NAME = ...",
        "local DQTC = _G[ADDON_NAME]",
        "DQTC.Data = DQTC.Data or {}",
        "DQTC.Data.itemDrops = {}",
        "DQTC.Data.itemObjectDrops = {}",
    ]
    for item_id in sorted(item_npc_drops.keys()):
        id_lines.append(fmt_item_drops(item_id, item_npc_drops[item_id]))
    for item_id in sorted(item_object_drops.keys()):
        id_lines.append(fmt_item_object_drops(item_id, item_object_drops[item_id]))
    id_path.write_text("\n".join(id_lines) + "\n", encoding="utf-8")
    print(f"Wrote {id_path} ({len(item_npc_drops)} npc + {len(item_object_drops)} object item drops)")

    # Area map file
    am_path = ROOT / "Database" / "Classic" / "AreaMap.lua"
    lines = [
        "-- AUTO-GENERATED areaId -> uiMapId",
        "local ADDON_NAME = ...",
        "local DQTC = _G[ADDON_NAME]",
        "DQTC.Data = DQTC.Data or {}",
        "DQTC.Data.areaToUiMap = {",
    ]
    for k in sorted(area_map.keys()):
        lines.append(f"  [{k}] = {area_map[k]},")
    lines.append("}")
    am_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"Wrote {am_path} ({len(area_map)} entries)")

    # Ensure TOC includes generated DB files
    toc = ROOT / "DefaultQuestTrackerClassic.toc"
    toc_text = toc.read_text(encoding="utf-8")
    for rel in ("Database\\Classic\\AreaMap.lua", "Database\\Classic\\ItemDrops.lua"):
        if rel not in toc_text:
            toc_text = toc_text.replace(
                "Database\\Classic\\Objects.lua",
                "Database\\Classic\\Objects.lua\n" + rel,
            )
            print(f"Updated TOC with {rel}")
    toc.write_text(toc_text, encoding="utf-8")


if __name__ == "__main__":
    main()
