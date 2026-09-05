# Default Quest Tracker Classic

Unlimited quest tracker for **WoW Classic Era**: a Blizzard-style watch list, retail-style numbered quest areas on the map, and nameplate icons.

**Questie is not required.** This addon ships its own slim quest/spawn database derived from Questie Classic community data (see [Credits](#credits--license)).

**Repository:** [github.com/TylerAkins/default-quest-tracker-classic](https://github.com/TylerAkins/default-quest-tracker-classic)

## Install

Download the latest **addon zip** from [Releases](https://github.com/TylerAkins/default-quest-tracker-classic/releases) (not GitHub’s “Source code” archive). Extract so the folder is named exactly `DefaultQuestTrackerClassic`, then copy it into:

`World of Warcraft\_classic_era_\Interface\AddOns\`

Restart WoW (or `/reload`) and enable the addon at character select if needed.

CurseForge publishing is planned; until then, GitHub Releases are the install path.

**Optional:** [TomTom](https://www.curseforge.com/wow/addons/tomtom) for “Send to GPS.” HereBeDragons is already embedded.

## Features

- Track more quests than Blizzard’s usual watch limit
- Organize tracked quests by zone (on by default); click a zone name to collapse or expand it
- Default position under the minimap; unlock/drag to move; reset in options
- Tracker titles numbered `(1) (2) (3)`, matching world map and minimap POIs
- Objective and turn-in **areas** clustered from the spawn database (not a pin on every mob)
- Hover a numbered pin (map or tracker) for a light-blue transparent circle with a thin black outline
- `!` pins for available quest givers (toggleable)
- Nameplate numbers and unit tooltip quest lines
- Clickable Questie chat links open the matching quest in your log
- Right-click: Send to GPS, copy Wowhead URL, untrack, focus
- Options via `/dqtc`

## Commands

| Command | Action |
|---------|--------|
| `/dqtc` | Open options |
| `/dqtc lock` / `unlock` | Lock or unlock tracker position |
| `/dqtc reset` | Reset tracker to the default position |
| `/dqtc refresh` | Force a full refresh |
| `/dqtc testpin` | Place a test pin on your position |
| `/dqtc markers` | Enable markers and print diagnostics |
| `/dqtc tooltip [npcId]` | Print tooltip lines for an NPC |

## Using with Questie

You can run both. To avoid double map markers, enable **Suppress map/nameplate markers if Questie is loaded** in options.

Clicking a Questie quest link in chat opens that quest when it is in your log. Links for quests you are not on keep Questie’s normal tooltip behavior.

## Credits & license

Licensed under **GPLv3** — see [LICENSE](LICENSE). More detail: [ATTRIBUTION.md](ATTRIBUTION.md).

### Questie (database source)

`Database/Classic/` is a slim conversion of Questie Classic community DB tables. Questie itself is not bundled; this addon does not copy Questie UI code or icons.

- [Questie on GitHub](https://github.com/Questie/Questie)
- [Questie on CurseForge](https://www.curseforge.com/wow/addons/questie)

### HereBeDragons

Map pins use an embedded copy of [HereBeDragons](https://www.wowace.com/projects/herebedragons) (BSD) by Nevcairiel (`HereBeDragons-DQTC-*`).

## Development

Regenerate the slim DB with [Questie](https://github.com/Questie/Questie) installed next to this folder (`../Questie`):

```bash
python tools/convert_questie_db.py
```

Scripts under `tools/` are for maintainers. Do not commit `tools/.wowhead_cache/` or crawl logs.

Releases are built by GitHub Actions from annotated tags (`vX.Y.Z`). Set the TOC version, update [CHANGELOG.md](CHANGELOG.md), then tag. Player zips come from the Release asset, not the automatic source archive. Publishing notes: [ATTRIBUTION.md](ATTRIBUTION.md).
