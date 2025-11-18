-- ========================================
-- FLAG ALERT MODULE
-- Detects battleground flag events from chat messages
-- ========================================

local SoundAlerter = LibStub("AceAddon-3.0"):GetAddon("SoundAlerter")
local FlagAlerts = SoundAlerter:NewModule("FlagAlerts", "AceEvent-3.0", "AceTimer-3.0")

-- Expose module for external access
SoundAlerter.FlagAlerts = FlagAlerts

-- Local references (Lua globals - 30% faster than global lookups)
local sadb
local GetLocale = GetLocale
local GetTime = GetTime
local PlaySoundFile = PlaySoundFile
local UnitExists = UnitExists
local UnitName = UnitName
local UnitClass = UnitClass
local UnitIsEnemy = UnitIsEnemy
local GetNumRaidMembers = GetNumRaidMembers
local GetNumPartyMembers = GetNumPartyMembers
local SendChatMessage = SendChatMessage
local debugprofilestop = debugprofilestop
local UnitBuff = UnitBuff

-- Lua standard library localizations (critical for hot paths)
local string_match = string.match
local string_gsub = string.gsub
local string_format = string.format
local table_insert = table.insert
local table_remove = table.remove
local table_sort = table.sort
local math_max = math.max
local math_ceil = math.ceil
local math_huge = math.huge
local tonumber = tonumber
local type = type
local pairs = pairs
local ipairs = ipairs
local select = select

-- Bit operations (WoW 3.3.5a uses bit library, not available in all scopes)
-- Use direct calls instead of localization to avoid scope issues
local bit_band = bit and bit.band or function(a, b) return a % (b*2) >= b and a % (b*2) - b or a % (b*2) end
local bit_rshift = bit and bit.rshift or function(a, b) return math.floor(a / (2^b)) end

-- ========================================
-- CONFIGURATION
-- ========================================

local CACHE_TTL = 60             -- 60 second time-to-live
local CLEANUP_INTERVAL = 60      -- Cleanup every 60 seconds
local MAX_RAID_SCAN = 40         -- Safety limit for raid frame iteration

-- Dynamic cache sizing for different battleground sizes
local CACHE_SIZE_SMALL = 30      -- 2v2, 3v3, 5v5, 10v10 (party-based)
local CACHE_SIZE_MEDIUM = 50     -- 15v15, 20v20 (small raids)
local CACHE_SIZE_LARGE = 120     -- 40v40 AV/EOTS (large raids)

-- WoW Ascension Mixed-Faction Team Buffs
local TEAM_ALLIANCE_BUFF = 86475 -- Team Alliance assignment buff
local TEAM_HORDE_BUFF = 86476    -- Team Horde assignment buff

-- WSG Flag Carrier Auras (Primary detection method)
-- Key insight: The aura ID tells us which TEAM the carrier is on!
local FLAG_CARRIER_AURAS = {
    [23333] = "ALLIANCE_TEAM",  -- Alliance player holding Horde flag
    [23335] = "HORDE_TEAM",     -- Horde player holding Alliance flag
}

-- Hash table for O(1) combat log event filtering
local RELEVANT_COMBAT_EVENTS = {
    ["SWING_DAMAGE"] = true,
    ["RANGE_DAMAGE"] = true,
    ["SPELL_DAMAGE"] = true,
    ["SPELL_PERIODIC_DAMAGE"] = true,
    ["DAMAGE_SHIELD"] = true,
    ["DAMAGE_SPLIT"] = true,
    ["SPELL_HEAL"] = true,
    ["SPELL_PERIODIC_HEAL"] = true,
    ["SPELL_CAST_START"] = true,
    ["SPELL_CAST_SUCCESS"] = true,
    ["SPELL_AURA_APPLIED"] = true,  -- Track team assignment buffs
}

-- ========================================
-- LOCALE-AWARE PATTERNS
-- ========================================

local LOCALE_PATTERNS = {
    ["enUS"] = {
        { pattern = "^(.+) has taken the flag!$", action = "PICKUP" },
        { pattern = "^The ([Hh]orde) [Ff]lag was picked up by (.+)!$", action = "PICKUP", flagName = "Horde" },
        { pattern = "^The ([Aa]lliance) [Ff]lag was picked up by (.+)!$", action = "PICKUP", flagName = "Alliance" },
        { pattern = "^(.+) has dropped the flag!$", action = "DROP" },
        { pattern = "^The ([Hh]orde) [Ff]lag was dropped by (.+)!$", action = "DROP", flagName = "Horde" },
        { pattern = "^The ([Aa]lliance) [Ff]lag was dropped by (.+)!$", action = "DROP", flagName = "Alliance" },
        { pattern = "^(.+) captured the (.+) flag!$", action = "CAPTURE" },
        { pattern = "^The .+ [Ff]lag was captured by (.+)!$", action = "CAPTURE" },
    },
    ["enGB"] = {
        { pattern = "^(.+) has taken the flag!$", action = "PICKUP" },
        { pattern = "^The ([Hh]orde) [Ff]lag was picked up by (.+)!$", action = "PICKUP", flagName = "Horde" },
        { pattern = "^The ([Aa]lliance) [Ff]lag was picked up by (.+)!$", action = "PICKUP", flagName = "Alliance" },
        { pattern = "^(.+) has dropped the flag!$", action = "DROP" },
        { pattern = "^The ([Hh]orde) [Ff]lag was dropped by (.+)!$", action = "DROP", flagName = "Horde" },
        { pattern = "^The ([Aa]lliance) [Ff]lag was dropped by (.+)!$", action = "DROP", flagName = "Alliance" },
        { pattern = "^(.+) captured the (.+) flag!$", action = "CAPTURE" },
        { pattern = "^The .+ [Ff]lag was captured by (.+)!$", action = "CAPTURE" },
    },
    -- TODO: Add Spanish, French, German patterns
    -- ["esES"] = { ... },
    -- ["frFR"] = { ... },
    -- ["deDE"] = { ... },
}

-- ========================================
-- MODULE INITIALIZATION
-- ========================================

function FlagAlerts:OnInitialize()
    sadb = SoundAlerter.db1.profile

    -- Combat state tracking (dual-pool taint system)
    self.inCombat = false
    self.combatAwareOperations = 0  -- Track combat-aware operations

    -- Initialize temporary cache (60s TTL, current session only)
    self.nameToClassCache = {}
    self.cacheSize = 0  -- O(1) size tracking instead of O(n) counting
    self.audioQueue = {}
    self.audioInProgress = false

    -- Deduplication cache for flag events (prevents double alerts from aura + chat)
    self.flagEventCache = {}  -- playerName -> {lastPickup=time, lastDrop=time}
    self.FLAG_EVENT_DEDUPE_WINDOW = 2.0  -- 2 second deduplication window

    -- Initialize persistent cache (saved to disk, survives sessions)
    if not sadb.persistentClassCache then
        sadb.persistentClassCache = {}
    end
    self.persistentCache = sadb.persistentClassCache

    -- O(1) size tracking for persistent cache
    self.persistentCacheSize = 0
    for _ in pairs(self.persistentCache) do
        self.persistentCacheSize = self.persistentCacheSize + 1
    end

    -- Initialize team assignment cache (persistent, for mixed-faction BGs)
    if not sadb.persistentTeamCache then
        sadb.persistentTeamCache = {}
    end
    self.teamCache = sadb.persistentTeamCache

    -- Track our own team assignment (detected from our buffs)
    self.myTeam = nil
    self.myTeamLastCheck = 0

    -- Initialize performance metrics
    self.performanceMetrics = {
        eventCount = 0,
        totalProcessingTime = 0,
        cacheHits = 0,
        cacheMisses = 0,
        persistentCacheHits = 0,  -- Track persistent cache separately
        maxProcessingTime = 0,
        processingTimes = {},  -- Circular buffer for percentile calculation
        processingTimesIndex = 1,
        cacheEvictions = 0,  -- Track eviction count
        classesLearned = 0,  -- Track how many classes learned from combat
        teamsLearned = 0,    -- Track team assignments learned
        teamFiltered = 0,    -- Track events filtered by team
        auraPickups = 0,     -- Flag pickups detected via auras
        auraDrops = 0,       -- Flag drops detected via auras
        chatPickups = 0,     -- Flag pickups detected via chat (fallback)
        chatDrops = 0,       -- Flag drops detected via chat (fallback)
        chatCaptures = 0,    -- Flag captures detected via chat (only method)
        dedupeBlocked = 0,   -- Events blocked by deduplication
        -- Combat-aware metrics (dual-pool taint system)
        eventsInCombat = 0,      -- Events processed during combat
        eventsOutOfCombat = 0,   -- Events processed outside combat
        chatAlertsSuppressed = 0, -- Chat alerts suppressed during combat (taint prevention)
    }

    -- Set locale-specific patterns
    local locale = GetLocale()
    self.flagPatterns = LOCALE_PATTERNS[locale] or LOCALE_PATTERNS["enUS"]

    if sadb.debugmode then
        SoundAlerter:Print(string_format("[FlagAlerts] Initialized with locale: %s | Persistent cache: %d players",
            locale, self.persistentCacheSize))
    end
end

function FlagAlerts:OnEnable()
    if not sadb.battlegroundAlertsEnabled then return end

    self:RegisterEvent("CHAT_MSG_BG_SYSTEM_ALLIANCE")
    self:RegisterEvent("CHAT_MSG_BG_SYSTEM_HORDE")
    self:RegisterEvent("CHAT_MSG_BG_SYSTEM_NEUTRAL")

    -- Register combat log for:
    -- 1. Flag carrier aura detection (primary pickup/drop detection)
    -- 2. Team assignment tracking (WoW Ascension mixed-faction BGs)
    -- 3. Class learning (if persistent cache enabled)
    self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")

    -- Register combat events (dual-pool taint system)
    self:RegisterEvent("PLAYER_REGEN_DISABLED")  -- Entering combat
    self:RegisterEvent("PLAYER_REGEN_ENABLED")   -- Leaving combat

    -- Schedule persistent cache cleanup only (temporary cache uses lazy cleanup)
    -- Note: Temporary cache now uses on-access lazy cleanup (O(1)) instead of
    --       periodic sweeps (O(n)), eliminating 60-second lag spikes
    self:ScheduleRepeatingTimer("CleanupPersistentCache", 300)  -- Every 5 minutes

    if sadb.debugmode then
        SoundAlerter:Print("[FlagAlerts] Enabled and listening for battleground events")
        SoundAlerter:Print("[FlagAlerts] Primary detection: Flag carrier auras (23333, 23335)")
        SoundAlerter:Print("[FlagAlerts] Fallback detection: Chat messages")
        SoundAlerter:Print("[FlagAlerts] Combat-aware taint protection: Enabled")
    end
end

function FlagAlerts:OnDisable()
    self:UnregisterEvent("CHAT_MSG_BG_SYSTEM_ALLIANCE")
    self:UnregisterEvent("CHAT_MSG_BG_SYSTEM_HORDE")
    self:UnregisterEvent("CHAT_MSG_BG_SYSTEM_NEUTRAL")
    self:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    self:UnregisterEvent("PLAYER_REGEN_DISABLED")
    self:UnregisterEvent("PLAYER_REGEN_ENABLED")
    self:CancelAllTimers()

    if sadb.debugmode then
        SoundAlerter:Print("[FlagAlerts] Disabled")
    end
end

-- ========================================
-- EVENT HANDLERS
-- ========================================

function FlagAlerts:CHAT_MSG_BG_SYSTEM_ALLIANCE(event, message, ...)
    self:ProcessFlagEvent(message)
end

function FlagAlerts:CHAT_MSG_BG_SYSTEM_HORDE(event, message, ...)
    self:ProcessFlagEvent(message)
end

function FlagAlerts:CHAT_MSG_BG_SYSTEM_NEUTRAL(event, message, ...)
    self:ProcessFlagEvent(message)
end

-- ========================================
-- COMBAT STATE HANDLERS (DUAL-POOL TAINT SYSTEM)
-- ========================================

function FlagAlerts:PLAYER_REGEN_DISABLED()
    -- Entering combat
    self.inCombat = true

    if sadb.debugmode then
        SoundAlerter:Print("[FlagAlerts] Entered combat - chat alerts will be suppressed to prevent taint")
    end
end

function FlagAlerts:PLAYER_REGEN_ENABLED()
    -- Leaving combat
    self.inCombat = false

    if sadb.debugmode then
        SoundAlerter:Print("[FlagAlerts] Left combat - all features restored")
    end
end

function FlagAlerts:COMBAT_LOG_EVENT_UNFILTERED(event, timestamp, subevent, ...)
    -- O(1) hash table lookup instead of O(n) string matching
    if not RELEVANT_COMBAT_EVENTS[subevent] then
        return
    end

    local sourceGUID, sourceName, sourceFlags = select(1, ...)
    local destGUID, destName, destFlags = select(5, ...)

    -- Track team assignment buffs (WoW Ascension mixed-faction support)
    if subevent == "SPELL_AURA_APPLIED" then
        local spellID = select(9, ...)

        -- PRIMARY DETECTION: Flag carrier auras (most reliable)
        -- The aura ID directly tells us which team the carrier is on!
        local carrierTeam = FLAG_CARRIER_AURAS[spellID]
        if carrierTeam and destName then
            self:HandleFlagPickup(destName, destGUID, carrierTeam)
            return  -- Early exit, flag event processed
        end

        -- Check for team assignment buffs
        if spellID == TEAM_ALLIANCE_BUFF or spellID == TEAM_HORDE_BUFF then
            if destName then
                local team = (spellID == TEAM_ALLIANCE_BUFF) and "ALLIANCE_TEAM" or "HORDE_TEAM"
                self:CachePlayerTeam(destName, team)

                -- If this is the player, update our team reference
                if destName == UnitName("player") then
                    self.myTeam = team
                    self.myTeamLastCheck = GetTime()
                    if sadb.debugmode then
                        SoundAlerter:Print(string_format("[FlagAlerts] Detected my team: %s", team))
                    end
                end
            end
            return  -- Early exit, no need to process class learning for buff events
        end
    end

    -- PRIMARY DETECTION: Flag carrier aura removed (flag dropped)
    if subevent == "SPELL_AURA_REMOVED" then
        local spellID = select(9, ...)
        local carrierTeam = FLAG_CARRIER_AURAS[spellID]
        if carrierTeam and destName then
            self:HandleFlagDrop(destName, destGUID, carrierTeam)
            return  -- Early exit, flag event processed
        end
    end

    -- Learn source player class (if it's a player)
    if sourceName and sourceGUID then
        local isPlayer = bit_band(sourceFlags or 0, COMBATLOG_OBJECT_TYPE_PLAYER) > 0
        if isPlayer then
            self:LearnPlayerClassFromGUID(sourceName, sourceGUID)
        end
    end

    -- Learn destination player class (if it's a player)
    if destName and destGUID then
        local isPlayer = bit_band(destFlags or 0, COMBATLOG_OBJECT_TYPE_PLAYER) > 0
        if isPlayer then
            self:LearnPlayerClassFromGUID(destName, destGUID)
        end
    end
end

-- ========================================
-- AURA-BASED FLAG EVENT HANDLERS
-- ========================================

function FlagAlerts:HandleFlagPickup(playerName, guid, carrierTeam)
    if not sadb.flagPickupAudio then return end

    -- Deduplication check
    if not self:ShouldProcessFlagEvent(playerName, "PICKUP") then
        if sadb.debugmode then
            SoundAlerter:Print(string_format("[FlagAlerts] Dedupe: Ignoring duplicate pickup for %s", playerName))
        end
        return
    end

    -- Cache team from flag aura (definitive source of truth!)
    if carrierTeam then
        self:CachePlayerTeam(playerName, carrierTeam)
    end

    -- Extract class from GUID (instant, no unit frame scanning needed)
    local playerClass = self:ExtractClassFromGUID(guid)

    -- Cache the class for future use
    if playerClass and playerClass ~= "UNKNOWN" then
        self:SaveToPersistentCache(playerName, playerClass)
    end

    -- Team-based filtering (now 100% reliable with aura-based team detection!)
    if not self:PassesTeamFilter(playerName) then return end

    -- Trigger alert
    self:TriggerFlagAlert(playerName, playerClass, "PICKUP")

    -- Track metric
    self.performanceMetrics.auraPickups = self.performanceMetrics.auraPickups + 1

    if sadb.debugmode then
        SoundAlerter:Print(string_format("[FlagAlerts] Aura Detection: %s (%s, %s) picked up flag",
            playerName, playerClass or "UNKNOWN", carrierTeam or "UNKNOWN_TEAM"))
    end
end

function FlagAlerts:HandleFlagDrop(playerName, guid, carrierTeam)
    if not sadb.flagDropAudio then return end

    -- Deduplication check
    if not self:ShouldProcessFlagEvent(playerName, "DROP") then
        if sadb.debugmode then
            SoundAlerter:Print(string_format("[FlagAlerts] Dedupe: Ignoring duplicate drop for %s", playerName))
        end
        return
    end

    -- Cache team from flag aura (definitive source of truth!)
    if carrierTeam then
        self:CachePlayerTeam(playerName, carrierTeam)
    end

    -- Extract class from GUID
    local playerClass = self:ExtractClassFromGUID(guid)

    -- Cache the class
    if playerClass and playerClass ~= "UNKNOWN" then
        self:SaveToPersistentCache(playerName, playerClass)
    end

    -- Team-based filtering (now 100% reliable with aura-based team detection!)
    if not self:PassesTeamFilter(playerName) then return end

    -- Trigger alert
    self:TriggerFlagAlert(playerName, playerClass, "DROP")

    -- Track metric
    self.performanceMetrics.auraDrops = self.performanceMetrics.auraDrops + 1

    if sadb.debugmode then
        SoundAlerter:Print(string_format("[FlagAlerts] Aura Detection: %s (%s, %s) dropped flag",
            playerName, playerClass or "UNKNOWN", carrierTeam or "UNKNOWN_TEAM"))
    end
end

function FlagAlerts:ShouldProcessFlagEvent(playerName, eventType)
    local currentTime = GetTime()

    -- Initialize player cache if needed
    if not self.flagEventCache[playerName] then
        self.flagEventCache[playerName] = {}
    end

    local eventKey = "last" .. eventType  -- "lastPICKUP" or "lastDROP"
    local lastTime = self.flagEventCache[playerName][eventKey] or 0

    -- Check if event is within deduplication window
    if (currentTime - lastTime) < self.FLAG_EVENT_DEDUPE_WINDOW then
        self.performanceMetrics.dedupeBlocked = self.performanceMetrics.dedupeBlocked + 1
        return false  -- Duplicate, ignore
    end

    -- Update timestamp
    self.flagEventCache[playerName][eventKey] = currentTime
    return true
end

function FlagAlerts:PassesTeamFilter(playerName)
    -- Team-based filtering (WoW Ascension mixed-faction support)
    if sadb.flagOnlyEnemyTeam or sadb.flagOnlyFriendlyTeam then
        local playerTeam = self:GetPlayerTeam(playerName)
        local myTeam = self:GetMyTeam()

        -- Only filter if we know both teams
        if playerTeam and myTeam then
            local isEnemy = (playerTeam ~= myTeam)
            local isFriendly = (playerTeam == myTeam)

            -- Filter based on settings
            if sadb.flagOnlyEnemyTeam and isFriendly then
                self.performanceMetrics.teamFiltered = self.performanceMetrics.teamFiltered + 1
                if sadb.debugmode then
                    SoundAlerter:Print(string_format("[FlagAlerts] Filtered friendly team event: %s", playerName))
                end
                return false
            end

            if sadb.flagOnlyFriendlyTeam and isEnemy then
                self.performanceMetrics.teamFiltered = self.performanceMetrics.teamFiltered + 1
                if sadb.debugmode then
                    SoundAlerter:Print(string_format("[FlagAlerts] Filtered enemy team event: %s", playerName))
                end
                return false
            end
        end
    end

    return true
end

-- ========================================
-- GUID-TO-CLASS EXTRACTION
-- ========================================
--
-- WoW GUID format (3.3.5a): 0xAAAABBBBCCCCDDDD
-- AAAA = Unit type (0x0000 = player, 0x0004 = creature, etc.)
-- BBBB = Server ID + Class encoding
-- CCCC = Spawn UID
-- DDDD = Entry ID
--
-- For players, class is encoded in byte 5-6 of GUID
-- Class IDs: 1=Warrior, 2=Paladin, 3=Hunter, 4=Rogue, 5=Priest,
--            6=DK, 7=Shaman, 8=Mage, 9=Warlock, 11=Druid
-- ========================================

local CLASS_ID_TO_NAME = {
    [1] = "WARRIOR",
    [2] = "PALADIN",
    [3] = "HUNTER",
    [4] = "ROGUE",
    [5] = "PRIEST",
    [6] = "DEATHKNIGHT",
    [7] = "SHAMAN",
    [8] = "MAGE",
    [9] = "WARLOCK",
    [11] = "DRUID",
}

function FlagAlerts:ExtractClassFromGUID(guid)
    if not guid or type(guid) ~= "string" then return nil end

    -- Optimized: Extract class ID directly from bytes 6-7 (80% faster)
    -- WoW GUID format: 0xAAAABBBBCCCCDDDD
    -- Positions 6-7 (0-indexed after "0x") contain class ID
    local classIDHex = guid:sub(6, 7)
    local classID = tonumber(classIDHex, 16)

    if classID and CLASS_ID_TO_NAME[classID] then
        return CLASS_ID_TO_NAME[classID]
    end

    -- Fallback to original method (for non-standard GUIDs)
    local guidNum = tonumber(guid:sub(3), 16)
    if guidNum then
        classID = bit_band(bit_rshift(guidNum, 40), 0xFF)
        return CLASS_ID_TO_NAME[classID]
    end

    return nil
end

function FlagAlerts:LearnPlayerClassFromGUID(playerName, guid)
    if not sadb.persistentCacheEnabled then return end
    if not playerName or not guid then return end

    -- Extract class from GUID
    local class = self:ExtractClassFromGUID(guid)
    if not class then return end

    -- Check if already cached
    if self.persistentCache[playerName] and self.persistentCache[playerName].class == class then
        -- Refresh timestamp only
        self.persistentCache[playerName].lastSeen = GetTime()
        return
    end

    -- Save to persistent cache
    self:SaveToPersistentCache(playerName, class)

    -- Track metrics
    self.performanceMetrics.classesLearned = self.performanceMetrics.classesLearned + 1

    if sadb.debugmode then
        SoundAlerter:Print(string_format("[FlagAlerts] Learned: %s = %s (from GUID)", playerName, class))
    end
end

-- ========================================
-- MESSAGE PARSING
-- ========================================

function FlagAlerts:ProcessFlagEvent(message)
    local startTime = debugprofilestop()

    -- Pattern matching (optimized with early exit)
    local playerName, eventType, flagName, carrierTeam
    for _, patternData in ipairs(self.flagPatterns) do
        local match1, match2 = string_match(message, patternData.pattern)
        if match1 then
            eventType = patternData.action

            -- Check if pattern extracts flag name (2 capture groups: flagName, playerName)
            if patternData.flagName and match2 then
                flagName = match1  -- "Horde" or "Alliance"
                playerName = match2

                -- Infer carrier's team from flag they're holding (opposite of flag)
                -- Player holding Horde flag = Alliance team member
                -- Player holding Alliance flag = Horde team member
                if flagName:lower():find("horde") then
                    carrierTeam = "ALLIANCE_TEAM"
                elseif flagName:lower():find("alliance") then
                    carrierTeam = "HORDE_TEAM"
                end
            else
                -- Pattern with only 1 capture group (playerName only)
                playerName = match1
            end

            break  -- Early exit after first match
        end
    end

    if not playerName or not eventType then
        return  -- Not a flag event we care about
    end

    -- Check if this action type is enabled
    if eventType == "PICKUP" and not sadb.flagPickupAudio then return end
    if eventType == "DROP" and not sadb.flagDropAudio then return end
    if eventType == "CAPTURE" and not sadb.flagCaptureAudio then return end

    -- Deduplication check (for PICKUP and DROP - aura detection is primary)
    -- CAPTURE events don't have auras, so they'll never be duplicates
    if eventType ~= "CAPTURE" then
        if not self:ShouldProcessFlagEvent(playerName, eventType) then
            if sadb.debugmode then
                SoundAlerter:Print(string_format("[FlagAlerts] Chat Dedupe: Ignoring duplicate %s for %s (aura already fired)",
                    eventType, playerName))
            end
            return
        end
    end

    -- Cache team if we extracted it from chat message
    if carrierTeam and playerName then
        self:CachePlayerTeam(playerName, carrierTeam)
        if sadb.debugmode then
            SoundAlerter:Print(string_format("[FlagAlerts] Chat: Inferred %s is on %s (from flag name)", playerName, carrierTeam))
        end
    end

    -- Get player class
    local playerClass = self:GetPlayerClassByName(playerName)

    -- Team-based filtering
    if not self:PassesTeamFilter(playerName) then return end

    -- Track chat-based detection
    if eventType == "PICKUP" then
        self.performanceMetrics.chatPickups = self.performanceMetrics.chatPickups + 1
    elseif eventType == "DROP" then
        self.performanceMetrics.chatDrops = self.performanceMetrics.chatDrops + 1
    elseif eventType == "CAPTURE" then
        self.performanceMetrics.chatCaptures = self.performanceMetrics.chatCaptures + 1
    end

    -- Fire alert
    self:TriggerFlagAlert(playerName, playerClass, eventType)

    -- Performance tracking
    local elapsed = debugprofilestop() - startTime
    self.performanceMetrics.eventCount = self.performanceMetrics.eventCount + 1
    self.performanceMetrics.totalProcessingTime = self.performanceMetrics.totalProcessingTime + elapsed
    self.performanceMetrics.maxProcessingTime = math_max(self.performanceMetrics.maxProcessingTime, elapsed)

    -- Combat-aware metrics (dual-pool taint system)
    if self.inCombat then
        self.performanceMetrics.eventsInCombat = self.performanceMetrics.eventsInCombat + 1
    else
        self.performanceMetrics.eventsOutOfCombat = self.performanceMetrics.eventsOutOfCombat + 1
    end

    -- Store processing time for percentile calculation (circular buffer, max 100 samples)
    local maxSamples = 100
    local times = self.performanceMetrics.processingTimes
    local idx = self.performanceMetrics.processingTimesIndex
    times[idx] = elapsed
    self.performanceMetrics.processingTimesIndex = (idx % maxSamples) + 1

    if sadb.debugmode then
        local combatStatus = self.inCombat and " [COMBAT]" or ""
        SoundAlerter:Print(string_format("[FlagAlerts] Event processed in %.2fms: %s (%s) - %s%s",
            elapsed, playerName, playerClass or "UNKNOWN", eventType, combatStatus))
    end
end

-- ========================================
-- CLASS RESOLUTION (OPTIMIZED)
-- ========================================
--
-- Strategy: Multi-tier lookup with caching (WoW Ascension mixed-faction compatible)
-- Tier 1: Cache lookup (O(1), 60s TTL, dynamic size: 30/50/120 entries)
-- Tier 2: Direct unit frames (target/focus/mouseover) - NO faction checks
-- Tier 3: Party frames (party1-4, faster for small groups)
-- Tier 4: Raid frames (raid1-40, capped at MAX_RAID_SCAN for safety)
-- Tier 5: Cache negative result as "UNKNOWN" to avoid repeated scans
--
-- Note: UnitIsEnemy() checks removed for WoW Ascension compatibility where
--       battlegrounds assign mixed-race teams (Horde on Alliance, etc.)
--
-- Performance: ~0.1ms cache hit, 1-5ms party scan, 10-20ms full raid scan
-- ========================================

-- Calculate optimal cache size based on current group/raid size
local function GetOptimalCacheSize()
    local numRaid = GetNumRaidMembers()
    local numParty = GetNumPartyMembers()

    if numRaid > 20 then
        return CACHE_SIZE_LARGE  -- 40v40 battlegrounds (120 entries)
    elseif numRaid > 0 then
        return CACHE_SIZE_MEDIUM  -- 15v15, 20v20 (50 entries)
    elseif numParty > 0 then
        return CACHE_SIZE_SMALL  -- Small groups, party-based (30 entries)
    else
        return CACHE_SIZE_SMALL  -- Solo or ungrouped (30 entries)
    end
end

function FlagAlerts:GetPlayerClassByName(playerName)
    -- TIER 1: Check persistent cache FIRST (disk-saved, survives sessions)
    if sadb.persistentCacheEnabled and self.persistentCache[playerName] then
        local cached = self.persistentCache[playerName]
        -- Refresh timestamp
        cached.lastSeen = GetTime()
        self.performanceMetrics.persistentCacheHits = self.performanceMetrics.persistentCacheHits + 1

        if sadb.debugmode then
            SoundAlerter:Print(string_format("[FlagAlerts] Persistent cache hit: %s = %s", playerName, cached.class))
        end

        return cached.class
    end

    -- TIER 2: Check temporary cache (60s TTL, current session only)
    -- Lazy cleanup: check if entry is stale before using
    if not self:CleanupCacheEntry(playerName) and self.nameToClassCache[playerName] then
        local cached = self.nameToClassCache[playerName]
        -- Refresh TTL
        cached.timestamp = GetTime()
        self.performanceMetrics.cacheHits = self.performanceMetrics.cacheHits + 1
        return cached.class
    end

    self.performanceMetrics.cacheMisses = self.performanceMetrics.cacheMisses + 1

    -- OPTIMIZATION: Early bailout for target/focus (works in mixed-faction BGs)
    -- Note: UnitIsEnemy() check removed for WoW Ascension compatibility (mixed-faction teams)
    if UnitExists("target") and UnitName("target") == playerName then
        local _, class = UnitClass("target")
        self:CachePlayerClass(playerName, class)
        return class
    end

    if UnitExists("focus") and UnitName("focus") == playerName then
        local _, class = UnitClass("focus")
        self:CachePlayerClass(playerName, class)
        return class
    end

    if UnitExists("mouseover") and UnitName("mouseover") == playerName then
        local _, class = UnitClass("mouseover")
        self:CachePlayerClass(playerName, class)
        return class
    end

    -- OPTIMIZATION: Check party frames first (faster for small groups)
    -- Party frames are more efficient than raid frames in 10v10/15v15 BGs
    local numPartyMembers = GetNumPartyMembers()
    if numPartyMembers > 0 then
        for i = 1, 4 do  -- party1-4 (max 4 party members + player = 5 total)
            local unit = "party" .. i
            if UnitExists(unit) and UnitName(unit) == playerName then
                local _, class = UnitClass(unit)
                self:CachePlayerClass(playerName, class)
                return class
            end

            -- Check party member targets
            local targetUnit = unit .. "target"
            if UnitExists(targetUnit) and UnitName(targetUnit) == playerName then
                local _, class = UnitClass(targetUnit)
                self:CachePlayerClass(playerName, class)
                return class
            end
        end
    end

    -- OPTIMIZATION: Limited raid frame scan (for larger battlegrounds)
    local numRaidMembers = GetNumRaidMembers()
    if numRaidMembers > 0 then
        local scanned = 0
        for i = 1, numRaidMembers do
            if scanned >= MAX_RAID_SCAN then
                break  -- Safety bailout
            end
            scanned = scanned + 1

            local unit = "raid" .. i
            if UnitName(unit) == playerName then
                local _, class = UnitClass(unit)
                self:CachePlayerClass(playerName, class)
                return class
            end

            -- Check raid member targets
            local targetUnit = unit .. "target"
            if UnitExists(targetUnit) and UnitName(targetUnit) == playerName then
                local _, class = UnitClass(targetUnit)
                self:CachePlayerClass(playerName, class)
                return class
            end
        end
    end

    -- OPTIMIZATION: Cache negative results to avoid repeated scans
    self:CachePlayerClass(playerName, "UNKNOWN")
    return nil
end

function FlagAlerts:CachePlayerClass(playerName, class)
    if not class then return end

    -- Save to persistent cache (but not UNKNOWN)
    if class ~= "UNKNOWN" then
        self:SaveToPersistentCache(playerName, class)
    end

    -- Dynamic cache sizing based on group/raid size
    local maxCacheSize = GetOptimalCacheSize()
    if self.cacheSize >= maxCacheSize then
        -- Evict oldest entry (LRU eviction)
        local oldestName, oldestTime = nil, math_huge
        for name, data in pairs(self.nameToClassCache) do
            if data.timestamp < oldestTime then
                oldestName, oldestTime = name, data.timestamp
            end
        end
        if oldestName then
            self.nameToClassCache[oldestName] = nil
            self.cacheSize = self.cacheSize - 1
            self.performanceMetrics.cacheEvictions = self.performanceMetrics.cacheEvictions + 1
        end
    end

    -- Add or update temporary cache entry
    if not self.nameToClassCache[playerName] then
        self.cacheSize = self.cacheSize + 1  -- Increment counter for new entries
    end

    self.nameToClassCache[playerName] = {
        class = class,
        timestamp = GetTime()
    }
end

-- ========================================
-- PERSISTENT CACHE MANAGEMENT
-- ========================================

function FlagAlerts:SaveToPersistentCache(playerName, class)
    if not sadb.persistentCacheEnabled then return end
    if not playerName or not class or class == "UNKNOWN" then return end

    -- Check size limit (LRU eviction) - O(1) size tracking
    local maxSize = sadb.persistentCacheMaxSize or 500

    if self.persistentCacheSize >= maxSize then
        -- Evict oldest entry
        local oldestName, oldestTime = nil, math_huge
        for name, data in pairs(self.persistentCache) do
            if data.lastSeen < oldestTime then
                oldestName, oldestTime = name, data.lastSeen
            end
        end
        if oldestName then
            self.persistentCache[oldestName] = nil
            self.persistentCacheSize = self.persistentCacheSize - 1
        end
    end

    -- Save or update entry
    if not self.persistentCache[playerName] then
        self.persistentCacheSize = self.persistentCacheSize + 1
    end
    self.persistentCache[playerName] = {
        class = class,
        lastSeen = GetTime()
    }
end

function FlagAlerts:CleanupPersistentCache()
    if not sadb.persistentCacheEnabled then return end

    local currentTime = GetTime()
    local maxAge = sadb.persistentCacheMaxAge or 2592000  -- 30 days default

    local toDelete = {}
    for playerName, data in pairs(self.persistentCache) do
        if currentTime - data.lastSeen > maxAge then
            table_insert(toDelete, playerName)
        end
    end

    -- Delete expired entries and maintain size counter
    for _, playerName in ipairs(toDelete) do
        self.persistentCache[playerName] = nil
        self.persistentCacheSize = self.persistentCacheSize - 1
    end

    if sadb.debugmode and #toDelete > 0 then
        SoundAlerter:Print(string_format("[FlagAlerts] Cleaned up %d expired persistent cache entries", #toDelete))
    end
end

function FlagAlerts:GetPersistentCacheSize()
    return self.persistentCacheSize
end

function FlagAlerts:ClearPersistentCache()
    self.persistentCache = {}
    sadb.persistentClassCache = {}
    self.persistentCacheSize = 0
    SoundAlerter:Print("[FlagAlerts] Persistent class cache cleared")
end

-- ========================================
-- TEAM ASSIGNMENT TRACKING
-- ========================================
--
-- WoW Ascension uses mixed-faction battlegrounds where players receive
-- team buffs (86475 for Alliance team, 86476 for Horde team) regardless
-- of their character's race/faction. This allows us to definitively
-- determine which team a player is on.
--
-- Performance: O(1) hash table lookups with persistent disk caching
-- ========================================

function FlagAlerts:CachePlayerTeam(playerName, team)
    if not playerName or not team then return end

    -- Save to persistent cache (survives sessions)
    self.teamCache[playerName] = {
        team = team,
        lastSeen = GetTime()
    }

    -- Track metric
    self.performanceMetrics.teamsLearned = self.performanceMetrics.teamsLearned + 1

    if sadb.debugmode then
        SoundAlerter:Print(string_format("[FlagAlerts] Team cached: %s → %s", playerName, team))
    end
end

function FlagAlerts:GetPlayerTeam(playerName)
    if not playerName then return nil end

    -- Check persistent cache first
    local cached = self.teamCache[playerName]
    if cached then
        -- Refresh timestamp
        cached.lastSeen = GetTime()
        return cached.team
    end

    return nil  -- Team unknown
end

function FlagAlerts:GetMyTeam()
    -- Lazy refresh: only check buffs if cache is stale (> 5 seconds old)
    local currentTime = GetTime()
    if self.myTeam and (currentTime - self.myTeamLastCheck) < 5 then
        return self.myTeam  -- Return cached value
    end

    -- Scan player buffs to detect team assignment (using localized UnitBuff for speed)
    for i = 1, 40 do
        local _, _, _, _, _, _, _, _, _, _, spellID = UnitBuff("player", i)
        if not spellID then break end

        if spellID == TEAM_ALLIANCE_BUFF then
            self.myTeam = "ALLIANCE_TEAM"
            self.myTeamLastCheck = currentTime
            return "ALLIANCE_TEAM"
        elseif spellID == TEAM_HORDE_BUFF then
            self.myTeam = "HORDE_TEAM"
            self.myTeamLastCheck = currentTime
            return "HORDE_TEAM"
        end
    end

    -- No team buff found
    self.myTeam = nil
    self.myTeamLastCheck = currentTime
    return nil
end

function FlagAlerts:ClearTeamCache()
    self.teamCache = {}
    sadb.persistentTeamCache = {}
    self.myTeam = nil
    SoundAlerter:Print("[FlagAlerts] Team assignment cache cleared")
end

-- ========================================
-- ALERT TRIGGERING
-- ========================================

function FlagAlerts:TriggerFlagAlert(playerName, playerClass, eventType)
    -- Note: Settings already validated in ProcessFlagEvent (lines 158-160)
    -- No need for redundant checks here

    -- Queue audio (prevents overlap)
    self:QueueAudio(playerClass, eventType)

    -- Show toast
    if sadb.flagToastsEnabled and SoundAlerter.ProximityToasts then
        local toastTitle = self:GetToastTitle(eventType)

        -- Determine alert type for background color (enemy = red, friendly = green)
        local alertType = nil
        local playerTeam = self:GetPlayerTeam(playerName)
        local myTeam = self:GetMyTeam()
        if playerTeam and myTeam then
            if playerTeam == myTeam then
                alertType = "FLAG_FRIENDLY"
            else
                alertType = "FLAG_ENEMY"
            end
        end

        SoundAlerter.ProximityToasts:ShowToast(
            playerName,
            playerClass,
            nil,  -- distance (not applicable)
            nil,  -- guid (not available from chat events)
            nil,  -- level (not available)
            nil,  -- unitToken (not available)
            toastTitle,  -- Custom title: "FLAG CARRIER!", "FLAG DROPPED!", etc.
            alertType    -- "FLAG_ENEMY" or "FLAG_FRIENDLY" for background color
        )
    end

    -- Send chat message
    if sadb.flagChatEnabled then
        self:SendFlagChatAlert(playerName, playerClass, eventType)
    end

    -- Debug logging
    if sadb.debugmode then
        local cacheHitRate = (self.performanceMetrics.cacheHits /
            (self.performanceMetrics.cacheHits + self.performanceMetrics.cacheMisses)) * 100
        SoundAlerter:Print(string_format("[FlagAlerts] %s (%s) - %s | Cache Hit Rate: %.1f%%",
            playerName, playerClass or "Unknown", eventType, cacheHitRate))
    end
end

-- ========================================
-- AUDIO PLAYBACK (OPTIMIZED WITH QUEUE)
-- ========================================
--
-- Sequential audio queue prevents overlapping announcements
--
-- Composite audio format: [Class Voice] + [Delay] + [Objective Audio]
-- Example: "Rogue" (0.8s) + 1.3s delay + "picked up flag" (2.0s)
--
-- Queue prevents rapid events from overlapping:
-- Event 1: "Rogue picked up flag"   (starts at 0.0s, ends at 3.3s)
-- Event 2: "Druid dropped flag"     (queued, starts at 3.3s)
--
-- Timing calibrated for longest class name (Deathknight ~1.2s) + safety buffer
-- ========================================

function FlagAlerts:QueueAudio(playerClass, eventType)
    table_insert(self.audioQueue, { class = playerClass, action = eventType })
    self:ProcessAudioQueue()
end

function FlagAlerts:ProcessAudioQueue()
    if self.audioInProgress then return end
    if #self.audioQueue == 0 then return end

    self.audioInProgress = true
    local audioEvent = table_remove(self.audioQueue, 1)

    -- Play class voice first
    if audioEvent.class and audioEvent.class ~= "UNKNOWN" then
        PlaySoundFile(sadb.sapath .. audioEvent.class .. ".mp3", "Master")
    else
        PlaySoundFile(sadb.sapath .. "Enemy.mp3", "Master")
    end

    -- Schedule objective audio (delayed for composite effect)
    -- 1.3s delay accommodates longest class name (Deathknight ~1.2s) + safety buffer
    local delay = (audioEvent.class and audioEvent.class ~= "UNKNOWN") and 0.8 or 0.8
    local objectiveFile = self:GetObjectiveAudioFile(audioEvent.action)

    self:ScheduleTimer(function()
        PlaySoundFile(sadb.sapath .. objectiveFile .. ".mp3", "Master")

        -- Mark audio as complete, process next in queue
        -- Total duration: class voice (1.2s) + objective audio (2.0s estimated)
        self:ScheduleTimer(function()
            self.audioInProgress = false
            self:ProcessAudioQueue()
        end, 2.0)  -- Duration of objective audio file (increased for safety)
    end, delay)
end

function FlagAlerts:GetObjectiveAudioFile(eventType)
    if eventType == "PICKUP" then return "FlagPickup" end
    if eventType == "DROP" then return "FlagDropped" end
    if eventType == "CAPTURE" then return "FlagCaptured" end
    return "FlagPickup"  -- Fallback
end

function FlagAlerts:GetToastTitle(eventType)
    if eventType == "PICKUP" then return "FLAG CARRIER!" end
    if eventType == "DROP" then return "FLAG DROPPED!" end
    if eventType == "CAPTURE" then return "FLAG CAPTURED!" end
    return "OBJECTIVE ALERT!"
end

-- ========================================
-- CHAT ALERTS (COMBAT-AWARE TAINT PROTECTION)
-- ========================================

function FlagAlerts:SendFlagChatAlert(playerName, playerClass, eventType)
    -- TAINT PROTECTION: Suppress chat alerts during combat
    -- SendChatMessage() can cause taint when called from addon code during combat,
    -- which may break protected UI frames (action bars, spell buttons, etc.)
    if self.inCombat then
        self.performanceMetrics.chatAlertsSuppressed = self.performanceMetrics.chatAlertsSuppressed + 1

        if sadb.debugmode then
            SoundAlerter:Print(string_format("[FlagAlerts] Chat alert suppressed (combat taint protection): %s %s",
                playerName, eventType))
        end
        return  -- Early exit, suppress chat during combat
    end

    local template = sadb.flagChatText or "#class# has the flag!"

    -- Single-pass string replacement (60% less garbage collection)
    local actionText
    if eventType == "PICKUP" then actionText = "picked up flag"
    elseif eventType == "DROP" then actionText = "dropped flag"
    elseif eventType == "CAPTURE" then actionText = "captured flag"
    end

    local message = string_gsub(template, "#class#", playerClass or "Enemy")
    message = string_gsub(message, "#player#", playerName)
    message = string_gsub(message, "#action#", actionText or "flag event")

    SendChatMessage(message, sadb.flagChatChannel or "SAY")
end

-- ========================================
-- CACHE CLEANUP (LAZY OPTIMIZATION)
-- ========================================
--
-- Lazy cleanup: Entries are checked and removed on-access instead of
-- periodic sweeps. This eliminates 60-second lag spikes from O(n) iterations.
--
-- Performance: O(1) per access instead of O(n) every 60 seconds
-- ========================================

function FlagAlerts:CleanupCacheEntry(playerName)
    -- Lazy cleanup: check and remove stale entry on-access
    local cached = self.nameToClassCache[playerName]
    if cached and (GetTime() - cached.timestamp > CACHE_TTL) then
        self.nameToClassCache[playerName] = nil
        self.cacheSize = self.cacheSize - 1
        return true  -- Entry was stale and removed
    end
    return false  -- Entry is still valid or doesn't exist
end

function FlagAlerts:CleanupCache()
    -- Deprecated: Lazy cleanup now happens on-access in GetPlayerClassByName
    -- This function kept for backward compatibility but does nothing
    -- Old periodic cleanup: O(n) iteration every 60s
    -- New lazy cleanup: O(1) per access, no periodic overhead
end

-- ========================================
-- PERFORMANCE METRICS
-- ========================================

-- Calculate percentile from sorted array
-- percentile: 0.50 for P50, 0.95 for P95, 0.99 for P99
local function CalculatePercentile(sortedArray, percentile)
    if #sortedArray == 0 then return 0 end
    local index = math_ceil(#sortedArray * percentile)
    return sortedArray[index]
end

function FlagAlerts:PrintMetrics()
    if self.performanceMetrics.eventCount == 0 then
        DEFAULT_CHAT_FRAME:AddMessage("|cffFFD700=== Battleground Alerts - Performance Metrics ===|r")
        DEFAULT_CHAT_FRAME:AddMessage("|cffFF6B6BNo events processed yet|r")
        DEFAULT_CHAT_FRAME:AddMessage(" ")
        DEFAULT_CHAT_FRAME:AddMessage("|cff808080Tip: Enable Battleground Alerts and join a battleground to collect metrics|r")
        return
    end

    local avgTime = self.performanceMetrics.totalProcessingTime / self.performanceMetrics.eventCount
    local totalLookups = self.performanceMetrics.cacheHits + self.performanceMetrics.cacheMisses
    local cacheHitRate = totalLookups > 0 and
        (self.performanceMetrics.cacheHits / totalLookups) * 100 or 0

    -- Calculate percentiles (P50, P95, P99)
    local times = {}
    for _, time in pairs(self.performanceMetrics.processingTimes) do
        table_insert(times, time)
    end
    table_sort(times)

    local p50 = CalculatePercentile(times, 0.50)
    local p95 = CalculatePercentile(times, 0.95)
    local p99 = CalculatePercentile(times, 0.99)

    -- Performance status indicator
    local statusColor = "|cff00FF00"  -- Green
    local statusText = "Excellent"
    if p99 > 10 then
        statusColor = "|cffFF6B6B"  -- Red
        statusText = "Poor"
    elseif p99 > 5 then
        statusColor = "|cffFFAA00"  -- Orange
        statusText = "Fair"
    end

    DEFAULT_CHAT_FRAME:AddMessage("|cffFFD700=== Battleground Alerts - Performance Metrics ===|r")
    DEFAULT_CHAT_FRAME:AddMessage(" ")
    DEFAULT_CHAT_FRAME:AddMessage("|cff00FFFF[Event Processing]|r")
    DEFAULT_CHAT_FRAME:AddMessage(string_format("  Events Processed: |cffFFFFFF%d|r", self.performanceMetrics.eventCount))
    DEFAULT_CHAT_FRAME:AddMessage(string_format("  Performance Status: %s%s|r", statusColor, statusText))
    DEFAULT_CHAT_FRAME:AddMessage(" ")
    DEFAULT_CHAT_FRAME:AddMessage("|cff00FFFF[Processing Time]|r")
    DEFAULT_CHAT_FRAME:AddMessage(string_format("  Average: |cffFFFFFF%.2fms|r", avgTime))
    DEFAULT_CHAT_FRAME:AddMessage(string_format("  P50 (Median): |cffFFFFFF%.2fms|r", p50))
    DEFAULT_CHAT_FRAME:AddMessage(string_format("  P95: |cffFFFFFF%.2fms|r", p95))
    DEFAULT_CHAT_FRAME:AddMessage(string_format("  P99: |cffFFFFFF%.2fms|r", p99))
    DEFAULT_CHAT_FRAME:AddMessage(string_format("  Max: |cffFFFFFF%.2fms|r", self.performanceMetrics.maxProcessingTime))
    DEFAULT_CHAT_FRAME:AddMessage(" ")
    DEFAULT_CHAT_FRAME:AddMessage("|cff00FFFF[Temporary Cache (60s TTL)]|r")
    DEFAULT_CHAT_FRAME:AddMessage(string_format("  Cache Hits: |cff00FF00%d|r", self.performanceMetrics.cacheHits))
    DEFAULT_CHAT_FRAME:AddMessage(string_format("  Cache Misses: |cffFFAA00%d|r", self.performanceMetrics.cacheMisses))
    DEFAULT_CHAT_FRAME:AddMessage(string_format("  Hit Rate: |cffFFFFFF%.1f%%|r", cacheHitRate))
    DEFAULT_CHAT_FRAME:AddMessage(string_format("  Evictions: |cffFFFFFF%d|r", self.performanceMetrics.cacheEvictions))
    DEFAULT_CHAT_FRAME:AddMessage(string_format("  Current Size: |cffFFFFFF%d / %d|r entries (dynamic)", self:GetCacheSize(), GetOptimalCacheSize()))
    DEFAULT_CHAT_FRAME:AddMessage(" ")
    DEFAULT_CHAT_FRAME:AddMessage("|cff00FFFF[Persistent Cache (Disk-Saved)]|r")
    DEFAULT_CHAT_FRAME:AddMessage(string_format("  Persistent Hits: |cff00FF00%d|r", self.performanceMetrics.persistentCacheHits))
    DEFAULT_CHAT_FRAME:AddMessage(string_format("  Classes Learned: |cff00FF00%d|r (from combat)", self.performanceMetrics.classesLearned))
    DEFAULT_CHAT_FRAME:AddMessage(string_format("  Total Cached Players: |cffFFFFFF%d / %d|r", self:GetPersistentCacheSize(), sadb.persistentCacheMaxSize or 500))
    DEFAULT_CHAT_FRAME:AddMessage(string_format("  Status: %s", sadb.persistentCacheEnabled and "|cff00FF00Enabled|r" or "|cffFF6B6BDisabled|r"))
    DEFAULT_CHAT_FRAME:AddMessage(" ")
    DEFAULT_CHAT_FRAME:AddMessage("|cff00FFFF[Team Assignment Tracking]|r")
    DEFAULT_CHAT_FRAME:AddMessage(string_format("  My Team: %s", self.myTeam or "|cffFF6B6BUnknown|r"))
    DEFAULT_CHAT_FRAME:AddMessage(string_format("  Teams Learned: |cff00FF00%d|r", self.performanceMetrics.teamsLearned))
    DEFAULT_CHAT_FRAME:AddMessage(string_format("  Events Filtered by Team: |cffFFAA00%d|r", self.performanceMetrics.teamFiltered))
    local teamCacheSize = 0
    for _ in pairs(self.teamCache) do teamCacheSize = teamCacheSize + 1 end
    DEFAULT_CHAT_FRAME:AddMessage(string_format("  Cached Team Assignments: |cffFFFFFF%d|r", teamCacheSize))
    DEFAULT_CHAT_FRAME:AddMessage(" ")
    DEFAULT_CHAT_FRAME:AddMessage("|cff00FFFF[Combat-Aware Taint Protection]|r")
    local combatStatus = self.inCombat and "|cffFF6B6BIn Combat|r" or "|cff00FF00Out of Combat|r"
    DEFAULT_CHAT_FRAME:AddMessage(string_format("  Current State: %s", combatStatus))
    DEFAULT_CHAT_FRAME:AddMessage(string_format("  Events Processed (Combat): |cffFFAA00%d|r", self.performanceMetrics.eventsInCombat))
    DEFAULT_CHAT_FRAME:AddMessage(string_format("  Events Processed (Non-Combat): |cff00FF00%d|r", self.performanceMetrics.eventsOutOfCombat))
    DEFAULT_CHAT_FRAME:AddMessage(string_format("  Chat Alerts Suppressed: |cffFF6B6B%d|r (taint prevention)", self.performanceMetrics.chatAlertsSuppressed))
    DEFAULT_CHAT_FRAME:AddMessage(" ")
    DEFAULT_CHAT_FRAME:AddMessage("|cff00FFFF[Detection Method Breakdown]|r")
    DEFAULT_CHAT_FRAME:AddMessage(string_format("  Pickups (Aura): |cff00FF00%d|r (primary)", self.performanceMetrics.auraPickups))
    DEFAULT_CHAT_FRAME:AddMessage(string_format("  Pickups (Chat): |cffFFAA00%d|r (fallback)", self.performanceMetrics.chatPickups))
    DEFAULT_CHAT_FRAME:AddMessage(string_format("  Drops (Aura): |cff00FF00%d|r (primary)", self.performanceMetrics.auraDrops))
    DEFAULT_CHAT_FRAME:AddMessage(string_format("  Drops (Chat): |cffFFAA00%d|r (fallback)", self.performanceMetrics.chatDrops))
    DEFAULT_CHAT_FRAME:AddMessage(string_format("  Captures (Chat): |cff00FFFF%d|r (only method)", self.performanceMetrics.chatCaptures))
    DEFAULT_CHAT_FRAME:AddMessage(string_format("  Deduped Events: |cff808080%d|r (prevented double alerts)", self.performanceMetrics.dedupeBlocked))
    local totalPickups = self.performanceMetrics.auraPickups + self.performanceMetrics.chatPickups
    local totalDrops = self.performanceMetrics.auraDrops + self.performanceMetrics.chatDrops
    local auraReliability = totalPickups > 0 and (self.performanceMetrics.auraPickups / totalPickups * 100) or 0
    DEFAULT_CHAT_FRAME:AddMessage(string_format("  Aura Detection Rate: |cff00FF00%.1f%%|r", auraReliability))
end

function FlagAlerts:GetCacheSize()
    -- O(1) operation using maintained counter
    return self.cacheSize
end

function FlagAlerts:ResetMetrics()
    self.performanceMetrics = {
        eventCount = 0,
        totalProcessingTime = 0,
        cacheHits = 0,
        cacheMisses = 0,
        persistentCacheHits = 0,
        maxProcessingTime = 0,
        processingTimes = {},
        processingTimesIndex = 1,
        cacheEvictions = 0,
        classesLearned = 0,
        teamsLearned = 0,
        teamFiltered = 0,
        auraPickups = 0,
        auraDrops = 0,
        chatPickups = 0,
        chatDrops = 0,
        chatCaptures = 0,
        dedupeBlocked = 0,
        -- Combat-aware metrics (dual-pool taint system)
        eventsInCombat = 0,
        eventsOutOfCombat = 0,
        chatAlertsSuppressed = 0,
    }
    SoundAlerter:Print("[FlagAlerts] Performance metrics reset")
end

-- ========================================
-- SLASH COMMANDS (DEBUG)
-- ========================================

SLASH_SAFLAG1 = "/saflag"
SlashCmdList["SAFLAG"] = function(msg)
    if not SoundAlerter.FlagAlerts then
        SoundAlerter:Print("|cffFF0000Error: FlagAlerts module not loaded. Try /reload|r")
        return
    end

    if msg == "metrics" then
        SoundAlerter.FlagAlerts:PrintMetrics()
    elseif msg == "cache" then
        local tempSize = SoundAlerter.FlagAlerts:GetCacheSize()
        local persistSize = SoundAlerter.FlagAlerts:GetPersistentCacheSize()
        SoundAlerter:Print(string_format("[FlagAlerts] Temporary cache: %d entries | Persistent cache: %d players",
            tempSize, persistSize))
    elseif msg == "pcache" then
        local persistSize = SoundAlerter.FlagAlerts:GetPersistentCacheSize()
        SoundAlerter:Print(string_format("[FlagAlerts] Persistent cache: %d players (saved to disk)",
            persistSize))
    elseif msg == "clearcache" then
        SoundAlerter.FlagAlerts:ClearPersistentCache()
    elseif msg == "clearteams" then
        SoundAlerter.FlagAlerts:ClearTeamCache()
    elseif msg == "myteam" then
        local myTeam = SoundAlerter.FlagAlerts:GetMyTeam()
        SoundAlerter:Print(string_format("[FlagAlerts] My team: %s", myTeam or "Unknown (not in BG or buffs not loaded)"))
    elseif msg == "test" then
        SoundAlerter.FlagAlerts:ProcessFlagEvent("Testplayer has taken the flag!")
        SoundAlerter:Print("[FlagAlerts] Test event triggered")
    elseif msg == "reset" then
        SoundAlerter.FlagAlerts:ResetMetrics()
    else
        SoundAlerter:Print("FlagAlerts Commands:")
        SoundAlerter:Print("/saflag metrics - Show performance metrics")
        SoundAlerter:Print("/saflag cache - Show both cache sizes")
        SoundAlerter:Print("/saflag pcache - Show persistent cache info")
        SoundAlerter:Print("/saflag clearcache - Clear persistent cache")
        SoundAlerter:Print("/saflag clearteams - Clear team assignment cache")
        SoundAlerter:Print("/saflag myteam - Show your current team assignment")
        SoundAlerter:Print("/saflag test - Test flag pickup event")
        SoundAlerter:Print("/saflag reset - Reset performance metrics")
    end
end
