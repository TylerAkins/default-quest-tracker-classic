# Default Quest Tracker Classic

Unlimited quest tracker for **WoW Classic Era** that keeps the default Blizzard tracker look, with map/minimap markers and nameplate quest icons.

Questie is **not required** at runtime. The slim spawn/quest database shipped in `Database/Classic/` is **derived from Questie Classic** (see [Credits](#credits--license)).

## Features

- Track more than 5 quests (bypasses Blizzard watch limit)
- Default position under the minimap; unlock and drag to move; reset in options
- Map/minimap markers: `!` / `?` for available and turn-ins, small dots for objectives
- Item-drop objectives (bandanas, Hogger claw, etc.) resolve to mob spawn pins
- Available quest givers, objectives, and turn-ins (toggleable)
- Quest icons on nameplates + unit tooltip quest lines
- Right-click: Send to GPS (TomTom or Zygor), Copy Wowhead URL, untrack, focus
- Built-in Settings panel (`/dqtc`)

## Install (players)

1. Download a release zip (GitHub Releases or CurseForge when published).
2. Extract so the folder is named exactly `DefaultQuestTrackerClassic`.
3. Place it in:
   `World of Warcraft\_classic_era_\Interface\AddOns\`
4. Enable the addon at the character select screen.

Optional: [TomTom](https://www.curseforge.com/wow/addons/tomtom) for “Send to GPS”.

**HereBeDragons** is embedded under `Libs/` — you do **not** need a separate HBD install for pins.

## Commands

| Command | Action |
|---------|--------|
| `/dqtc` | Open options |
| `/dqtc lock` | Lock tracker position |
| `/dqtc unlock` | Unlock tracker (drag to move) |
| `/dqtc reset` | Reset tracker to default position |
| `/dqtc refresh` | Force refresh |
| `/dqtc testpin` | Drop a test pin on your position (opens map) |
| `/dqtc markers` | Force-enable markers and print diagnostics |
| `/dqtc tooltip [npcId]` | Print quest tooltip lines for an NPC |

## Verify markers

1. `/reload`
2. `/dqtc testpin` — yellow `!` on you with the map open
3. `/dqtc markers` — expect `mode=OK`, `hbd=true`
4. Hover a quest NPC/mob — tooltip lines appear

If Questie is also installed, leave **Suppress map/nameplate markers if Questie is loaded** **off** to see DQTC pins (or turn it on to avoid double markers).

## Credits & license

This addon is released under the **GNU General Public License v3** — see [LICENSE](LICENSE).

### Questie (quest / spawn database)

The Classic Era data under `Database/Classic/` is a **slim conversion** of Questie Classic community DB tables (`tools/convert_questie_db.py`). Questie is **not** bundled; DQTC does not copy Questie UI code or icons.

- GitHub: [https://github.com/Questie/Questie](https://github.com/Questie/Questie)
- CurseForge: [https://www.curseforge.com/wow/addons/questie](https://www.curseforge.com/wow/addons/questie)

Huge thanks to the Questie authors and contributors. If you want the full quest helper experience, use Questie.

### HereBeDragons

Map/minimap pins use an embedded copy of [HereBeDragons](https://www.wowace.com/projects/herebedragons) (BSD) by Nevcairiel, namespaced as `HereBeDragons-DQTC-*`.

### Other optional integrations

- [TomTom](https://www.curseforge.com/wow/addons/tomtom) — GPS arrow
- Zygor Guides — optional GPS if present (not required)

See [ATTRIBUTION.md](ATTRIBUTION.md) for publishing notes.

## Development

### Regenerating the slim DB

Requires the [Questie](https://github.com/Questie/Questie) addon installed as a sibling folder (`../Questie`):

```bash
python tools/convert_questie_db.py
```

Other maintainers scripts live under `tools/` (item objective patches, offline Wowhead crawl experiments). Do **not** commit `tools/.wowhead_cache/` or crawl logs.

### CurseForge packaging (when you publish)

1. Create the CurseForge project; set license to **GPLv3**.
2. Relations → **Embedded Library** → HereBeDragons (documentation).
3. Optional Relations → TomTom as **Optional Dependency**.
4. Upload a zip whose root folder is `DefaultQuestTrackerClassic` (same as the `.toc` name).
5. Prefer [BigWigs packager](https://github.com/BigWigsMods/packager) / `.pkgmeta` so `tools/` caches are excluded from the player zip; keep full source on GitHub for GPL compliance.
6. Paste a short Credits blurb (Questie + HereBeDragons links) into the CurseForge description.

Do **not** ship Questie’s addon folder, icons, or branding.

## Changelog

See [CHANGELOG.md](CHANGELOG.md).
