-- ================================================================================
-- Casting Bars - Player, Target, and Focus casting bars
-- ================================================================================
-- Author: th3pajay
-- WoW Version: 3.3.5a (WotLK) - Ascension
-- Purpose: Display casting/channeling progress for player, target, and focus
-- ================================================================================
-- NOTE: This module stores functions in a global temporary variable.
--       SoundAlerter.lua's OnInitialize() will attach it to the addon.
-- ================================================================================
-- REFACTORED: Fixed visibility, spell name extraction, time updates, and textures
-- ================================================================================

local CastingBars = {}

-- ================================================================================
-- CONSTANTS
-- ================================================================================

local BAR_WIDTH = 280
local BAR_HEIGHT = 24
local TEXT_UPDATE_THROTTLE = 0.016  -- ~60 FPS for smooth millisecond updates
local BOUNCE_DURATION = 0.3  -- Duration of bounce effect in seconds

-- ================================================================================
-- INITIALIZATION
-- ================================================================================

function CastingBars:Initialize()
	-- Get addon reference (will be available after OnInitialize attaches this module)
	local SoundAlerter = LibStub("AceAddon-3.0"):GetAddon("SoundAlerter")
	if not SoundAlerter then
		error("CastingBars:Initialize() called before addon is ready")
		return
	end

	self.addon = SoundAlerter
	self.db = self.addon.db1.profile.castingBars
	self.initialized = false

	-- Cached values to detect changes
	self.lastUpdate = {
		playerText = 0,
		targetText = 0,
		focusText = 0,
	}

	-- Bounce animation state
	self.bounceState = {
		player = { active = false, startTime = 0 },
		target = { active = false, startTime = 0 },
		focus = { active = false, startTime = 0 },
	}

	-- Casting state - tracks active casts/channels
	self.castingState = {
		player = { casting = false, channeling = false, startTime = 0, endTime = 0, spellName = "" },
		target = { casting = false, channeling = false, startTime = 0, endTime = 0, spellName = "" },
		focus = { casting = false, channeling = false, startTime = 0, endTime = 0, spellName = "" },
	}

	-- Track if texture has been applied to prevent re-application
	self.textureApplied = false

	-- Screen dimensions (cached)
	self.screenWidth, self.screenHeight = UIParent:GetSize()

	-- Always create all frames (show/hide based on enabled state)
	self:CreatePlayerFrame()
	self:CreateTargetFrame()
	self:CreateFocusFrame()

	-- Register events
	self:RegisterEvents()

	-- Apply settings (will show/hide based on enabled state)
	self:LoadSettings()

	self.initialized = true
end

-- ================================================================================
-- POSITION SAVE FUNCTIONS
-- ================================================================================

function CastingBars:SavePlayerPosition()
	self.addon.BarUtils:SavePosition(self.playerFrame, self.addon.db1.profile.castingBars.player, "")
end

function CastingBars:SaveTargetPosition()
	self.addon.BarUtils:SavePosition(self.targetFrame, self.addon.db1.profile.castingBars.target, "")
end

function CastingBars:SaveFocusPosition()
	self.addon.BarUtils:SavePosition(self.focusFrame, self.addon.db1.profile.castingBars.focus, "")
end

-- ================================================================================
-- FRAME CREATION - PLAYER
-- ================================================================================

function CastingBars:CreatePlayerFrame()
	self.playerFrame = CreateFrame("Frame", "SoundAlerterCastingBar_Player", UIParent)
	self.playerFrame:SetSize(BAR_WIDTH + 20, BAR_HEIGHT + 30)
	self.playerFrame:SetFrameStrata("MEDIUM")
	self.playerFrame:SetFrameLevel(10)
	self.playerFrame:SetPoint("CENTER", UIParent, "CENTER", 0, -200)

	-- Make draggable using BarUtils
	self.addon.BarUtils:MakeDraggable(self.playerFrame, self.db, function()
		self:SavePlayerPosition()
	end)

	-- Title text
	self.playerTitle = self.playerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	self.playerTitle:SetPoint("BOTTOM", self.playerFrame, "TOP", 0, 2)
	self.playerTitle:SetText("Player Cast")
	self.playerTitle:SetTextColor(0.8, 0.8, 0.8, 1)

	-- Casting bar
	self.playerBar = CreateFrame("StatusBar", nil, self.playerFrame)
	self.playerBar:SetSize(BAR_WIDTH, BAR_HEIGHT)
	self.playerBar:SetPoint("CENTER")
	self.playerBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
	self.playerBar:GetStatusBarTexture():SetHorizTile(false)
	self.playerBar:SetMinMaxValues(0, 1)
	self.playerBar:SetValue(0)

	-- Background
	self.playerBar.bg = self.playerBar:CreateTexture(nil, "BACKGROUND")
	self.playerBar.bg:SetAllPoints()
	self.playerBar.bg:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
	self.playerBar.bg:SetVertexColor(0.1, 0.1, 0.1, 0.5)

	-- Create backdrop using BarUtils
	self.addon.BarUtils:CreateBackdrop(self.playerBar, 0.5, 0.5, 0.5, 1)

	-- Spell name text
	self.playerSpellText = self.playerBar:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	self.playerSpellText:SetPoint("CENTER", self.playerBar, "CENTER", 0, 0)
	self.playerSpellText:SetText("")

	-- Time text
	self.playerTimeText = self.playerBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	self.playerTimeText:SetPoint("RIGHT", self.playerBar, "RIGHT", -5, 0)
	self.playerTimeText:SetText("")

	-- Spell icon (optional, shown to left of bar)
	self.playerIcon = self.playerFrame:CreateTexture(nil, "ARTWORK")
	self.playerIcon:SetSize(BAR_HEIGHT, BAR_HEIGHT)
	self.playerIcon:SetPoint("RIGHT", self.playerBar, "LEFT", -4, 0)
	self.playerIcon:SetTexCoord(0.07, 0.93, 0.07, 0.93)  -- Crop edges for cleaner look
	self.playerIcon:Hide()

	-- Latency shadow (optional, shown at right end of bar)
	self.playerLatency = self.playerBar:CreateTexture(nil, "BORDER")
	self.playerLatency:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
	self.playerLatency:SetVertexColor(1, 0, 0, 0.6)  -- Red semi-transparent
	self.playerLatency:SetPoint("RIGHT", self.playerBar, "RIGHT", 0, 0)
	self.playerLatency:SetHeight(BAR_HEIGHT)
	self.playerLatency:SetWidth(1)  -- Will be updated dynamically
	self.playerLatency:Hide()

	-- Start hidden - will be shown based on lock state and casting
	self.playerFrame:Hide()
end

-- ================================================================================
-- FRAME CREATION - TARGET
-- ================================================================================

function CastingBars:CreateTargetFrame()
	self.targetFrame = CreateFrame("Frame", "SoundAlerterCastingBar_Target", UIParent)
	self.targetFrame:SetSize(BAR_WIDTH + 20, BAR_HEIGHT + 30)
	self.targetFrame:SetFrameStrata("MEDIUM")
	self.targetFrame:SetFrameLevel(10)
	self.targetFrame:SetPoint("CENTER", UIParent, "CENTER", 0, -230)

	-- Make draggable using BarUtils
	self.addon.BarUtils:MakeDraggable(self.targetFrame, self.db, function()
		self:SaveTargetPosition()
	end)

	-- Title text
	self.targetTitle = self.targetFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	self.targetTitle:SetPoint("BOTTOM", self.targetFrame, "TOP", 0, 2)
	self.targetTitle:SetText("Target Cast")
	self.targetTitle:SetTextColor(0.8, 0.8, 0.8, 1)

	-- Casting bar
	self.targetBar = CreateFrame("StatusBar", nil, self.targetFrame)
	self.targetBar:SetSize(BAR_WIDTH, BAR_HEIGHT)
	self.targetBar:SetPoint("CENTER")
	self.targetBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
	self.targetBar:GetStatusBarTexture():SetHorizTile(false)
	self.targetBar:SetMinMaxValues(0, 1)
	self.targetBar:SetValue(0)

	-- Background
	self.targetBar.bg = self.targetBar:CreateTexture(nil, "BACKGROUND")
	self.targetBar.bg:SetAllPoints()
	self.targetBar.bg:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
	self.targetBar.bg:SetVertexColor(0.1, 0.1, 0.1, 0.5)

	-- Create backdrop using BarUtils
	self.addon.BarUtils:CreateBackdrop(self.targetBar, 0.5, 0.5, 0.5, 1)

	-- Spell name text
	self.targetSpellText = self.targetBar:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	self.targetSpellText:SetPoint("CENTER", self.targetBar, "CENTER", 0, 0)
	self.targetSpellText:SetText("")

	-- Time text
	self.targetTimeText = self.targetBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	self.targetTimeText:SetPoint("RIGHT", self.targetBar, "RIGHT", -5, 0)
	self.targetTimeText:SetText("")

	-- Spell icon (optional, shown to left of bar)
	self.targetIcon = self.targetFrame:CreateTexture(nil, "ARTWORK")
	self.targetIcon:SetSize(BAR_HEIGHT, BAR_HEIGHT)
	self.targetIcon:SetPoint("RIGHT", self.targetBar, "LEFT", -4, 0)
	self.targetIcon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	self.targetIcon:Hide()

	-- Latency shadow (optional, shown at right end of bar)
	self.targetLatency = self.targetBar:CreateTexture(nil, "BORDER")
	self.targetLatency:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
	self.targetLatency:SetVertexColor(1, 0, 0, 0.6)
	self.targetLatency:SetPoint("RIGHT", self.targetBar, "RIGHT", 0, 0)
	self.targetLatency:SetHeight(BAR_HEIGHT)
	self.targetLatency:SetWidth(1)
	self.targetLatency:Hide()

	-- Start hidden
	self.targetFrame:Hide()
end

-- ================================================================================
-- FRAME CREATION - FOCUS
-- ================================================================================

function CastingBars:CreateFocusFrame()
	self.focusFrame = CreateFrame("Frame", "SoundAlerterCastingBar_Focus", UIParent)
	self.focusFrame:SetSize(BAR_WIDTH + 20, BAR_HEIGHT + 30)
	self.focusFrame:SetFrameStrata("MEDIUM")
	self.focusFrame:SetFrameLevel(10)
	self.focusFrame:SetPoint("CENTER", UIParent, "CENTER", 0, -260)

	-- Make draggable using BarUtils
	self.addon.BarUtils:MakeDraggable(self.focusFrame, self.db, function()
		self:SaveFocusPosition()
	end)

	-- Title text
	self.focusTitle = self.focusFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	self.focusTitle:SetPoint("BOTTOM", self.focusFrame, "TOP", 0, 2)
	self.focusTitle:SetText("Focus Cast")
	self.focusTitle:SetTextColor(0.8, 0.8, 0.8, 1)

	-- Casting bar
	self.focusBar = CreateFrame("StatusBar", nil, self.focusFrame)
	self.focusBar:SetSize(BAR_WIDTH, BAR_HEIGHT)
	self.focusBar:SetPoint("CENTER")
	self.focusBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
	self.focusBar:GetStatusBarTexture():SetHorizTile(false)
	self.focusBar:SetMinMaxValues(0, 1)
	self.focusBar:SetValue(0)

	-- Background
	self.focusBar.bg = self.focusBar:CreateTexture(nil, "BACKGROUND")
	self.focusBar.bg:SetAllPoints()
	self.focusBar.bg:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
	self.focusBar.bg:SetVertexColor(0.1, 0.1, 0.1, 0.5)

	-- Create backdrop using BarUtils
	self.addon.BarUtils:CreateBackdrop(self.focusBar, 0.5, 0.5, 0.5, 1)

	-- Spell name text
	self.focusSpellText = self.focusBar:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	self.focusSpellText:SetPoint("CENTER", self.focusBar, "CENTER", 0, 0)
	self.focusSpellText:SetText("")

	-- Time text
	self.focusTimeText = self.focusBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	self.focusTimeText:SetPoint("RIGHT", self.focusBar, "RIGHT", -5, 0)
	self.focusTimeText:SetText("")

	-- Spell icon (optional, shown to left of bar)
	self.focusIcon = self.focusFrame:CreateTexture(nil, "ARTWORK")
	self.focusIcon:SetSize(BAR_HEIGHT, BAR_HEIGHT)
	self.focusIcon:SetPoint("RIGHT", self.focusBar, "LEFT", -4, 0)
	self.focusIcon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	self.focusIcon:Hide()

	-- Latency shadow (optional, shown at right end of bar)
	self.focusLatency = self.focusBar:CreateTexture(nil, "BORDER")
	self.focusLatency:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
	self.focusLatency:SetVertexColor(1, 0, 0, 0.6)
	self.focusLatency:SetPoint("RIGHT", self.focusBar, "RIGHT", 0, 0)
	self.focusLatency:SetHeight(BAR_HEIGHT)
	self.focusLatency:SetWidth(1)
	self.focusLatency:Hide()

	-- Start hidden
	self.focusFrame:Hide()
end

-- ================================================================================
-- EVENT REGISTRATION
-- ================================================================================

function CastingBars:RegisterEvents()
	-- Create event frame
	self.eventFrame = CreateFrame("Frame")

	-- Register all casting events (work for player, target, and focus)
	self.eventFrame:RegisterEvent("UNIT_SPELLCAST_START")
	self.eventFrame:RegisterEvent("UNIT_SPELLCAST_STOP")
	self.eventFrame:RegisterEvent("UNIT_SPELLCAST_FAILED")
	self.eventFrame:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
	self.eventFrame:RegisterEvent("UNIT_SPELLCAST_DELAYED")
	self.eventFrame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
	self.eventFrame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")
	self.eventFrame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_UPDATE")
	self.eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
	self.eventFrame:RegisterEvent("PLAYER_FOCUS_CHANGED")

	self.eventFrame:SetScript("OnEvent", function(frame, event, ...)
		self:OnEvent(event, ...)
	end)

	-- OnUpdate for progress and animations - runs every frame
	self.eventFrame:SetScript("OnUpdate", function(frame, elapsed)
		self:OnUpdate(elapsed)
	end)
end

-- ================================================================================
-- EVENT HANDLERS
-- ================================================================================

function CastingBars:OnEvent(event, unit, ...)
	-- Handle target/focus change events first (these don't have a unit parameter)
	if event == "PLAYER_TARGET_CHANGED" then
		self:OnTargetChanged()
		return
	elseif event == "PLAYER_FOCUS_CHANGED" then
		self:OnFocusChanged()
		return
	end

	-- Only handle player, target, focus for UNIT_SPELLCAST events
	if unit ~= "player" and unit ~= "target" and unit ~= "focus" then
		return
	end

	if event == "UNIT_SPELLCAST_START" then
		self:OnCastStart(unit)
	elseif event == "UNIT_SPELLCAST_STOP" then
		self:OnCastStop(unit)
	elseif event == "UNIT_SPELLCAST_FAILED" then
		self:OnCastStop(unit)
	elseif event == "UNIT_SPELLCAST_INTERRUPTED" then
		self:OnCastStop(unit)
	elseif event == "UNIT_SPELLCAST_DELAYED" then
		self:OnCastDelay(unit)
	elseif event == "UNIT_SPELLCAST_CHANNEL_START" then
		self:OnChannelStart(unit)
	elseif event == "UNIT_SPELLCAST_CHANNEL_STOP" then
		self:OnCastStop(unit)
	elseif event == "UNIT_SPELLCAST_CHANNEL_UPDATE" then
		self:OnChannelUpdate(unit)
	end
end

-- ================================================================================
-- CAST START HANDLER
-- WoW 3.3.5 UnitCastingInfo returns:
-- name, nameSubtext, text, texture, startTime, endTime, isTradeSkill, castID, notInterruptible
-- - name: The actual spell name (e.g., "Frostbolt")
-- - nameSubtext: The rank/subtext (e.g., "Rank 1")
-- - text: Same as name in most cases
-- ================================================================================

function CastingBars:OnCastStart(unit)
	-- UnitCastingInfo returns: name, nameSubtext, text, texture, startTime, endTime, ...
	local spellName, nameSubtext, text, texture, startTime, endTime = UnitCastingInfo(unit)

	-- Validate we have cast info
	if not spellName then return end

	local state, frame, bar, spellText, timeText
	if unit == "player" and self.playerFrame then
		if not self.db.player.enabled then return end
		state = self.castingState.player
		frame = self.playerFrame
		bar = self.playerBar
		spellText = self.playerSpellText
		timeText = self.playerTimeText
	elseif unit == "target" and self.targetFrame then
		if not self.db.target.enabled then return end
		state = self.castingState.target
		frame = self.targetFrame
		bar = self.targetBar
		spellText = self.targetSpellText
		timeText = self.targetTimeText
	elseif unit == "focus" and self.focusFrame then
		if not self.db.focus.enabled then return end
		state = self.castingState.focus
		frame = self.focusFrame
		bar = self.focusBar
		spellText = self.focusSpellText
		timeText = self.focusTimeText
	else
		return
	end

	-- Convert startTime/endTime from milliseconds to seconds
	-- WoW returns these in milliseconds since game start
	local startTimeSec = (startTime or 0) / 1000
	local endTimeSec = (endTime or 0) / 1000

	-- Validate times
	local now = GetTime()
	if startTimeSec <= 0 then startTimeSec = now end
	if endTimeSec <= startTimeSec then endTimeSec = now + 1 end

	-- Update casting state
	state.casting = true
	state.channeling = false
	state.startTime = startTimeSec
	state.endTime = endTimeSec
	state.spellName = spellName  -- Use the actual spell name (first return value)

	-- Set initial bar state
	bar:SetValue(0)
	bar:SetStatusBarColor(0.2, 0.5, 1.0, 1)  -- Blue for casting

	-- Set spell name immediately
	spellText:SetText(spellName)

	-- Set initial time
	local remaining = endTimeSec - now
	timeText:SetText(self:FormatTime(remaining))

	-- Start bounce animation
	self:StartBounce(unit)

	-- Set spell icon if enabled
	local icon
	if unit == "player" then
		icon = self.playerIcon
	elseif unit == "target" then
		icon = self.targetIcon
	elseif unit == "focus" then
		icon = self.focusIcon
	end

	if icon and self.db.showSpellIcon and texture then
		icon:SetTexture(texture)
		icon:Show()
	elseif icon then
		icon:Hide()
	end

	-- Set latency shadow if enabled (only for player)
	if unit == "player" and self.playerLatency and self.db.showLatency then
		local down, up, lagHome, lagWorld = GetNetStats()
		local latencyMS = lagWorld or 50  -- Default to 50ms if nil
		local latencySeconds = latencyMS / 1000  -- Convert ms to seconds
		local castDuration = endTimeSec - startTimeSec

		if castDuration > 0 and latencyMS > 0 then
			-- Calculate width based on latency as percentage of cast time
			local latencyPercent = latencySeconds / castDuration
			local barWidth = self.playerBar:GetWidth()
			local latencyWidth = barWidth * latencyPercent

			-- Ensure minimum visible width of 10 pixels, cap at 50% of bar
			latencyWidth = math.max(10, math.min(latencyWidth, barWidth * 0.5))

			self.playerLatency:SetWidth(latencyWidth)
			self.playerLatency:Show()
		else
			self.playerLatency:Hide()
		end
	elseif unit == "player" and self.playerLatency then
		self.playerLatency:Hide()
	end

	-- SHOW the frame - this is an active cast
	frame:Show()
end

-- ================================================================================
-- CHANNEL START HANDLER
-- WoW 3.3.5 UnitChannelInfo returns same format as UnitCastingInfo
-- ================================================================================

function CastingBars:OnChannelStart(unit)
	-- UnitChannelInfo returns: name, nameSubtext, text, texture, startTime, endTime, ...
	local spellName, nameSubtext, text, texture, startTime, endTime = UnitChannelInfo(unit)

	-- Validate we have channel info
	if not spellName then return end

	local state, frame, bar, spellText, timeText
	if unit == "player" and self.playerFrame then
		if not self.db.player.enabled then return end
		state = self.castingState.player
		frame = self.playerFrame
		bar = self.playerBar
		spellText = self.playerSpellText
		timeText = self.playerTimeText
	elseif unit == "target" and self.targetFrame then
		if not self.db.target.enabled then return end
		state = self.castingState.target
		frame = self.targetFrame
		bar = self.targetBar
		spellText = self.targetSpellText
		timeText = self.targetTimeText
	elseif unit == "focus" and self.focusFrame then
		if not self.db.focus.enabled then return end
		state = self.castingState.focus
		frame = self.focusFrame
		bar = self.focusBar
		spellText = self.focusSpellText
		timeText = self.focusTimeText
	else
		return
	end

	-- Convert startTime/endTime from milliseconds to seconds
	local startTimeSec = (startTime or 0) / 1000
	local endTimeSec = (endTime or 0) / 1000

	-- Validate times
	local now = GetTime()
	if startTimeSec <= 0 then startTimeSec = now end
	if endTimeSec <= startTimeSec then endTimeSec = now + 1 end

	-- Update casting state
	state.casting = false
	state.channeling = true
	state.startTime = startTimeSec
	state.endTime = endTimeSec
	state.spellName = spellName  -- Use the actual spell name

	-- Set initial bar state - channels start full and drain
	bar:SetValue(1)
	bar:SetStatusBarColor(0.7, 0.3, 1.0, 1)  -- Purple for channeling

	-- Set spell name immediately
	spellText:SetText(spellName)

	-- Set initial time
	local remaining = endTimeSec - now
	timeText:SetText(self:FormatTime(remaining))

	-- Start bounce animation
	self:StartBounce(unit)

	-- Set spell icon if enabled
	local icon
	if unit == "player" then
		icon = self.playerIcon
	elseif unit == "target" then
		icon = self.targetIcon
	elseif unit == "focus" then
		icon = self.focusIcon
	end

	if icon and self.db.showSpellIcon and texture then
		icon:SetTexture(texture)
		icon:Show()
	elseif icon then
		icon:Hide()
	end

	-- Set latency shadow if enabled (only for player)
	if unit == "player" and self.playerLatency and self.db.showLatency then
		local down, up, lagHome, lagWorld = GetNetStats()
		local latencyMS = lagWorld or 50  -- Default to 50ms if nil
		local latencySeconds = latencyMS / 1000  -- Convert ms to seconds
		local castDuration = endTimeSec - startTimeSec

		if castDuration > 0 and latencyMS > 0 then
			-- Calculate width based on latency as percentage of cast time
			local latencyPercent = latencySeconds / castDuration
			local barWidth = self.playerBar:GetWidth()
			local latencyWidth = barWidth * latencyPercent

			-- Ensure minimum visible width of 10 pixels, cap at 50% of bar
			latencyWidth = math.max(10, math.min(latencyWidth, barWidth * 0.5))

			self.playerLatency:SetWidth(latencyWidth)
			self.playerLatency:Show()
		else
			self.playerLatency:Hide()
		end
	elseif unit == "player" and self.playerLatency then
		self.playerLatency:Hide()
	end

	-- SHOW the frame - this is an active channel
	frame:Show()
end

-- ================================================================================
-- CAST STOP HANDLER
-- Called when cast ends, fails, or is interrupted
-- ================================================================================

function CastingBars:OnCastStop(unit)
	local state, frame, bar, spellText, timeText
	if unit == "player" and self.playerFrame then
		state = self.castingState.player
		frame = self.playerFrame
		bar = self.playerBar
		spellText = self.playerSpellText
		timeText = self.playerTimeText
	elseif unit == "target" and self.targetFrame then
		state = self.castingState.target
		frame = self.targetFrame
		bar = self.targetBar
		spellText = self.targetSpellText
		timeText = self.targetTimeText
	elseif unit == "focus" and self.focusFrame then
		state = self.castingState.focus
		frame = self.focusFrame
		bar = self.focusBar
		spellText = self.focusSpellText
		timeText = self.focusTimeText
	else
		return
	end

	-- Clear casting state
	state.casting = false
	state.channeling = false
	state.startTime = 0
	state.endTime = 0
	state.spellName = ""

	-- Reset bar visuals
	bar:SetValue(0)

	-- CRITICAL: Handle visibility based on lock state
	if self.db.locked then
		-- LOCKED MODE: Hide the bar immediately when cast ends
		frame:Hide()
		spellText:SetText("")
		timeText:SetText("")
	else
		-- UNLOCKED MODE: Show "Ready" for positioning
		spellText:SetText("Ready")
		timeText:SetText("")
		-- Keep frame visible for positioning
	end
end

-- ================================================================================
-- CAST DELAY HANDLER (pushback)
-- ================================================================================

function CastingBars:OnCastDelay(unit)
	local spellName, nameSubtext, text, texture, startTime, endTime = UnitCastingInfo(unit)
	if not spellName then return end

	local state
	if unit == "player" and self.playerFrame then
		state = self.castingState.player
	elseif unit == "target" and self.targetFrame then
		state = self.castingState.target
	elseif unit == "focus" and self.focusFrame then
		state = self.castingState.focus
	else
		return
	end

	if state.casting then
		-- Update times for pushback
		state.startTime = (startTime or 0) / 1000
		state.endTime = (endTime or 0) / 1000
	end
end

-- ================================================================================
-- CHANNEL UPDATE HANDLER
-- ================================================================================

function CastingBars:OnChannelUpdate(unit)
	local spellName, nameSubtext, text, texture, startTime, endTime = UnitChannelInfo(unit)
	if not spellName then return end

	local state
	if unit == "player" and self.playerFrame then
		state = self.castingState.player
	elseif unit == "target" and self.targetFrame then
		state = self.castingState.target
	elseif unit == "focus" and self.focusFrame then
		state = self.castingState.focus
	else
		return
	end

	if state.channeling then
		-- Update times
		state.startTime = (startTime or 0) / 1000
		state.endTime = (endTime or 0) / 1000
	end
end

-- ================================================================================
-- TARGET CHANGE HANDLER
-- Polls UnitCastingInfo/UnitChannelInfo when player targets new unit mid-cast
-- ================================================================================

function CastingBars:OnTargetChanged()
	-- Early return if target bar disabled
	if not self.db.target.enabled then return end

	-- Check if new target exists
	if not UnitExists("target") then
		-- No target: hide bar and clear state
		if self.targetFrame then
			self:OnCastStop("target")
		end
		return
	end

	-- Poll for active cast
	local spellName, nameSubtext, text, texture, startTime, endTime = UnitCastingInfo("target")

	if spellName then
		-- Target is casting: trigger cast start manually
		self:OnCastStart("target")
		return
	end

	-- Poll for active channel
	local chanSpellName, chanNameSubtext, chanText, chanTexture, chanStartTime, chanEndTime = UnitChannelInfo("target")

	if chanSpellName then
		-- Target is channeling: trigger channel start manually
		self:OnChannelStart("target")
		return
	end

	-- Target not casting/channeling: hide bar
	self:OnCastStop("target")
end

-- ================================================================================
-- FOCUS CHANGE HANDLER
-- Polls UnitCastingInfo/UnitChannelInfo when player sets new focus mid-cast
-- ================================================================================

function CastingBars:OnFocusChanged()
	-- Early return if focus bar disabled
	if not self.db.focus.enabled then return end

	-- Check if new focus exists
	if not UnitExists("focus") then
		-- No focus: hide bar and clear state
		if self.focusFrame then
			self:OnCastStop("focus")
		end
		return
	end

	-- Poll for active cast
	local spellName, nameSubtext, text, texture, startTime, endTime = UnitCastingInfo("focus")

	if spellName then
		-- Focus is casting: trigger cast start manually
		self:OnCastStart("focus")
		return
	end

	-- Poll for active channel
	local chanSpellName, chanNameSubtext, chanText, chanTexture, chanStartTime, chanEndTime = UnitChannelInfo("focus")

	if chanSpellName then
		-- Focus is channeling: trigger channel start manually
		self:OnChannelStart("focus")
		return
	end

	-- Focus not casting/channeling: hide bar
	self:OnCastStop("focus")
end

-- ================================================================================
-- UPDATE LOOP - Runs every frame
-- ================================================================================

function CastingBars:OnUpdate(elapsed)
	local now = GetTime()

	-- Update player bar if casting/channeling
	if self.playerFrame and self.db.player.enabled then
		local state = self.castingState.player
		if state.casting or state.channeling then
			self:UpdateBar("player", now)
			self:UpdateBounce("player", now)
		end
	end

	-- Update target bar if casting/channeling
	if self.targetFrame and self.db.target.enabled then
		local state = self.castingState.target
		if state.casting or state.channeling then
			self:UpdateBar("target", now)
			self:UpdateBounce("target", now)
		end
	end

	-- Update focus bar if casting/channeling
	if self.focusFrame and self.db.focus.enabled then
		local state = self.castingState.focus
		if state.casting or state.channeling then
			self:UpdateBar("focus", now)
			self:UpdateBounce("focus", now)
		end
	end
end

-- ================================================================================
-- BAR UPDATE - Progress and time text
-- ================================================================================

function CastingBars:UpdateBar(unit, now)
	local state, bar, spellText, timeText

	if unit == "player" then
		state = self.castingState.player
		bar = self.playerBar
		spellText = self.playerSpellText
		timeText = self.playerTimeText
	elseif unit == "target" then
		state = self.castingState.target
		bar = self.targetBar
		spellText = self.targetSpellText
		timeText = self.targetTimeText
	elseif unit == "focus" then
		state = self.castingState.focus
		bar = self.focusBar
		spellText = self.focusSpellText
		timeText = self.focusTimeText
	else
		return
	end

	-- Calculate timing
	local duration = state.endTime - state.startTime
	if duration <= 0 then duration = 1 end  -- Prevent division by zero

	local remaining = state.endTime - now
	local progress

	if state.channeling then
		-- Channeling: bar drains from full to empty
		progress = remaining / duration
		bar:SetValue(math.max(0, math.min(1, progress)))
	else
		-- Casting: bar fills from empty to full
		local elapsed = now - state.startTime
		progress = elapsed / duration
		bar:SetValue(math.max(0, math.min(1, progress)))
	end

	-- Check if cast has ended (time expired)
	if remaining <= 0 then
		self:OnCastStop(unit)
		return
	end

	-- Update spell name if changed
	local currentText = spellText:GetText()
	if currentText ~= state.spellName and state.spellName ~= "" then
		spellText:SetText(state.spellName)
	end

	-- Update time text (throttled for performance but fast enough for milliseconds)
	local lastUpdate = self.lastUpdate[unit .. "Text"] or 0
	if (now - lastUpdate) >= TEXT_UPDATE_THROTTLE then
		timeText:SetText(self:FormatTime(remaining))
		self.lastUpdate[unit .. "Text"] = now
	end
end

-- ================================================================================
-- BOUNCE ANIMATION
-- ================================================================================

function CastingBars:StartBounce(unit)
	if unit == "player" then
		self.bounceState.player.active = true
		self.bounceState.player.startTime = GetTime()
	elseif unit == "target" then
		self.bounceState.target.active = true
		self.bounceState.target.startTime = GetTime()
	elseif unit == "focus" then
		self.bounceState.focus.active = true
		self.bounceState.focus.startTime = GetTime()
	end
end

function CastingBars:UpdateBounce(unit, now)
	local bounceState, bar

	if unit == "player" then
		bounceState = self.bounceState.player
		bar = self.playerBar
	elseif unit == "target" then
		bounceState = self.bounceState.target
		bar = self.targetBar
	elseif unit == "focus" then
		bounceState = self.bounceState.focus
		bar = self.focusBar
	else
		return
	end

	if not bounceState.active or not bar then return end

	local elapsed = now - bounceState.startTime

	if elapsed >= BOUNCE_DURATION then
		-- Pulse complete - reset to default border
		bounceState.active = false
		bar:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
	else
		-- Calculate pulse progress (0 to 1)
		local progress = elapsed / BOUNCE_DURATION

		-- Use sine wave for smooth pulse (border color intensity)
		local intensity = math.sin(progress * math.pi)

		-- Pulse the backdrop border color (subtle glow effect)
		bar:SetBackdropBorderColor(
			0.5 + (0.5 * intensity),  -- Pulse from 0.5 to 1.0
			0.5 + (0.5 * intensity),
			1.0,  -- Keep blue tint
			1
		)
	end
end

-- ================================================================================
-- HELPER FUNCTIONS
-- ================================================================================

function CastingBars:FormatTime(seconds)
	if not seconds or type(seconds) ~= "number" or seconds ~= seconds then
		local format = self.addon and self.addon.db1 and self.addon.db1.profile.castingBars.timeFormat
		return format == "centiseconds" and "00.00" or "00.000"
	end

	if seconds < 0 then seconds = 0 end

	local wholeSecs = math.floor(seconds)
	local format = self.addon and self.addon.db1 and self.addon.db1.profile.castingBars.timeFormat

	if format == "centiseconds" then
		local centisecs = math.floor((seconds - wholeSecs) * 100)
		return string.format("%02d.%02d", wholeSecs, centisecs)
	else
		local millisecs = math.floor((seconds - wholeSecs) * 1000)
		return string.format("%02d.%03d", wholeSecs, millisecs)
	end
end

-- ================================================================================
-- SETTINGS MANAGEMENT
-- ================================================================================

function CastingBars:LoadSettings()
	if not self.db then return end

	-- Load player bar settings
	if self.playerFrame then
		local playerDB = self.db.player
		self.addon.BarUtils:LoadPosition(self.playerFrame, playerDB, "", 0, -200)

		if playerDB.width and playerDB.height then
			self.playerBar:SetSize(playerDB.width or BAR_WIDTH, playerDB.height or BAR_HEIGHT)
			self.playerFrame:SetSize((playerDB.width or BAR_WIDTH) + 20, (playerDB.height or BAR_HEIGHT) + 30)
		end

		if playerDB.enabled then
			-- Enable/disable mouse interaction based on lock state
			self.playerFrame:EnableMouse(not self.db.locked)

			-- Hide/show title label based on lock state
			if self.db.locked then
				self.playerTitle:Hide()
			else
				self.playerTitle:Show()
			end

			if not self.db.locked then
				-- UNLOCKED: Show with "Ready" for positioning
				self.playerFrame:Show()
				self.playerSpellText:SetText("Ready")
				self.playerTimeText:SetText("")
				self.playerBar:SetValue(0)
			else
				-- LOCKED: Only show if actively casting
				if self.castingState.player.casting or self.castingState.player.channeling then
					self.playerFrame:Show()
				else
					self.playerFrame:Hide()
				end
			end
		else
			self.playerFrame:Hide()
			self.playerTitle:Hide()
		end
	end

	-- Load target bar settings
	if self.targetFrame then
		local targetDB = self.db.target
		self.addon.BarUtils:LoadPosition(self.targetFrame, targetDB, "", 0, -230)

		if targetDB.width and targetDB.height then
			self.targetBar:SetSize(targetDB.width or BAR_WIDTH, targetDB.height or BAR_HEIGHT)
			self.targetFrame:SetSize((targetDB.width or BAR_WIDTH) + 20, (targetDB.height or BAR_HEIGHT) + 30)
		end

		if targetDB.enabled then
			self.targetFrame:EnableMouse(not self.db.locked)

			-- Hide/show title label based on lock state
			if self.db.locked then
				self.targetTitle:Hide()
			else
				self.targetTitle:Show()
			end

			if not self.db.locked then
				self.targetFrame:Show()
				self.targetSpellText:SetText("Ready")
				self.targetTimeText:SetText("")
				self.targetBar:SetValue(0)
			else
				if self.castingState.target.casting or self.castingState.target.channeling then
					self.targetFrame:Show()
				else
					self.targetFrame:Hide()
				end
			end
		else
			self.targetFrame:Hide()
			self.targetTitle:Hide()
		end
	end

	-- Load focus bar settings
	if self.focusFrame then
		local focusDB = self.db.focus
		self.addon.BarUtils:LoadPosition(self.focusFrame, focusDB, "", 0, -260)

		if focusDB.width and focusDB.height then
			self.focusBar:SetSize(focusDB.width or BAR_WIDTH, focusDB.height or BAR_HEIGHT)
			self.focusFrame:SetSize((focusDB.width or BAR_WIDTH) + 20, (focusDB.height or BAR_HEIGHT) + 30)
		end

		if focusDB.enabled then
			self.focusFrame:EnableMouse(not self.db.locked)

			-- Hide/show title label based on lock state
			if self.db.locked then
				self.focusTitle:Hide()
			else
				self.focusTitle:Show()
			end

			if not self.db.locked then
				self.focusFrame:Show()
				self.focusSpellText:SetText("Ready")
				self.focusTimeText:SetText("")
				self.focusBar:SetValue(0)
			else
				if self.castingState.focus.casting or self.castingState.focus.channeling then
					self.focusFrame:Show()
				else
					self.focusFrame:Hide()
				end
			end
		else
			self.focusFrame:Hide()
			self.focusTitle:Hide()
		end
	end

	-- Apply textures only once to prevent random changes
	if not self.textureApplied then
		self:ApplyBarTexture()
		self.textureApplied = true
	end
end

-- ================================================================================
-- TEXTURE APPLICATION
-- Only called once during initialization to prevent random texture changes
-- ================================================================================

function CastingBars:ApplyBarTexture()
	if not self.db then return end

	local texture = self.db.barTexture or "default"

	-- Apply texture to all bars using BarUtils
	if self.playerBar then
		self.addon.BarUtils:ApplyBarTexture(self.playerBar, texture)
	end

	if self.targetBar then
		self.addon.BarUtils:ApplyBarTexture(self.targetBar, texture)
	end

	if self.focusBar then
		self.addon.BarUtils:ApplyBarTexture(self.focusBar, texture)
	end
end

-- Public method to force texture update (called from options UI)
function CastingBars:UpdateTexture()
	self.textureApplied = false
	self:ApplyBarTexture()
	self.textureApplied = true
end

-- ================================================================================
-- LOCK/UNLOCK TOGGLE
-- Called when user toggles lock state in options
-- ================================================================================

function CastingBars:SetLocked(locked)
	if not self.db then return end

	self.db.locked = locked

	-- Update visibility based on new lock state
	self:LoadSettings()
end

-- ================================================================================
-- PROFILE MANAGEMENT
-- ================================================================================

function CastingBars:OnProfileChanged()
	local SoundAlerter = LibStub("AceAddon-3.0"):GetAddon("SoundAlerter")
	if not SoundAlerter then return end

	self.addon = SoundAlerter
	self.db = self.addon.db1.profile.castingBars

	-- Reset texture flag on profile change to ensure correct texture is applied
	self.textureApplied = false

	if self.initialized then
		self:LoadSettings()
	end
end

-- ================================================================================
-- MODULE EXPORT
-- ================================================================================

-- Store in global temporary variable for SoundAlerter.lua to pick up
-- This avoids timing issues with GetAddon() during file load
SoundAlerter_CastingBarsModule = CastingBars
