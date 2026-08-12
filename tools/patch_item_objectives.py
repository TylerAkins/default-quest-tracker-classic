#!/usr/bin/env python3
"""
Patch Database/Classic for Questie item objectives without a full DB regen.

Reads Questie classicQuestDB + classicItemDB (+ classicNpcDB for missing droppers)
and updates Quests.lua o={} entries, writes ItemDrops.lua, appends missing NPCs.

Usage:
  python tools/patch_item_objectives.py [path/to/Questie/Database/Classic]
"""

from __future__ import annotations

import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
OUT = ROOT / "Database" / "Classic"
DEFAULT_QUESTIE_CLASSIC = pathlib.Path(r"C:\Users\takin\AppData\Local\Temp\Questie\Database\Classic")


def lua_double_quoted(s: str) -> str:
    s = str(s or "").replace('"', "'").replace("\\", "\\\\")
    return s


def extract_item_objectives(quest_db_text: str) -> dict[int, list[int]]:
    """questId -> [itemId, ...] from Questie objectives[3] item slot."""
    result: dict[int, list[int]] = {}
    # [qid] = {..., {creature},{object},{{itemId} or itemId}, ...}
    # Match quest rows and pull the objectives table (10th field is hard; use known pattern)
    # Questie stores objectives as: {nil,nil,{{1931}}} or {{{80}}} or {nil,{{obj}},nil}
    for m in re.finditer(
        r"\[(\d+)\]\s*=\s*\{(.*?)\}\s*,?\s*(?:\n|\[|\}\s*\]\])",
        quest_db_text,
        re.S,
    ):
        qid = int(m.group(1))
        body = m.group(2)
        # Find objectives-like `{nil,nil,{{123}}}` or `{nil,nil,{123}}` after description string
        # Prefer the first table that looks like objectives (has nested lists of ints, often after a quoted desc)
        item_ids: list[int] = []
        # Explicit item-only objective forms used by Questie
        for im in re.finditer(r"\{nil,nil,\{\{(\d+)\}\}\}", body):
            item_ids.append(int(im.group(1)))
        for im in re.finditer(r"\{nil,nil,\{(\d+)\}(?!\})", body):
            item_ids.append(int(im.group(1)))
        # Multi-item: {nil,nil,{{a},{b}}}
        for im in re.finditer(r"\{nil,nil,\{((?:\{\d+\},?)+)\}\}", body):
            for num in re.findall(r"\{(\d+)\}", im.group(1)):
                item_ids.append(int(num))
        if item_ids:
            # dedupe preserve order
            seen = set()
            uniq = []
            for i in item_ids:
                if i not in seen:
                    seen.add(i)
                    uniq.append(i)
            result[qid] = uniq
    return result


def extract_item_npc_drops(item_db_text: str, needed: set[int]) -> dict[int, list[int]]:
    drops: dict[int, list[int]] = {}
    for item_id in needed:
        # Match [id] = {'Name',{npc,...},...} or [id] = {"Name",nil,...}
        m = re.search(rf"\[{item_id}\]\s*=\s*\{{", item_db_text)
        if not m:
            continue
        i = m.end() - 1  # at '{'
        # scan balanced braces for full entry
        depth = 0
        start = i
        for j in range(i, len(item_db_text)):
            ch = item_db_text[j]
            if ch == "{":
                depth += 1
            elif ch == "}":
                depth -= 1
                if depth == 0:
                    body = item_db_text[start + 1 : j]
                    break
        else:
            continue
        # Skip quoted name, then read npcDrops field
        nm = re.match(r"\s*(?:'((?:\\'|[^'])*)'|\"((?:\\\"|[^\"])*)\")\s*,", body)
        if not nm:
            continue
        rest = body[nm.end() :].lstrip()
        if rest.startswith("nil"):
            continue
        if not rest.startswith("{"):
            continue
        depth = 0
        for j, ch in enumerate(rest):
            if ch == "{":
                depth += 1
            elif ch == "}":
                depth -= 1
                if depth == 0:
                    inner = rest[1:j]
                    npc_ids = [int(x) for x in re.findall(r"\d+", inner)]
                    if npc_ids:
                        drops[item_id] = npc_ids
                    break
    return drops


def extract_npc_spawn_line(npc_db_text: str, npc_id: int) -> str | None:
    m = re.search(rf"\[{npc_id}\]\s*=\s*\{{(.*?)\}}\s*,?\s*\n", npc_db_text, re.S)
    if not m:
        return None
    body = m.group(1)
    name_m = re.match(r"'((?:\\'|[^'])*)'|\"((?:\\\"|[^\"])*)\"", body)
    if not name_m:
        return None
    name = name_m.group(1) if name_m.group(1) is not None else name_m.group(2)
    name = name.replace("\\'", "'")
    # spawns dict: {[12]={{x,y},...}}
    sp_m = re.search(r"\{(\[\d+\]=\{.*)\}", body)
    # Find first {[area]=...} style after level fields — Questie npc: name, min,max,min,max,faction,spawns
    spawns_m = re.search(r",(\{\[\d+\].*\})\s*,nil,", body)
    if not spawns_m:
        # try looser: first {[digit]
        spawns_m = re.search(r"(\{\[\d+\]=\{(?:\{[0-9.]+,[0-9.]+\}(?:,)?)+\}\})", body)
    sp_lua = "{}"
    if spawns_m:
        raw = spawns_m.group(1)
        # Cap coords per area to 12
        capped_parts = []
        for am in re.finditer(r"\[(\d+)\]=\{((?:\{[0-9.]+,[0-9.]+\}(?:,)?)*)\}", raw):
            area = am.group(1)
            coords = re.findall(r"\{([0-9.]+),([0-9.]+)\}", am.group(2))[:12]
            if coords:
                c = ",".join(f"{{{x},{y}}}" for x, y in coords)
                capped_parts.append(f"[{area}]={{{c}}}")
        if capped_parts:
            sp_lua = "{" + ",".join(capped_parts) + "}"
    safe = lua_double_quoted(name)
    return f'DQTC.Data.npcs[{npc_id}]={{n="{safe}",sp={sp_lua}}}'


def patch_quests_lua(quests_path: pathlib.Path, item_objs: dict[int, list[int]]) -> int:
    text = quests_path.read_text(encoding="utf-8")
    patched = 0

    def repl(m: re.Match) -> str:
        nonlocal patched
        qid = int(m.group(1))
        line = m.group(0)
        items = item_objs.get(qid)
        if not items:
            return line
        # Build new o= merging existing non-empty with items
        o_m = re.search(r"o=(\{(?:[^{}]|\{[^{}]*\})*\})", line)
        if not o_m:
            return line
        existing = o_m.group(1)
        parts = []
        # keep existing monster/object entries
        for em in re.finditer(r'\{t="(monster|object|item)",i=(\d+)\}', existing):
            parts.append(f'{{t="{em.group(1)}",i={em.group(2)}}}')
        have_items = {int(x) for x in re.findall(r't="item",i=(\d+)', existing)}
        for iid in items:
            if iid not in have_items:
                parts.append(f'{{t="item",i={iid}}}')
        if not parts:
            return line
        new_o = "{" + ",".join(parts) + "}"
        if new_o == existing:
            return line
        patched += 1
        return line[: o_m.start(1)] + new_o + line[o_m.end(1) :]

    new_text = re.sub(r"DQTC\.Data\.quests\[(\d+)\]=\{.*\}", repl, text)
    quests_path.write_text(new_text, encoding="utf-8")
    return patched


def main() -> None:
    classic = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT_QUESTIE_CLASSIC
    qpath = classic / "classicQuestDB.lua"
    ipath = classic / "classicItemDB.lua"
    npath = classic / "classicNpcDB.lua"
    for p in (qpath, ipath, npath):
        if not p.exists():
            print(f"Missing {p}", file=sys.stderr)
            sys.exit(1)

    print("Scanning quest item objectives...")
    qtext = qpath.read_text(encoding="utf-8", errors="replace")
    item_objs = extract_item_objectives(qtext)
    print(f"  {len(item_objs)} quests with item objectives from Questie")

    print("Patching Quests.lua...")
    n_patched = patch_quests_lua(OUT / "Quests.lua", item_objs)
    print(f"  patched {n_patched} quest rows")

    # Prefer items already on Quests.lua (authoritative after patch) for drop resolution
    needed_items: set[int] = set()
    for ids in item_objs.values():
        needed_items.update(ids)
    quests_lua = (OUT / "Quests.lua").read_text(encoding="utf-8")
    for iid in re.findall(r't="item",i=(\d+)', quests_lua):
        needed_items.add(int(iid))

    print(f"Resolving drops for {len(needed_items)} items...")
    itext = ipath.read_text(encoding="utf-8", errors="replace")
    drops = extract_item_npc_drops(itext, needed_items)
    print(f"  {len(drops)} items with npcDrops")

    # ItemDrops.lua
    id_path = OUT / "ItemDrops.lua"
    lines = [
        "-- AUTO-GENERATED by tools/patch_item_objectives.py / convert_questie_db.py",
        "local ADDON_NAME = ...",
        "local DQTC = _G[ADDON_NAME]",
        "DQTC.Data = DQTC.Data or {}",
        "DQTC.Data.itemDrops = {}",
        "DQTC.Data.itemObjectDrops = {}",
    ]
    for item_id in sorted(drops.keys()):
        ids = ",".join(str(n) for n in drops[item_id])
        lines.append(f"DQTC.Data.itemDrops[{item_id}]={{{ids}}}")
    id_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"Wrote {id_path}")

    # Ensure dropper NPCs exist in Npcs.lua
    npcs_path = OUT / "Npcs.lua"
    npcs_text = npcs_path.read_text(encoding="utf-8")
    ntext = npath.read_text(encoding="utf-8", errors="replace")
    missing = []
    for npc_ids in drops.values():
        for nid in npc_ids:
            if f"DQTC.Data.npcs[{nid}]=" not in npcs_text:
                missing.append(nid)
    missing = sorted(set(missing))
    if missing:
        print(f"Appending {len(missing)} missing dropper NPCs...")
        extras = []
        for nid in missing:
            line = extract_npc_spawn_line(ntext, nid)
            if line:
                extras.append(line)
            else:
                print(f"  warn: no spawn data for npc {nid}")
        if extras:
            with npcs_path.open("a", encoding="utf-8") as f:
                f.write("\n-- Item dropper NPCs added by patch_item_objectives.py\n")
                f.write("\n".join(extras) + "\n")

    # Spot-check key quests
    qcheck = (OUT / "Quests.lua").read_text(encoding="utf-8")
    for qid in (18, 11, 153, 176):
        m = re.search(rf"DQTC\.Data\.quests\[{qid}\]=(\{{.*\}})", qcheck)
        print(f"  quest {qid}: {m.group(1) if m else 'MISSING'}")

    toc = ROOT / "DefaultQuestTrackerClassic.toc"
    toc_text = toc.read_text(encoding="utf-8")
    if "Database\\Classic\\ItemDrops.lua" not in toc_text:
        toc_text = toc_text.replace(
            "Database\\Classic\\Objects.lua",
            "Database\\Classic\\Objects.lua\nDatabase\\Classic\\ItemDrops.lua",
        )
        toc.write_text(toc_text, encoding="utf-8")
        print("Updated TOC with ItemDrops.lua")


if __name__ == "__main__":
    main()
