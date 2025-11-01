# SoundAlerter for Project Ascension (Bronzebeard)

<p align="center">
<img src="SoundAlerter/soundalerter.png" alt="SoundAlerter Addon Logo" width="256"/>
</p>

**Instant voice alerts for critical PvP spells.** Never miss Cyclone, Divine Shield, or enemy cooldowns again.

## Features

- **Quick Start** - Get arena-ready in 60 seconds with guided setup
- **Voice Alerts** - 450+ spells with intent-based organization (defensives, CC, cooldowns)
- **Proximity Alerts** - Detect stealthed enemies nearby (Rogues/Druids)
- **Spell Finder** - Search 12,000+ spells with IDs and tooltips
- **Ascension Support** - Auto-detects retail and 11-prefixed spell IDs
- **Multi-Channel Chat** - Alert teammates via party, raid, or battleground chat
- **Minimap Button** - Quick access with draggable icon
- **Dual Language** - English and Spanish voice packs

## Installation

1. Download the latest release
2. Extract **SoundAlerter** folder to `.../Interface/AddOns/`
3. Restart WoW or `/reload`

## Quick Setup

1. Type `/sa` in-game (or click minimap button)
2. Follow **Quick Start** tab (zones, alert scope, audio)
3. Enter arena/BG to hear voice alerts

## Advanced Usage

**Customize Alerts:**
- **Voice Alerts** tab - Toggle 450+ spells by class/intent
- **Proximity Alerts** tab - Detect nearby enemies
- **Advanced** tab - Create custom alerts
- **Developer Tools** tab - Find spell IDs for new alerts

**Chat Integration:**
- Enable multi-channel output in Voice Alerts > Chat Alerts
- Announce CC, interrupts, and cooldowns to teammates

## Performance

- **Database Build:** ~3.5 seconds (first login)
- **Search Speed:** <1ms with indexing
- **Memory Usage:** ~485 KB
- **Subsequent Logins:** ~2 seconds (loads from cache)

## Development

New features and enhancements are merged to `develop` branch first, then `main`.

### Technical Details
- **Optimized Spell Database** - String interning, multi-level indexing, LRU caching
- **SavedVariables Persistence** - Database persists between sessions
- **Non-blocking Scanning** - Background spell ID scanning (70,000 IDs in chunks)
- **WoW API Integration** - Uses `GetSpellInfo()` and `GameTooltip` for spell data

## Credits

| Role | Name |
|------|------|
| **Original Author** | Trolollolol |
| **Current Maintainer** | th3pajay (October 2025) |

Fair winds, fellow adventurers! 🌊
*th3pajay / Starmistx - An old feral (https://warcraftmovies.com/pv.php?t=3&l=pajay)*