# Default Quest Tracker Classic

Unlimited quest tracker for **WoW Classic Era** with a Blizzard-style look, plus map/minimap markers and nameplate quest icons.

**Questie is not required.** This addon ships its own slim quest/spawn database derived from Questie Classic (see [Credits](#credits--license)).

**Repository:** [github.com/TylerAkins/default-quest-tracker-classic](https://github.com/TylerAkins/default-quest-tracker-classic)

## Install

### CurseForge (coming soon)

Install and update through the [CurseForge](https://www.curseforge.com/) app once the project is published. That will be the easiest option for most players.

### GitHub Releases (available now)

1. Open [Releases](https://github.com/TylerAkins/default-quest-tracker-classic/releases) and download the latest **addon zip** (not “Source code”).
2. Extract so the folder is named exactly `DefaultQuestTrackerClassic`.
3. Copy that folder into:
   `World of Warcraft\_classic_era_\Interface\AddOns\`
4. Restart WoW (or `/reload`), then enable the addon at the character select screen if needed.

> **Note:** GitHub’s automatic “Source code” zip is fine for developers, but players should use a **Release asset** zip whose root folder matches the `.toc` name. See [Cutting a release](#cutting-a-release) below.

### Optional addons

- [TomTom](https://www.curseforge.com/wow/addons/tomtom) — “Send to GPS” from the tracker or map pins  
- **HereBeDragons** — already embedded; no separate install needed for pins

## Features

- Track more than Blizzard’s usual watch limit
- Default position under the minimap; unlock/drag to move; reset in options
- Map and minimap markers (`!` / `?` for available and turn-ins; dots for objectives)
- Item-drop objectives resolve to mob spawn pins
- Available quests, objectives, and turn-ins (each toggleable)
- Nameplate icons and unit tooltip quest lines
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

You can run both. To avoid double map markers, enable **Suppress map/nameplate markers if Questie is loaded** in options. Leave it off if you want DQTC’s pins instead.

## Credits & license

Licensed under **GPLv3** — see [LICENSE](LICENSE).

### Questie (database source)

`Database/Classic/` is a slim conversion of Questie Classic community DB tables. Questie itself is not bundled; this addon does not copy Questie UI code or icons.

- [Questie on GitHub](https://github.com/Questie/Questie)
- [Questie on CurseForge](https://www.curseforge.com/wow/addons/questie)

Thanks to the Questie authors and contributors. For a full quest helper suite, use Questie.

### HereBeDragons

Map pins use an embedded copy of [HereBeDragons](https://www.wowace.com/projects/herebedragons) (BSD) by Nevcairiel (`HereBeDragons-DQTC-*`).

More detail: [ATTRIBUTION.md](ATTRIBUTION.md).

## Development

Regenerate the slim DB with [Questie](https://github.com/Questie/Questie) installed next to this folder (`../Questie`):

```bash
python tools/convert_questie_db.py
```

Scripts under `tools/` are for maintainers. Do not commit `tools/.wowhead_cache/` or crawl logs.

### Cutting a release

Players need a **GitHub Release** with an attached zip (CurseForge will use its own uploads later).

1. Bump `## Version:` in `DefaultQuestTrackerClassic.toc` and add notes to [CHANGELOG.md](CHANGELOG.md).
2. Build a zip whose **top-level folder** is `DefaultQuestTrackerClassic` (include the `.toc`, `Libs/`, `Database/`, modules — exclude `.git`, caches, and preferably `tools/`).
3. Tag and publish on GitHub, e.g. `v1.0.0`, and attach that zip as a release asset.
4. Prefer the [BigWigs packager](https://github.com/BigWigsMods/packager) with [.pkgmeta](.pkgmeta) so ignore rules stay consistent.

### CurseForge (when you publish)

1. Create the project; set license to **GPLv3**.
2. Relations → **Embedded Library** → HereBeDragons; optional → TomTom.
3. Paste [CURSEFORGE_DESCRIPTION.md](CURSEFORGE_DESCRIPTION.md) into the project description.
4. Upload the same style of zip as GitHub Releases.

## Changelog

See [CHANGELOG.md](CHANGELOG.md).
