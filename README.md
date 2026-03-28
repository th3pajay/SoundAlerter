# SoundAlerter - Complete PvP Combat Suite

![Version](https://img.shields.io/badge/version-1.4.85-blue.svg) ![License](https://img.shields.io/badge/license-MIT-green.svg) ![WoW](https://img.shields.io/badge/WoW-3.3.5-orange.svg) ![Platform](https://img.shields.io/badge/platform-Ascension-purple.svg)

**From Simple Alerts to Complete Combat Suite**
Voice callouts evolved into a comprehensive PvP combat suite for WoW Ascension.
<p align="center">
<img src="Media/soundalerter.png" alt="SoundAlerter Addon Logo" width="256"/>
</p>
---

## A Different SoundAlerter 

SoundAlerter is a combat system built for competitive PvP. Eight integrated modules provide awareness of combat events.

**Performance**: Sub-millisecond latency, <500KB memory footprint, optimized to the brim. 
**Ascension Support**: Native support for retail and 11-prefixed spell IDs. 

---

---
1.4.85 - Profile nil crash, flagToast nil - position, technical pre-checks fixed
---


## The Complete Suite

### Voice Alerts - Instant Audio Callouts
450+ critical spell callouts with professional voice alerts.

[To extend: Use https://luvvoice.com/ English (United Kingdom) / Sonia with Rate 10% speed-up]

**Features:**
* Defensive cooldown tracking (Ice Block, Shield Wall, Divine Shield)
* CC alerts (Cyclone, Polymorph, Fear, Stuns)
* Interrupt notifications (Kick, Counterspell, Mind Freeze)
* Enemy and friendly spell differentiation
* English and Spanish voice packs

**Configuration**: `/sa` -> Voice Alerts tab

---

### Proximity Alerts - Range Detection
Visual and audio alerts for nearby enemies. Sticky toasts include instant targeting and countdown timers.
<p align="center">
<img src="Media/toast_sticky.gif?raw=true" alt="Sticky Toast" width="256"/>
</p>
**Features:**
* Automatic enemy detection with configurable range
* Persistent toasts until enemy leaves range
* One-click targeting from toast
* PvE mode filtering
* <1ms targeting latency

**Configuration**: `/sa` -> Proximity Alerts tab
**Commands**: `/satoast test` (preview), `/satoast status` (metrics)

---

### Battleground Alerts - Objective Tracking
Team-aware CTF tracking for WSG and Eye of the Storm. 
<p align="center">
<img src="Media/toast_bg_flagpickup.gif?raw=true" alt="BG Flag Alerts" width="256"/>
</p>
**Features:**
* Automatic team detection for mixed-faction BGs
* Class identification via combat log
* Visual flag status indicators
* Persistent class caching
* <10ms processing per event

**Configuration**: `/sa` -> Battleground Alerts tab
**Commands**: `/saflag myteam` (team check), `/saflag metrics` (stats)

---

### Resource Bars - Power Tracking
Unified bars for Health, Mana, Energy, Rage, and Combo Points.
<p align="center">
<img src="Media/resource_mgt.gif?raw=true" alt="Resource Mgt" width="256"/>
</p>
**Features:**
* Feral Druid form-switching support
* Smooth animations
* Zero-taint implementation
* Position memory per profile

**Configuration**: `/sa` -> Resource Bars tab

---

### Casting Bars - Accurate Timing
Cast bars for Player, Target, and Focus units.

**Features:**
* Millisecond accuracy
* Channeled and mid-cast targeting support
* Interrupt flash effects
* Independent unit toggles

**Configuration**: `/sa` -> Casting Bars tab

---

### Spell Tracker - Aura Management
Icon-based tracking for buffs, debuffs, and cooldowns.
<p align="center">
<img src="Media/spell_tracker.gif?raw=true" alt="Spell Tracker" width="256"/>
</p>
**Features:**
* Simultaneous player and target tracking
* Cooldown spiral animations
* Duration overlays
* Customizable icon sizing

**Configuration**: `/sa` -> Spell Tracker tab

---

### Spell Finder - Database Access
Search 12,000+ spells instantly for IDs and tooltip data.
<p align="center">
<img src="Media/find_spell_db_progress.gif?raw=true" alt="Find Spell" width="256"/>
</p>
**Features:**
* <1ms search response
* Retail and 11-prefixed ID support
* Non-blocking database build
* Data export functionality

**Configuration**: `/sa` -> Developer Tools tab

---

### Statistics - Combat Intelligence
Encounter statistics and danger ratings.

**Features:**
* Per-encounter data
* Alert frequency tracking
* Enemy danger ratings
* Session summaries

---

## Getting Started

### Installation
1. Download the latest release.
2. Extract the `SoundAlerter` folder to `World of Warcraft/Interface/AddOns/`.
3. Launch WoW and check the minimap button (alternatively use shift and ctrl clicks to shortcut proximity and battleground alerts).
 
<p align="center">
<img src="Media/minimap_anim.gif?raw=true" alt="Minimap Anim" width="32"/>
</p>

### Quick Setup
1. Type `/sa`.
2. Go to **Quick Start** tab.
3. Select combat zones (Arena, BGs, World).
4. Choose alert scope.
5. Test audio via preview.

---

## Performance Metrics

| Metric | Value | Details |
| :--- | :--- | :--- |
| Alert Latency | <1ms | Optimized combat log parsing |
| Memory Footprint | ~485 KB | String interning and LRU caching |
| Toast Targeting | <1ms | Pre-built unit scan lists |
| Flag Processing | P99 <10ms | Event-driven class caching |
| Spell Search | <1ms | Multi-level indexing |

---

## Command Reference

| Command | Action |
| :--- | :--- |
| `/sa` | Main options panel |
| `/satoast test` | Show test proximity alert |
| `/satoast status` | Proximity performance metrics |
| `/saflag myteam` | Current BG team assignment |
| `/saflag metrics` | Flag alert performance stats |
| `/saflag cache` | Class cache efficiency |
| `/sa stats` | Class detection statistics |

---

## Technical Highlights

* **Framework**: Built on Ace3 (AceAddon, AceEvent, AceDB, AceConfig, AceGUI).
* **Zero-Taint**: Uses secure APIs to prevent combat blocking.
* **Ascension-Native**: Handles both retail and 11-prefixed spell IDs.
* **Event-Driven**: Hooks `COMBAT_LOG_EVENT_UNFILTERED` for reliability.
* **Profiles**: Supports per-character configuration and export.

---

## Credits

**Authors**: Trolololol, Abatorlos, Duskashes, Superk
**Ascension Dev**: th3pajay
**Inspiration**: LootCollector (Toasts), Spy-Bronzebeard (Proximity)

---

## License
MIT License - Open for use, modification, and distribution.

Fair winds, fellow adventurers!
*th3pajay / Starmistx - An old feral (https://warcraftmovies.com/pv.php?t=3&l=pajay)*