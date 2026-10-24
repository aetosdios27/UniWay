# POI Icon Assets

> **NOTE:** The PNG icons currently in this directory are temporary **PLACEHOLDERS** for designers' Figma exports. They are simple colored circular badges with two-letter glyphs generated for testing and development.

## Designer Export Specification
- **Base Canvas:** 32x32 dp/pt frame.
- **Export Format:** PNG @2x (64x64 px), transparent background.
- **File Name:** `<icon_key>.png` matching the icon key exactly (all lowercase, no spaces).
- **Replacement:** Replace the existing placeholder file in-place (`assets/icons/poi/<key>.png`).

## Supported Icon Keys
The keys are defined in `data/poi-icon-keys.json` (version 1) and in `lib/core/constants/poi_icons.dart` (`kPoiIconKeys`):

| Key | Description | Categories that map to it |
| --- | --- | --- |
| `default` | Fallback for anything unrecognised | any other category |
| `academic` | Academic blocks, lecture halls, library | academic, library |
| `dome` | The Dome building | dome |
| `food` | Mess, canteens, food courts | food, canteen, mess |
| `entrance` | Gates and entry/exit points | entrance, exit, gate, entrance/exit |
| `amenities` | Toilets, ATMs, parking, medical and similar | amenities, amenity, toilet, restroom, atm, parking, medical |
| `auditorium` | Amphitheatre and auditorium | auditorium, amphitheatre, amphitheater, ampi/audi |
| `sports` | Grounds, courts, sports facilities | sports, sport |


