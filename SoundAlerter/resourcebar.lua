local SoundAlerter = LibStub("AceAddon-3.0"):GetAddon("SoundAlerter")
if not SoundAlerter then return end

local ResourceBar = {}
SoundAlerter.ResourceBar = ResourceBar

local math_sin = math.sin
local math_pi = math.pi
local GetTime = GetTime
local UnitPower = UnitPower
local UnitPowerMax = UnitPowerMax
local UnitHealth = UnitHealth
local UnitHealthMax = UnitHealthMax
local UnitMana = UnitMana
local UnitManaMax = UnitManaMax
local GetComboPoints = GetComboPoints

local POWER_TYPE_MANA = 0
local POWER_TYPE_RAGE = 1
local POWER_TYPE_ENERGY = 3

local BAR_WIDTH = 280
local BAR_HEIGHT = 20
local CP_CONTAINER_WIDTH = 280
local CP_HEIGHT = 30
local CP_SPACING = 8

local TEXT_UPDATE_THROTTLE = 0.05
local VALUE_UPDATE_THROTTLE = 0.016  -- 60 FPS for smooth continuous energy regen
local ENERGY_UPDATE_THROTTLE = 0.01  -- 100 FPS for ultra-smooth energy display
local ANIMATION_UPDATE_THROTTLE = 0.016
local LOW_POWER_PULSE_FREQ = 3
local OVERCAP_GLOW_FREQ = 4
local CP_PULSE_SCALE = 0.25
local CP_FULL_SCALE = 0.4
local TWO_PI = math_pi * 2

function ResourceBar:Initialize()
	self.db = SoundAlerter.db1.profile.resourceBar
	self.initialized = false

	-- Cache for colors to avoid repeated database lookups
	self.cachedColors = {}

	-- Cache for previous values to detect changes
	self.lastValues = {
		energy = -1,
		rage = -1,
		health = -1,
		mana = -1,
		combo = -1
	}

	-- Cache for text values to avoid redundant updates
	self.lastText = {
		energy = "",
		rage = "",
		health = "",
		mana = "",
		combo = ""
	}

	-- Throttle timers
	self.updateTimers = {
		energy = 0,
		rage = 0,
		health = 0,
		mana = 0,
		combo = 0
	}

	-- Pre-formatted combo text strings
	self.comboStrings = {"0/5", "1/5", "2/5", "3/5", "4/5", "5/5"}

	-- Screen dimensions cache
	self.screenWidth, self.screenHeight = UIParent:GetSize()

	self:CreateEnergyFrame()
	self:CreateRageFrame()
	self:CreateHealthFrame()
	self:CreateManaFrame()
	self:CreateCPFrame()
	self:CreateCPTextFrame()
	self:RegisterEvents()
	self:LoadSettings()
	self:ApplyBarTexture()
	self:CacheColors()
	self:UpdateVisibility()

	self.initialized = true
end

function ResourceBar:CacheColors()
	if not self.db then return end

	self.cachedColors.energy = self.db.energyColor
	self.cachedColors.rage = self.db.rageColor
	self.cachedColors.health = self.db.healthColor
	self.cachedColors.mana = self.db.manaColor
	self.cachedColors.comboActive = self.db.comboActiveColor
	self.cachedColors.comboMax = self.db.comboMaxColor
	self.cachedColors.comboInactive = self.db.comboInactiveColor
end

function ResourceBar:SaveEnergyPosition()
	if not self.energyFrame then return end
	local x, y = self.energyFrame:GetCenter()
	if not x or not y then return end

	SoundAlerter.db1.profile.resourceBar.energyPositionX = x - (self.screenWidth / 2)
	SoundAlerter.db1.profile.resourceBar.energyPositionY = y - (self.screenHeight / 2)
end

function ResourceBar:SaveRagePosition()
	if not self.rageFrame then return end
	local x, y = self.rageFrame:GetCenter()
	if not x or not y then return end

	SoundAlerter.db1.profile.resourceBar.ragePositionX = x - (self.screenWidth / 2)
	SoundAlerter.db1.profile.resourceBar.ragePositionY = y - (self.screenHeight / 2)
end

function ResourceBar:SaveHealthPosition()
	if not self.healthFrame then return end
	local x, y = self.healthFrame:GetCenter()
	if not x or not y then return end

	SoundAlerter.db1.profile.resourceBar.healthPositionX = x - (self.screenWidth / 2)
	SoundAlerter.db1.profile.resourceBar.healthPositionY = y - (self.screenHeight / 2)
end

function ResourceBar:SaveManaPosition()
	if not self.manaFrame then return end
	local x, y = self.manaFrame:GetCenter()
	if not x or not y then return end

	SoundAlerter.db1.profile.resourceBar.manaPositionX = x - (self.screenWidth / 2)
	SoundAlerter.db1.profile.resourceBar.manaPositionY = y - (self.screenHeight / 2)
end

function ResourceBar:SaveComboPosition()
	if not self.comboFrame then return end
	local x, y = self.comboFrame:GetCenter()
	if not x or not y then return end

	SoundAlerter.db1.profile.resourceBar.comboPositionX = x - (self.screenWidth / 2)
	SoundAlerter.db1.profile.resourceBar.comboPositionY = y - (self.screenHeight / 2)
end

function ResourceBar:SaveComboTextPosition()
	if not self.comboTextFrame then return end
	local x, y = self.comboTextFrame:GetCenter()
	if not x or not y then return end

	SoundAlerter.db1.profile.resourceBar.comboTextPositionX = x - (self.screenWidth / 2)
	SoundAlerter.db1.profile.resourceBar.comboTextPositionY = y - (self.screenHeight / 2)
end

function ResourceBar:CreateEnergyFrame()
	self.energyFrame = CreateFrame("Frame", "SoundAlerterResourceBar_Energy", UIParent)
	self.energyFrame:SetSize(BAR_WIDTH + 20, BAR_HEIGHT + 20)
	self.energyFrame:SetFrameStrata("MEDIUM")
	self.energyFrame:SetFrameLevel(10)
	self.energyFrame:SetPoint("CENTER", UIParent, "CENTER", 0, -120)
	self.energyFrame:SetMovable(true)
	self.energyFrame:EnableMouse(true)
	self.energyFrame:RegisterForDrag("LeftButton")

	self.energyFrame:SetScript("OnDragStart", function(frame)
		if not self.db.locked then
			frame:StartMoving()
		end
	end)

	self.energyFrame:SetScript("OnDragStop", function(frame)
		frame:StopMovingOrSizing()
		self:SaveEnergyPosition()
	end)

	self.energyBar = CreateFrame("StatusBar", nil, self.energyFrame)
	self.energyBar:SetSize(BAR_WIDTH, BAR_HEIGHT)
	self.energyBar:SetPoint("CENTER")
	self.energyBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
	self.energyBar:GetStatusBarTexture():SetHorizTile(false)
	self.energyBar:SetMinMaxValues(0, 100)
	self.energyBar:SetValue(0)

	self.energyBar.bg = self.energyBar:CreateTexture(nil, "BACKGROUND")
	self.energyBar.bg:SetAllPoints()
	self.energyBar.bg:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
	self.energyBar.bg:SetVertexColor(0.1, 0.1, 0.1, 0.5)

	self.energyBar:SetBackdrop({
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		edgeSize = 12,
		insets = {left = 2, right = 2, top = 2, bottom = 2}
	})
	self.energyBar:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)

	self.energyText = self.energyBar:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	self.energyText:SetPoint("CENTER")
	self.energyText:SetText("0")

	self.energyBar.glow = self.energyBar:CreateTexture(nil, "BACKGROUND")
	self.energyBar.glow:SetAllPoints(self.energyFrame)
	self.energyBar.glow:SetTexture("Interface\\FullScreenTextures\\LowHealth")
	self.energyBar.glow:SetBlendMode("ADD")
	self.energyBar.glow:SetAlpha(0)

	self.energyFrame:Hide()
end

function ResourceBar:CreateRageFrame()
	self.rageFrame = CreateFrame("Frame", "SoundAlerterResourceBar_Rage", UIParent)
	self.rageFrame:SetSize(BAR_WIDTH + 20, BAR_HEIGHT + 20)
	self.rageFrame:SetFrameStrata("MEDIUM")
	self.rageFrame:SetFrameLevel(10)
	self.rageFrame:SetPoint("CENTER", UIParent, "CENTER", 0, -120)
	self.rageFrame:SetMovable(true)
	self.rageFrame:EnableMouse(true)
	self.rageFrame:RegisterForDrag("LeftButton")

	self.rageFrame:SetScript("OnDragStart", function(frame)
		if not self.db.locked then
			frame:StartMoving()
		end
	end)

	self.rageFrame:SetScript("OnDragStop", function(frame)
		frame:StopMovingOrSizing()
		self:SaveRagePosition()
	end)

	self.rageBar = CreateFrame("StatusBar", nil, self.rageFrame)
	self.rageBar:SetSize(BAR_WIDTH, BAR_HEIGHT)
	self.rageBar:SetPoint("CENTER")
	self.rageBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
	self.rageBar:GetStatusBarTexture():SetHorizTile(false)
	self.rageBar:SetMinMaxValues(0, 100)
	self.rageBar:SetValue(0)

	self.rageBar.bg = self.rageBar:CreateTexture(nil, "BACKGROUND")
	self.rageBar.bg:SetAllPoints()
	self.rageBar.bg:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
	self.rageBar.bg:SetVertexColor(0.1, 0.1, 0.1, 0.5)

	self.rageBar:SetBackdrop({
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		edgeSize = 12,
		insets = {left = 2, right = 2, top = 2, bottom = 2}
	})
	self.rageBar:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)

	self.rageText = self.rageBar:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	self.rageText:SetPoint("CENTER")
	self.rageText:SetText("0")

	self.rageBar.glow = self.rageBar:CreateTexture(nil, "BACKGROUND")
	self.rageBar.glow:SetAllPoints(self.rageFrame)
	self.rageBar.glow:SetTexture("Interface\\FullScreenTextures\\LowHealth")
	self.rageBar.glow:SetBlendMode("ADD")
	self.rageBar.glow:SetAlpha(0)

	self.rageFrame:Hide()
end

function ResourceBar:CreateHealthFrame()
	self.healthFrame = CreateFrame("Frame", "SoundAlerterResourceBar_Health", UIParent)
	self.healthFrame:SetSize(BAR_WIDTH + 20, BAR_HEIGHT + 20)
	self.healthFrame:SetFrameStrata("MEDIUM")
	self.healthFrame:SetFrameLevel(10)
	self.healthFrame:SetPoint("CENTER", UIParent, "CENTER", 0, -140)
	self.healthFrame:SetMovable(true)
	self.healthFrame:EnableMouse(true)
	self.healthFrame:RegisterForDrag("LeftButton")

	self.healthFrame:SetScript("OnDragStart", function(frame)
		if not self.db.locked then
			frame:StartMoving()
		end
	end)

	self.healthFrame:SetScript("OnDragStop", function(frame)
		frame:StopMovingOrSizing()
		self:SaveHealthPosition()
	end)

	self.healthBar = CreateFrame("StatusBar", nil, self.healthFrame)
	self.healthBar:SetSize(BAR_WIDTH, BAR_HEIGHT)
	self.healthBar:SetPoint("CENTER")
	self.healthBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
	self.healthBar:GetStatusBarTexture():SetHorizTile(false)
	self.healthBar:SetMinMaxValues(0, 100)
	self.healthBar:SetValue(100)

	self.healthBar.bg = self.healthBar:CreateTexture(nil, "BACKGROUND")
	self.healthBar.bg:SetAllPoints()
	self.healthBar.bg:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
	self.healthBar.bg:SetVertexColor(0.1, 0.1, 0.1, 0.5)

	self.healthBar:SetBackdrop({
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		edgeSize = 12,
		insets = {left = 2, right = 2, top = 2, bottom = 2}
	})
	self.healthBar:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)

	self.healthText = self.healthBar:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	self.healthText:SetPoint("CENTER")
	self.healthText:SetText("100%")

	self.healthBar.glow = self.healthBar:CreateTexture(nil, "BACKGROUND")
	self.healthBar.glow:SetAllPoints(self.healthFrame)
	self.healthBar.glow:SetTexture("Interface\\FullScreenTextures\\LowHealth")
	self.healthBar.glow:SetBlendMode("ADD")
	self.healthBar.glow:SetAlpha(0)

	self.healthFrame:Hide()
end

function ResourceBar:CreateManaFrame()
	self.manaFrame = CreateFrame("Frame", "SoundAlerterResourceBar_Mana", UIParent)
	self.manaFrame:SetSize(BAR_WIDTH + 20, BAR_HEIGHT + 20)
	self.manaFrame:SetFrameStrata("MEDIUM")
	self.manaFrame:SetFrameLevel(10)
	self.manaFrame:SetPoint("CENTER", UIParent, "CENTER", 0, -100)
	self.manaFrame:SetMovable(true)
	self.manaFrame:EnableMouse(true)
	self.manaFrame:RegisterForDrag("LeftButton")

	self.manaFrame:SetScript("OnDragStart", function(frame)
		if not self.db.locked then
			frame:StartMoving()
		end
	end)

	self.manaFrame:SetScript("OnDragStop", function(frame)
		frame:StopMovingOrSizing()
		self:SaveManaPosition()
	end)

	self.manaBar = CreateFrame("StatusBar", nil, self.manaFrame)
	self.manaBar:SetSize(BAR_WIDTH, BAR_HEIGHT)
	self.manaBar:SetPoint("CENTER")
	self.manaBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
	self.manaBar:GetStatusBarTexture():SetHorizTile(false)
	self.manaBar:SetMinMaxValues(0, 100)
	self.manaBar:SetValue(100)

	self.manaBar.bg = self.manaBar:CreateTexture(nil, "BACKGROUND")
	self.manaBar.bg:SetAllPoints()
	self.manaBar.bg:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
	self.manaBar.bg:SetVertexColor(0.1, 0.1, 0.1, 0.5)

	self.manaBar:SetBackdrop({
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		edgeSize = 12,
		insets = {left = 2, right = 2, top = 2, bottom = 2}
	})
	self.manaBar:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)

	self.manaText = self.manaBar:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	self.manaText:SetPoint("CENTER")
	self.manaText:SetText("100%")

	self.manaBar.glow = self.manaBar:CreateTexture(nil, "BACKGROUND")
	self.manaBar.glow:SetAllPoints(self.manaFrame)
	self.manaBar.glow:SetTexture("Interface\\FullScreenTextures\\LowHealth")
	self.manaBar.glow:SetBlendMode("ADD")
	self.manaBar.glow:SetAlpha(0)

	self.manaFrame:Hide()
end

function ResourceBar:CreateCPFrame()
	self.comboFrame = CreateFrame("Frame", "SoundAlerterResourceBar_Combo", UIParent)
	self.comboFrame:SetSize(CP_CONTAINER_WIDTH + 20, CP_HEIGHT + 20)
	self.comboFrame:SetFrameStrata("MEDIUM")
	self.comboFrame:SetFrameLevel(10)
	self.comboFrame:SetPoint("CENTER", UIParent, "CENTER", 0, -85)
	self.comboFrame:SetMovable(true)
	self.comboFrame:EnableMouse(true)
	self.comboFrame:RegisterForDrag("LeftButton")

	self.comboFrame:SetScript("OnDragStart", function(frame)
		if not self.db.locked then
			frame:StartMoving()
		end
	end)

	self.comboFrame:SetScript("OnDragStop", function(frame)
		frame:StopMovingOrSizing()
		self:SaveComboPosition()
	end)

	self.comboPoints = {}
	local cpWidth = (CP_CONTAINER_WIDTH - (CP_SPACING * 4)) / 5

	for i = 1, 5 do
		local cpFrame = CreateFrame("Frame", nil, self.comboFrame)
		cpFrame:SetSize(CP_HEIGHT, CP_HEIGHT)

		cpFrame.texture = cpFrame:CreateTexture(nil, "ARTWORK")
		cpFrame.texture:SetAllPoints(cpFrame)
		cpFrame.texture:SetVertexColor(0.25, 0.25, 0.25, 1)

		cpFrame.sparks = cpFrame:CreateTexture(nil, "OVERLAY")
		cpFrame.sparks:SetAllPoints(cpFrame)
		cpFrame.sparks:SetTexture("Interface\\FullScreenTextures\\LowHealth")
		cpFrame.sparks:SetBlendMode("ADD")
		cpFrame.sparks:SetAlpha(0)

		cpFrame.glow = cpFrame:CreateTexture(nil, "BACKGROUND")
		cpFrame.glow:SetPoint("CENTER")
		cpFrame.glow:SetSize(CP_HEIGHT * 1.5, CP_HEIGHT * 1.5)
		cpFrame.glow:SetTexture("Interface\\FullScreenTextures\\LowHealth")
		cpFrame.glow:SetBlendMode("ADD")
		cpFrame.glow:SetAlpha(0)

		cpFrame.particles = cpFrame:CreateTexture(nil, "OVERLAY")
		cpFrame.particles:SetPoint("CENTER")
		cpFrame.particles:SetSize(CP_HEIGHT * 2, CP_HEIGHT * 2)
		cpFrame.particles:SetTexture("Interface\\Cooldown\\star4")
		cpFrame.particles:SetBlendMode("ADD")
		cpFrame.particles:SetAlpha(0)

		if i == 1 then
			cpFrame:SetPoint("LEFT", self.comboFrame, "LEFT", 10, 0)
		else
			cpFrame:SetPoint("LEFT", self.comboPoints[i-1], "RIGHT", CP_SPACING, 0)
		end

		self.comboPoints[i] = cpFrame
	end

	self:ApplyCPStyle()
	self.comboFrame:Hide()
end

function ResourceBar:ApplyCPStyle()
	if not self.comboPoints or not self.db then return end

	local style = self.db.comboStyle or "circle"

	for i = 1, 5 do
		local cp = self.comboPoints[i]
		if cp and cp.texture then
			if style == "square" then
				cp.texture:SetTexture("Interface\\Buttons\\WHITE8X8")
				cp.texture:SetTexCoord(0, 1, 0, 1)
			elseif style == "circle" then
				local success = cp.texture:SetTexture("Interface\\AddOns\\SoundAlerter\\Textures\\circle")
				if not success then
					success = cp.texture:SetTexture("Interface\\Minimap\\Ping\\ping5")
				end
				if not success then
					cp.texture:SetTexture("Interface\\Buttons\\WHITE8X8")
				end
				cp.texture:SetTexCoord(0, 1, 0, 1)
			end
		end
	end
end

function ResourceBar:CreateCPTextFrame()
	self.comboTextFrame = CreateFrame("Frame", "SoundAlerterResourceBar_ComboText", UIParent)
	self.comboTextFrame:SetSize(80, 30)
	self.comboTextFrame:SetFrameStrata("MEDIUM")
	self.comboTextFrame:SetFrameLevel(11)
	self.comboTextFrame:SetPoint("CENTER", UIParent, "CENTER", 0, -50)
	self.comboTextFrame:SetMovable(true)
	self.comboTextFrame:EnableMouse(true)
	self.comboTextFrame:RegisterForDrag("LeftButton")

	self.comboTextFrame:SetScript("OnDragStart", function(frame)
		if not self.db.locked then
			frame:StartMoving()
		end
	end)

	self.comboTextFrame:SetScript("OnDragStop", function(frame)
		frame:StopMovingOrSizing()
		self:SaveComboTextPosition()
	end)

	self.comboText = self.comboTextFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	self.comboText:SetPoint("CENTER")
	self.comboText:SetText("0/5")
	self.comboText:SetTextColor(1, 1, 1, 1)

	self.comboTextFrame:Hide()
end

function ResourceBar:RegisterEvents()
	self.energyFrame:RegisterEvent("UNIT_POWER")
	self.energyFrame:RegisterEvent("UNIT_MAXPOWER")
	self.energyFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

	self.rageFrame:RegisterEvent("UNIT_POWER")
	self.rageFrame:RegisterEvent("UNIT_MAXPOWER")
	self.rageFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

	self.healthFrame:RegisterEvent("UNIT_HEALTH")
	self.healthFrame:RegisterEvent("UNIT_MAXHEALTH")
	self.healthFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

	self.manaFrame:RegisterEvent("UNIT_POWER")
	self.manaFrame:RegisterEvent("UNIT_MAXPOWER")
	self.manaFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

	self.comboFrame:RegisterEvent("UNIT_COMBO_POINTS")
	self.comboFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
	self.comboFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

	local function HandleEvents(frame, event, ...)
		if ResourceBar[event] then
			ResourceBar[event](ResourceBar, event, ...)
		end
	end

	self.energyFrame:SetScript("OnEvent", HandleEvents)
	self.rageFrame:SetScript("OnEvent", HandleEvents)
	self.healthFrame:SetScript("OnEvent", HandleEvents)
	self.manaFrame:SetScript("OnEvent", HandleEvents)
	self.comboFrame:SetScript("OnEvent", HandleEvents)
end

function ResourceBar:UNIT_POWER(event, unitId, powerType)
	if unitId ~= "player" then return end

	-- Set dirty flags for immediate updates on next frame
	if self.energyFrame and self.energyFrame:IsShown() then
		self.updateTimers.energy = VALUE_UPDATE_THROTTLE
	end

	if self.rageFrame and self.rageFrame:IsShown() then
		self.updateTimers.rage = VALUE_UPDATE_THROTTLE
	end

	if self.manaFrame and self.manaFrame:IsShown() then
		self.updateTimers.mana = VALUE_UPDATE_THROTTLE
	end
end

function ResourceBar:UNIT_MAXPOWER(event, unitId, powerType)
	if unitId ~= "player" then return end
	self:UNIT_POWER(event, unitId, powerType)
end

function ResourceBar:UNIT_HEALTH(event, unitId)
	if unitId ~= "player" then return end
	if self.healthFrame and self.healthFrame:IsShown() then
		self.updateTimers.health = VALUE_UPDATE_THROTTLE
	end
end

function ResourceBar:UNIT_MAXHEALTH(event, unitId)
	if unitId ~= "player" then return end
	self:UNIT_HEALTH(event, unitId)
end

function ResourceBar:UNIT_COMBO_POINTS(event, unitId)
	if unitId ~= "player" then return end
	if self.comboFrame and self.comboFrame:IsShown() then
		self:UpdateComboPoints()
	end
end

function ResourceBar:PLAYER_TARGET_CHANGED()
	if self.comboFrame and self.comboFrame:IsShown() then
		self:UpdateComboPoints()
	end
end

function ResourceBar:PLAYER_ENTERING_WORLD()
	self:UpdateVisibility()
	self:UpdateEnergyBar()
	self:UpdateRageBar()
	self:UpdateHealthBar()
	self:UpdateManaBar()
	self:UpdateComboPoints()
end

function ResourceBar:UpdateEnergyBar()
	if not self.energyBar then return end

	local current = UnitPower("player", POWER_TYPE_ENERGY)
	local max = UnitPowerMax("player", POWER_TYPE_ENERGY)

	if max == 0 then return end

	-- Always update bar value for continuous energy regeneration (private server)
	-- But only update text if value actually changed to reduce string allocations
	if current ~= self.lastValues.energy then
		self.energyBar:SetMinMaxValues(0, max)
		self.energyBar:SetValue(current)

		local newText = tostring(current)
		if newText ~= self.lastText.energy then
			self.energyText:SetText(newText)
			self.lastText.energy = newText
		end

		self.lastValues.energy = current
	else
		-- Even if value hasn't changed by whole numbers, update the bar
		-- This ensures smooth sub-integer energy regeneration display
		self.energyBar:SetValue(current)
	end

	local percent = (current / max) * 100
	local color = self.cachedColors.energy
	local time = GetTime()

	if percent < 25 then
		-- Use modulo to keep time in bounds (0 to 2*PI for sine wave)
		local animTime = (time * 2) % TWO_PI
		local pulse = 0.7 + (math_sin(animTime) * 0.3)
		local vibrate = math_sin(time * 8) * 0.15

		if color then
			self.energyBar:SetStatusBarColor(color.r * pulse, color.g * pulse, color.b * pulse)
		end
		self.energyBar:SetBackdropBorderColor(0.8 + vibrate, 0.3 + vibrate, 0.3 + vibrate, 1)
	else
		if color then
			self.energyBar:SetStatusBarColor(color.r, color.g, color.b)
		end
		self.energyBar:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
	end

	if percent >= 95 then
		local animTime = (time * 0.5) % TWO_PI
		local glowPulse = math_sin(animTime) * 0.5 + 0.5
		if self.energyBar.glow and color then
			self.energyBar.glow:SetAlpha(glowPulse * 0.4)
			self.energyBar.glow:SetVertexColor(color.r, color.g, color.b, glowPulse * 0.4)
		end
	else
		if self.energyBar.glow then
			self.energyBar.glow:SetAlpha(0)
		end
	end
end

function ResourceBar:UpdateRageBar()
	if not self.rageBar then return end

	local current = UnitPower("player", POWER_TYPE_RAGE)
	local max = UnitPowerMax("player", POWER_TYPE_RAGE)

	if max == 0 then return end

	-- Only update if value changed
	if current ~= self.lastValues.rage then
		self.rageBar:SetMinMaxValues(0, max)
		self.rageBar:SetValue(current)

		local newText = tostring(current)
		if newText ~= self.lastText.rage then
			self.rageText:SetText(newText)
			self.lastText.rage = newText
		end

		self.lastValues.rage = current
	end

	local percent = (current / max) * 100
	local color = self.cachedColors.rage
	local time = GetTime()

	if percent < 25 then
		local animTime = (time * 2) % TWO_PI
		local pulse = 0.7 + (math_sin(animTime) * 0.3)
		local vibrate = math_sin(time * 8) * 0.15

		if color then
			self.rageBar:SetStatusBarColor(color.r * pulse, color.g * pulse, color.b * pulse)
		end
		self.rageBar:SetBackdropBorderColor(0.8 + vibrate, 0.3 + vibrate, 0.3 + vibrate, 1)
	else
		if color then
			self.rageBar:SetStatusBarColor(color.r, color.g, color.b)
		end
		self.rageBar:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
	end

	if percent >= 95 then
		local animTime = (time * 0.5) % TWO_PI
		local glowPulse = math_sin(animTime) * 0.5 + 0.5
		if self.rageBar.glow and color then
			self.rageBar.glow:SetAlpha(glowPulse * 0.4)
			self.rageBar.glow:SetVertexColor(color.r, color.g, color.b, glowPulse * 0.4)
		end
	else
		if self.rageBar.glow then
			self.rageBar.glow:SetAlpha(0)
		end
	end
end

function ResourceBar:UpdateHealthBar()
	if not self.healthBar then return end

	local current = UnitHealth("player")
	local max = UnitHealthMax("player")

	if max == 0 then return end

	local percent = (current / max) * 100

	-- Only update if value changed
	if current ~= self.lastValues.health then
		self.healthBar:SetMinMaxValues(0, max)
		self.healthBar:SetValue(current)

		local newText = string.format("%.0f%%", percent)
		if newText ~= self.lastText.health then
			self.healthText:SetText(newText)
			self.lastText.health = newText
		end

		self.lastValues.health = current
	end

	local color = self.cachedColors.health
	local time = GetTime()

	if percent < 25 then
		local animTime = (time * 2) % TWO_PI
		local pulse = 0.7 + (math_sin(animTime) * 0.3)
		local vibrate = math_sin(time * 8) * 0.15

		if color then
			self.healthBar:SetStatusBarColor(color.r * pulse, color.g * pulse, color.b * pulse)
		end
		self.healthBar:SetBackdropBorderColor(0.8 + vibrate, 0.3 + vibrate, 0.3 + vibrate, 1)
	else
		if color then
			self.healthBar:SetStatusBarColor(color.r, color.g, color.b)
		end
		self.healthBar:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
	end

	if percent >= 95 then
		local animTime = (time * 0.5) % TWO_PI
		local glowPulse = math_sin(animTime) * 0.5 + 0.5
		if self.healthBar.glow and color then
			self.healthBar.glow:SetAlpha(glowPulse * 0.4)
			self.healthBar.glow:SetVertexColor(color.r, color.g, color.b, glowPulse * 0.4)
		end
	else
		if self.healthBar.glow then
			self.healthBar.glow:SetAlpha(0)
		end
	end
end

function ResourceBar:UpdateManaBar()
	if not self.manaBar then return end

	local current = UnitPower("player", POWER_TYPE_MANA)
	local max = UnitPowerMax("player", POWER_TYPE_MANA)

	if max == 0 then return end

	local percent = (current / max) * 100

	-- Only update if value changed
	if current ~= self.lastValues.mana then
		self.manaBar:SetMinMaxValues(0, max)
		self.manaBar:SetValue(current)

		local newText = string.format("%.0f%%", percent)
		if newText ~= self.lastText.mana then
			self.manaText:SetText(newText)
			self.lastText.mana = newText
		end

		self.lastValues.mana = current
	end

	local color = self.cachedColors.mana
	local time = GetTime()

	if percent < 25 then
		local animTime = (time * 2) % TWO_PI
		local pulse = 0.7 + (math_sin(animTime) * 0.3)
		local vibrate = math_sin(time * 8) * 0.15

		if color then
			self.manaBar:SetStatusBarColor(color.r * pulse, color.g * pulse, color.b * pulse)
		end
		self.manaBar:SetBackdropBorderColor(0.8 + vibrate, 0.3 + vibrate, 0.3 + vibrate, 1)
	else
		if color then
			self.manaBar:SetStatusBarColor(color.r, color.g, color.b)
		end
		self.manaBar:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
	end

	if percent >= 95 then
		local animTime = (time * 0.5) % TWO_PI
		local glowPulse = math_sin(animTime) * 0.5 + 0.5
		if self.manaBar.glow and color then
			self.manaBar.glow:SetAlpha(glowPulse * 0.4)
			self.manaBar.glow:SetVertexColor(color.r, color.g, color.b, glowPulse * 0.4)
		end
	else
		if self.manaBar.glow then
			self.manaBar.glow:SetAlpha(0)
		end
	end
end

function ResourceBar:UpdateComboPoints()
	if not self.comboPoints then return end

	local cp = GetComboPoints("player", "target") or 0
	local lastCP = self.lastComboPoints or 0

	-- Only update if combo points changed
	if cp ~= lastCP then
		local activeColor = (cp == 5) and self.cachedColors.comboMax or self.cachedColors.comboActive
		local inactiveColor = self.cachedColors.comboInactive

		for i = 1, 5 do
			if i <= cp then
				if activeColor then
					self.comboPoints[i].texture:SetVertexColor(activeColor.r, activeColor.g, activeColor.b, 1)
				end

				if i > lastCP and i == cp and not (cp == 5 and lastCP == 4) then
					self:AnimateCPGain(i)
				end
			else
				if inactiveColor then
					self.comboPoints[i].texture:SetVertexColor(inactiveColor.r, inactiveColor.g, inactiveColor.b, 1)
				end
			end
		end

		if cp == 5 and lastCP == 4 then
			self:Animate5CPCelebrationWave()
		end

		self.lastComboPoints = cp

		-- Use pre-formatted string
		if self.comboText then
			local newText = self.comboStrings[cp + 1]
			if newText ~= self.lastText.combo then
				self.comboText:SetText(newText)
				self.lastText.combo = newText
			end
		end
	end
end

function ResourceBar:AnimateCPGain(cpIndex)
	local cp = self.comboPoints[cpIndex]
	if not cp then return end

	local originalScale = cp:GetScale()

	cp:SetScript("OnUpdate", function(frame, elapsed)
		if not frame.bounceTime then
			frame.bounceTime = 0
			frame.bounceStart = GetTime()
		end

		frame.bounceTime = frame.bounceTime + elapsed
		local progress = frame.bounceTime / 0.2

		if progress >= 1 then
			frame:SetScale(originalScale)
			frame:SetScript("OnUpdate", nil)
			frame.bounceTime = nil
			frame.bounceStart = nil
			if cp.sparks then cp.sparks:SetAlpha(0) end
		else
			local scale = originalScale + (math_sin(progress * math_pi) * 0.15)
			frame:SetScale(scale)

			if cp.sparks then
				local alpha = 0.8 * (1 - progress)
				cp.sparks:SetAlpha(alpha)
				cp.sparks:SetVertexColor(1, 0.9, 0.3, alpha)
			end
		end
	end)
end

function ResourceBar:Animate5CPCelebrationWave()
	if not self.comboFrame then return end

	if self.db.fullCPSound then
		PlaySound("AuctionWindowClose")
	end

	self.comboFrame:SetScript("OnUpdate", function(frame, elapsed)
		if not frame.celebrationTime then
			frame.celebrationTime = 0
		end

		frame.celebrationTime = frame.celebrationTime + elapsed
		local totalDuration = 0.6
		local progress = frame.celebrationTime / totalDuration

		if progress >= 1 then
			for i = 1, 5 do
				local cp = self.comboPoints[i]
				if cp then
					if cp.glow then
						cp.glow:SetAlpha(0)
					end
					if cp.particles then
						cp.particles:SetAlpha(0)
					end
					if cp.sparks then
						cp.sparks:SetAlpha(0)
					end
					cp:SetScale(1.0)
					local color = self.cachedColors.comboMax
					if color and cp.texture then
						cp.texture:SetVertexColor(color.r, color.g, color.b, 1)
					end
				end
			end
			frame:SetScript("OnUpdate", nil)
			frame.celebrationTime = nil
		else
			for i = 1, 5 do
				local cp = self.comboPoints[i]
				if cp then
					local waveDelay = (i - 1) * 0.08
					local cpProgress = (frame.celebrationTime - waveDelay) / 0.4

					if cpProgress > 0 and cpProgress < 1 then
						local scale = 1.0 + (math_sin(cpProgress * math_pi) * 0.25)
						cp:SetScale(scale)

						if cp.glow then
							local glowAlpha = 0.9 * math_sin(cpProgress * math_pi)
							cp.glow:SetAlpha(glowAlpha)
							cp.glow:SetVertexColor(1, 0.8, 0.2, glowAlpha)
						end

						if cp.particles then
							local particleAlpha = math_sin(cpProgress * math_pi)
							local particleScale = 1 + (cpProgress * 1.5)
							cp.particles:SetAlpha(particleAlpha)
							cp.particles:SetVertexColor(1, 0.9, 0.3, particleAlpha)
							cp.particles:SetSize(CP_HEIGHT * 2 * particleScale, CP_HEIGHT * 2 * particleScale)
						end

						if cp.sparks then
							local sparksAlpha = 0.8 * math_sin(cpProgress * math_pi)
							cp.sparks:SetAlpha(sparksAlpha)
							cp.sparks:SetVertexColor(1, 0.9, 0.3, sparksAlpha)
						end

						if cp.texture then
							local flashProgress = cpProgress * 2
							if flashProgress < 1 then
								local flashIntensity = math_sin(flashProgress * math_pi)
								cp.texture:SetVertexColor(
									0.8 + (0.2 * flashIntensity),
									0.6 + (0.3 * flashIntensity),
									1.0,
									1
								)
							else
								local color = self.cachedColors.comboMax
								if color then
									cp.texture:SetVertexColor(color.r, color.g, color.b, 1)
								end
							end
						end
					elseif cpProgress >= 1 then
						cp:SetScale(1.0)
						if cp.glow then
							cp.glow:SetAlpha(0)
						end
						if cp.particles then
							cp.particles:SetAlpha(0)
						end
						if cp.sparks then
							cp.sparks:SetAlpha(0)
						end
						local color = self.cachedColors.comboMax
						if color and cp.texture then
							cp.texture:SetVertexColor(color.r, color.g, color.b, 1)
						end
					end
				end
			end
		end
	end)
end

function ResourceBar:ApplyBarTexture()
	if not self.db then return end

	local texture = self.db.barTexture or "default"
	local texturePath = "Interface\\TargetingFrame\\UI-StatusBar"

	if texture == "solid" then
		texturePath = "Interface\\Buttons\\WHITE8X8"
	elseif texture == "transparent" then
		texturePath = "Interface\\Buttons\\WHITE8X8"
	end

	if self.energyBar then
		self.energyBar:SetStatusBarTexture(texturePath)
		self.energyBar.bg:SetTexture(texturePath)
		if texture == "transparent" then
			self.energyBar:SetAlpha(0.7)
		else
			self.energyBar:SetAlpha(1.0)
		end
	end

	if self.rageBar then
		self.rageBar:SetStatusBarTexture(texturePath)
		self.rageBar.bg:SetTexture(texturePath)
		if texture == "transparent" then
			self.rageBar:SetAlpha(0.7)
		else
			self.rageBar:SetAlpha(1.0)
		end
	end

	if self.healthBar then
		self.healthBar:SetStatusBarTexture(texturePath)
		self.healthBar.bg:SetTexture(texturePath)
		if texture == "transparent" then
			self.healthBar:SetAlpha(0.7)
		else
			self.healthBar:SetAlpha(1.0)
		end
	end

	if self.manaBar then
		self.manaBar:SetStatusBarTexture(texturePath)
		self.manaBar.bg:SetTexture(texturePath)
		if texture == "transparent" then
			self.manaBar:SetAlpha(0.7)
		else
			self.manaBar:SetAlpha(1.0)
		end
	end
end

function ResourceBar:LoadSettings()
	if not self.db then return end

	-- Update screen dimensions cache
	self.screenWidth, self.screenHeight = UIParent:GetSize()

	if self.energyFrame then
		local x = (self.db.energyPositionX or 0) + (self.screenWidth / 2)
		local y = (self.db.energyPositionY or -120) + (self.screenHeight / 2)
		self.energyFrame:ClearAllPoints()
		self.energyFrame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
		self.energyFrame:SetScale(self.db.energyScale or 1.0)
	end

	if self.rageFrame then
		local x = (self.db.ragePositionX or 0) + (self.screenWidth / 2)
		local y = (self.db.ragePositionY or -120) + (self.screenHeight / 2)
		self.rageFrame:ClearAllPoints()
		self.rageFrame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
		self.rageFrame:SetScale(self.db.rageScale or 1.0)
	end

	if self.healthFrame then
		local x = (self.db.healthPositionX or 0) + (self.screenWidth / 2)
		local y = (self.db.healthPositionY or -140) + (self.screenHeight / 2)
		self.healthFrame:ClearAllPoints()
		self.healthFrame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
		self.healthFrame:SetScale(self.db.healthScale or 1.0)

		local height = self.db.healthHeight or BAR_HEIGHT
		self.healthBar:SetSize(BAR_WIDTH, height)
		self.healthFrame:SetSize(BAR_WIDTH + 20, height + 20)
	end

	if self.manaFrame then
		local x = (self.db.manaPositionX or 0) + (self.screenWidth / 2)
		local y = (self.db.manaPositionY or -100) + (self.screenHeight / 2)
		self.manaFrame:ClearAllPoints()
		self.manaFrame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
		self.manaFrame:SetScale(self.db.manaScale or 1.0)
	end

	if self.comboFrame then
		local x = (self.db.comboPositionX or 0) + (self.screenWidth / 2)
		local y = (self.db.comboPositionY or -85) + (self.screenHeight / 2)
		self.comboFrame:ClearAllPoints()
		self.comboFrame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
		self.comboFrame:SetScale(self.db.comboScale or 1.0)
	end

	if self.comboTextFrame then
		local x = (self.db.comboTextPositionX or 0) + (self.screenWidth / 2)
		local y = (self.db.comboTextPositionY or -50) + (self.screenHeight / 2)
		self.comboTextFrame:ClearAllPoints()
		self.comboTextFrame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
	end
end

function ResourceBar:StartEnergyUpdates()
	if not self.energyFrame then return end
	-- Energy needs very frequent updates for continuous regeneration on private servers
	self.energyFrame:SetScript("OnUpdate", function(frame, elapsed)
		self.updateTimers.energy = self.updateTimers.energy + elapsed
		if self.updateTimers.energy >= ENERGY_UPDATE_THROTTLE then
			self:UpdateEnergyBar()
			self.updateTimers.energy = 0
		end
	end)
end

function ResourceBar:StopEnergyUpdates()
	if not self.energyFrame then return end
	self.energyFrame:SetScript("OnUpdate", nil)
	self.updateTimers.energy = 0
end

function ResourceBar:StartRageUpdates()
	if not self.rageFrame then return end
	-- Rage bar uses event-driven updates only (no smooth regeneration needed)
	self.rageFrame:SetScript("OnUpdate", function(frame, elapsed)
		-- Only animations run on update, values updated by events
		self:UpdateRageBar()
	end)
end

function ResourceBar:StopRageUpdates()
	if not self.rageFrame then return end
	self.rageFrame:SetScript("OnUpdate", nil)
	self.updateTimers.rage = 0
end

function ResourceBar:StartHealthUpdates()
	if not self.healthFrame then return end
	-- Health bar uses event-driven updates with animations
	self.healthFrame:SetScript("OnUpdate", function(frame, elapsed)
		self:UpdateHealthBar()
	end)
end

function ResourceBar:StopHealthUpdates()
	if not self.healthFrame then return end
	self.healthFrame:SetScript("OnUpdate", nil)
	self.updateTimers.health = 0
end

function ResourceBar:StartManaUpdates()
	if not self.manaFrame then return end
	-- Mana needs frequent updates for smooth regeneration display
	self.manaFrame:SetScript("OnUpdate", function(frame, elapsed)
		self.updateTimers.mana = self.updateTimers.mana + elapsed
		if self.updateTimers.mana >= VALUE_UPDATE_THROTTLE then
			self:UpdateManaBar()
			self.updateTimers.mana = 0
		end
	end)
end

function ResourceBar:StopManaUpdates()
	if not self.manaFrame then return end
	self.manaFrame:SetScript("OnUpdate", nil)
	self.updateTimers.mana = 0
end

function ResourceBar:StartComboUpdates()
	if not self.comboFrame then return end
	-- Combo points are event-driven only, no OnUpdate needed
	-- Animations are handled by individual combo point frames
end

function ResourceBar:StopComboUpdates()
	if not self.comboFrame then return end
	-- Clean up any running animations
	for i = 1, 5 do
		if self.comboPoints[i] then
			self.comboPoints[i]:SetScript("OnUpdate", nil)
		end
	end
	if self.comboFrame then
		self.comboFrame:SetScript("OnUpdate", nil)
	end
	self.updateTimers.combo = 0
end

function ResourceBar:UpdateVisibility()
	if not self.db then return end

	if self.energyFrame then
		if self.db.energyEnabled then
			self.energyFrame:Show()
			self.energyFrame:EnableMouse(not self.db.locked)
			self:UpdateEnergyBar()
			self:StartEnergyUpdates()
		else
			self.energyFrame:Hide()
			self:StopEnergyUpdates()
		end
	end

	if self.rageFrame then
		if self.db.rageEnabled then
			self.rageFrame:Show()
			self.rageFrame:EnableMouse(not self.db.locked)
			self:UpdateRageBar()
			self:StartRageUpdates()
		else
			self.rageFrame:Hide()
			self:StopRageUpdates()
		end
	end

	if self.healthFrame then
		if self.db.healthEnabled then
			self.healthFrame:Show()
			self.healthFrame:EnableMouse(not self.db.locked)
			self:UpdateHealthBar()
			self:StartHealthUpdates()
		else
			self.healthFrame:Hide()
			self:StopHealthUpdates()
		end
	end

	if self.manaFrame then
		if self.db.manaEnabled then
			self.manaFrame:Show()
			self.manaFrame:EnableMouse(not self.db.locked)
			self:UpdateManaBar()
			self:StartManaUpdates()
		else
			self.manaFrame:Hide()
			self:StopManaUpdates()
		end
	end

	if self.comboFrame then
		if self.db.comboEnabled then
			self.comboFrame:Show()
			self.comboFrame:EnableMouse(not self.db.locked)
			self:UpdateComboPoints()
			self:StartComboUpdates()
		else
			self.comboFrame:Hide()
			self:StopComboUpdates()
		end
	end

	if self.comboTextFrame then
		if self.db.comboTextEnabled then
			self.comboTextFrame:Show()
			self.comboTextFrame:EnableMouse(not self.db.locked)
		else
			self.comboTextFrame:Hide()
		end
	end
end

function ResourceBar:SetLocked(locked)
	if not self.db then return end

	self.db.locked = locked
	self:UpdateVisibility()
end

function ResourceBar:OnProfileChanged()
	self.db = SoundAlerter.db1.profile.resourceBar
	self:CacheColors()
	self:LoadSettings()
	self:ApplyBarTexture()
	self:UpdateVisibility()
end
