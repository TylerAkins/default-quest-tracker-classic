# CurseForge description (paste into project page)

Paste everything below this line into the CurseForge long description.

---

**Default Quest Tracker Classic** is an unlimited quest tracker for WoW Classic Era. It keeps a Blizzard-style watch list, draws numbered quest areas on the world map and minimap, and shows matching numbers on nameplates.

**Questie is not required.** This addon ships its own slim quest and spawn database, derived from Questie Classic community data. You can run it alone or alongside Questie.

## Features

- Track more quests than Blizzard’s usual watch limit
- Watch list under the minimap by default; unlock and drag to move, or reset in options
- Numbered tracker titles `(1) (2) (3)` that match world map and minimap pins
- Objective and turn-in **areas** clustered from the spawn database, not a pin on every mob
- Hover a numbered pin (map or tracker) for a light-blue transparent circle with a thin black outline
- Optional `!` pins for available quest givers
- Nameplate numbers and quest lines on unit tooltips
- Right-click a quest: focus, untrack, copy Wowhead URL, or send to GPS (TomTom)
- Questie chat links open the matching quest when it is in your log
- Options via `/dqtc`

## Using with Questie

You can use both addons at once. To avoid doubled map and nameplate markers, enable **Suppress map/nameplate markers if Questie is loaded** in options.

## Commands

- `/dqtc` — open options
- `/dqtc lock` / `/dqtc unlock` — lock or unlock tracker position
- `/dqtc reset` — reset the tracker to the default position

## Optional

- [TomTom](https://www.curseforge.com/wow/addons/tomtom) — Send to GPS
- HereBeDragons is already embedded for map pins

## Credits

- **Questie** — quest/spawn database source ([CurseForge](https://www.curseforge.com/wow/addons/questie), [GitHub](https://github.com/Questie/Questie)). Questie itself is not bundled; this addon does not copy Questie UI or icons.
- **HereBeDragons** (Nevcairiel) — embedded map pin library ([WowAce](https://www.wowace.com/projects/herebedragons))

## License

GPLv3. Source: [github.com/TylerAkins/default-quest-tracker-classic](https://github.com/TylerAkins/default-quest-tracker-classic)
