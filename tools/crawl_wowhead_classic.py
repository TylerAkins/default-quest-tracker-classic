#!/usr/bin/env python3
"""
Offline Wowhead Classic → DQTC Database/Wowhead bake.

Uses https://www.wowhead.com/classic/ (Classic Era / vanilla Classic).
No official API — rate-limited HTML fetch + parse of g_mapperData / listviews.

Strategy:
  1) Seed from existing Database/Classic quests (IDs + starters/enders/item objectives)
  2) Fetch Wowhead NPC pages for spawn coords (g_mapperData)
  3) Fetch Wowhead item pages for dropped-by NPC lists
  4) Emit Database/Wowhead/{Quests,Npcs,ItemDrops,ItemNames,AreaMap,Init}.lua

Usage:
  python tools/crawl_wowhead_classic.py --sample-elwynn
  python tools/crawl_wowhead_classic.py --from-classic --zones 12,38 --rate 60.0
  python tools/crawl_wowhead_classic.py --from-classic --limit-npcs 200

Be polite to Wowhead: default --rate is 60.0s between live fetches. On HTTP 403
the crawler backs off exponentially (30s, 60s, 120s, …) and retries the page
instead of failing immediately. Successful HTML is cached under tools/.wowhead_cache.
"""

from __future__ import annotations

import argparse
import json
import pathlib
import re
import sys
import time
import urllib.error
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parents[1]
CLASSIC = ROOT / "Database" / "Classic"
OUT = ROOT / "Database" / "Wowhead"
CACHE = ROOT / "tools" / ".wowhead_cache"

# Browser-like UA for a local offline bake tool (not a bulk public scraper).
UA = (
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
    "AppleWebKit/537.36 (KHTML, like Gecko) "
    "Chrome/124.0.0.0 Safari/537.36 "
    "DefaultQuestTrackerClassic-crawler/1.2"
)
BASE = "https://www.wowhead.com/classic"

# Default pause between live (uncached) fetches. Keep high to reduce 403s.
DEFAULT_RATE = 60.0
MIN_RATE = 0.8
# On HTTP 403 / 429: sleep these delays then retry the same URL.
THROTTLE_BACKOFF_SECS = (30, 60, 120, 240)
MAX_FETCH_RETRIES = 1 + len(THROTTLE_BACKOFF_SECS)  # initial try + backoff tries

# AreaId -> Classic Era uiMapId (subset; mirrors Database/Classic/AreaMap.lua)
AREA_TO_UIMAP = {
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
}

SAMPLE_QUESTS = [11, 18, 153, 176, 239, 353, 1097, 418, 416, 1338, 1339]


def ensure_dirs() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    CACHE.mkdir(parents=True, exist_ok=True)


def lua_quote(s: str) -> str:
    return str(s or "").replace("\\", "\\\\").replace('"', "'")


def fetch(url: str, rate: float, force: bool = False) -> str:
    """Fetch URL with HTML disk cache, polite rate limit, and 403/429 backoff.

    Cached pages are returned without sleeping or hitting the network.
    On throttle responses, sleeps THROTTLE_BACKOFF_SECS and retries so a
    temporary block does not abort the whole crawl.
    """
    cache_key = re.sub(r"[^a-zA-Z0-9._-]+", "_", url)
    cache_path = CACHE / f"{cache_key}.html"
    if cache_path.exists() and not force:
        return cache_path.read_text(encoding="utf-8", errors="replace")

    headers = {
        "User-Agent": UA,
        "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
        "Accept-Language": "en-US,en;q=0.9",
        "Referer": f"{BASE}/",
    }
    last_err: Exception | None = None
    for attempt in range(MAX_FETCH_RETRIES):
        time.sleep(max(rate, MIN_RATE))
        req = urllib.request.Request(url, headers=headers)
        try:
            with urllib.request.urlopen(req, timeout=45) as resp:
                text = resp.read().decode("utf-8", errors="replace")
            cache_path.write_text(text, encoding="utf-8")
            return text
        except urllib.error.HTTPError as e:
            last_err = e
            if e.code in (403, 429) and attempt < MAX_FETCH_RETRIES - 1:
                delay = THROTTLE_BACKOFF_SECS[min(attempt, len(THROTTLE_BACKOFF_SECS) - 1)]
                print(
                    f"  throttled HTTP {e.code} for {url} "
                    f"(attempt {attempt + 1}/{MAX_FETCH_RETRIES}); "
                    f"backing off {delay}s then retry…",
                    file=sys.stderr,
                    flush=True,
                )
                time.sleep(delay)
                continue
            raise RuntimeError(f"HTTP {e.code} for {url}") from e
        except urllib.error.URLError as e:
            last_err = e
            if attempt < MAX_FETCH_RETRIES - 1:
                delay = THROTTLE_BACKOFF_SECS[min(attempt, len(THROTTLE_BACKOFF_SECS) - 1)]
                print(
                    f"  network error for {url}: {e.reason!r} "
                    f"(attempt {attempt + 1}/{MAX_FETCH_RETRIES}); "
                    f"backing off {delay}s then retry…",
                    file=sys.stderr,
                    flush=True,
                )
                time.sleep(delay)
                continue
            raise RuntimeError(f"URL error for {url}: {e.reason}") from e
    raise RuntimeError(f"fetch failed for {url}: {last_err}")


def parse_mapper_data(html: str) -> dict[int, list[tuple[float, float]]]:
    """Parse var g_mapperData = {"38":[{"coords":[[x,y],...]}, ...], ...}"""
    m = re.search(r"var\s+g_mapperData\s*=\s*(\{.*?\})\s*;", html, re.S)
    if not m:
        m = re.search(r"g_mapperData\s*=\s*(\{.*?\})\s*;", html, re.S)
    if not m:
        return {}
    raw = m.group(1)
    # Prefer JSON; Wowhead uses JSON-ish here
    try:
        data = json.loads(raw)
    except json.JSONDecodeError:
        return {}
    out: dict[int, list[tuple[float, float]]] = {}
    for area_s, entries in data.items():
        try:
            area = int(area_s)
        except ValueError:
            continue
        coords: list[tuple[float, float]] = []
        if not isinstance(entries, list):
            continue
        for entry in entries:
            if not isinstance(entry, dict):
                continue
            for pair in entry.get("coords") or []:
                if isinstance(pair, list) and len(pair) >= 2:
                    try:
                        coords.append((float(pair[0]), float(pair[1])))
                    except (TypeError, ValueError):
                        pass
        if coords:
            out[area] = coords
    return out


def parse_npc_name(html: str) -> str:
    m = re.search(r"<title>([^<]+)</title>", html, re.I)
    if not m:
        return ""
    title = m.group(1)
    title = re.sub(r"\s*-\s*NPC.*$", "", title, flags=re.I).strip()
    title = re.sub(r"\s*-\s*Classic.*$", "", title, flags=re.I).strip()
    return title


def parse_item_name(html: str) -> str:
    m = re.search(r"<title>([^<]+)</title>", html, re.I)
    if not m:
        return ""
    title = m.group(1)
    title = re.sub(r"\s*-\s*Item.*$", "", title, flags=re.I).strip()
    title = re.sub(r"\s*-\s*Classic.*$", "", title, flags=re.I).strip()
    return title


def _extract_balanced_array(src: str, open_idx: int) -> str:
    """Return substring of [...] starting at open_idx (must be '[')."""
    if open_idx < 0 or open_idx >= len(src) or src[open_idx] != "[":
        return ""
    depth = 0
    in_str = False
    esc = False
    quote = ""
    for i in range(open_idx, len(src)):
        ch = src[i]
        if in_str:
            if esc:
                esc = False
            elif ch == "\\":
                esc = True
            elif ch == quote:
                in_str = False
            continue
        if ch in ("'", '"'):
            in_str = True
            quote = ch
            continue
        if ch == "[":
            depth += 1
        elif ch == "]":
            depth -= 1
            if depth == 0:
                return src[open_idx : i + 1]
    return ""


def parse_item_dropped_by_npcs(html: str) -> list[int]:
    """Extract NPC ids from the 'dropped-by' listview data array.

    Wowhead Classic puts computeDataFunc before data:, and rows are JSON
    objects with quoted keys ("id":217), not bare id:217.
    """
    ids: list[int] = []
    anchors = [
        r"id:\s*'dropped-by'",
        r'id:\s*"dropped-by"',
        r"id:\s*'dropCreatures'",
        r"WH\.TERMS\.droppedby",
    ]
    for pat in anchors:
        m = re.search(pat, html, re.I)
        if not m:
            continue
        window = html[m.start() : m.start() + 500000]
        dm = re.search(r"\bdata:\s*(\[)", window)
        if not dm:
            continue
        body = _extract_balanced_array(window, dm.start(1))
        if not body:
            continue
        try:
            data = json.loads(body)
            for row in data:
                if isinstance(row, dict) and "id" in row:
                    ids.append(int(row["id"]))
                elif isinstance(row, (int, float)):
                    ids.append(int(row))
        except (json.JSONDecodeError, TypeError, ValueError):
            for nid in re.findall(r'"id"\s*:\s*(\d+)', body):
                ids.append(int(nid))
        if ids:
            break

    if not ids:
        section = html
        m = re.search(r'id="tab-dropped-by".*?(id="tab-|</div>\s*<script>)', html, re.S | re.I)
        if m:
            section = m.group(0)
        for nid in re.findall(r"/classic/npc=(\d+)", section):
            ids.append(int(nid))

    seen: set[int] = set()
    out: list[int] = []
    for i in ids:
        if i not in seen:
            seen.add(i)
            out.append(i)
    return out


def parse_classic_quests_lua() -> dict[int, dict]:
    """Parse slim DQTC.Data.quests[...] lines into dicts."""
    path = CLASSIC / "Quests.lua"
    text = path.read_text(encoding="utf-8", errors="replace")
    quests: dict[int, dict] = {}

    def extract_brace_block(src: str, open_idx: int) -> str:
        depth = 0
        for i in range(open_idx, len(src)):
            ch = src[i]
            if ch == "{":
                depth += 1
            elif ch == "}":
                depth -= 1
                if depth == 0:
                    return src[open_idx + 1 : i]
        return ""

    for m in re.finditer(r"DQTC\.Data\.quests\[(\d+)\]\s*=\s*\{", text):
        qid = int(m.group(1))
        body = extract_brace_block(text, m.end() - 1)
        q: dict = {"id": qid}
        nm = re.search(r'n="([^"]*)"', body)
        q["n"] = nm.group(1) if nm else f"Quest {qid}"
        for key in ("l", "rl", "f", "r", "c", "nq"):
            km = re.search(rf"\b{key}=(-?\d+)", body)
            if km:
                q[key] = int(km.group(1))
        for key in ("s", "e", "pq", "pg", "ex"):
            km = re.search(rf"\b{key}=(\{{)", body)
            if km:
                inner = extract_brace_block(body, km.start(1))
                q[key] = [int(x) for x in re.findall(r"\d+", inner)]
            else:
                q[key] = []
        objs = []
        for om in re.finditer(r'\{t="(monster|object|item)",i=(\d+)\}', body):
            objs.append({"t": om.group(1), "i": int(om.group(2))})
        q["o"] = objs
        quests[qid] = q
    return quests


def parse_classic_npc_zones() -> dict[int, set[int]]:
    """npcId -> set of areaIds from Classic Npcs.lua (for zone filtering)."""
    path = CLASSIC / "Npcs.lua"
    text = path.read_text(encoding="utf-8", errors="replace")
    out: dict[int, set[int]] = {}
    for m in re.finditer(r"DQTC\.Data\.npcs\[(\d+)\]=\{n=\"([^\"]*)\",sp=(\{.*\})\}", text):
        nid = int(m.group(1))
        areas = {int(a) for a in re.findall(r"\[(\d+)\]=", m.group(3))}
        out[nid] = areas
    return out


def fmt_spawns(area_coords: dict[int, list[tuple[float, float]]], cap: int = 12) -> str:
    parts = []
    for area in sorted(area_coords.keys()):
        coords = area_coords[area][:cap]
        if not coords:
            continue
        cparts = ",".join(f"{{{x:g},{y:g}}}" for x, y in coords)
        parts.append(f"[{area}]={{{cparts}}}")
    return "{" + ",".join(parts) + "}"


def fmt_quest(q: dict) -> str:
    o_parts = [f'{{t="{o["t"]}",i={o["i"]}}}' for o in q.get("o") or []]
    parts = [
        f'n="{lua_quote(q.get("n",""))}"',
        f"l={q.get('l', 1)}",
        f"rl={q.get('rl', 1)}",
        f"f={q.get('f', 0)}",
        f"s={{{','.join(str(x) for x in (q.get('s') or []))}}}",
        f"e={{{','.join(str(x) for x in (q.get('e') or []))}}}",
        f"o={{{','.join(o_parts)}}}",
    ]
    if q.get("r"):
        parts.append(f"r={q['r']}")
    if q.get("c"):
        parts.append(f"c={q['c']}")
    if q.get("pq"):
        parts.append(f"pq={{{','.join(str(x) for x in q['pq'])}}}")
    if q.get("pg"):
        parts.append(f"pg={{{','.join(str(x) for x in q['pg'])}}}")
    if q.get("ex"):
        parts.append(f"ex={{{','.join(str(x) for x in q['ex'])}}}")
    if q.get("nq"):
        parts.append(f"nq={q['nq']}")
    return f"DQTC.DataSources.wowhead.quests[{q['id']}]={{{','.join(parts)}}}"


def write_outputs(
    quests: dict[int, dict],
    npcs: dict[int, dict],
    item_drops: dict[int, list[int]],
    item_names: dict[int, str],
    meta: dict,
) -> None:
    ensure_dirs()

    # Init bootstraps empty tables then other files fill them
    (OUT / "Init.lua").write_text(
        "\n".join(
            [
                "-- AUTO-GENERATED by tools/crawl_wowhead_classic.py",
                "local ADDON_NAME = ...",
                "local DQTC = _G[ADDON_NAME]",
                "DQTC.DataSources = DQTC.DataSources or {}",
                "DQTC.DataSources.wowhead = {",
                "  quests = {},",
                "  npcs = {},",
                "  objects = {},",
                "  itemDrops = {},",
                "  itemObjectDrops = {},",
                "  itemNames = {},",
                "  areaToUiMap = {},",
                "}",
                "",
            ]
        ),
        encoding="utf-8",
    )

    def header(extra: str = "") -> list[str]:
        return [
            "-- AUTO-GENERATED by tools/crawl_wowhead_classic.py. Do not edit by hand.",
            "local ADDON_NAME = ...",
            "local DQTC = _G[ADDON_NAME]",
            "DQTC.DataSources = DQTC.DataSources or {}",
            "DQTC.DataSources.wowhead = DQTC.DataSources.wowhead or {}",
            extra,
        ]

    q_lines = header("DQTC.DataSources.wowhead.quests = DQTC.DataSources.wowhead.quests or {}")
    for qid in sorted(quests):
        q_lines.append(fmt_quest(quests[qid]))
    (OUT / "Quests.lua").write_text("\n".join(q_lines) + "\n", encoding="utf-8")

    n_lines = header("DQTC.DataSources.wowhead.npcs = DQTC.DataSources.wowhead.npcs or {}")
    for nid in sorted(npcs):
        n = npcs[nid]
        n_lines.append(
            f'DQTC.DataSources.wowhead.npcs[{nid}]={{n="{lua_quote(n.get("n",""))}",sp={n.get("sp_lua","{{}}")}}}'
        )
    (OUT / "Npcs.lua").write_text("\n".join(n_lines) + "\n", encoding="utf-8")

    d_lines = header(
        "DQTC.DataSources.wowhead.itemDrops = DQTC.DataSources.wowhead.itemDrops or {}\n"
        "DQTC.DataSources.wowhead.itemObjectDrops = DQTC.DataSources.wowhead.itemObjectDrops or {}"
    )
    for iid in sorted(item_drops):
        ids = ",".join(str(x) for x in item_drops[iid])
        d_lines.append(f"DQTC.DataSources.wowhead.itemDrops[{iid}]={{{ids}}}")
    (OUT / "ItemDrops.lua").write_text("\n".join(d_lines) + "\n", encoding="utf-8")

    in_lines = header("DQTC.DataSources.wowhead.itemNames = DQTC.DataSources.wowhead.itemNames or {}")
    in_lines[5] = "DQTC.DataSources.wowhead.itemNames = {"
    # rewrite cleaner
    in_lines = header()[:-1] + ["DQTC.DataSources.wowhead.itemNames = {"]
    for iid, name in sorted(item_names.items()):
        in_lines.append(f'  [{iid}] = "{lua_quote(name)}",')
    in_lines.append("}")
    (OUT / "ItemNames.lua").write_text("\n".join(in_lines) + "\n", encoding="utf-8")

    am_lines = [
        "-- AUTO-GENERATED areaId -> uiMapId for Wowhead bake",
        "local ADDON_NAME = ...",
        "local DQTC = _G[ADDON_NAME]",
        "DQTC.DataSources = DQTC.DataSources or {}",
        "DQTC.DataSources.wowhead = DQTC.DataSources.wowhead or {}",
        "DQTC.DataSources.wowhead.areaToUiMap = {",
    ]
    for k in sorted(AREA_TO_UIMAP):
        am_lines.append(f"  [{k}] = {AREA_TO_UIMAP[k]},")
    am_lines.append("}")
    (OUT / "AreaMap.lua").write_text("\n".join(am_lines) + "\n", encoding="utf-8")

    (OUT / "crawl_meta.json").write_text(json.dumps(meta, indent=2), encoding="utf-8")
    print(f"Wrote Wowhead bake: quests={len(quests)} npcs={len(npcs)} itemDrops={len(item_drops)}")


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--sample-elwynn", action="store_true", help="Bake sample Elwynn/Loch quest set")
    ap.add_argument("--from-classic", action="store_true", help="Seed quests from Database/Classic/Quests.lua")
    ap.add_argument("--quest-ids", type=str, default="", help="Extra quest ids / ranges")
    ap.add_argument("--zones", type=str, default="", help="Only quests whose Classic NPCs spawn in these areaIds")
    ap.add_argument("--limit-npcs", type=int, default=0, help="Cap NPC fetches (0 = no cap)")
    ap.add_argument("--limit-items", type=int, default=0, help="Cap item fetches (0 = no cap)")
    ap.add_argument(
        "--rate",
        type=float,
        default=DEFAULT_RATE,
        help=(
            f"Seconds between live (uncached) fetches "
            f"(default {DEFAULT_RATE}; cached pages skip the wait). "
            "Raise further if Wowhead returns HTTP 403."
        ),
    )
    ap.add_argument("--force", action="store_true", help="Ignore HTML cache")
    args = ap.parse_args()

    if args.rate < MIN_RATE:
        print(
            f"warning: --rate {args.rate} is very aggressive; "
            f"clamping floor to {MIN_RATE}s for live fetches",
            file=sys.stderr,
        )

    ensure_dirs()
    classic_quests = parse_classic_quests_lua()
    classic_npc_zones = parse_classic_npc_zones()

    quest_ids: set[int] = set()
    if args.sample_elwynn:
        quest_ids.update(SAMPLE_QUESTS)
    if args.from_classic:
        quest_ids.update(classic_quests.keys())
    if args.quest_ids:
        for part in args.quest_ids.split(","):
            part = part.strip()
            if not part:
                continue
            if "-" in part:
                a, b = part.split("-", 1)
                quest_ids.update(range(int(a), int(b) + 1))
            else:
                quest_ids.add(int(part))

    if not quest_ids:
        print("No quests selected. Use --sample-elwynn and/or --from-classic / --quest-ids", file=sys.stderr)
        sys.exit(1)

    zone_filter: set[int] | None = None
    if args.zones:
        zone_filter = {int(x) for x in args.zones.split(",") if x.strip()}

    # Build quest subset
    selected: dict[int, dict] = {}
    for qid in sorted(quest_ids):
        q = classic_quests.get(qid)
        if not q:
            continue
        if zone_filter is not None:
            npc_ids = set(q.get("s") or []) | set(q.get("e") or [])
            # also include known droppers later; for now filter by starter/ender zones
            ok = False
            for nid in npc_ids:
                if classic_npc_zones.get(nid, set()) & zone_filter:
                    ok = True
                    break
            # also include if any monster objective npc in zone
            for o in q.get("o") or []:
                if o["t"] == "monster" and classic_npc_zones.get(o["i"], set()) & zone_filter:
                    ok = True
                    break
            if not ok and not (npc_ids or q.get("o")):
                ok = True
            if not ok:
                continue
        selected[qid] = q

    print(f"Selected {len(selected)} quests")

    needed_npcs: set[int] = set()
    needed_items: set[int] = set()
    for q in selected.values():
        needed_npcs.update(q.get("s") or [])
        needed_npcs.update(q.get("e") or [])
        for o in q.get("o") or []:
            if o["t"] == "monster":
                needed_npcs.add(o["i"])
            elif o["t"] == "item":
                needed_items.add(o["i"])

    item_drops: dict[int, list[int]] = {}
    item_names: dict[int, str] = {}
    meta = {"base": BASE, "quests": len(selected), "pages": {}}

    item_list = sorted(needed_items)
    if args.limit_items and len(item_list) > args.limit_items:
        item_list = item_list[: args.limit_items]
    print(f"Fetching {len(item_list)} item pages for droppers...")
    for i, iid in enumerate(item_list, 1):
        url = f"{BASE}/item={iid}"
        try:
            html = fetch(url, args.rate, force=args.force)
            name = parse_item_name(html)
            drops = parse_item_dropped_by_npcs(html)
            if name:
                item_names[iid] = name
            if drops:
                item_drops[iid] = drops
                needed_npcs.update(drops)
            meta["pages"][f"item:{iid}"] = {"ok": True, "drops": len(drops), "name": name}
            print(f"  [{i}/{len(item_list)}] item {iid} {name!r} drops={len(drops)}")
        except Exception as e:  # noqa: BLE001
            meta["pages"][f"item:{iid}"] = {"ok": False, "error": str(e)}
            print(f"  [{i}/{len(item_list)}] item {iid} FAIL {e}", file=sys.stderr)

    npc_list = sorted(needed_npcs)
    if args.limit_npcs and len(npc_list) > args.limit_npcs:
        npc_list = npc_list[: args.limit_npcs]
    print(f"Fetching {len(npc_list)} NPC pages for spawns...")
    npcs: dict[int, dict] = {}
    for i, nid in enumerate(npc_list, 1):
        url = f"{BASE}/npc={nid}"
        try:
            html = fetch(url, args.rate, force=args.force)
            name = parse_npc_name(html)
            mapper = parse_mapper_data(html)
            # Cap coords per area
            capped = {a: c[:12] for a, c in mapper.items()}
            npcs[nid] = {"n": name or f"NPC {nid}", "sp_lua": fmt_spawns(capped)}
            meta["pages"][f"npc:{nid}"] = {"ok": True, "areas": list(mapper.keys()), "name": name}
            print(f"  [{i}/{len(npc_list)}] npc {nid} {name!r} areas={list(mapper.keys())}")
        except Exception as e:  # noqa: BLE001
            meta["pages"][f"npc:{nid}"] = {"ok": False, "error": str(e)}
            print(f"  [{i}/{len(npc_list)}] npc {nid} FAIL {e}", file=sys.stderr)

    write_outputs(selected, npcs, item_drops, item_names, meta)
    print("Done. In-game: set Quest POI data source to Wowhead, then /reload.")


if __name__ == "__main__":
    main()
