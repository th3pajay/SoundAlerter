# SoundAlerter for Project Ascension (Bronzebeard)

![Version](https://img.shields.io/badge/version-1.4.4-blue.svg) ![License](https://img.shields.io/badge/license-MIT-green.svg) ![WoW](https://img.shields.io/badge/WoW-3.3.5-orange.svg)
<p align="center">
<img src="Media/soundalerter.png" alt="SoundAlerter Addon Logo" width="256"/>
</p>

**Never miss critical enemy cooldowns again.**  SoundAlerter provides real-time, high-priority audio and visual cues to give you the competitive edge in World of Warcraft PvP.

---
## ✨ Experimental Features

V1.4.4
* ***Resource Management:***
* Single unified bar for core resources (Health/Mana or Energy/Rage).
* Combo bar + combo points preserved.
* Full customization: textures, scaling.

Persistence: bar positions and sizes are stored and survive UI reloads and client restarts.
<p align="center">
<img src="Media/resource_mgt.gif?raw=true" alt="BG Flag Alerts" width="256"/>
</p>

* ***Battleground Alerts:***
  * Flag/CTF alerts for Battlegrounds (WSG, EOTS).
  * Toast backgrounds automatically colored by team (friendly / enemy).
  * Optional rainbow edge effect for extra visibility.

// Battleground alerts are based upon mixed-faction team compositions identified over time. As the battle goes on GUID list with enemy names and classes is added to the list. 
Alerts will either successfully identify classes or in case not yet seen players, in 'ramp-up' will only alert for 'enemy' flag alerts.

<p align="center">
<img src="Media/toast_bg_flagpickup.gif?raw=true" alt="BG Flag Alerts" width="256"/>
</p>

* ***Sticky Toasts:*** **Hover** over to stop in-frame countdown of toast fade-out.
  * Hover over a toast to pause its fade-out countdown.
  * Works both in/combat with safe fallbacks.
  * Optional rainbow edge effect.

<p align="center">
<img src="Media/toast_sticky.gif?raw=true" alt="Sticky Toast" width="256"/>
</p>

* ***Proximity Alerts:***
  * Reorganized options with clearer layout.
  * Dual pool (combat / non-combat) for secure-button handling — prevents taint and click-action errors.
  * Fine-tuned behavior for toasts that trigger during combat transitions.


* ***Find Spell***
  * Progress bar while rebuilding the spell DB.
  * LRU caching to speed repeated searches.
  * Click actions: Left-click / Shift+Left-click to insert spellID or description into chat. Enchant IDs and other DB entries supported.

<p align="center">
<img src="Media/find_spell_db_progress.gif?raw=true" alt="Find Spell" width="256"/>
</p>

* **New minimap button:**
* Toggle proximity/background alerts via minimap icon.
* Shift/Ctrl modifiers allow separate quick toggles.

<p align="center">
<img src="Media/minimap_anim.gif?raw=true" alt="Minimap Anim" width="32"/>
</p>

## ⛓️‍💥 Fixes
* Typo fixed: aruaApplied → auraApplied.
* Proximity Alert click errors: improved protection for toasts fired during the transition between combat and non-combat states.
* Chat groups: sadb.chatgroups now respect channel outputs properly (e.g., /s for stealth messages to enemy channels is fixed).

## 🧩 Key Features & Functionality

### ⚔️ Combat & Alert System
* **Voice Alerts:** Hear **450+ critical spell callouts**, logically organized by intent (defensives, Crowd Control (CC), interrupts, cooldowns).
* **Proximity Alerts:** Receive **prominent visual toasts** or **audible alerts** for nearby enemies. **Click toasts to instantly target enemies** or **Shift-click to set focus** (World PvP only). Customize the detection threshold and output.
* **Chat Integration:** **Auto-announce critical spells** (CC, interrupts, cooldowns) to your teammates via Party, Raid, or Battleground chat channels.

### ⚙️ Usability & Customization
* **Quick Start:** Get **arena-ready in 60 seconds** using the guided configuration process.
* **Spell Finder:** Easily **search a database of 12,000+ spells**, complete with IDs and tooltips.
* **Customization:** Full control with **per-spell toggles**, zone filters, and custom alert rules (via the **Advanced** tab).
* **Minimap Button:** Quick access to settings with a convenient **draggable icon**.

### 🌍 Compatibility & Language
* **Ascension Support:** Automatically detects retail and **11-prefixed spell IDs**.
* **Dual Language:** Includes both **English and Spanish** voice packs.

---


## 🏃 Getting Started

### Installation
1.  **Download** the latest release.
2.  **Extract** the `SoundAlerter` folder to your WoW AddOns directory (`.../Interface/AddOns/`).
3.  **Restart WoW** or use the `/reload` command in-game.

### Quick Setup
1.  Type `/sa` in-game (or click the Minimap Button).
2.  Follow the steps in the **Quick Start** tab (set zones, alert scope and audio).
3.  Enter an Arena or Battleground to immediately hear the voice alerts.

---

## 🔨 Advanced Usage

| Feature | Tab Location | Description |
| :--- | :--- | :--- |
| **Customize Voice Alerts** | **Voice Alerts** tab | Toggle and fine-tune the 450+ spell alerts by class and intent. |
| **Proximity Tuning** | **Proximity Alerts** tab | Adjust the distance threshold and choose the output (voice or toast pop-ups) for nearby enemies. Enable **click-to-target** and **shift-click focus** for instant enemy targeting in World PvP. |
| **Create Custom Alerts** | **Advanced** tab | Define your own rules for specific in-game events. |
| **Chat Integration** | **Voice Alerts** tab > **Chat Alerts** | Enable multi-channel output to alert teammates of CC, interrupts, and cooldowns. |
| **Find Spell IDs** | **Developer Tools** tab | Use this tool to quickly find spell IDs for creating new custom alerts. |
| **Performance Stats** | **In-Game Command** | Use **`/sa stats`** to view **Class Detection Performance Stats**, including cache hits, lookup times, and learned classes for optimization/debugging. |
---

## 📈 Performance & Technical Details

| Metric | Detail | Technical Feature |
| :--- | :--- | :--- |
| **Initial Load** | ~3.5 seconds (first login) | **Database Build** with String Interning & Multi-level Indexing. |
| **Subsequent Load** | ~2 seconds | Loads quickly from **SavedVariables Persistence** and **LRU caching**. |
| **Search Speed** | <1ms | Achieved through advanced indexing. |
| **Memory Usage** | **~485 KB** | Extremely low memory footprint. |
| **Spell Scanning** | Non-blocking (70,000 IDs in chunks) | **Non-blocking Scanning** prevents game freezes; uses `GetSpellInfo()` and `GameTooltip` for accurate data. |
| **Toast Click Latency** | <1ms (common case) | **Optimized targeting** with pre-built unit scan lists and cached combat state for instant enemy targeting. |
| **Development** | N/A | New features merged to `develop` branch first, then `main`. |

## License

MIT License

## Shoutout
Respect and admiration to these developers for their ingenuity and inspiration:
* https://github.com/mmobrain/LootCollector/tree/main
* https://github.com/MCribari/Spy-Bronzebeard

Fair winds, fellow adventurers! 🌊
*th3pajay / Starmistx - An old feral (https://warcraftmovies.com/pv.php?t=3&l=pajay)*