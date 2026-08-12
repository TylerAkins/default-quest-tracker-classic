# Attribution & publishing notes

## What is original vs third-party

**Original DQTC code** (tracker UI, options, markers, tooltips, GPS bridge, etc.) is written for this addon. Shared ideas (unlimited tracker, map pins) are normal. Do **not** copy Questie/Dugi/Zygor source, icons, or branding.

## License

**GPLv3** ([LICENSE](LICENSE)).

`Database/Classic/` is derived from Questie Classic via `tools/convert_questie_db.py`. Questie is GPLv3; shipping that data keeps this project GPLv3 with source on GitHub.

## Questie

- GitHub: https://github.com/Questie/Questie  
- CurseForge: https://www.curseforge.com/wow/addons/questie  

Runtime Questie is optional. Credit them in README and CurseForge descriptions.

## HereBeDragons

Embedded [HereBeDragons](https://www.wowace.com/projects/herebedragons) (BSD), namespaced `HereBeDragons-DQTC-*`. On CurseForge: Relations → Embedded Library → HereBeDragons.

## Wowhead

`tools/crawl_wowhead_classic.py` is experimental offline tooling only. Be polite with rate limits; do not claim Wowhead endorsement. The live addon uses the Classic (Questie-derived) bake.

## Publish checklist

- [x] GPLv3 `LICENSE` + Questie credits in README  
- [x] HereBeDragons credit / embed  
- [x] `.gitignore` / `.pkgmeta`  
- [x] GitHub repo: https://github.com/TylerAkins/default-quest-tracker-classic  
- [ ] First **GitHub Release** (`v1.0.0`) with addon zip asset (folder name `DefaultQuestTrackerClassic`)  
- [ ] CurseForge project (coming soon); paste `CURSEFORGE_DESCRIPTION.md`; GPLv3; Relations for HBD / TomTom  
- [ ] Keep GitHub Releases in sync with CurseForge version numbers after launch  
