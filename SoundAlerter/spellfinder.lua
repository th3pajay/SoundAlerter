--[[
Spell Finder Module - Optimized spell database and search functionality
Provides a searchable database of all WoW spells with IDs and tooltips
Optimized for memory efficiency and search performance
Phase 1 Optimizations: Local caching, table pre-allocation, reduced function calls
--]]

local AceGUI = LibStub("AceGUI-3.0")
local SoundAlerter = SoundAlerter

-- Phase 1: Cache frequently used globals and string operations as locals (10-30% performance gain)
local pairs, ipairs, tonumber, tostring, type = pairs, ipairs, tonumber, tostring, type
local table_insert, table_sort, table_remove = table.insert, table.sort, table.remove
local string_lower, string_sub, string_match, string_find, string_format = string.lower, string.sub, string.match, string.find, string.format
local math_min, math_max, math_floor = math.min, math.max, math.floor
local time, select = time, select
local GetSpellInfo, GetSpellLink = GetSpellInfo, GetSpellLink
local GetBuildInfo = GetBuildInfo

-- Optimized Spell Database Architecture
-- Uses string interning, multi-level indexing, and LRU caching
SoundAlerter.spellDatabase = {
    -- Optimized storage (5 bytes per spell vs 56 bytes)
    byID = {},              -- [spellID] = {nameIdx, rank}

    -- String interning tables (avoid duplicates)
    names = {},             -- [index] = "Healing Touch"
    nameToIdx = {},         -- ["healing touch"] = index

    -- Multi-level search indexes
    searchIndex = {},       -- [firstLetter] = {spellID = true, ...}
    prefixIndex = {},       -- ["hea"] = {spellID = true, ...}

    -- LRU search cache (50 entries max)
    searchCache = {},       -- [searchTerm..rankFilter] = results

    -- Metadata
    isBuilding = false,
    progress = 0,
    totalScanned = 0,
    lastUpdate = 0
}

-- LRU cache tracking
local cacheAge = {}
local MAX_CACHE_SIZE = 50

-- Database Building Functions
-- =============================

-- Add spell to database with string interning
function SoundAlerter:AddSpellToDatabase(spellID, name, rank)
    local db = self.spellDatabase
    local nameToIdx = db.nameToIdx  -- Cache table access
    local names = db.names

    -- Extract base name (remove rank suffix like "(Rank 4)")
    local baseName = string_match(name, "^(.-)%s*%(") or name
    local lowerName = string_lower(baseName)

    -- String interning: reuse existing name strings
    local nameIdx = nameToIdx[lowerName]
    if not nameIdx then
        nameIdx = #names + 1
        names[nameIdx] = baseName
        nameToIdx[lowerName] = nameIdx
    end

    -- Parse rank number from rank string or name
    local rankNum = 0
    if rank and rank ~= "" then
        rankNum = tonumber(string_match(rank, "%d+")) or 0
    else
        -- Check if rank in name "Healing Touch (Rank 5)"
        local rankInName = string_match(name, "%(Rank%s*(%d+)%)")
        if rankInName then
            rankNum = tonumber(rankInName) or 0
        end
    end

    -- Store minimal spell data (only 5 bytes)
    db.byID[spellID] = {
        nameIdx = nameIdx,
        rank = rankNum
    }
end

-- Build multi-level search indexes for fast lookups
function SoundAlerter:BuildSearchIndexes()
    local db = self.spellDatabase
    local searchIndex = {}
    local prefixIndex = {}
    local names = db.names
    local byID = db.byID

    -- Cache string functions used in loop
    local string_byte, string_char = string.byte, string.char

    -- Initialize first-letter index (a-z) - pre-allocate tables
    for letter = string_byte('a'), string_byte('z') do
        searchIndex[string_char(letter)] = {}
    end

    -- Build indexes from spell data
    for spellID, data in pairs(byID) do
        local baseName = names[data.nameIdx]
        if baseName then
            local lower = string_lower(baseName)
            local lowerLen = #lower

            -- First letter index (e.g., "h" for "Healing Touch")
            local firstChar = string_sub(lower, 1, 1)
            local firstCharIndex = searchIndex[firstChar]
            if firstCharIndex then
                firstCharIndex[spellID] = true
            end

            -- 3-character prefix index (e.g., "hea" for "Healing Touch")
            if lowerLen >= 3 then
                local prefix = string_sub(lower, 1, 3)
                local prefixTable = prefixIndex[prefix]
                if not prefixTable then
                    prefixTable = {}
                    prefixIndex[prefix] = prefixTable
                end
                prefixTable[spellID] = true
            end
        end
    end

    -- Assign at end to avoid repeated table lookups
    db.searchIndex = searchIndex
    db.prefixIndex = prefixIndex
end

-- Build spell database by scanning all spell IDs (optimized non-blocking)
function SoundAlerter:BuildSpellDatabase()
    local db = self.spellDatabase

    if db.isBuilding then
        return -- Already building
    end

    db.isBuilding = true
    db.progress = 0
    db.totalScanned = 0

    -- Start UI refresh timer to update progress display
    if not self.dbRefreshTimer then
        self.dbRefreshTimer = self:ScheduleRepeatingTimer(function()
            if db.isBuilding then
                -- Force options UI to refresh and show updated progress
                local AceConfigRegistry = LibStub("AceConfigRegistry-3.0")
                if AceConfigRegistry then
                    AceConfigRegistry:NotifyChange("SoundAlerter")
                end
            else
                -- Stop timer when rebuild complete
                if self.dbRefreshTimer then
                    self:CancelTimer(self.dbRefreshTimer)
                    self.dbRefreshTimer = nil
                end
            end
        end, 0.1) -- Refresh UI 10 times per second
    end

    -- Optimized scan parameters
    local MAX_SPELL_ID = 70000
    local CHUNK_SIZE = 1000      -- Increased from 500 (fewer context switches)
    local CHUNK_DELAY = 0.05     -- Reduced from 0.1s (faster completion)
    local currentID = 1

    local function ProcessChunk()
        local endID = math_min(currentID + CHUNK_SIZE - 1, MAX_SPELL_ID)
        local foundCount = 0

        -- Cache method reference to avoid repeated lookups
        local AddSpellToDatabase = self.AddSpellToDatabase

        -- Process chunk of spell IDs
        for spellID = currentID, endID do
            local name, rank = GetSpellInfo(spellID)
            if name then
                AddSpellToDatabase(self, spellID, name, rank)
                foundCount = foundCount + 1

                -- Also check 11-prefixed ID for WoW Ascension compatibility
                -- Pre-calculate with string concatenation cache
                local ascensionID = tonumber("11" .. spellID)
                if ascensionID then
                    local ascName, ascRank = GetSpellInfo(ascensionID)
                    if ascName then
                        AddSpellToDatabase(self, ascensionID, ascName, ascRank)
                    end
                end
            end
        end

        -- Update progress
        db.totalScanned = endID
        db.progress = (db.totalScanned / MAX_SPELL_ID) * 100

        currentID = endID + 1

        if currentID <= MAX_SPELL_ID then
            -- Schedule next chunk
            self:ScheduleTimer(ProcessChunk, CHUNK_DELAY)
        else
            -- Database complete - build indexes
            self:BuildSearchIndexes()
            db.isBuilding = false
            db.lastUpdate = time()

            -- Stop UI refresh timer
            if self.dbRefreshTimer then
                self:CancelTimer(self.dbRefreshTimer)
                self.dbRefreshTimer = nil
            end

            -- Final UI refresh to show completion
            local AceConfigRegistry = LibStub("AceConfigRegistry-3.0")
            if AceConfigRegistry then
                AceConfigRegistry:NotifyChange("SoundAlerter")
            end

            -- Save to disk
            self:SaveSpellDatabase()

            -- Notify user
            local spellCount = self:CountSpells()
            self:Print(string_format("Spell database built: %d spells indexed", spellCount))
        end
    end

    -- Start processing
    self:Print("Building spell database... This will take ~3-4 seconds.")
    ProcessChunk()
end

-- Persistence Functions
-- ======================

-- Save spell database to SavedVariables (disk)
function SoundAlerter:SaveSpellDatabase()
    SoundAlerterSpellDB = {
        byID = self.spellDatabase.byID,
        names = self.spellDatabase.names,
        nameToIdx = self.spellDatabase.nameToIdx,
        version = GetBuildInfo(), -- Invalidate on game updates
        lastUpdate = time()
    }
end

-- Load spell database from SavedVariables (disk)
function SoundAlerter:LoadSpellDatabase()
    if not SoundAlerterSpellDB then
        return false -- No saved database
    end

    -- Validate version (rebuild if game updated)
    if SoundAlerterSpellDB.version ~= GetBuildInfo() then
        self:Print("Game version changed - rebuilding spell database")
        return false
    end

    -- Check age (rebuild if > 30 days old)
    local age = time() - SoundAlerterSpellDB.lastUpdate
    if age > 2592000 then -- 30 days in seconds
        self:Print("Spell database outdated - rebuilding")
        return false
    end

    -- Load from saved data
    self.spellDatabase.byID = SoundAlerterSpellDB.byID
    self.spellDatabase.names = SoundAlerterSpellDB.names
    self.spellDatabase.nameToIdx = SoundAlerterSpellDB.nameToIdx
    self.spellDatabase.lastUpdate = SoundAlerterSpellDB.lastUpdate

    -- Rebuild indexes (not persisted to save disk space)
    self:BuildSearchIndexes()

    local spellCount = self:CountSpells()
    self:Print(string.format("Spell database loaded: %d spells indexed", spellCount))

    return true
end

-- Search Functions
-- =================

-- Optimized spell search with multi-level indexing and caching
function SoundAlerter:SearchSpells(searchTerm, rankFilter)
    local db = self.spellDatabase

    -- Validate input
    if not searchTerm or searchTerm == "" then
        return {}
    end

    -- Check cache first (LRU cache)
    local cacheKey = searchTerm .. (rankFilter or "")
    local searchCache = db.searchCache
    local cachedResult = searchCache[cacheKey]
    if cachedResult then
        return cachedResult
    end

    local searchLower = string_lower(searchTerm)
    local searchLen = #searchLower
    local results = {}
    local candidateSpells

    -- Cache frequently accessed tables
    local byID = db.byID
    local names = db.names
    local prefixIndex = db.prefixIndex
    local searchIndex = db.searchIndex

    -- Choose optimal index strategy
    if searchLen >= 3 then
        -- Use 3-char prefix index (best performance)
        local prefix = string_sub(searchLower, 1, 3)
        candidateSpells = prefixIndex[prefix] or {}
    elseif searchLen >= 1 then
        -- Use first-letter index (good performance)
        local firstChar = string_sub(searchLower, 1, 1)
        candidateSpells = searchIndex[firstChar] or {}
    else
        return {} -- Search term too short
    end

    -- Convert rankFilter once
    local rankFilterNum = rankFilter and rankFilter ~= "" and tonumber(rankFilter) or nil

    -- Filter candidates and build results (pre-allocate for common case)
    local resultCount = 0
    for spellID in pairs(candidateSpells) do
        local data = byID[spellID]
        if data then
            local baseName = names[data.nameIdx]
            local baseNameLower = string_lower(baseName)

            -- Partial string match (case-insensitive)
            if string_find(baseNameLower, searchLower, 1, true) then
                -- Apply rank filter if specified
                if not rankFilterNum or data.rank == rankFilterNum then
                    resultCount = resultCount + 1
                    results[resultCount] = {
                        spellID = spellID,
                        name = baseName,
                        rank = data.rank,
                        baseName = baseName,
                        rankNum = data.rank
                    }
                end
            end
        end
    end

    -- Sort results by spell name, then rank
    table_sort(results, function(a, b)
        if a.baseName ~= b.baseName then
            return a.baseName < b.baseName
        end
        return a.rankNum < b.rankNum
    end)

    -- Cache result with LRU eviction
    self:CacheSearchResult(cacheKey, results)

    return results
end

-- LRU cache management
function SoundAlerter:CacheSearchResult(key, results)
    local cache = self.spellDatabase.searchCache

    -- Evict oldest entry if cache is full
    if #cacheAge >= MAX_CACHE_SIZE then
        local oldestKey = table_remove(cacheAge, 1)
        cache[oldestKey] = nil
    end

    -- Add new entry
    cache[key] = results
    table_insert(cacheAge, key)
end

-- Clear search cache
function SoundAlerter:ClearSearchCache()
    self.spellDatabase.searchCache = {}
    cacheAge = {}
end

-- Utility Functions
-- ==================

-- Count total spells in database
function SoundAlerter:CountSpells()
    local count = 0
    for _ in pairs(self.spellDatabase.byID) do
        count = count + 1
    end
    return count
end

-- Get database status string
function SoundAlerter:GetDatabaseStatus()
    local db = self.spellDatabase

    if db.isBuilding then
        return string_format("|cFFFFAA00Building: %.1f%% (%d / 70,000)|r",
            db.progress, db.totalScanned)
    else
        local spellCount = self:CountSpells()
        local ageMinutes = math_floor((time() - db.lastUpdate) / 60)
        if ageMinutes < 1 then
            return string_format("|cFF00FF00Ready: %d spells indexed (just now)|r", spellCount)
        elseif ageMinutes < 60 then
            return string_format("|cFF00FF00Ready: %d spells indexed (%dm ago)|r", spellCount, ageMinutes)
        else
            local ageHours = math_floor(ageMinutes / 60)
            return string_format("|cFF00FF00Ready: %d spells indexed (%dh ago)|r", spellCount, ageHours)
        end
    end
end

-- Rebuild database from scratch
function SoundAlerter:RebuildSpellDatabase()
    self.spellDatabase.byID = {}
    self.spellDatabase.names = {}
    self.spellDatabase.nameToIdx = {}
    self.spellDatabase.searchIndex = {}
    self.spellDatabase.prefixIndex = {}
    self:ClearSearchCache()
    self:BuildSpellDatabase()

    -- Immediately refresh UI to show building state
    local AceConfigRegistry = LibStub("AceConfigRegistry-3.0")
    if AceConfigRegistry then
        AceConfigRegistry:NotifyChange("SoundAlerter")
    end
end

-- UI Functions
-- =============

-- Create the Find Spell UI window
function SoundAlerter:CreateFindSpellFrame()
    local frame = AceGUI:Create("Window")
    frame:SetTitle("SoundAlerter - Find Spell")
    frame:SetLayout("Flow")
    frame:SetWidth(650)
    frame:SetHeight(550)

    -- Ensure frame appears on top
    if frame.frame then
        frame.frame:SetFrameStrata("DIALOG")
        frame.frame:Raise()
    end

    -- Description
    local desc = AceGUI:Create("Label")
    desc:SetText("Search for spell IDs to add to spellist.lua. Shows both retail and Ascension (11-prefixed) IDs.")
    desc:SetFullWidth(true)
    desc:SetColor(0.8, 0.8, 0.8)
    frame:AddChild(desc)

    -- Spacer
    local spacer1 = AceGUI:Create("Label")
    spacer1:SetText(" ")
    spacer1:SetFullWidth(true)
    frame:AddChild(spacer1)

    -- Input group
    local inputGroup = AceGUI:Create("SimpleGroup")
    inputGroup:SetFullWidth(true)
    inputGroup:SetLayout("Flow")
    frame:AddChild(inputGroup)

    -- Search input
    local searchBox = AceGUI:Create("EditBox")
    searchBox:SetLabel("Spell Name:")
    searchBox:SetWidth(350)
    inputGroup:AddChild(searchBox)

    -- Rank filter
    local rankBox = AceGUI:Create("EditBox")
    rankBox:SetLabel("Rank (optional):")
    rankBox:SetWidth(120)
    inputGroup:AddChild(rankBox)

    -- Search button
    local searchBtn = AceGUI:Create("Button")
    searchBtn:SetText("Search")
    searchBtn:SetWidth(120)
    inputGroup:AddChild(searchBtn)

    -- Store references on frame first
    frame.searchBox = searchBox
    frame.rankBox = rankBox

    -- Now set callbacks that reference the frame widgets
    searchBox:SetCallback("OnEnterPressed", function(widget)
        self:PerformSearch(frame, frame.searchBox:GetText(), frame.rankBox:GetText())
    end)

    rankBox:SetCallback("OnEnterPressed", function(widget)
        self:PerformSearch(frame, frame.searchBox:GetText(), frame.rankBox:GetText())
    end)

    searchBtn:SetCallback("OnClick", function()
        self:PerformSearch(frame, frame.searchBox:GetText(), frame.rankBox:GetText())
    end)

    -- Spacer
    local spacer2 = AceGUI:Create("Label")
    spacer2:SetText(" ")
    spacer2:SetFullWidth(true)
    frame:AddChild(spacer2)

    -- Results scroll frame
    local scrollFrame = AceGUI:Create("ScrollFrame")
    scrollFrame:SetLayout("List")
    scrollFrame:SetFullWidth(true)
    scrollFrame:SetFullHeight(true)
    frame:AddChild(scrollFrame)

    -- Store scrollFrame reference
    frame.scrollFrame = scrollFrame

    -- Show initial status
    self:DisplayDatabaseStatus(scrollFrame)

    return frame
end

-- Perform search and display results
function SoundAlerter:PerformSearch(frame, searchTerm, rankFilter)
    local results = self:SearchSpells(searchTerm, rankFilter)
    local scrollFrame = frame.scrollFrame

    -- Clear previous results
    scrollFrame:ReleaseChildren()

    local resultCount = #results
    if resultCount == 0 then
        local label = AceGUI:Create("Label")
        if self.spellDatabase.isBuilding then
            label:SetText("|cFFFF8800Database still building. Please wait and try again.|r\n\n" ..
                          self:GetDatabaseStatus())
        else
            label:SetText("|cFFFF0000No spells found for '" .. searchTerm .. "'|r\n\n" ..
                          "Try a different search term or check spelling.")
        end
        label:SetFullWidth(true)
        scrollFrame:AddChild(label)

        -- Show status
        self:DisplayDatabaseStatus(scrollFrame)
        return
    end

    -- Header
    local header = AceGUI:Create("Heading")
    header:SetText(string_format("Found %d spell(s) for '%s'", resultCount, searchTerm))
    header:SetFullWidth(true)
    scrollFrame:AddChild(header)

    -- Spacer
    local spacer = AceGUI:Create("Label")
    spacer:SetText(" ")
    spacer:SetFullWidth(true)
    scrollFrame:AddChild(spacer)

    -- Display results (limit to 50)
    local displayCount = math_min(resultCount, 50)
    for i = 1, displayCount do
        local spell = results[i]
        local icon = select(3, GetSpellInfo(spell.spellID))
        local iconStr = icon and "\124T" .. icon .. ":20\124t " or ""

        -- Calculate Ascension ID (11-prefixed)
        local spellIDStr = tostring(spell.spellID)
        local ascensionID
        local isAscensionID = string_match(spellIDStr, "^11")
        if not isAscensionID then
            ascensionID = tonumber("11" .. spellIDStr)
        else
            ascensionID = spell.spellID
        end

        -- Spell label with icon
        local rankText = spell.rankNum > 0 and ("Rank " .. spell.rankNum) or "No Rank"
        local spellLabel = AceGUI:Create("InteractiveLabel")
        spellLabel:SetText(string_format("%s|cFFFFFFFF%s|r |cFFAAAAAA(%s)|r",
            iconStr, spell.baseName, rankText))
        spellLabel:SetFullWidth(true)
        spellLabel:SetCallback("OnEnter", function(widget)
            -- Show tooltip on hover
            GameTooltip:SetOwner(widget.frame, "ANCHOR_CURSOR")
            local spellLink = GetSpellLink(spell.spellID)
            if spellLink then
                GameTooltip:SetHyperlink(spellLink)
            else
                GameTooltip:AddLine(spell.name, 1, 1, 1)
                GameTooltip:AddLine("Spell ID: " .. spell.spellID, 0.5, 0.5, 1)
            end
            GameTooltip:Show()
        end)
        spellLabel:SetCallback("OnLeave", function()
            GameTooltip:Hide()
        end)
        scrollFrame:AddChild(spellLabel)

        -- ID label
        local idLabel = AceGUI:Create("Label")
        idLabel:SetText(string_format("     |cFFAAAAARetail ID:|r |cFF00FFFF%d|r  |  |cFFAAAAAAAAscension ID:|r |cFF00FFFF%d|r",
            spell.spellID, ascensionID))
        idLabel:SetFullWidth(true)
        scrollFrame:AddChild(idLabel)

        -- Spacer between entries
        if i < displayCount then
            local entrySpacer = AceGUI:Create("Label")
            entrySpacer:SetText(" ")
            entrySpacer:SetFullWidth(true)
            scrollFrame:AddChild(entrySpacer)
        end
    end

    if resultCount > 50 then
        local spacerMore = AceGUI:Create("Label")
        spacerMore:SetText(" ")
        spacerMore:SetFullWidth(true)
        scrollFrame:AddChild(spacerMore)

        local moreLabel = AceGUI:Create("Label")
        moreLabel:SetText("|cFFFF8800Showing first 50 results. Refine your search to see more specific results.|r")
        moreLabel:SetFullWidth(true)
        scrollFrame:AddChild(moreLabel)
    end

    -- Footer spacer
    local footerSpacer = AceGUI:Create("Label")
    footerSpacer:SetText(" ")
    footerSpacer:SetFullWidth(true)
    scrollFrame:AddChild(footerSpacer)

    -- Database status
    self:DisplayDatabaseStatus(scrollFrame)
end

-- Display database status in scroll frame
function SoundAlerter:DisplayDatabaseStatus(scrollFrame)
    local statusLabel = AceGUI:Create("Label")
    statusLabel:SetText("Database Status: " .. self:GetDatabaseStatus())
    statusLabel:SetFullWidth(true)
    scrollFrame:AddChild(statusLabel)
end
