# SoundAlerter: Enhanced for WoW Ascension: Classic+ (20251014)

<p align="center">
<img src="SoundAlerter/soundalerter.png" alt="SoundAlerter Addon Logo" width="256"/>
</p>

SoundAlerter provides **instant, critical voice alerts** for enemy and friendly spell usage. This release significantly overhauls the addon for better reliability, easier maintenance, and expanded spell coverage on **WoW Ascension: Classic+**.

Never miss a "Cyclone," "Divine Shield," or "Shadowmeld" again!

## ✨ Key Updates
| Feature | Description |
| :--- | :--- |
| **Expanded Spell Content** | Added many new abilities including **Artifacts, Legendaries, and class spells**, complete with voice-cloned audio. |
| **Ascension Integration** | Spell IDs are piggybacked on the Ascension database (using the "Show Ids In tooltips" feature) for expanded, though preliminary, alerts. |
| **Modernized Structure** | Spells are consolidated by Class/Name and now auto-support standard and private server ID formats (e.g., `[SpellID]` and `11[SpellID]`). |
| **Full Options Support** | All new spells are integrated with in-game toggle options for easy customization (`/sa`). **Tooltips are now supported in the options menu.** |

> **Note:** Currently testing the feature that announces the interrupted spell's name/ID directly in the chat alert. As this is an early release for this server, spell IDs are not fully confirmed. **Expect potential errors.**

---

## 🛡️ Core Features

* **Voice Alerts:** Real-time audio alerts for major CC, interrupts, and defensive cooldowns.
* **Customization:** Toggle alerts on/off via the in-game options menu (`/sa`).
* **Localization:** Includes English and Spanish voice packs.
* **Reliable Hooking:** Integrates directly and efficiently with the WoW Combat Log.

---

## 🚀 Usage & Setup

### 1. Installation
Download the latest release ZIP and **extract the entire and only `SoundAlerter` folder** into your WoW AddOns directory (e.g., `.../Interface/AddOns/`).
`SpellData` folder is only for tracking currently planned spells for the addon, it can be ignored.

### 2. In-Game Configuration
Log in and open the options menu with the command: `/sa`.

New alerts are enabled by default. Customize toggles and volume as needed.

---

## 🛠️ Contribution & Development

Contributions are welcome! Updates will be made as time allows, but feel free to maintain and spin-off the addon. New work should be merged into the `develop` branch.

---

## 📜 Credits

Have fun and fair winds fellow adventurers.

| Role | Name / Handle |
| :--- | :--- |
| **Original Author** | Trolollolol |
| **Current Maintainer** | th3pajay (October 2025) |

*th3pajay / Starmistx - An old feral (https://warcraftmovies.com/pv.php?t=3&l=pajay)*