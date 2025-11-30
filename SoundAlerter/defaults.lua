dbDefaults = {
	profile = {
		-- ===========================
		-- General Settings
		-- ===========================
		sapath = SA_LOCALEPATH[GetLocale()] or "Interface\\Addons\\SoundAlerter\\voice\\",
		debugmode = false,
		spelldebug = false,
		ignorePVEMode = true,

		-- ===========================
		-- SLC UI Settings
		-- ===========================
		quickStartEnabled = false,
		showDeveloperTools = false,
		objectiveAlertsEnabled = false,

		-- ===========================
		-- Spell Finder Settings
		-- ===========================
		findSpell = {
			autoSearch = false,  -- Auto-search as you type (200ms debounce)
		},

		-- ===========================
		-- Minimap Button
		-- ===========================
		MinimapButtonPosition = nil,  -- Saved when user drags button
		MinimapButtonHidden = false,

		-- ===========================
		-- Zone Settings
		-- ===========================
		all = false,
		arena = true,
		battleground = true,
		field = true,

		-- ===========================
		-- Target Settings
		-- ===========================
		myself = true,
		ArenaPartner = false,
		enemyinrange = false,

		-- ===========================
		-- General Alerts
		-- ===========================
		trinket = true,
		drinking = true,
		class = true,

		-- ===========================
		-- Enemy Alerts (CC)
		-- ===========================
		blindenemy = true,
		cycloneenemy = true,
		fearenemy = true,
		hexenemy = true,
		polyenemy = true,
		sapenemy = true,

		-- ===========================
		-- Enemy Alerts (Defensive)
		-- ===========================
		bubbleenemy = true,
		bubbleeenemy = true,
		stealthenemy = true,
		prowlhenemy = true,
		vanishalert = true,

		-- ===========================
		-- Enemy Alerts (Other)
		-- ===========================
		interruptenemy = true,
		enemyinterrupts = true,

		-- ===========================
		-- Self/Friend Alerts (CC)
		-- ===========================
		blindselffriend = true,
		cycloneselffriend = true,
		fearselffriend = true,
		hexselffriend = true,
		sapselffriend = true,

		-- ===========================
		-- Target Filters
		-- ===========================
		caonlyTF = true,
		vanishTF = true,
		stealthTF = true,
		prowlTF = true,

		-- ===========================
		-- Event Monitoring
		-- ===========================
		aruaApplied = false,
		aruaRemoved = false,
		castStart = false,
		castSuccess = false,
		interrupt = false,

		-- ===========================
		-- Specific Spell Alerts
		-- ===========================
		PresenceofMind = false,
		Starfire = false,
		lavaburst = false,

		-- ===========================
		-- Chat Settings
		-- ===========================
		chatdownfriend = false,
		chatdownself = true,
		interruptself = false,
		trinketalert = false,
		sayspell = true,
		chatgroups = {["SAY"] = false, ["PARTY"] = true, ["RAID"] = false, ["BATTLEGROUND"] = true, ["NONE"] = false,},

		-- ===========================
		-- Chat Messages - Interrupts
		-- ===========================
		InterruptEnemyText = "Interrupted #enemy#'s #interruptedspellname# with #spell#.",
		InterruptSelfText = "#enemy# interrupted my #interruptedspellname# with #spell#.",

		-- ===========================
		-- Chat Messages - General
		-- ===========================
		friendchat = "#enemy# casted #spell# on #friend#",
		selfchat = "#enemy# casted #spell# on me!",
		enemychat = "#spell# up on #enemy#",
		enemybuffchat = "#enemy# casted #spell#",

		-- ===========================
		-- Chat Messages - Sap
		-- ===========================
		sapselftext = "I'm Sapped!",
		saptextself = "I'm Sapped!",
		sapfriendtext = "#friend# is Sapped!",

		-- ===========================
		-- Chat Messages - Blind
		-- ===========================
		blindtext = "#enemy# blinded me!",
		blindtextfriend = "#friend# Is Blinded!",

		-- ===========================
		-- Chat Messages - Other
		-- ===========================
		bubbleenemytext = "#enemy# bubbled!",
		trinketalerttext = "[#enemy#] Trinketted!",

		-- ===========================
		-- Custom Configuration
		-- ===========================
		custom = {},
		cspell = "",

		-- ===========================
		-- Proximity Alert Settings
		-- ===========================
		proximityEnabled = false,
		proximityWorld = false,
		proximityBattleground = false,
		proximityArena = false,
		proximityCooldown = 60,
		proximityChat = false,
		proximityChatText = "[#class#] #player# detected nearby!",

		-- ===========================
		-- Proximity Toast Settings
		-- ===========================
		proximityToasts = {
			enabled = false,
			displayDuration = 3.0,
			showPlayerName = true,
			useClassColors = true,
			maxConcurrent = 3,
			positionX = 0,
			positionY = -200,
			-- Click-to-target functionality (World PvP only)
			clickEnabled = true,
			enableClickToTarget = true,
			enableFocusTarget = true,
			-- Visual enhancements
			rainbowBorder = false,
		},

		-- ===========================
		-- Multi-Class Resource Bar Settings
		-- ===========================
		resourceBar = {
			locked = false,

			energyEnabled = false,
			energyPositionX = 0,
			energyPositionY = -120,
			energyScale = 1.0,
			energyTexture = "Interface\\TargetingFrame\\UI-StatusBar",
			energyColor = {r = 1, g = 1, b = 0.2},
			energyLowColor = {r = 1, g = 0.3, b = 0},
			lowEnergyThreshold = 15,
			showOverCapAlert = true,
			showLowEnergyAlert = true,

			rageEnabled = false,
			ragePositionX = 0,
			ragePositionY = -120,
			rageScale = 1.0,
			rageTexture = "Interface\\TargetingFrame\\UI-StatusBar",
			rageColor = {r = 1, g = 0.2, b = 0.2},
			rageLowColor = {r = 0.8, g = 0.1, b = 0.1},
			lowRageThreshold = 20,
			showLowRageAlert = false,

			healthEnabled = false,
			healthPositionX = 0,
			healthPositionY = -140,
			healthScale = 1.0,
			healthHeight = 20,
			healthTexture = "Interface\\TargetingFrame\\UI-StatusBar",
			healthColor = {r = 0.2, g = 1, b = 0.2},

			manaEnabled = false,
			manaPositionX = 0,
			manaPositionY = -100,
			manaScale = 1.0,
			manaTexture = "Interface\\TargetingFrame\\UI-StatusBar",
			manaColor = {r = 0.2, g = 0.5, b = 1},
			manaLowColor = {r = 0.1, g = 0.3, b = 0.8},
			lowManaThreshold = 20,
			showLowManaAlert = false,

			comboEnabled = false,
			comboPositionX = 0,
			comboPositionY = -85,
			comboScale = 1.0,
			comboStyle = "circle",
			comboActiveColor = {r = 0.2, g = 1, b = 0.2},
			comboMaxColor = {r = 1, g = 0.8, b = 0.2},
			comboInactiveColor = {r = 0.25, g = 0.25, b = 0.25},

			comboTextEnabled = false,
			comboTextPositionX = 0,
			comboTextPositionY = -50,

			smoothPower = false,
			cpAnimations = true,
			fullCPAnimation = true,
			fullCPSound = false,

			barTexture = "default",
		},

		-- ===========================
		-- Battleground Alert Settings
		-- ===========================
		battlegroundAlertsEnabled = false,  -- Disabled by default (opt-in)

		-- Flag-specific alerts
		flagPickupAudio = true,
		flagDropAudio = true,
		flagCaptureAudio = true,
		flagReturnAudio = false,  -- Less critical

		-- Toast settings for flag alerts
		flagToastsEnabled = true,

		-- Team-based background colors for flag toasts
		flagTeamBackgroundColors = true,  -- Master toggle for colored backgrounds
		flagEnemyRedBackground = true,    -- Red transparent background for enemy flag carriers
		flagFriendlyGreenBackground = true, -- Green transparent background for friendly flag carriers

		-- Team-based background textures for flag toasts
		flagEnemyTexture = "Solid",       -- Background texture for enemy flag carriers
		flagFriendlyTexture = "Solid",    -- Background texture for friendly flag carriers

		-- Chat integration
		flagChatEnabled = false,
		flagChatText = "#class# has the flag!",  -- Placeholders: #class#, #player#, #action#
		flagChatChannel = "SAY",

		-- Team-based filtering (WoW Ascension mixed-faction support)
		flagOnlyEnemyTeam = true,     -- Only alert for enemy flag events (default for competitive play)
		flagOnlyFriendlyTeam = false, -- Only alert for friendly flag events
		flagAllActions = false,       -- Alert for all flag events (pickup, drop, cap, return)

		-- Team assignment cache (persistent, for mixed-faction BGs)
		persistentTeamCache = {},  -- PlayerName → { team, lastSeen } mapping

		-- ===========================
		-- Performance Optimization (All Zones)
		-- ===========================
		learnedClasses = {},  -- GUID → class mapping (persistent)
		learnedClassesEnabled = true,

		-- ===========================
		-- Persistent Class Cache (Battleground Alerts)
		-- ===========================
		persistentClassCache = {},  -- PlayerName → { class, lastSeen } mapping
		persistentCacheEnabled = true,
		persistentCacheMaxSize = 500,  -- Max entries (LRU eviction)
		persistentCacheMaxAge = 2592000,  -- 30 days in seconds
		learnedClassesMaxSize = 5000,
		negativeCacheEnabled = true,
		negativeCacheTTL = 5,

		-- ===========================
		-- Alert Statistics Settings
		-- ===========================
		statistics = {
			-- Feature toggle
			enabled = true,

			-- Session statistics (reset on login/reload)
			session = {
				totalAlerts = 0,
				startTime = 0,  -- GetTime() when session started
				byCategory = {
					spellAlerts = 0,
					proximityAlerts = 0,
					trinketAlerts = 0,
					flagAlerts = 0,
				},
			},

			-- Persistent statistics (all-time)
			allTime = {
				totalAlerts = 0,
				totalSessions = 0,

				-- Top spells tracking (limited to maxTopSpells)
				topSpells = {},  -- [spellID] = { count, lastSeen, name }

				-- Category breakdown
				byCategory = {
					spellAlerts = 0,
					proximityAlerts = 0,
					trinketAlerts = 0,
					flagAlerts = 0,
				},

				-- Zone breakdown
				byZone = {
					arena = 0,
					battleground = 0,
					worldPvP = 0,
				},
			},

			-- Configuration
			maxTopSpells = 50,  -- Limit top spells to prevent memory bloat (LRU eviction)
			trackingStartTime = 0,  -- time() when tracking first enabled
		},
	}
}