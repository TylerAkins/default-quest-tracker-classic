#!/usr/bin/env python3
"""Bake DQTC.Data.itemNames for items referenced by ItemDrops.lua."""
from __future__ import annotations

import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
OUT = ROOT / "Database" / "Classic"
DEFAULT_ITEM_DB = pathlib.Path(r"C:\Users\takin\AppData\Local\Temp\Questie\Database\Classic\classicItemDB.lua")


def lua_double_quoted(s: str) -> str:
    return str(s or "").replace('"', "'").replace("\\", "\\\\")


def main() -> None:
    item_db = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT_ITEM_DB
    drops_path = OUT / "ItemDrops.lua"
    if not item_db.exists() or not drops_path.exists():
        print("missing inputs", file=sys.stderr)
        sys.exit(1)

    ids = {int(x) for x in re.findall(r"itemDrops\[(\d+)\]", drops_path.read_text(encoding="utf-8"))}
    ids |= {int(x) for x in re.findall(r"itemObjectDrops\[(\d+)\]", drops_path.read_text(encoding="utf-8"))}
    text = item_db.read_text(encoding="utf-8", errors="replace")

    names: dict[int, str] = {}
    for item_id in sorted(ids):
        m = re.search(rf"\[{item_id}\]\s*=\s*\{{", text)
        if not m:
            continue
        i = m.end() - 1
        depth = 0
        for j in range(i, len(text)):
            if text[j] == "{":
                depth += 1
            elif text[j] == "}":
                depth -= 1
                if depth == 0:
                    body = text[i + 1 : j]
                    break
        else:
            continue
        nm = re.match(r"\s*(?:'((?:\\'|[^'])*)'|\"((?:\\\"|[^\"])*)\")", body)
        if not nm:
            continue
        name = nm.group(1) if nm.group(1) is not None else nm.group(2)
        name = name.replace("\\'", "'").replace('\\"', '"')
        names[item_id] = name

    path = OUT / "ItemNames.lua"
    lines = [
        "-- AUTO-GENERATED itemId -> name for tooltip matching",
        "local ADDON_NAME = ...",
        "local DQTC = _G[ADDON_NAME]",
        "DQTC.Data = DQTC.Data or {}",
        "DQTC.Data.itemNames = {",
    ]
    for item_id, name in names.items():
        lines.append(f'  [{item_id}] = "{lua_double_quoted(name)}",')
    lines.append("}")
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"Wrote {path} ({len(names)} names)")
    for iid in (3172, 3173, 3174):
        print(iid, names.get(iid))


if __name__ == "__main__":
    main()
