# Attribution & publishing notes

## What is original vs third-party

**Original DQTC code** (tracker UI, options, marker controller, tooltips, GPS bridge, etc.) is written for this addon. Shared *ideas* (unlimited tracker, map pins) are normal in the addon ecosystem. Do **not** copy Questie/Dugi/Zygor source files, icons, or trademarked branding into this project.

## License

DQTC is licensed under **GPLv3** ([LICENSE](LICENSE)).

The Classic spawn/quest tables in `Database/Classic/` are **derived from Questie Classic** DB dumps via `tools/convert_questie_db.py`. Questie is GPLv3; shipping that derived database means this project stays GPLv3-compatible with source available (GitHub).

## Questie

- **GitHub:** [https://github.com/Questie/Questie](https://github.com/Questie/Questie)
- **CurseForge:** [https://www.curseforge.com/wow/addons/questie](https://www.curseforge.com/wow/addons/questie)

Credit Questie prominently in README and CurseForge descriptions. Runtime Questie is **optional** (DQTC embeds its own slim bake).

Do **not** claim the spawn DB is “original Blizzard data” if it came from Questie tables. Quest IDs and facts aren’t copyrighted; Questie’s compiled DB expression is.

## HereBeDragons

Map/minimap pins use an **embedded** copy of [HereBeDragons](https://www.wowace.com/projects/herebedragons) (BSD, Nevcairiel), registered as `HereBeDragons-DQTC-2.0` / `HereBeDragons-DQTC-Pins-2.0` so it does not clash with Questie’s HBD fork.

On CurseForge: Relations → **Embedded Library** → HereBeDragons.

## Wowhead

Optional offline crawl tooling (`tools/crawl_wowhead_classic.py`) may fetch public HTML for local baking. Do not scrape abusively; do not claim Wowhead endorsement. Incomplete `Database/Wowhead/` sample tables are not a substitute for the Classic (Questie-derived) bake.

## Blizzard / ToS

Reading the quest log and drawing UI frames is normal. Don’t automate gameplay. Wowhead **links** are fine; don’t ship scraped Wowhead page content as a product dump without care for their ToS.

## Publish checklist

- [x] `LICENSE` (GPLv3) for code + Questie-derived DB
- [x] Credit Questie (GitHub + CurseForge URLs) in README
- [x] Credit HereBeDragons
- [x] `.gitignore` excludes crawl caches / logs
- [x] `.pkgmeta` ready for packager (excludes tools caches from zip)
- [ ] Create GitHub repo; push without `tools/.wowhead_cache`
- [ ] Create CurseForge project; set GPLv3; paste credits into description
- [ ] Relations: Embedded Library → HereBeDragons; Optional → TomTom
- [ ] First release zip: folder name = `DefaultQuestTrackerClassic`
- [ ] Don’t ship Questie icons, code, or trademarked branding
