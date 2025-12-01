# SoundAlerter for Project Ascension (Bronzebeard)

![Version](https://img.shields.io/badge/version-1.4.57-blue.svg) ![License](https://img.shields.io/badge/license-MIT-green.svg) ![WoW](https://img.shields.io/badge/WoW-3.3.5-orange.svg)
<p align="center">
<img src="Media/soundalerter.png" alt="SoundAlerter Addon Logo" width="256"/>
</p>

**Never miss critical enemy cooldowns again.**  SoundAlerter provides real-time, high-priority audio and visual cues to give you the competitive edge in World of Warcraft PvP.

---

## Recent Updates (v1.4.56)

**Resource Management:**
- Unified resource bars (Energy/Rage, Health/Mana) with full customization and persistent positioning
- Combo points bar with celebration animations and optional text display
<p align="center">
<img src="Media/resource_mgt.gif?raw=true" alt="Resource Mgt" width="256"/>
</p>

**Battleground Alerts (CTF):**
- Flag pickup, drop, capture, and return detection via combat log auras and chat messages
- Team-aware filtering (friendly/enemy) with persistent class and team caching
- Toast notifications with color-coded backgrounds (red for enemy, green for friendly)
- Composite audio alerts (class name + objective)
<p align="center">
<img src="Media/toast_bg_flagpickup.gif?raw=true" alt="BG Flag Alerts" width="256"/>
</p>

**Proximity Alerts:**
- Dual-pool toast system (secure/insecure frames) for combat taint protection
- Hover-to-pause countdown with visual segment timer
- Click-to-target and Shift-click-to-focus functionality
- Rainbow border option and class-colored backgrounds
<p align="center">
<img src="Media/toast_sticky.gif?raw=true" alt="Sticky Toast" width="256"/>
</p>


**Statistics Tracking:**
- Session and all-time alert tracking by category (spell, proximity, flag, trinket)
- Top spells with LRU eviction, zone-based breakdowns, and reset functionality

**Spell Finder (Developer Tools):**
- Database of 12,000+ spells with LRU caching for instant repeated searches
- Click actions: Left-click to copy spell ID, Shift+Left-click to copy description
- Non-blocking scan with progress bar (prevents UI freezing)
<p align="center">
<img src="Media/find_spell_db_progress.gif?raw=true" alt="Find Spell" width="256"/>
</p>

**Minimap Button:**
- Quick-toggle for proximity/battleground alerts (Shift+Click, Ctrl+Click)
- Animated hover effects and state-based icons
- Draggable with persistent positioning
<p align="center">
<img src="Media/minimap_anim.gif?raw=true" alt="Minimap Anim" width="32"/>
</p>

**Performance Optimizations:**
- Persistent class cache (survives sessions) for battleground/proximity alerts
- Negative lookup cache (5s TTL) reduces repeated unit frame scans
- Lazy cache cleanup (O(1) per access vs O(n) periodic sweeps)
- Combat-aware taint protection (chat alerts suppressed during combat)

**Bug Fixes:**
- Fixed typo: `aruaApplied` → `auraApplied` in combat log event handling
- Fixed proximity toast click errors during combat/non-combat state transitions
- Fixed chat group output channel handling (e.g., `/s` for stealth messages)

---

## Key Features

**Voice Alerts:** 450+ critical spell callouts (defensives, CC, interrupts, cooldowns)
**Proximity Alerts:** Visual toasts + audio alerts for nearby enemies with instant targeting
**Battleground Alerts:** Flag event detection (WSG, EOTS) with team-aware filtering
**Resource Bars:** Unified Health/Mana/Energy/Rage/Combo tracking for Feral Druids
**Spell Finder:** Search 12,000+ spells with tooltips and IDs (Developer Tools tab)
**Chat Integration:** Auto-announce CC, interrupts, cooldowns to party/raid/battleground
**Ascension Support:** Auto-detects retail and 11-prefixed spell IDs
**Dual Language:** English and Spanish voice packs included

---

## Getting Started

### Installation
1.  **Download** the latest release
2.  **Extract** the `SoundAlerter` folder to your WoW AddOns directory (`.../Interface/AddOns/`)
3.  **Restart WoW** or use the `/reload` command in-game

### Quick Setup
1.  Type `/sa` in-game (or click the Minimap Button)
2.  Follow the steps in the **Quick Start** tab (set zones, alert scope, and audio)
3.  Enter an Arena or Battleground to immediately hear the voice alerts

---

## Advanced Usage

| Feature | Tab Location | Description |
| :--- | :--- | :--- |
| **Customize Voice Alerts** | **Voice Alerts** tab | Toggle and fine-tune the 450+ spell alerts by class and intent |
| **Proximity Tuning** | **Proximity Alerts** tab | Adjust distance threshold, choose output (voice or toasts), enable click-to-target/focus |
| **Battleground Alerts** | **Battleground Alerts** tab | Configure flag event audio, toasts, chat alerts, and team filtering |
| **Resource Bars** | **Resource Bars** tab | Enable/customize Health, Mana, Energy, Rage, and Combo Point bars |
| **Statistics** | **Statistics** tab | View alert tracking by category, zone, and top spells |
| **Create Custom Alerts** | **Advanced** tab | Define your own rules for specific in-game events |
| **Chat Integration** | **Voice Alerts** tab > **Chat Alerts** | Enable multi-channel output to alert teammates of CC, interrupts, and cooldowns |
| **Find Spell IDs** | **Developer Tools** tab | Use this tool to quickly find spell IDs for creating new custom alerts |
| **Performance Stats** | **In-Game Commands** | `/sa stats` (class detection), `/saflag metrics` (battleground), `/satoast status` (proximity) |

---

## Performance & Technical Details

| Metric | Detail | Technical Feature |
| :--- | :--- | :--- |
| **Initial Load** | ~3.5 seconds (first login) | Database build with string interning & multi-level indexing |
| **Subsequent Load** | ~2 seconds | Loads from SavedVariables persistence & LRU caching |
| **Search Speed** | <1ms | Advanced indexing for spell database |
| **Memory Usage** | ~485 KB | Extremely low memory footprint |
| **Spell Scanning** | Non-blocking (70,000 IDs in chunks) | Prevents game freezes; uses `GetSpellInfo()` and `GameTooltip` |
| **Toast Click Latency** | <1ms (common case) | Optimized targeting with pre-built unit scan lists and cached combat state |
| **Flag Alert Processing** | P99: <10ms | Event-driven with persistent class cache and lazy cleanup |
| **Proximity Cache** | 60s TTL (temporary) + persistent (disk-saved) | Dual-tier caching with automatic eviction |
| **Development** | N/A | New features merged to `develop` branch first, then `main` |

---

## In-Game Commands

| Command | Description |
| :--- | :--- |
| `/sa` | Open options menu |
| `/sa stats` | Show class detection performance stats |
| `/saflag metrics` | Show battleground alert performance metrics |
| `/saflag cache` | Show battleground class cache size |
| `/saflag myteam` | Show your current team assignment (mixed-faction BGs) |
| `/satoast test` | Show test proximity toast |
| `/satoast status` | Show proximity toast system performance metrics |

---

## License

MIT License

---

## Shoutout
Respect and admiration to these developers for their ingenuity and inspiration:
* https://github.com/mmobrain/LootCollector/tree/main
* https://github.com/MCribari/Spy-Bronzebeard

Fair winds, fellow adventurers!
*th3pajay / Starmistx - An old feral (https://warcraftmovies.com/pv.php?t=3&l=pajay)*
