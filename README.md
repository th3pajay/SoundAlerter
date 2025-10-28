# SoundAlerter for WoW Ascension: Classic+

<p align="center">
<img src="SoundAlerter/soundalerter.png" alt="SoundAlerter Addon Logo" width="256"/>
</p>

**Instant voice alerts for critical PvP spells.** Never miss Cyclone, Divine Shield, or enemy cooldowns again.

## Features

- **Voice Alerts** - Real-time audio for CC, interrupts, and defensive cooldowns
- **Spell Finder** - Built-in tool to search 12,000+ spells with IDs and tooltips
- **Ascension Support** - Auto-detects both retail and 11-prefixed spell IDs
- **Customizable** - Toggle alerts per spell via `/sa` options menu
- **Multi-Channel Output** - Send alerts to say, party, raid, or battleground chat
- **Minimap Button** - Draggable button for quick access
- **Dual Language** - English (major updates, encoded with 40% size reduction) and Spanish voice packs

## WIP
- **Voice Rework**
- **Proximity Alerts**
- **Additional Performance Optimizations**

## Installation

1. Download the latest release
2. Extract **SoundAlerter** folder to `.../Interface/AddOns/`
3. Restart WoW or `/reload`

## Usage

**Open Options:**
- Type `/sa` in-game
- Or click the minimap button (battle shout icon)

**Find Spell IDs:**
1. `/sa` → **Find Spell** tab
2. Click "Open Spell Finder Window"
3. Search by spell name (e.g., "Polymorph", "Healing Touch")
4. View results with retail and Ascension IDs
5. Hover for tooltips

**Add Custom Spells:**
- Use Find Spell to discover spell IDs
- Edit `spellist.lua` to add new alerts
- Add corresponding MP3 file to `Voice/` folder

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