# Changelog

All notable changes to Default Quest Tracker Classic are documented here.

## [1.1.2] - 2026-08-27

### Fixed

- Area highlights no longer error with `Cannot set tex coords when texture has mask`
- Tracked quests use retail numbered-circle POIs on the tracker (not `(1)` text) and the same atlas on the map

## [1.1.1] - 2026-08-27

### Fixed

- Numbered map pins use the same brown/gold circle as available-quest bangs, with a gold digit on top (no floating black numbers)
- Area highlights are a small round wash behind the POI instead of a large stretched oval

## [1.1.0] - 2026-08-27

### Changed

- Map markers no longer place a pin on every spawn like Questie
- Tracked quests now highlight clustered objective/turn-in **areas** with matching **(1) (2) (3)** numbers
- Quest tracker titles show `(1) (2) (3)` in the same order as those map numbers
- Nameplates for tracked objectives/turn-ins use the same numbered POI
- GPS waypoints use the nearest clustered area instead of the first raw spawn

### Added

- Option to toggle world-map area highlights (`Highlight objective areas on the world map`)

## [1.0.3] - 2026-08-13

### Fixed

- Hide profession-gated quest offers until the character meets their required skill rank
- Hide AQ War Effort quest offers by default with a new configurable option

## [1.0.2] - 2026-08-13

### Added

- Clickable Questie chat links open and select matching quests in the active quest log

## [1.0.1] - 2026-08-12

### Added

- Optional setting to hide the quest tracker during combat, disabled by default

## [1.0.0] - 2026-08-12

### Added

- Unlimited Classic Era quest tracker with Blizzard-style presentation
- World map and minimap markers (available / objectives / turn-ins)
- Nameplate quest icons and unit tooltip quest lines
- Item-drop objective pins (Questie-derived slim DB)
- Race/class/prereq availability filtering; soft-prereq allowlist for known edge cases
- Optional TomTom / Zygor “Send to GPS”
- Embedded HereBeDragons (`HereBeDragons-DQTC-*`)
- Options panel and `/dqtc` slash commands
- Offline tools to regenerate Classic DB from Questie (`tools/convert_questie_db.py`)
