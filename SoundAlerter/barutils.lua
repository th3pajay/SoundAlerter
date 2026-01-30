-- ================================================================================
-- Bar Utilities - Shared utilities for all SoundAlerter bars
-- ================================================================================
-- Author: th3pajay
-- WoW Version: 3.3.5a (WotLK) - Ascension
-- Purpose: Shared code for resource bars and casting bars
-- ================================================================================
-- NOTE: This module stores functions in a global temporary variable.
--       SoundAlerter.lua's OnInitialize() will attach it to the addon.
-- ================================================================================

local BarUtils = {}

-- ================================================================================
-- CONSTANTS
-- ================================================================================

-- Texture paths
local TEXTURE_STATUSBAR = "Interface\\TargetingFrame\\UI-StatusBar"
local TEXTURE_SOLID = "Interface\\Buttons\\WHITE8X8"
local TEXTURE_BORDER = "Interface\\Tooltips\\UI-Tooltip-Border"
local TEXTURE_BANTO = "Interface\\PaperDollInfoFrame\\UI-Character-Skills-Bar"
local TEXTURE_HALCYONE = "Interface\\RaidFrame\\Raid-Bar-HP-Fill"

-- ================================================================================
-- POSITION MANAGEMENT
-- ================================================================================

-- Save bar position relative to screen center
-- @param frame: The frame to save position for
-- @param db: Database table to save to
-- @param prefix: Prefix for position keys (e.g., "energy", "playerCast")
function BarUtils:SavePosition(frame, db, prefix)
	if not frame or not db or not prefix then return end

	local x, y = frame:GetCenter()
	if not x or not y then return end

	local screenWidth, screenHeight = UIParent:GetSize()
	db[prefix .. "PositionX"] = x - (screenWidth / 2)
	db[prefix .. "PositionY"] = y - (screenHeight / 2)
end

-- Load bar position from saved settings
-- @param frame: The frame to position
-- @param db: Database table to load from
-- @param prefix: Prefix for position keys
-- @param defaultX: Default X offset if no saved position
-- @param defaultY: Default Y offset if no saved position
function BarUtils:LoadPosition(frame, db, prefix, defaultX, defaultY)
	if not frame or not db or not prefix then return end

	local screenWidth, screenHeight = UIParent:GetSize()
	local x = (db[prefix .. "PositionX"] or defaultX or 0) + (screenWidth / 2)
	local y = (db[prefix .. "PositionY"] or defaultY or 0) + (screenHeight / 2)

	frame:ClearAllPoints()
	frame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
end

-- ================================================================================
-- DRAGGING
-- ================================================================================

-- Make a frame draggable with lock support
-- @param frame: Frame to make draggable
-- @param db: Database table containing 'locked' setting
-- @param onStopCallback: Optional callback when dragging stops
function BarUtils:MakeDraggable(frame, db, onStopCallback)
	if not frame or not db then return end

	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")

	frame:SetScript("OnDragStart", function(self)
		if not db.locked then
			self:StartMoving()
		end
	end)

	frame:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		if onStopCallback then
			onStopCallback()
		end
	end)
end

-- ================================================================================
-- TEXTURE APPLICATION
-- ================================================================================

-- Apply texture to a StatusBar based on settings
-- @param bar: StatusBar frame
-- @param textureSetting: Texture type ("default", "solid", "transparent")
function BarUtils:ApplyBarTexture(bar, textureSetting)
	if not bar then return end

	local texturePath = TEXTURE_STATUSBAR

	if textureSetting == "solid" then
		texturePath = TEXTURE_SOLID
	elseif textureSetting == "transparent" then
		texturePath = TEXTURE_SOLID
	elseif textureSetting == "banto" then
		texturePath = TEXTURE_BANTO
	elseif textureSetting == "halcyone" then
		texturePath = TEXTURE_HALCYONE
	end

	-- Apply to main bar
	bar:SetStatusBarTexture(texturePath)
	bar:GetStatusBarTexture():SetHorizTile(false)

	-- Apply to background if it exists
	if bar.bg then
		bar.bg:SetTexture(texturePath)
	end

	-- Set alpha for transparent mode
	if textureSetting == "transparent" then
		bar:SetAlpha(0.7)
	else
		bar:SetAlpha(1.0)
	end
end

-- ================================================================================
-- BACKDROP/BORDER
-- ================================================================================

-- Create standard backdrop for bars
-- @param frame: Frame to apply backdrop to
-- @param r, g, b, a: Border color (optional, defaults to gray)
function BarUtils:CreateBackdrop(frame, r, g, b, a)
	if not frame then return end

	frame:SetBackdrop({
		edgeFile = TEXTURE_BORDER,
		edgeSize = 12,
		insets = {left = 2, right = 2, top = 2, bottom = 2}
	})

	frame:SetBackdropBorderColor(r or 0.5, g or 0.5, b or 0.5, a or 1)
end

-- ================================================================================
-- LOCK/UNLOCK
-- ================================================================================

-- Set locked state for a frame
-- @param frame: Frame to lock/unlock
-- @param locked: True to lock, false to unlock
function BarUtils:SetLocked(frame, locked)
	if not frame then return end

	frame:EnableMouse(not locked)
end

-- ================================================================================
-- SCALE MANAGEMENT
-- ================================================================================

-- Apply scale to a frame from settings
-- @param frame: Frame to scale
-- @param db: Database table containing scale setting
-- @param prefix: Prefix for scale key
-- @param defaultScale: Default scale if not set (default: 1.0)
function BarUtils:ApplyScale(frame, db, prefix, defaultScale)
	if not frame or not db or not prefix then return end

	local scale = db[prefix .. "Scale"] or defaultScale or 1.0
	frame:SetScale(scale)
end

-- ================================================================================
-- SIZE MANAGEMENT
-- ================================================================================

-- Apply width and height to a frame from settings
-- @param frame: Frame to resize
-- @param db: Database table containing size settings
-- @param prefix: Prefix for width/height keys
-- @param defaultWidth: Default width if not set
-- @param defaultHeight: Default height if not set
function BarUtils:ApplySize(frame, db, prefix, defaultWidth, defaultHeight)
	if not frame or not db or not prefix then return end

	local width = db[prefix .. "Width"] or defaultWidth
	local height = db[prefix .. "Height"] or defaultHeight

	if width and height then
		frame:SetSize(width, height)
	end
end

-- ================================================================================
-- VISIBILITY MANAGEMENT
-- ================================================================================

-- Update frame visibility based on enabled state and lock
-- @param frame: Frame to show/hide
-- @param db: Database table containing 'enabled' and 'locked' settings
function BarUtils:UpdateVisibility(frame, db)
	if not frame or not db then return end

	if db.enabled then
		frame:Show()
		frame:EnableMouse(not db.locked)
	else
		frame:Hide()
	end
end

-- ================================================================================
-- FONT STRING HELPERS
-- ================================================================================

-- Create a standard font string for bars
-- @param parent: Parent frame
-- @param fontSize: Font size (default: 14)
-- @param outline: Font outline ("OUTLINE", "THICKOUTLINE", or nil)
-- @return FontString
function BarUtils:CreateFontString(parent, fontSize, outline)
	if not parent then return nil end

	local fontString = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	fontString:SetFont("Fonts\\FRIZQT__.TTF", fontSize or 14, outline or "OUTLINE")
	fontString:SetShadowOffset(1, -1)
	fontString:SetShadowColor(0, 0, 0, 1)

	return fontString
end

-- ================================================================================
-- COLOR HELPERS
-- ================================================================================

-- Interpolate between two colors
-- @param t: Interpolation factor (0.0 to 1.0)
-- @param r1, g1, b1: First color (RGB, 0-1)
-- @param r2, g2, b2: Second color (RGB, 0-1)
-- @return r, g, b: Interpolated color
function BarUtils:LerpColor(t, r1, g1, b1, r2, g2, b2)
	return r1 * (1 - t) + r2 * t,
	       g1 * (1 - t) + g2 * t,
	       b1 * (1 - t) + b2 * t
end

-- ================================================================================
-- VALIDATION HELPERS
-- ================================================================================

-- Validate that a frame and database exist
-- @param frame: Frame to validate
-- @param db: Database to validate
-- @return boolean: True if both are valid
function BarUtils:ValidateFrameAndDB(frame, db)
	return (frame ~= nil) and (db ~= nil)
end

-- ================================================================================
-- THROTTLE HELPERS
-- ================================================================================

-- Check if enough time has elapsed for throttled updates
-- @param lastUpdate: Last update time (from GetTime())
-- @param throttle: Throttle interval in seconds
-- @return boolean: True if update should occur
-- @return number: Current time (for updating lastUpdate)
function BarUtils:ShouldUpdate(lastUpdate, throttle)
	local now = GetTime()

	if not lastUpdate then
		return true, now
	end

	if (now - lastUpdate) >= throttle then
		return true, now
	end

	return false, now
end

-- ================================================================================
-- PROFILE CHANGE HELPERS
-- ================================================================================

-- Apply all settings to a frame after profile change
-- @param frame: Frame to update
-- @param db: Database table containing all settings
-- @param prefix: Prefix for settings keys
-- @param defaultX, defaultY: Default position
-- @param defaultWidth, defaultHeight: Default size
-- @param defaultScale: Default scale
function BarUtils:ApplyAllSettings(frame, db, prefix, defaultX, defaultY, defaultWidth, defaultHeight, defaultScale)
	if not self:ValidateFrameAndDB(frame, db) then return end

	self:LoadPosition(frame, db, prefix, defaultX, defaultY)
	self:ApplyScale(frame, db, prefix, defaultScale)
	self:ApplySize(frame, db, prefix, defaultWidth, defaultHeight)
	self:UpdateVisibility(frame, db)
end

-- ================================================================================
-- DEBUG HELPERS
-- ================================================================================

-- Print debug message if debug mode is enabled
-- @param addon: SoundAlerter addon reference
-- @param message: Message to print
function BarUtils:DebugPrint(addon, message)
	if addon and addon.db1 and addon.db1.profile.debugmode then
		addon:Print("[BarUtils] " .. tostring(message))
	end
end

-- ================================================================================
-- MODULE EXPORT
-- ================================================================================

-- Store in global temporary variable for SoundAlerter.lua to pick up
-- This avoids timing issues with GetAddon() during file load
SoundAlerter_BarUtilsModule = BarUtils
