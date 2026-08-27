# Attribution & publishing notes

## What is original vs third-party

**Original DQTC code** (tracker UI, options, markers, tooltips, GPS bridge, etc.) is written for this addon. Shared ideas (unlimited tracker, map pins, numbered POIs) are normal. Do **not** copy other addons’ source, icons, or branding.

`Media/*.tga` are original circular fill/ring/atlas textures. QuestHelper drew numbered map dots from its own `Art/Icons.tga` atlas and a hover glow; this addon follows that idea (circular pins with the digit in the art + hover area) without shipping QuestHelper art.

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
- [x] `.gitignore` / `.pkgmeta` (player zip ignores `tools/`)  
- [x] GitHub repo: https://github.com/TylerAkins/default-quest-tracker-classic  
- [x] CI + Release workflows (`.github/workflows/`) — tag `v*` → GitHub Release zip  
- [ ] First **GitHub Release** (`v1.0.0`): bump TOC/CHANGELOG, `git tag -a v1.0.0 -m "v1.0.0" && git push origin v1.0.0`  
- [ ] CurseForge project (coming soon); paste `CURSEFORGE_DESCRIPTION.md`; GPLv3; Relations for HBD / TomTom  
- [ ] Phase 2: CurseForge auto-upload — repo secret `CF_API_TOKEN`, `## X-Curse-Project-ID:` in TOC, same tag workflow  
- [ ] Keep GitHub Releases in sync with CurseForge version numbers after launch  
