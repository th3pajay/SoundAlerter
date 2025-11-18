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
		negativeCacheTTL = 5,  -- seconds
	}
}