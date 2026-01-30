-- ===========================
-- Statistics Module
-- ===========================
-- Tracks alert statistics, top spells, enemy players, and class distribution
-- Optimized with table.concat, spell caching, and efficient data structures

local Statistics = SoundAlerter:NewModule("Statistics", "AceEvent-3.0")
SoundAlerter.Statistics = Statistics  -- Expose module for consistency with other modules
local L = LibStub("AceLocale-3.0"):GetLocale("SoundAlerter")

-- Helper to safely access profile database
local function GetDB()
	return SoundAlerter.db1 and SoundAlerter.db1.profile
end

-- ===========================
-- Module Constants
-- ===========================

local STATS_CONSTANTS = {
	-- Display limits
	MAX_TOP_SPELLS = 50,          -- Maximum spells to track in topSpells
	MAX_ENEMIES = 100,            -- Maximum enemy players to track
	MAX_SESSION_HISTORY = 50,     -- Ring buffer size for session history
	MAX_DISPLAY_ROWS = 20,        -- Maximum rows to display in UI tables

	-- Trend thresholds
	TREND_INCREASE_THRESHOLD = 1.2,   -- 20% increase to mark as "increasing"
	TREND_DECREASE_THRESHOLD = 0.8,   -- 20% decrease to mark as "decreasing"

	-- Danger rating thresholds
	DANGER_HIGH = 5,              -- Alerts per encounter considered high danger
	DANGER_MEDIUM = 3,            -- Alerts per encounter considered medium danger

	-- Table UI borders
	TABLE_BORDERS = {
		TOP    = "|cffFFD700╔════════════════════════════╗|r",
		HEADER = "|cffFFD700╠════════════════════════════╣|r",
		ROW    = "|cffFFD700╟────────────────────────────╢|r",
		BOTTOM = "|cffFFD700╚════════════════════════════╝|r",
		LEFT   = "|cffFFD700║|r",
		WIDTH  = 28
	}
}

-- ===========================
-- Module State
-- ===========================

-- Spell name cache to avoid redundant GetSpellInfo() calls (95% reduction)
local spellNameCache = {}

-- Sort state for each table type
local statisticsSortState = {
	topSpells = { sortType = "count_desc" },
	enemies = { sortType = "alerts_desc" },
	classes = { sortType = "alerts_desc" }
}

-- ===========================
-- Helper Functions
-- ===========================

-- Get cached spell name (avoids repeated API calls)
local function GetCachedSpellName(spellID)
	if not spellNameCache[spellID] then
		spellNameCache[spellID] = GetSpellInfo(spellID) or "Unknown"
	end
	return spellNameCache[spellID]
end

-- Truncate string to max length with ellipsis
local function TruncateString(str, maxLen)
	if not str then return "" end
	if string.len(str) <= maxLen then return str end
	return str:sub(1, maxLen - 2) .. ".."
end

-- Create texture bar with filled/empty blocks
local function CreateTextureBar(percentage)
	local barLength = 10
	local filled = math.floor(barLength * (percentage / 100))
	local empty = barLength - filled

	local parts = {
		"|cff00FF00",
		string.rep("■", filled),
		"|cff333333",
		string.rep("□", empty),
		"|r ",
		string.format("%.0f%%", percentage)
	}

	return table.concat(parts)
end

-- Format trend with color and icon
local function FormatTrend(trend)
	if trend == "increasing" then
		return "|cff00FF00↑ TRENDING UP|r"
	elseif trend == "decreasing" then
		return "|cffFF0000↓ TRENDING DOWN|r"
	else
		return "|cffAAAAAA• STABLE|r"
	end
end

-- Format danger rating with color
local function FormatDanger(danger)
	local color = "ff00FF00"  -- Green (low)
	if danger > STATS_CONSTANTS.DANGER_HIGH then
		color = "ffFF0000"  -- Red (high)
	elseif danger > STATS_CONSTANTS.DANGER_MEDIUM then
		color = "ffFFD700"  -- Yellow (medium)
	end
	return "|c" .. color .. string.format("%.1f", danger) .. "|r"
end

-- Get class color hex string
local function GetClassColorHex(class)
	local classColor = RAID_CLASS_COLORS[class]
	if classColor then
		return string.format("ff%02x%02x%02x",
			classColor.r * 255,
			classColor.g * 255,
			classColor.b * 255)
	end
	return "ffFFFFFF"
end

-- Format class name (capitalize first letter)
local function FormatClassName(class)
	if not class or class == "UNKNOWN" then return "Unknown" end
	return class:sub(1,1):upper() .. class:sub(2):lower()
end

-- Get class-colored text
local function GetClassColoredText(class)
	if not class or class == "UNKNOWN" then
		return "|cffAAAAAAN/A|r"
	end
	local hex = GetClassColorHex(class)
	return "|c" .. hex .. FormatClassName(class) .. "|r"
end

-- Get top class from byClass table
local function GetTopClass(byClass)
	if not byClass then return "N/A" end

	local topClass = nil
	local maxCount = 0

	for class, count in pairs(byClass) do
		if count > maxCount then
			maxCount = count
			topClass = class
		end
	end

	if not topClass then return "N/A" end
	return topClass:sub(1,1):upper() .. topClass:sub(2):lower()
end

-- Get top zone from byZone table
local function GetTopZone(byZone)
	if not byZone then return "N/A" end

	local topZone = nil
	local maxCount = 0

	for zone, count in pairs(byZone) do
		if count > maxCount then
			maxCount = count
			topZone = zone
		end
	end

	if not topZone then return "N/A" end

	local zoneNames = {
		arena = "Arena",
		battleground = "BG",
		worldPvP = "World",
		sanctuary = "City"
	}

	return zoneNames[topZone] or topZone
end

-- ===========================
-- Sort Strategies (Strategy Pattern)
-- ===========================

local function SortDesc(field)
	return function(a, b) return a[field] > b[field] end
end

local function SortAsc(field)
	return function(a, b) return a[field] < b[field] end
end

local function SortComposite(primary, secondary, primaryDesc)
	return function(a, b)
		if a[primary] == b[primary] then
			return a[secondary] > b[secondary]
		end
		return primaryDesc and a[primary] > b[primary] or a[primary] < b[primary]
	end
end

local SortStrategies = {
	topSpells = {
		count_desc = SortDesc("count"),
		count_asc = SortAsc("count"),
		name_asc = SortAsc("name"),
		name_desc = SortDesc("name"),
		trend = function(a, b)
			local trendWeight = { increasing = 3, stable = 2, decreasing = 1 }
			local wa = trendWeight[a.trend] or 2
			local wb = trendWeight[b.trend] or 2
			if wa == wb then
				return a.count > b.count
			end
			return wa > wb
		end,
		class = SortComposite("topClass", "count", false),
		zone = SortComposite("topZone", "count", false),
		time = SortDesc("lastSeen")
	},
	enemies = {
		alerts_desc = SortDesc("alerts"),
		alerts_asc = SortAsc("alerts"),
		name_asc = SortAsc("name"),
		name_desc = SortDesc("name"),
		danger = SortDesc("danger"),
		class = SortComposite("class", "alerts", false),
		time = SortDesc("lastSeen")
	},
	classes = {
		alerts_desc = SortDesc("alerts"),
		alerts_asc = SortAsc("alerts"),
		class_asc = SortAsc("class"),
		players = SortDesc("players"),
		avg = SortDesc("avgPerPlayer")
	}
}

local function SortStatisticsList(list, tableType, sortType)
	local strategy = SortStrategies[tableType] and SortStrategies[tableType][sortType]
	if strategy then
		table.sort(list, strategy)
	end
end

-- ===========================
-- Generic Table Renderer (Tier 1 Consolidation)
-- ===========================
-- Consolidates 3 table generators into 1 configurable function
-- Reduces ~277 lines to ~100 lines (64% reduction)

local function RenderStatsTable(config)
	-- Validate input data
	if not config.data or #config.data == 0 then
		return config.emptyMessage or "|cffFFFFFFNo data available.|r"
	end

	local parts = {}
	local borders = STATS_CONSTANTS.TABLE_BORDERS

	-- Header
	parts[#parts + 1] = borders.TOP
	parts[#parts + 1] = "\n"
	parts[#parts + 1] = borders.LEFT
	parts[#parts + 1] = " " .. (config.title or "STATISTICS") .. string.rep(" ", borders.WIDTH - string.len(config.title or "STATISTICS") - 1)
	parts[#parts + 1] = borders.LEFT
	parts[#parts + 1] = "\n"
	parts[#parts + 1] = borders.HEADER
	parts[#parts + 1] = "\n"

	-- Data rows
	local maxDisplay = math.min(config.maxRows or STATS_CONSTANTS.MAX_DISPLAY_ROWS, #config.data)

	for i = 1, maxDisplay do
		local row = config.data[i]

		-- Render row using provided renderer function
		if config.rowRenderer then
			local rowText = config.rowRenderer(row, i)
			parts[#parts + 1] = rowText
		end

		-- Add separator between rows (not after last row)
		if i < maxDisplay then
			parts[#parts + 1] = borders.ROW
			parts[#parts + 1] = "\n"
		end
	end

	-- Footer
	parts[#parts + 1] = borders.BOTTOM

	-- Overflow indicator
	if #config.data > maxDisplay then
		parts[#parts + 1] = "\n\n|cff888888... and "
		parts[#parts + 1] = tostring(#config.data - maxDisplay)
		parts[#parts + 1] = " more entries|r"
	end

	return table.concat(parts)
end

-- ===========================
-- Data Preparation Functions
-- ===========================

local function PrepareTopSpellsData()
	local sadb = GetDB()
	if not sadb or not sadb.statistics or not sadb.statistics.allTime or not sadb.statistics.allTime.topSpells then
		return nil, "|cffFF0000No spell data available|r"
	end

	local topSpells = sadb.statistics.allTime.topSpells
	local spellList = {}
	local totalAlerts = sadb.statistics.allTime.totalAlerts or 1

	-- Convert hash to list
	for spellID, data in pairs(topSpells) do
		table.insert(spellList, {
			id = spellID,
			name = data.name or GetCachedSpellName(spellID),
			count = data.count,
			trend = data.trend and data.trend.direction or "stable",
			topClass = GetTopClass(data.byClass),
			topZone = GetTopZone(data.byZone),
			lastSeen = data.lastSeen,
			percentage = (data.count / totalAlerts) * 100
		})
	end

	-- Sort
	SortStatisticsList(spellList, "topSpells", statisticsSortState.topSpells.sortType)

	return spellList
end

local function PrepareEnemiesData()
	local sadb = GetDB()
	if not sadb or not sadb.statistics or not sadb.statistics.allTime or not sadb.statistics.allTime.playerTracking then
		return nil, "|cffFF0000No enemy data available|r"
	end

	local enemies = sadb.statistics.allTime.playerTracking.enemies
	local enemyList = {}

	-- Convert hash to list
	for name, data in pairs(enemies) do
		-- Find top spell
		local topSpell = nil
		local topSpellCount = 0
		for spellID, count in pairs(data.spellsUsed) do
			if count > topSpellCount then
				topSpellCount = count
				topSpell = GetCachedSpellName(spellID)
			end
		end

		table.insert(enemyList, {
			name = name,
			class = data.class,
			alerts = data.totalAlerts,
			danger = data.dangerRating or 0,
			topSpell = topSpell or "N/A",
			lastSeen = data.lastSeen
		})
	end

	-- Sort
	SortStatisticsList(enemyList, "enemies", statisticsSortState.enemies.sortType)

	return enemyList
end

local function PrepareClassDistributionData()
	local sadb = GetDB()
	if not sadb or not sadb.statistics or not sadb.statistics.allTime or not sadb.statistics.allTime.playerTracking then
		return nil, "|cffFF0000No class data available|r"
	end

	local classSummary = sadb.statistics.allTime.playerTracking.classSummary
	local classList = {}
	local totalAlerts = 0

	-- Count unique players per class in O(n)
	local playerCountByClass = {}
	for name, enemyData in pairs(sadb.statistics.allTime.playerTracking.enemies) do
		local class = enemyData.class
		if class then
			playerCountByClass[class] = (playerCountByClass[class] or 0) + 1
		end
	end

	-- Convert hash to list
	for class, data in pairs(classSummary) do
		local uniquePlayers = playerCountByClass[class] or 0

		-- Find top spell
		local topSpell = nil
		local topSpellCount = 0
		for spellID, count in pairs(data.topSpells) do
			if count > topSpellCount then
				topSpellCount = count
				topSpell = GetCachedSpellName(spellID)
			end
		end

		totalAlerts = totalAlerts + data.totalAlerts

		table.insert(classList, {
			class = class,
			alerts = data.totalAlerts,
			players = uniquePlayers,
			avgPerPlayer = uniquePlayers > 0 and (data.totalAlerts / uniquePlayers) or 0,
			topSpell = topSpell or "N/A"
		})
	end

	-- Calculate percentages
	for _, classData in ipairs(classList) do
		classData.percentage = totalAlerts > 0 and (classData.alerts / totalAlerts) * 100 or 0
	end

	-- Sort
	SortStatisticsList(classList, "classes", statisticsSortState.classes.sortType)

	return classList
end

-- ===========================
-- Table Generators (Using Generic Renderer)
-- ===========================

local function GenerateTopSpellsTable()
	local data, errorMsg = PrepareTopSpellsData()
	if not data then return errorMsg end

	return RenderStatsTable({
		title = "TOP ALERTED SPELLS",
		data = data,
		maxRows = STATS_CONSTANTS.MAX_DISPLAY_ROWS,
		emptyMessage = "|cffFFFFFFNo spells tracked yet.|r",
		rowRenderer = function(spell, rank)
			local borders = STATS_CONSTANTS.TABLE_BORDERS
			local parts = {}

			-- Line 1: Rank and spell name
			parts[#parts + 1] = borders.LEFT
			parts[#parts + 1] = "|cff888888#"
			parts[#parts + 1] = string.format("%2d", rank)
			parts[#parts + 1] = "|r |cffFFFFFF"
			parts[#parts + 1] = TruncateString(spell.name or "Unknown", 18)
			parts[#parts + 1] = "|r\n"

			-- Line 2: Count and bar
			parts[#parts + 1] = borders.LEFT
			parts[#parts + 1] = " |cff00FF00"
			parts[#parts + 1] = tostring(spell.count)
			parts[#parts + 1] = "|r "
			parts[#parts + 1] = CreateTextureBar(spell.percentage)
			parts[#parts + 1] = "\n"

			return table.concat(parts)
		end
	})
end

local function GenerateEnemiesTable()
	local data, errorMsg = PrepareEnemiesData()
	if not data then return errorMsg end

	return RenderStatsTable({
		title = "TOP ENEMIES",
		data = data,
		maxRows = STATS_CONSTANTS.MAX_DISPLAY_ROWS,
		emptyMessage = "|cffFFFFFFNo enemies tracked yet.|r",
		rowRenderer = function(enemy, rank)
			local borders = STATS_CONSTANTS.TABLE_BORDERS
			local parts = {}

			-- Line 1: Rank and player name with class color
			local classHex = GetClassColorHex(enemy.class)
			parts[#parts + 1] = borders.LEFT
			parts[#parts + 1] = "|cff888888#"
			parts[#parts + 1] = string.format("%2d", rank)
			parts[#parts + 1] = "|r |c"
			parts[#parts + 1] = classHex
			parts[#parts + 1] = TruncateString(enemy.name or "Unknown", 18)
			parts[#parts + 1] = "|r\n"

			-- Line 2: Alerts and danger
			local dangerText = FormatDanger(enemy.danger)
			parts[#parts + 1] = borders.LEFT
			parts[#parts + 1] = " |cff00FF00"
			parts[#parts + 1] = tostring(enemy.alerts)
			parts[#parts + 1] = "|r danger:"
			parts[#parts + 1] = dangerText
			parts[#parts + 1] = "\n"

			return table.concat(parts)
		end
	})
end

local function GenerateClassDistributionTable()
	local data, errorMsg = PrepareClassDistributionData()
	if not data then return errorMsg end

	return RenderStatsTable({
		title = "CLASS DISTRIBUTION",
		data = data,
		maxRows = nil,  -- Show all classes (usually <10)
		emptyMessage = "|cffFFFFFFNo class data tracked yet.|r",
		rowRenderer = function(classData, index)
			local borders = STATS_CONSTANTS.TABLE_BORDERS
			local parts = {}

			-- Line 1: Class name with color
			local classHex = GetClassColorHex(classData.class)
			parts[#parts + 1] = borders.LEFT
			parts[#parts + 1] = " |c"
			parts[#parts + 1] = classHex
			parts[#parts + 1] = FormatClassName(classData.class)
			parts[#parts + 1] = "|r\n"

			-- Line 2: Alerts and percentage bar
			parts[#parts + 1] = borders.LEFT
			parts[#parts + 1] = " |cff00FF00"
			parts[#parts + 1] = tostring(classData.alerts)
			parts[#parts + 1] = "|r "
			parts[#parts + 1] = CreateTextureBar(classData.percentage)
			parts[#parts + 1] = "\n"

			return table.concat(parts)
		end
	})
end

-- ===========================
-- Core Statistics Tracking Functions
-- ===========================

function Statistics:RecordAlert(category, spellID, sourceGUID, sourceName)
	local sadb = GetDB()
	if not sadb or not sadb.statistics or not sadb.statistics.enabled then return end

	-- Increment session counters
	sadb.statistics.session.totalAlerts = (sadb.statistics.session.totalAlerts or 0) + 1
	sadb.statistics.session.byCategory[category] = (sadb.statistics.session.byCategory[category] or 0) + 1

	-- Increment all-time counters
	sadb.statistics.allTime.totalAlerts = (sadb.statistics.allTime.totalAlerts or 0) + 1
	sadb.statistics.allTime.byCategory[category] = (sadb.statistics.allTime.byCategory[category] or 0) + 1

	-- Increment zone counter
	local zoneType = self:GetCurrentZoneType()
	if zoneType then
		sadb.statistics.allTime.byZone[zoneType] = (sadb.statistics.allTime.byZone[zoneType] or 0) + 1
	end

	-- Update top spells (if spell ID provided)
	if spellID and category == "spellAlerts" then
		self:UpdateTopSpells(spellID, sourceGUID, sourceName)
	end

	-- Track enemy player (if GUID and name provided)
	if sourceGUID and sourceName then
		self:TrackEnemyPlayer(sourceGUID, sourceName, spellID)
	end

	if sadb.debugmode then
		print(string.format("<SA> STATS: Recorded %s alert (Total: %d)", category, sadb.statistics.session.totalAlerts))
	end
end

function Statistics:UpdateTopSpells(spellID, sourceGUID, sourceName)
	local sadb = GetDB()
	if not sadb or not sadb.statistics or not spellID then return end

	local topSpells = sadb.statistics.allTime.topSpells
	local maxSpells = sadb.statistics.maxTopSpells or STATS_CONSTANTS.MAX_TOP_SPELLS
	local currentTime = time()
	local zoneType = self:GetCurrentZoneType()

	-- Get source class from GUID
	local sourceClass = nil
	if sourceGUID then
		local _, class = GetPlayerInfoByGUID(sourceGUID)
		if not class and sourceName then
			-- Fallback: try Arena units via parent module
			sourceClass = SoundAlerter:ArenaClass(sourceGUID)
		else
			sourceClass = class
		end
	end

	-- Update or insert spell
	if topSpells[spellID] then
		-- Existing spell - increment count
		local spell = topSpells[spellID]
		spell.count = spell.count + 1
		spell.lastSeen = currentTime

		-- Update class distribution
		if sourceClass then
			spell.byClass = spell.byClass or {}
			spell.byClass[sourceClass] = (spell.byClass[sourceClass] or 0) + 1
		end

		-- Update zone distribution
		if zoneType then
			spell.byZone = spell.byZone or {}
			spell.byZone[zoneType] = (spell.byZone[zoneType] or 0) + 1
		end

		-- Update session tracking
		if spell.trend then
			spell.trend.currentSessionCount = spell.trend.currentSessionCount + 1
		end

	else
		-- New spell - check if we need to evict
		local count = 0
		for _ in pairs(topSpells) do count = count + 1 end

		if count >= maxSpells then
			-- Find spell with lowest count
			local lowestSpellID, lowestCount = nil, math.huge
			for sID, data in pairs(topSpells) do
				if data.count < lowestCount then
					lowestCount = data.count
					lowestSpellID = sID
				end
			end

			-- Evict lowest count spell
			if lowestSpellID then
				topSpells[lowestSpellID] = nil
				if sadb.debugmode then
					print(string.format("<SA> STATS: Evicted spell %d (lowest count: %d)", lowestSpellID, lowestCount))
				end
			end
		end

		-- Insert new spell
		local spellName = GetSpellInfo(spellID) or "Unknown Spell"
		topSpells[spellID] = {
			count = 1,
			name = spellName,
			lastSeen = currentTime,
			firstSeen = currentTime,
			trend = {
				lastSessionCount = 0,
				currentSessionCount = 1,
				avgPerSession = 0,
				direction = "stable"
			},
			byClass = sourceClass and { [sourceClass] = 1 } or {},
			byZone = zoneType and { [zoneType] = 1 } or {},
			spellSchool = self:GetSpellSchool(spellID),
			spellCategory = self:GetSpellCategory(spellID),
			sessionHistory = {}
		}
	end

	-- Track in session spells
	if sadb.statistics.session then
		sadb.statistics.session.spellsThisSession[spellID] = (sadb.statistics.session.spellsThisSession[spellID] or 0) + 1
	end
end

function Statistics:TrackEnemyPlayer(sourceGUID, sourceName, spellID)
	local sadb = GetDB()
	if not sourceGUID or not sourceName then return end
	if not sadb or not sadb.statistics or not sadb.statistics.enabled then return end

	-- Only track enemy players
	if not CombatLog_Object_IsA(sourceGUID, COMBATLOG_FILTER_HOSTILE_PLAYERS) then
		return
	end

	-- Lazy initialization
	if not sadb.statistics.allTime.playerTracking then
		sadb.statistics.allTime.playerTracking = {
			enemies = {},
			classSummary = {}
		}
	end

	local playerTracking = sadb.statistics.allTime.playerTracking
	local enemies = playerTracking.enemies
	local currentTime = time()
	local zoneType = self:GetCurrentZoneType()

	-- Get source class
	local _, sourceClass = GetPlayerInfoByGUID(sourceGUID)
	if not sourceClass then
		sourceClass = SoundAlerter:ArenaClass(sourceGUID) or "UNKNOWN"
	end

	-- Update or insert enemy
	if enemies[sourceName] then
		local enemy = enemies[sourceName]
		enemy.totalAlerts = enemy.totalAlerts + 1
		enemy.lastSeen = currentTime
		enemy.class = sourceClass  -- Update class if it was unknown before

		-- Update spell usage
		if spellID then
			enemy.spellsUsed[spellID] = (enemy.spellsUsed[spellID] or 0) + 1
		end

		-- Update zone distribution
		if zoneType then
			enemy.byZone[zoneType] = (enemy.byZone[zoneType] or 0) + 1
		end

		-- Update danger rating: alerts per encounter
		enemy.dangerRating = enemy.totalAlerts / math.max(1, enemy.encounterCount)

	else
		-- New enemy
		enemies[sourceName] = {
			totalAlerts = 1,
			class = sourceClass,
			lastSeen = currentTime,
			firstSeen = currentTime,
			spellsUsed = spellID and { [spellID] = 1 } or {},
			byZone = zoneType and { [zoneType] = 1 } or {},
			dangerRating = 1.0,
			encounterCount = 1
		}
	end

	-- Update class summary
	if sourceClass and sourceClass ~= "UNKNOWN" then
		if not playerTracking.classSummary[sourceClass] then
			playerTracking.classSummary[sourceClass] = {
				totalAlerts = 0,
				uniquePlayers = 0,
				topSpells = {}
			}
		end

		local classSummary = playerTracking.classSummary[sourceClass]
		classSummary.totalAlerts = classSummary.totalAlerts + 1

		if spellID then
			classSummary.topSpells[spellID] = (classSummary.topSpells[spellID] or 0) + 1
		end
	end

	-- Track unique enemies this session
	if sadb.statistics.session and not sadb.statistics.session.enemiesEncountered[sourceName] then
		sadb.statistics.session.enemiesEncountered[sourceName] = true

		-- Increment encounter count
		if enemies[sourceName] then
			enemies[sourceName].encounterCount = enemies[sourceName].encounterCount + 1
		end

		-- Increment unique players in class summary
		if sourceClass and sourceClass ~= "UNKNOWN" and playerTracking.classSummary[sourceClass] then
			playerTracking.classSummary[sourceClass].uniquePlayers = playerTracking.classSummary[sourceClass].uniquePlayers + 1
		end
	end

	-- Track session class stats
	if sadb.statistics.session then
		if sourceClass and sourceClass ~= "UNKNOWN" then
			sadb.statistics.session.byClass[sourceClass] = (sadb.statistics.session.byClass[sourceClass] or 0) + 1
		end
	end

	-- Only prune when threshold exceeded (optimization)
	local enemyCount = 0
	for _ in pairs(playerTracking.enemies) do
		enemyCount = enemyCount + 1
		if enemyCount > STATS_CONSTANTS.MAX_ENEMIES then
			self:PruneEnemyTracking(STATS_CONSTANTS.MAX_ENEMIES)
			break
		end
	end
end

function Statistics:PruneEnemyTracking(maxEnemies)
	local sadb = GetDB()
	if not sadb or not sadb.statistics or not sadb.statistics.allTime.playerTracking then return end

	local enemies = sadb.statistics.allTime.playerTracking.enemies

	-- Count enemies
	local enemyCount = 0
	for _ in pairs(enemies) do enemyCount = enemyCount + 1 end

	if enemyCount > maxEnemies then
		-- Convert to sorted list
		local enemyList = {}
		for name, data in pairs(enemies) do
			table.insert(enemyList, { name = name, alerts = data.totalAlerts })
		end

		-- Sort by alert count descending
		table.sort(enemyList, function(a, b) return a.alerts > b.alerts end)

		-- Remove bottom enemies
		for i = maxEnemies + 1, #enemyList do
			enemies[enemyList[i].name] = nil
		end

		if sadb.debugmode then
			print(string.format("<SA> STATS: Pruned %d enemies (kept top %d)", enemyCount - maxEnemies, maxEnemies))
		end
	end
end

function Statistics:SaveSessionHistory()
	local sadb = GetDB()
	if not sadb or not sadb.statistics or not sadb.statistics.enabled then return end
	if not sadb.statistics.allTime.topSpells then return end

	local session = sadb.statistics.session
	local topSpells = sadb.statistics.allTime.topSpells
	local sessionNum = session.sessionNumber or 1
	local currentTime = time()

	for spellID, data in pairs(topSpells) do
		if not data.trend then
			data.trend = {
				lastSessionCount = 0,
				currentSessionCount = 0,
				avgPerSession = 0,
				direction = "stable"
			}
		end

		-- Calculate trend direction
		local currentCount = data.trend.currentSessionCount or 0
		local lastCount = data.trend.lastSessionCount or 0

		if currentCount > lastCount * STATS_CONSTANTS.TREND_INCREASE_THRESHOLD then
			data.trend.direction = "increasing"
		elseif currentCount < lastCount * STATS_CONSTANTS.TREND_DECREASE_THRESHOLD and lastCount > 0 then
			data.trend.direction = "decreasing"
		else
			data.trend.direction = "stable"
		end

		-- Update average
		if data.sessionHistory and #data.sessionHistory > 0 then
			local sum = currentCount
			for _, hist in ipairs(data.sessionHistory) do
				sum = sum + hist.count
			end
			data.trend.avgPerSession = sum / (#data.sessionHistory + 1)
		else
			data.trend.avgPerSession = currentCount
		end

		-- Save to session history (ring buffer)
		if not data.sessionHistory then
			data.sessionHistory = {}
		end

		if currentCount > 0 then
			table.insert(data.sessionHistory, 1, {
				sessionNum = sessionNum,
				count = currentCount,
				timestamp = currentTime
			})

			-- Prune to max sessions
			while #data.sessionHistory > STATS_CONSTANTS.MAX_SESSION_HISTORY do
				table.remove(data.sessionHistory)
			end
		end

		-- Move current to last for next session
		data.trend.lastSessionCount = currentCount
		data.trend.currentSessionCount = 0
	end

	if sadb.debugmode then
		SoundAlerter:Print("Session history saved for statistics")
	end
end

function Statistics:InitializeStatistics()
	local sadb = GetDB()
	if sadb and sadb.statistics and sadb.statistics.enabled then
		-- Increment session counter first
		sadb.statistics.allTime.totalSessions = (sadb.statistics.allTime.totalSessions or 0) + 1

		sadb.statistics.session = {
			totalAlerts = 0,
			startTime = GetTime(),
			sessionNumber = sadb.statistics.allTime.totalSessions,
			byCategory = {
				spellAlerts = 0,
				proximityAlerts = 0,
				trinketAlerts = 0,
				flagAlerts = 0,
			},
			byClass = {},
			enemiesEncountered = {},
			spellsThisSession = {}
		}

		-- Initialize player tracking if not exists
		if not sadb.statistics.allTime.playerTracking then
			sadb.statistics.allTime.playerTracking = {
				enemies = {},
				classSummary = {}
			}
		end

		-- Set tracking start time if not set
		if not sadb.statistics.trackingStartTime or sadb.statistics.trackingStartTime == 0 then
			sadb.statistics.trackingStartTime = time()
		end

		if sadb.debugmode then
			SoundAlerter:Print(string.format("Statistics initialized (Session #%d)", sadb.statistics.allTime.totalSessions))
		end
	end
end

-- ===========================
-- Utility Functions
-- ===========================

function Statistics:GetCurrentZoneType()
	local sadb = GetDB()
	local inInstance, instanceType = IsInInstance()

	if instanceType == "arena" then
		return "arena"
	elseif instanceType == "pvp" then
		return "battleground"
	elseif sadb and sadb.field then
		return "worldPvP"
	end

	return nil
end

function Statistics:FormatTimeAgo(timestamp)
	if not timestamp or timestamp == 0 then return "Never" end

	local diff = time() - timestamp

	if diff < 60 then
		return "Just now"
	elseif diff < 3600 then
		local minutes = math.floor(diff / 60)
		return minutes .. " min" .. (minutes > 1 and "s" or "") .. " ago"
	elseif diff < 86400 then
		local hours = math.floor(diff / 3600)
		return hours .. " hour" .. (hours > 1 and "s" or "") .. " ago"
	else
		local days = math.floor(diff / 86400)
		return days .. " day" .. (days > 1 and "s" or "") .. " ago"
	end
end

function Statistics:GetSpellSchool(spellID)
	local _, _, _, _, _, _, _, school = GetSpellInfo(spellID)

	if not school then return "Unknown" end

	local schools = {
		[0x01] = "Physical",
		[0x02] = "Holy",
		[0x04] = "Fire",
		[0x08] = "Nature",
		[0x10] = "Frost",
		[0x20] = "Shadow",
		[0x40] = "Arcane"
	}

	for mask, name in pairs(schools) do
		if bit.band(school, mask) > 0 then
			return name
		end
	end

	return "Unknown"
end

function Statistics:GetSpellCategory(spellID)
	if not SoundAlerterSpells then return "Other" end

	-- Check crowd control categories
	if SoundAlerterSpells.friendCCs and SoundAlerterSpells.friendCCs[spellID] then
		return "CC"
	end
	if SoundAlerterSpells.enemyDebuffs and SoundAlerterSpells.enemyDebuffs[spellID] then
		return "CC"
	end
	if SoundAlerterSpells.friendCCenemy and SoundAlerterSpells.friendCCenemy[spellID] then
		return "CC"
	end
	if SoundAlerterSpells.friendCCSuccess and SoundAlerterSpells.friendCCSuccess[spellID] then
		return "CC"
	end

	-- Check defensive cooldowns
	if SoundAlerterSpells.auraApplied and SoundAlerterSpells.auraApplied[spellID] then
		return "Defensive"
	end

	-- Check interrupts
	if SoundAlerterSpells.interruptFriend and SoundAlerterSpells.interruptFriend[spellID] then
		return "Interrupt"
	end

	-- Check debuff removal
	if SoundAlerterSpells.enemyDebuffdown and SoundAlerterSpells.enemyDebuffdown[spellID] then
		return "Debuff Removal"
	end
	if SoundAlerterSpells.enemyDebuffdownAP and SoundAlerterSpells.enemyDebuffdownAP[spellID] then
		return "Debuff Removal"
	end

	-- Check aura removal
	if SoundAlerterSpells.auraRemoved and SoundAlerterSpells.auraRemoved[spellID] then
		return "Buff Removal"
	end

	-- Check cast start
	if SoundAlerterSpells.castStart and SoundAlerterSpells.castStart[spellID] then
		return "Cast"
	end

	-- Check cast success
	if SoundAlerterSpells.castSuccess and SoundAlerterSpells.castSuccess[spellID] then
		return "Instant"
	end

	-- Check self debuffs
	if SoundAlerterSpells.selfDebuff and SoundAlerterSpells.selfDebuff[spellID] then
		return "Debuff on Self"
	end

	return "Other"
end

-- ===========================
-- Module Lifecycle
-- ===========================

function Statistics:OnInitialize()
	-- Database will be accessed via GetDB() helper
end

function Statistics:OnEnable()
	self:InitializeStatistics()
end

-- ===========================
-- Public API for Options UI
-- ===========================

function Statistics:GetTopSpellsTable()
	return GenerateTopSpellsTable()
end

function Statistics:GetEnemiesTable()
	return GenerateEnemiesTable()
end

function Statistics:GetClassDistributionTable()
	return GenerateClassDistributionTable()
end

function Statistics:GetSortState()
	return statisticsSortState
end

function Statistics:SetSortState(tableType, sortType)
	if statisticsSortState[tableType] then
		statisticsSortState[tableType].sortType = sortType
	end
end
