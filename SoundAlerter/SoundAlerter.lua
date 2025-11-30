--[[
SoundAlerter by Trolollolol (Original Author)
Updated by th3pajay (October 2025)
Voice prompts from the combat log, primarily for PvP environments.
--]]

SoundAlerter = LibStub("AceAddon-3.0"):NewAddon("SoundAlerter", "AceEvent-3.0", "AceConsole-3.0", "AceTimer-3.0")
local self, SoundAlerter = SoundAlerter, SoundAlerter

local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local AceConfig = LibStub("AceConfig-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("SoundAlerter")
local sadb

local playerName = UnitName("player")
local sourcetype, sourceuid, desttype, destuid = {}, {}, {}, {}

if ({["zhCN"] = true, ["zhTW"] = true, ["koKR"] = true, ["frFR"] = true, ["ruRU"] = true})[GetLocale()] then
    DEFAULT_CHAT_FRAME:AddMessage("|cffFF7D0ASoundAlerter|r Currently only works on English and Spanish Clients only, sorry. If you would like to get involved, contact the maintainer.");
end

self.SA_LOCALEPATH = SA_LOCALEPATH
self.SA_LANGUAGE = {
    ["Interface\\Addons\\SoundAlerter\\Voice_ES\\"] = "Spanish (Limited)",
    ["Interface\\Addons\\SoundAlerter\\Voice\\"] = "English",
}
self.SA_CHATGROUP = {
    ["SAY"] = L["Say"],
    ["PARTY"] = L["Party"],
    ["RAID"] = L["Raid"],
    ["BATTLEGROUND"] = L["Battleground"],
}
self.SA_EVENT = {
    SPELL_CAST_SUCCESS = L["Instant spell was successfully casted"],
    SPELL_CAST_START = L["Spell is casting"],
    SPELL_AURA_APPLIED = L["Spell buff/debuff applied"],
    SPELL_AURA_REMOVED = L["Spell buff/debuff down"],
    SPELL_INTERRUPT = L["Spell is interrupted"],
    SPELL_SUMMON = L["Summoning spell"],
    SPELL_DAMAGE = L["Spell cast successfully damaged"]
}
self.SA_UNIT = {
    any = L["Any"],
    player = L["Player"],
    target = L["Target"],
    focus = L["Focus"],
    mouseover = L["Mouseover"],
    party = L["Party"],
    arena = L["Arena (enemy)"],
    custom = L["Custom"],
}
self.SA_TYPE = {
    [COMBATLOG_FILTER_EVERYTHING] = L["Any"],
    [COMBATLOG_FILTER_FRIENDLY_UNITS] = L["Friendly"],
    [COMBATLOG_FILTER_HOSTILE_PLAYERS] = L["Hostile player"],
    [COMBATLOG_FILTER_HOSTILE_UNITS] = L["Hostile non-player"],
    [COMBATLOG_FILTER_NEUTRAL_UNITS] = L["Neutral"],
    [COMBATLOG_FILTER_ME] = L["Myself"],
    [COMBATLOG_FILTER_MINE] = L["My non-unit object (totem)"],
    [COMBATLOG_FILTER_MY_PET] = L["My pet"],
}

local function log(msg) DEFAULT_CHAT_FRAME:AddMessage("|cFF33FF22SA|r:"..msg) end

function SoundAlerter:ChangeProfile()
	sadb = self.db1.profile

	for k,v in SoundAlerter:IterateModules() do
		if type(v.ChangeProfile) == 'function' then
			v:ChangeProfile()
		end
	end

	if self.ProximityToasts then
		self.ProximityToasts:OnProfileChanged()
	end

	if self.ResourceBar then
		self.ResourceBar:OnProfileChanged()
	end

	if self.FlagAlerts then
		self.FlagAlerts:OnProfileChanged()
	end

	-- Re-initialize statistics for new profile
	if sadb.statistics and sadb.statistics.enabled then
		self:InitializeStatistics()
	end
end

function SoundAlerter:OnProfileCopied(event, db, sourceProfileKey)
	-- Call standard profile change handler
	self:ChangeProfile()

	-- Reset statistics for copied profile (stats don't make sense when copied)
	if sadb.statistics then
		sadb.statistics.session = {
			totalAlerts = 0,
			startTime = GetTime(),
			byCategory = {
				spellAlerts = 0,
				proximityAlerts = 0,
				trinketAlerts = 0,
				flagAlerts = 0,
			},
		}
		sadb.statistics.allTime = {
			totalAlerts = 0,
			totalSessions = 0,
			topSpells = {},
			byCategory = {
				spellAlerts = 0,
				proximityAlerts = 0,
				trinketAlerts = 0,
				flagAlerts = 0,
			},
			byZone = {
				arena = 0,
				battleground = 0,
				worldPvP = 0,
			},
		}
		sadb.statistics.trackingStartTime = time()

		self:Print("Statistics reset for copied profile (settings copied, but stats start fresh)")
	end
end

function SoundAlerter:AddOption(key, table)
	self.options.args[key] = table
end

local SoundAlerterMinimapButton
local BUTTON_TEXTURE = "Interface\\ICONS\\ability_warrior_battleshout"

function SoundAlerter:CreateMinimapButton()
    local db = sadb
    local buttonSize = 24
    local iconSize = 24
    local initialX = 5
    local initialY = -5

    -- Create main button frame
    SoundAlerterMinimapButton = CreateFrame("Button", "SoundAlerterMinimapButton", Minimap)
    SoundAlerterMinimapButton:SetSize(buttonSize, buttonSize)
    SoundAlerterMinimapButton:SetFrameStrata("MEDIUM")
    SoundAlerterMinimapButton:SetMovable(true)
    SoundAlerterMinimapButton:EnableMouse(true)
    SoundAlerterMinimapButton:RegisterForDrag("LeftButton")

    -- Icon texture (main visual element)
    local icon = SoundAlerterMinimapButton:CreateTexture(nil, "ARTWORK")
    icon:SetTexture(BUTTON_TEXTURE)
    icon:SetSize(iconSize, iconSize)
    icon:SetPoint("CENTER", SoundAlerterMinimapButton, "CENTER", 0, 0)
    icon:SetVertexColor(0.5, 1.0, 1.0)  -- Cyan tint
    SoundAlerterMinimapButton.icon = icon

    -- Border (clean button border without tracking indicator)
    local border = SoundAlerterMinimapButton:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Buttons\\UI-Quickslot-Depress")
    border:SetSize(iconSize + 4, iconSize + 4)
    border:SetPoint("CENTER", SoundAlerterMinimapButton, "CENTER", 0, 0)
    border:SetVertexColor(0.5, 0.5, 0.5, 0.8)  -- Subtle gray
    SoundAlerterMinimapButton.border = border

    -- Highlight glow (hover effect)
    local highlight = SoundAlerterMinimapButton:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    highlight:SetSize(iconSize, iconSize)
    highlight:SetPoint("CENTER", SoundAlerterMinimapButton, "CENTER", 0, 0)
    highlight:SetBlendMode("ADD")
    highlight:SetVertexColor(0.0, 0.8, 0.8)  -- Cyan glow
    highlight:SetAlpha(0)
    SoundAlerterMinimapButton.highlight = highlight

    -- Create animation groups
    self:CreateMinimapButtonAnimations()

    -- Event handlers
    SoundAlerterMinimapButton:SetScript("OnEnter", function(self)
        SoundAlerter:MinimapButton_OnEnter(self)
    end)

    SoundAlerterMinimapButton:SetScript("OnLeave", function(self)
        SoundAlerter:MinimapButton_OnLeave(self)
    end)

    SoundAlerterMinimapButton:SetScript("OnMouseDown", function(self, button)
        SoundAlerter:MinimapButton_OnMouseDown(self, button)
    end)

    SoundAlerterMinimapButton:SetScript("OnMouseUp", function(self, button)
        SoundAlerter:MinimapButton_OnMouseUp(self, button)
    end)

    SoundAlerterMinimapButton:SetScript("OnClick", function(self, button)
        SoundAlerter:MinimapButton_OnClick(self, button)
    end)

    SoundAlerterMinimapButton:SetScript("OnDragStart", function(self)
        SoundAlerter:MinimapButton_OnDragStart(self)
    end)

    SoundAlerterMinimapButton:SetScript("OnDragStop", function(self)
        SoundAlerter:MinimapButton_OnDragStop(self)
    end)

    -- Position
    if db.MinimapButtonPosition then
        SoundAlerterMinimapButton:ClearAllPoints()
        SoundAlerterMinimapButton:SetPoint("CENTER", Minimap, "CENTER",
            db.MinimapButtonPosition.x, db.MinimapButtonPosition.y)
    else
        SoundAlerterMinimapButton:SetPoint("TOPLEFT", Minimap, "TOPLEFT", initialX, initialY)
    end

    -- Visibility
    if db.MinimapButtonHidden then
        SoundAlerterMinimapButton:Hide()
    else
        SoundAlerterMinimapButton:Show()
    end

    -- Set initial icon based on current settings
    self:UpdateMinimapButtonIcon()
end

function SoundAlerter:CreateMinimapButtonAnimations()
    local button = SoundAlerterMinimapButton
    if not button then return end

    -- Hover scale-up animation
    button.hoverAnimGroup = button:CreateAnimationGroup()
    button.hoverAnimGroup:SetLooping("NONE")

    local hoverScale = button.hoverAnimGroup:CreateAnimation("Scale")
    hoverScale:SetScale(1.05, 1.05)
    hoverScale:SetDuration(0.15)
    hoverScale:SetSmoothing("OUT")

    -- Unhover scale-down animation
    button.unhoverAnimGroup = button:CreateAnimationGroup()
    button.unhoverAnimGroup:SetLooping("NONE")

    local unhoverScale = button.unhoverAnimGroup:CreateAnimation("Scale")
    unhoverScale:SetScale(0.952, 0.952)  -- 1/1.05 ≈ 0.952
    unhoverScale:SetDuration(0.15)
    unhoverScale:SetSmoothing("OUT")

    -- Press scale-down animation
    button.pressAnimGroup = button:CreateAnimationGroup()
    button.pressAnimGroup:SetLooping("NONE")

    local pressScale = button.pressAnimGroup:CreateAnimation("Scale")
    pressScale:SetScale(0.905, 0.905)  -- 0.95/1.05 ≈ 0.905
    pressScale:SetDuration(0.05)

    -- Release scale-up animation
    button.releaseAnimGroup = button:CreateAnimationGroup()
    button.releaseAnimGroup:SetLooping("NONE")

    local releaseScale = button.releaseAnimGroup:CreateAnimation("Scale")
    releaseScale:SetScale(1.105, 1.105)  -- 1.05/0.95 ≈ 1.105
    releaseScale:SetDuration(0.1)
    releaseScale:SetSmoothing("OUT")
end

function SoundAlerter:MinimapButton_OnEnter(self)
    -- Tooltip
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("SoundAlerter")
    GameTooltip:AddLine("Click: Options", 1, 1, 1)
    GameTooltip:AddLine("Shift+Click: Toggle Proximity", 0.8, 0.8, 0.8)
    GameTooltip:AddLine("Ctrl+Click: Toggle Battleground", 0.8, 0.8, 0.8)
    GameTooltip:AddLine("Drag to move", 0.6, 0.6, 0.6)
    GameTooltip:Show()

    -- Hover animation
    if SoundAlerterMinimapButton.hoverAnimGroup then
        SoundAlerterMinimapButton.unhoverAnimGroup:Stop()
        SoundAlerterMinimapButton.hoverAnimGroup:Play()
    end

    -- Border color transition to cyan
    if SoundAlerterMinimapButton.border then
        SoundAlerterMinimapButton.border:SetVertexColor(0.0, 0.8, 0.8, 1.0)
    end

    -- Glow fade in
    local highlight = SoundAlerterMinimapButton.highlight
    if highlight then
        UIFrameFadeIn(highlight, 0.15, highlight:GetAlpha(), 0.3)
    end
end

function SoundAlerter:MinimapButton_OnLeave(self)
    -- Hide tooltip
    GameTooltip:Hide()

    -- Unhover animation
    if SoundAlerterMinimapButton.unhoverAnimGroup then
        SoundAlerterMinimapButton.hoverAnimGroup:Stop()
        SoundAlerterMinimapButton.unhoverAnimGroup:Play()
    end

    -- Border color transition to gray
    if SoundAlerterMinimapButton.border then
        SoundAlerterMinimapButton.border:SetVertexColor(0.5, 0.5, 0.5, 0.8)
    end

    -- Glow fade out
    local highlight = SoundAlerterMinimapButton.highlight
    if highlight then
        UIFrameFadeOut(highlight, 0.15, highlight:GetAlpha(), 0)
    end
end

function SoundAlerter:MinimapButton_OnMouseDown(self, button)
    if button ~= "LeftButton" and button ~= "RightButton" then
        return
    end

    -- Capture modifier state early (before they're released)
    SoundAlerterMinimapButton.pendingShift = IsShiftKeyDown()
    SoundAlerterMinimapButton.pendingCtrl = IsControlKeyDown()

    -- Press animation
    if SoundAlerterMinimapButton.pressAnimGroup then
        SoundAlerterMinimapButton.releaseAnimGroup:Stop()
        SoundAlerterMinimapButton.pressAnimGroup:Play()
    end

    -- Icon dim
    if SoundAlerterMinimapButton.icon then
        SoundAlerterMinimapButton.icon:SetVertexColor(0.425, 0.85, 0.85)  -- 85% of cyan
    end

    -- Border flash white
    if SoundAlerterMinimapButton.border then
        SoundAlerterMinimapButton.border:SetVertexColor(1.0, 1.0, 1.0, 1.0)
    end

    -- Position shift (depress effect)
    local point, relativeTo, relativePoint, xOfs, yOfs = SoundAlerterMinimapButton:GetPoint(1)
    SoundAlerterMinimapButton.originalOffset = {point, relativeTo, relativePoint, xOfs, yOfs}
    SoundAlerterMinimapButton:ClearAllPoints()
    SoundAlerterMinimapButton:SetPoint(point, relativeTo, relativePoint, xOfs + 1, yOfs - 1)
end

function SoundAlerter:MinimapButton_OnMouseUp(self, button)
    if button ~= "LeftButton" and button ~= "RightButton" then
        return
    end

    -- Release animation
    if SoundAlerterMinimapButton.releaseAnimGroup then
        SoundAlerterMinimapButton.pressAnimGroup:Stop()
        SoundAlerterMinimapButton.releaseAnimGroup:Play()
    end

    -- Icon brighten
    if SoundAlerterMinimapButton.icon then
        SoundAlerterMinimapButton.icon:SetVertexColor(0.5, 1.0, 1.0)  -- Full cyan
    end

    -- Border fade to cyan (animate over 0.15s)
    if SoundAlerterMinimapButton.border then
        local startTime = GetTime()
        local duration = 0.15
        local startR, startG, startB = 1.0, 1.0, 1.0
        local endR, endG, endB = 0.0, 0.8, 0.8

        SoundAlerterMinimapButton.borderFadeFrame = SoundAlerterMinimapButton.borderFadeFrame or CreateFrame("Frame")
        SoundAlerterMinimapButton.borderFadeFrame:SetScript("OnUpdate", function(fadeFrame, elapsed)
            local progress = (GetTime() - startTime) / duration
            if progress >= 1.0 then
                SoundAlerterMinimapButton.border:SetVertexColor(endR, endG, endB, 1.0)
                fadeFrame:SetScript("OnUpdate", nil)
            else
                local r = startR + (endR - startR) * progress
                local g = startG + (endG - startG) * progress
                local b = startB + (endB - startB) * progress
                SoundAlerterMinimapButton.border:SetVertexColor(r, g, b, 1.0)
            end
        end)
    end

    -- Position reset
    if SoundAlerterMinimapButton.originalOffset then
        local point, relativeTo, relativePoint, xOfs, yOfs = unpack(SoundAlerterMinimapButton.originalOffset)
        SoundAlerterMinimapButton:ClearAllPoints()
        SoundAlerterMinimapButton:SetPoint(point, relativeTo, relativePoint, xOfs, yOfs)
        SoundAlerterMinimapButton.originalOffset = nil
    end
end

function SoundAlerter:UpdateMinimapButtonIcon()
    if not SoundAlerterMinimapButton or not SoundAlerterMinimapButton.icon then return end

    local proximityOn = sadb.proximityEnabled
    local battlegroundOn = sadb.battlegroundAlertsEnabled
    local icon = SoundAlerterMinimapButton.icon

    if proximityOn and battlegroundOn then
        -- State 4: Both enabled - Sword with burst (full combat mode)
        icon:SetTexture("Interface\\ICONS\\Ability_Warrior_VictoryRush")
    elseif proximityOn and not battlegroundOn then
        -- State 2: Proximity only - Hunter tracking/detection
        icon:SetTexture("Interface\\ICONS\\Ability_Hunter_SniperShot")
    elseif not proximityOn and battlegroundOn then
        -- State 3: Battleground only - Banner
        icon:SetTexture("Interface\\ICONS\\INV_Banner_02")
    else
        -- State 1: Both disabled - Default battle shout
        icon:SetTexture("Interface\\ICONS\\ability_warrior_battleshout")
    end

    -- Maintain cyan tint across all states
    icon:SetVertexColor(0.5, 1.0, 1.0)
end

function SoundAlerter:MinimapButton_OnClick(self, button)
    if button == "LeftButton" then
        -- Use captured modifier state from OnMouseDown
        local wasShift = SoundAlerterMinimapButton.pendingShift
        local wasCtrl = SoundAlerterMinimapButton.pendingCtrl

        -- Clear captured state
        SoundAlerterMinimapButton.pendingShift = false
        SoundAlerterMinimapButton.pendingCtrl = false

        if wasShift then
            -- Toggle proximity alerts
            sadb.proximityEnabled = not sadb.proximityEnabled
            local status = sadb.proximityEnabled and "|cff00FF00ON|r" or "|cffFF0000OFF|r"
            SoundAlerter:Print("Proximity Alerts: " .. status)
            -- Delay icon update slightly to let animation finish
            SoundAlerter:ScheduleTimer("UpdateMinimapButtonIcon", 0.05)
        elseif wasCtrl then
            -- Toggle battleground alerts
            sadb.battlegroundAlertsEnabled = not sadb.battlegroundAlertsEnabled
            local status = sadb.battlegroundAlertsEnabled and "|cff00FF00ON|r" or "|cffFF0000OFF|r"
            SoundAlerter:Print("Battleground Alerts: " .. status)
            -- Delay icon update slightly to let animation finish
            SoundAlerter:ScheduleTimer("UpdateMinimapButtonIcon", 0.05)
        else
            -- Normal click - open options
            SoundAlerter:ShowConfig()
        end
    elseif button == "RightButton" then
        SoundAlerter:ShowConfig()
    end
end

function SoundAlerter:MinimapButton_OnDragStart(self)
    self:StartMoving()
end

function SoundAlerter:MinimapButton_OnDragStop(self)
    self:StopMovingOrSizing()
    local minimapX, minimapY = Minimap:GetCenter()
    local buttonX, buttonY = self:GetCenter()

    sadb.MinimapButtonPosition = {
        x = buttonX - minimapX,
        y = buttonY - minimapY,
    }
end

function SoundAlerter:MigrateResourceBarSettings()
    local db = self.db1.profile.resourceBar

    if db.enabled ~= nil and not db.druid then
        self:Print("|cffFF7D0ASoundAlerter|r: Migrating Resource Bar settings to multi-class structure...")

        db.druid = {
            cat = {
                enabled = db.enabled,
                locked = db.locked or false,
                showEnergyBar = true,
                showComboPoints = db.showComboPoints or true,
                showHealthBar = db.showHealthBar or false,

                powerPositionX = db.energyPositionX or 0,
                powerPositionY = db.energyPositionY or -120,
                cpPositionX = db.cpPositionX or 0,
                cpPositionY = db.cpPositionY or -85,
                healthPositionX = db.healthPositionX or 0,
                healthPositionY = db.healthPositionY or -140,

                powerScale = db.energyScale or 1.0,
                cpScale = db.cpScale or 1.0,
                healthBarScale = db.healthBarScale or 1.0,
                healthBarHeight = db.healthBarHeight or 20,

                powerTexture = db.energyTexture or "Interface\\TargetingFrame\\UI-StatusBar",
                cpStyle = db.cpStyle or "square",
                showCPText = db.showCPText or true,
                cpTextPosition = db.cpTextPosition or "bottom",

                energyColor = db.energyColor or {r = 1, g = 1, b = 0.2},
                energyLowColor = db.energyLowColor or {r = 1, g = 0.3, b = 0},
                cpActiveColor = db.cpActiveColor or {r = 0.2, g = 1, b = 0.2},
                cpMaxColor = db.cpMaxColor or {r = 1, g = 0.8, b = 0.2},
                cpInactiveColor = db.cpInactiveColor or {r = 0.25, g = 0.25, b = 0.25},
                healthColor = db.healthColor or {r = 0.2, g = 1, b = 0.2},

                lowEnergyThreshold = db.lowEnergyThreshold or 15,
                showOverCapAlert = db.showOverCapAlert or true,
                showLowEnergyAlert = db.showLowEnergyAlert or true,

                smoothPower = db.smoothEnergy or false,
                cpAnimations = db.cpAnimations or true,
                fullCPAnimation = db.fullCPAnimation or true,
            },
            bear = dbDefaults.profile.resourceBar.druid.bear,
            caster = dbDefaults.profile.resourceBar.druid.caster,
        }
        db.rogue = dbDefaults.profile.resourceBar.rogue
        db.warrior = dbDefaults.profile.resourceBar.warrior

        for k in pairs(db) do
            if k ~= "druid" and k ~= "rogue" and k ~= "warrior" then
                db[k] = nil
            end
        end

        self:Print("|cffFF7D0ASoundAlerter|r: Migration complete! Your settings have been preserved.")
    end
end

function SoundAlerter:OnInitialize()
    if SoundAlerterSpells then
        self.spellList = SoundAlerterSpells
    else
        self:Print("|cffff0000Error: SoundAlerterSpells table not found. Check spellist.lua.|r")
        self.spellList = {}
    end

    for _, v in pairs(self.spellList) do
        for _, spell in pairs(v) do
            if dbDefaults.profile[spell] == nil then dbDefaults.profile[spell] = true end
        end
    end

    self.db1 = LibStub("AceDB-3.0"):New("SoundAlerterDB", dbDefaults, "Default");
    sadb = self.db1.profile

    self:MigrateResourceBarSettings()

    self.db1.RegisterCallback(self, "OnProfileChanged", "ChangeProfile")
    self.db1.RegisterCallback(self, "OnProfileCopied", "OnProfileCopied")
    self.db1.RegisterCallback(self, "OnProfileReset", "ChangeProfile")
    
    self:RegisterChatCommand("SoundAlerter", "HandleCommand")
    self:RegisterChatCommand("SALERTER", "HandleCommand")
    self:RegisterChatCommand("sa", "HandleCommand")

    SoundAlerter.options = {
        name = "SoundAlerter",
        desc = "Voice prompts from enemy used spells",
        type = 'group',
        icon = [[Interface\Icons\Spell_Nature_ForceOfNature]],
        args = {},
    }
    local bliz_options = CopyTable(SoundAlerter.options)
    bliz_options.args.load = {
        name = "Load configuration",
        desc = "Load configuration options",
        type = 'execute',
        func = "ShowConfig",
        handler = SoundAlerter,
    }

    AceConfig:RegisterOptionsTable("SoundAlerter_bliz", bliz_options)
    AceConfigDialog:AddToBlizOptions("SoundAlerter_bliz", "SoundAlerter")
    
    self:Print("|cffFF7D0ASoundAlerter|r by |cff0070DEth3pajay|r - /SA ")
	self:CreateMinimapButton()

	-- Initialize Spell Database for Find Spell feature
	if not self:LoadSpellDatabase() then
		-- Database not found or outdated - build from scratch
		self:BuildSpellDatabase()
	end
end

function SoundAlerter:OnEnable()
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    self:RegisterEvent("UNIT_AURA")
    self:RegisterEvent("PLAYER_TARGET_CHANGED")
    self:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
    self:RegisterEvent("PLAYER_LOGOUT")

    if not self.SA_LANGUAGE[sadb.path] then sadb.path = self.SA_LOCALEPATH[GetLocale()] end
    self.throttled = {}
    self.smarter = 0
    self.pveModePlayers = {}

    -- Proximity alert caches
    self.proximityAlertCache = {}
    self.proximityRecentGUIDs = {}
    self.guidToClassCache = {}
    self.enterWorldTime = 0

    -- Phase 1: Negative lookup cache (all zones)
    self.failedGUIDLookups = {}  -- GUID → timestamp

    -- Phase 0: Performance metrics (MUST be initialized BEFORE InitializeLearnedClassesCache)
    self.classDetectionStats = {
        totalDetections = 0,
        cacheHits = 0,
        learnedCacheHits = 0,
        negativeCacheHits = 0,
        unitLookups = 0,
        apiLookups = 0,
        failedLookups = 0,
        totalLookupTime = 0,
        learnedClassCount = 0,
    }

    -- Phase 3: Persistent learned cache (all zones)
    self:InitializeLearnedClassesCache()

    -- Initialize proximity toast system
    if self.ProximityToasts then
        self.ProximityToasts:Initialize()
    end

    -- Initialize resource bar system (Feral Druid)
    if self.ResourceBar then
        self.ResourceBar:Initialize()
    end

    -- Initialize battleground flag alerts system
    if self.FlagAlerts then
        if sadb.battlegroundAlertsEnabled then
            self.FlagAlerts:Enable()
        end
    end

    -- Initialize statistics tracking
    self:InitializeStatistics()

    self:ScheduleRepeatingTimer("CleanupProximityCaches", 30)
    self:ScheduleRepeatingTimer("SaveLearnedClasses", 60)

    GameTooltip:HookScript("OnTooltipSetUnit", function(tip)
        local name, server = tip:GetUnit()
        local Realm = GetRealmName()
        if (SA_sponsors and SA_sponsors[name]) then
            if (SA_sponsors[name]["Realm"] == Realm) then
                tip:AddLine(SA_sponsors[SA_sponsors[name].Type], 1, 0, 0)
            end
        end
    end)
end

function SoundAlerter:PlayTrinket()
    PlaySoundFile(sadb.sapath.."Trinket.mp3");

    -- Record statistics for trinket alerts
    if sadb.statistics and sadb.statistics.enabled then
        self:RecordAlert("trinketAlerts")
    end
end

function SoundAlerter:Interrupted()
    PlaySoundFile(sadb.sapath.."Interrupted.mp3");
end

function SoundAlerter:PlaySpell(list, spellID, ...)
    if list[spellID] then
        if not sadb[list[spellID]] then return end
        if sadb.debugmode then print("<SA> DEBUG: Playing sound file: "..list[spellID]..".mp3"); end
        PlaySoundFile(sadb.sapath..list[spellID]..".mp3");

        -- Record statistics for spell alerts
        if sadb.statistics and sadb.statistics.enabled then
            self:RecordAlert("spellAlerts", spellID)
        end
    end
end

-- ===========================
-- Statistics Tracking Functions
-- ===========================

function SoundAlerter:RecordAlert(category, spellID)
    if not sadb.statistics or not sadb.statistics.enabled then return end

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
        self:UpdateTopSpells(spellID)
    end

    if sadb.debugmode then
        print(string.format("<SA> STATS: Recorded %s alert (Total: %d)", category, sadb.statistics.session.totalAlerts))
    end
end

function SoundAlerter:UpdateTopSpells(spellID)
    if not sadb.statistics or not spellID then return end

    local topSpells = sadb.statistics.allTime.topSpells
    local maxSpells = sadb.statistics.maxTopSpells or 50

    -- Update or insert spell
    if topSpells[spellID] then
        -- Existing spell - increment count
        topSpells[spellID].count = topSpells[spellID].count + 1
        topSpells[spellID].lastSeen = time()
    else
        -- New spell - check if we need to evict
        local count = 0
        for _ in pairs(topSpells) do count = count + 1 end

        if count >= maxSpells then
            -- Find least recently used spell
            local oldestSpellID, oldestTime = nil, math.huge
            for sID, data in pairs(topSpells) do
                if data.lastSeen < oldestTime then
                    oldestTime = data.lastSeen
                    oldestSpellID = sID
                end
            end

            -- Evict oldest spell
            if oldestSpellID then
                topSpells[oldestSpellID] = nil
                if sadb.debugmode then
                    print(string.format("<SA> STATS: Evicted spell %d (LRU)", oldestSpellID))
                end
            end
        end

        -- Insert new spell
        local spellName = GetSpellInfo(spellID) or "Unknown Spell"
        topSpells[spellID] = {
            count = 1,
            lastSeen = time(),
            name = spellName,
        }
    end
end

function SoundAlerter:GetCurrentZoneType()
    -- Determine current zone type for statistics
    local inInstance, instanceType = IsInInstance()

    if instanceType == "arena" then
        return "arena"
    elseif instanceType == "pvp" then
        return "battleground"
    elseif sadb.field then
        -- World PvP
        return "worldPvP"
    end

    return nil
end

function SoundAlerter:FormatTimeAgo(timestamp)
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

function SoundAlerter:InitializeStatistics()
    -- Initialize session statistics
    if sadb.statistics and sadb.statistics.enabled then
        sadb.statistics.session = {
            totalAlerts = 0,
            startTime = GetTime(),
            byCategory = {
                spellAlerts = 0,
                proximityAlerts = 0,
                trinketAlerts = 0,
                flagAlerts = 0,
            },
        }

        -- Increment session counter
        sadb.statistics.allTime.totalSessions = (sadb.statistics.allTime.totalSessions or 0) + 1

        -- Set tracking start time if not set
        if not sadb.statistics.trackingStartTime or sadb.statistics.trackingStartTime == 0 then
            sadb.statistics.trackingStartTime = time()
        end

        if sadb.debugmode then
            self:Print(string.format("Statistics initialized (Session #%d)", sadb.statistics.allTime.totalSessions))
        end
    end
end

function SoundAlerter:spellOptions(order, spellID, ...)
    local spellname, _, icon = GetSpellInfo(spellID)
    
    if spellname ~= nil then
        return {
            type = 'toggle',
            name = "\124T"..icon..":24\124t"..spellname,
            desc = function ()
                local spellLink = GetSpellLink(spellID)
                if spellLink then
                    GameTooltip:SetHyperlink(spellLink);
                end
            end,
            descStyle = "custom",
            order = order,
        }
    else
        return {
            type = 'description',
            name = "Unknown Spell ID (" .. spellID .. ")",
            desc = "This spell ID could not be found by your WoW client. It has been disabled.",
            order = order,
            disabled = true,
        }
    end
end

function SoundAlerter:ArenaClass(id)
    for i = 1, 5 do
        if id == UnitGUID("arena"..i) then
            return select(2, UnitClass("arena"..i))
        end
    end
end

function SoundAlerter:IsInPVEMode(guid)
    local currentZoneType, pvpType = IsInInstance()
    if currentZoneType == "pvp" or currentZoneType == "arena" or pvpType == "arena" then
        return false
    end

    if self.pveModePlayers[guid] then
        return true
    end

    local unit = nil
    if UnitExists("target") and UnitGUID("target") == guid then unit = "target"
    elseif UnitExists("focus") and UnitGUID("focus") == guid then unit = "focus"
    elseif UnitExists("mouseover") and UnitGUID("mouseover") == guid then unit = "mouseover"
    end

    if unit then
        for i = 1, 40 do
            local name, _, _, _, _, _, _, _, _, _, spellId = UnitAura(unit, i)
            if not name then break end
            if spellId == 9931032 then
                self.pveModePlayers[guid] = true
                if sadb.debugmode then
                    self:Print("PVE Mode detected on " .. UnitName(unit) .. " via UnitAura scan")
                end
                return true
            end
        end
    end

    return false
end

function SoundAlerter:PLAYER_ENTERING_WORLD()
    CombatLogClearEntries()
    self.enterWorldTime = GetTime()
    self.pveModePlayers = {}
end

-- Phase 3: Save learned classes on logout
function SoundAlerter:PLAYER_LOGOUT()
    self:SaveLearnedClasses()
    if sadb.debugmode then
        self:Print("Saved learned classes on logout")
    end
end

-- Phase 0: Command handler
function SoundAlerter:HandleCommand(input)
    local args = {}
    for word in string.gmatch(input, "%S+") do
        table.insert(args, string.lower(word))
    end

    local command = args[1]

    if command == "stats" or command == "perf" then
        self:ShowPerformanceStats()
    else
        self:ShowConfig()
    end
end

-- Phase 0: Display performance statistics
function SoundAlerter:ShowPerformanceStats()
    local stats = self.classDetectionStats

    self:Print("=== |cffFF7D0AClass Detection Performance Stats|r ===")

    -- Total detections
    self:Print("Total detections: |cff00FF00" .. stats.totalDetections .. "|r")

    if stats.totalDetections > 0 then
        -- Cache hit rates
        local cacheHitRate = (stats.cacheHits / stats.totalDetections) * 100
        local learnedHitRate = (stats.learnedCacheHits / stats.totalDetections) * 100
        local negativeHitRate = (stats.negativeCacheHits / stats.totalDetections) * 100
        local totalHitRate = ((stats.cacheHits + stats.learnedCacheHits + stats.negativeCacheHits) / stats.totalDetections) * 100

        self:Print("Cache hits: |cff00FF00" .. stats.cacheHits .. "|r (" .. string.format("%.1f%%", cacheHitRate) .. ")")
        self:Print("Learned cache hits: |cff00FF00" .. stats.learnedCacheHits .. "|r (" .. string.format("%.1f%%", learnedHitRate) .. ")")
        self:Print("Negative cache hits: |cffFFFF00" .. stats.negativeCacheHits .. "|r (" .. string.format("%.1f%%", negativeHitRate) .. ")")
        self:Print("Total fast-path: |cff00FF00" .. string.format("%.1f%%", totalHitRate) .. "|r")

        -- Lookup methods
        self:Print("Unit lookups: |cff00FFFF" .. stats.unitLookups .. "|r")
        self:Print("API lookups (GetPlayerInfoByGUID): |cff00FFFF" .. stats.apiLookups .. "|r")
        self:Print("Failed lookups: |cffFF0000" .. stats.failedLookups .. "|r")

        -- Average lookup time
        local avgTime = (stats.totalLookupTime / stats.totalDetections) * 1000000  -- Convert to microseconds
        self:Print("Avg lookup time: |cffFFFF00" .. string.format("%.2f", avgTime) .. "µs|r")
    end

    -- Learned classes count
    self:Print("Learned classes: |cff00FF00" .. stats.learnedClassCount .. "|r")

    -- Settings status
    local learnedStatus = sadb.learnedClassesEnabled and "|cff00FF00Enabled|r" or "|cffFF0000Disabled|r"
    local negativeStatus = sadb.negativeCacheEnabled and "|cff00FF00Enabled|r" or "|cffFF0000Disabled|r"
    self:Print("Persistent cache: " .. learnedStatus)
    self:Print("Negative cache: " .. negativeStatus)

    self:Print("Use |cffFFFF00/sa stats|r to refresh")
end

function SoundAlerter:CleanupProximityCaches()
    local currentTime = GetTime()
    local cooldown = sadb.proximityCooldown or 30

    -- Remove expired alerts
    for guid, timestamp in pairs(self.proximityAlertCache) do
        if currentTime - timestamp > cooldown then
            self.proximityAlertCache[guid] = nil
        end
    end

    -- Cap guidToClassCache at 500 entries (prevent memory leak)
    local cacheSize = 0
    for _ in pairs(self.guidToClassCache) do
        cacheSize = cacheSize + 1
    end
    if cacheSize > 500 then
        local entriesToRemove = cacheSize - 500
        local removed = 0
        for guid in pairs(self.guidToClassCache) do
            self.guidToClassCache[guid] = nil
            removed = removed + 1
            if removed >= entriesToRemove then
                break
            end
        end
    end

    -- Clear recent GUID spam filter
    for guid in pairs(self.proximityRecentGUIDs) do
        self.proximityRecentGUIDs[guid] = nil
    end

    -- Phase 1: Clean up negative lookup cache
    if sadb.negativeCacheEnabled then
        local negativeTTL = sadb.negativeCacheTTL or 5
        for guid, timestamp in pairs(self.failedGUIDLookups) do
            if currentTime - timestamp > negativeTTL then
                self.failedGUIDLookups[guid] = nil
            end
        end
    end

    if sadb.debugmode then
        local cacheSize = 0
        for _ in pairs(self.proximityAlertCache) do
            cacheSize = cacheSize + 1
        end
        if cacheSize > 0 then
            self:Print("Proximity cache cleanup: " .. cacheSize .. " active alerts")
        end
    end
end

-- Phase 3: Initialize persistent learned classes cache
function SoundAlerter:InitializeLearnedClassesCache()
    if not sadb.learnedClassesEnabled then
        self.learnedClasses = {}
        return
    end

    -- Validate and load from SavedVariables
    if not sadb.learnedClasses or type(sadb.learnedClasses) ~= "table" then
        sadb.learnedClasses = {}
    end

    self.learnedClasses = sadb.learnedClasses
    self.learnedClassesDirty = false

    -- Count entries
    local count = 0
    for _ in pairs(self.learnedClasses) do
        count = count + 1
    end

    -- Enforce size limit
    local maxSize = sadb.learnedClassesMaxSize or 5000
    if count > maxSize then
        if sadb.debugmode then
            self:Print("Learned classes cache too large (" .. count .. "), limiting to " .. maxSize)
        end
        self:LimitLearnedClassesCache(maxSize)
        count = maxSize
    end

    self.classDetectionStats.learnedClassCount = count

    if sadb.debugmode then
        self:Print("Loaded " .. count .. " learned player classes from cache")
    end
end

-- Phase 3: Limit cache size by removing oldest entries
function SoundAlerter:LimitLearnedClassesCache(maxSize)
    local entries = {}
    for guid, class in pairs(self.learnedClasses) do
        table.insert(entries, guid)
    end

    -- Keep newest entries (simple random eviction for now)
    if #entries > maxSize then
        local toRemove = #entries - maxSize
        for i = 1, toRemove do
            self.learnedClasses[entries[i]] = nil
        end
    end

    sadb.learnedClasses = self.learnedClasses
    self.learnedClassesDirty = false
end

-- Phase 3: Save learned classes (called every 60 seconds)
function SoundAlerter:SaveLearnedClasses()
    if not sadb.learnedClassesEnabled then return end
    if not self.learnedClassesDirty then return end

    sadb.learnedClasses = self.learnedClasses
    self.learnedClassesDirty = false

    -- Update count
    local count = 0
    for _ in pairs(self.learnedClasses) do
        count = count + 1
    end
    self.classDetectionStats.learnedClassCount = count

    if sadb.debugmode then
        self:Print("Saved " .. count .. " learned classes to cache")
    end
end

function SoundAlerter:HandleAuraApplied(sourceGUID, sourceName, destGUID, destName, spellID)
    local currentZoneType, pvpType = IsInInstance()
    
    if desttype[COMBATLOG_FILTER_HOSTILE_PLAYERS] then
        if sourcetype[COMBATLOG_FILTER_ME] then
            if not sadb.enemydebuff then
                self:PlaySpell(self.spellList.enemyDebuffs, spellID)
            end
            if not sadb.chatalerts then
                if (((spellID == 6770 or spellID == 11297 or spellID == 51724) and sadb.sapenemy) or (spellID == 2094 and sadb.blindenemy) or (spellID == 33786 and sadb.cycloneenemy) or (spellID == 51514 and sadb.hexenemy) or (spellID == 5782 and sadb.fearenemy)) then
                    local ccenemychat = gsub(sadb.enemychat, "(#spell#)", GetSpellLink(spellID))
                    local message = gsub(ccenemychat, "(#enemy#)", destName)
                    if not sadb.chatgroups.NONE then
                        for channel, enabled in pairs(sadb.chatgroups) do
                            if enabled and channel ~= "NONE" then
                                SendChatMessage(message, channel, nil, nil)
                            end
                        end
                    end
                end
            end
        elseif (sourcetype[COMBATLOG_FILTER_FRIENDLY_UNITS] and (destuid.target or destuid.focus) and not sadb.dArenaPartner) then
            self:PlaySpell(self.spellList.friendCCenemy, spellID)
        elseif ((sadb.myself and (destuid.target or destuid.focus)) or sadb.enemyinrange) and not sadb.castSuccess then
            self:PlaySpell(self.spellList.auraApplied, spellID)
        end
    elseif desttype[COMBATLOG_FILTER_ME] then
        if not sadb.chatalerts then
            if sourcetype[COMBATLOG_FILTER_HOSTILE_PLAYERS] or ((spellID == 6770 or spellID == 11297 or spellID == 51724) and sadb.sapselffriend) then
                if ((spellID == 51514 and sadb.hexselffriend) or
                    (spellID == 33786 and sadb.cycloneselffriend) or
                    ((spellID == 6215 or spellID == 17928 or spellID == 5484) and sadb.fearselffriend) or
                    ((spellID == 12826 or spellID == 118 or spellID == 28271 or spellID == 28272) and sadb.polyenemy) or
                    (spellID == 2094 and sadb.blindselffriend)) then
                        local form1 = gsub(sadb.selfchat, "(#spell#)", GetSpellLink(spellID))
                        local form2 = gsub(form1, "(#target#)", "me")
                        local message = gsub(form2, "(#enemy#)", sourceName)
                        if not sadb.chatgroups.NONE then
                            for channel, enabled in pairs(sadb.chatgroups) do
                                if enabled and channel ~= "NONE" then
                                    SendChatMessage(message, channel, nil, nil)
                                end
                            end
                        end
                elseif (spellID == 6770 or spellID == 11297 or spellID == 51724) and sadb.sapselffriend then
                        local message = gsub(sadb.sapselftext, "(#spell#)", GetSpellLink(spellID))
                        if not sadb.chatgroups.NONE then
                            for channel, enabled in pairs(sadb.chatgroups) do
                                if enabled and channel ~= "NONE" then
                                    SendChatMessage(message, channel, nil, nil)
                                end
                            end
                        end
                end
            end
        end
        if not sourceuid.target and not sourceuid.focus and not sadb.dselfDebuff then
            self:PlaySpell(self.spellList.selfDebuff, spellID)
        end
    elseif desttype[COMBATLOG_FILTER_FRIENDLY_UNITS] then
        if (not sadb.chatalerts and not desttype[COMBATLOG_FILTER_ME] and (destuid.target or destuid.focus or (currentZoneType == "arena" or pvpType == "arena"))) then
            if (spellID == 6770 or spellID == 11297 or spellID == 51724) and sadb.sapselffriend then
                local sapfriendtext = gsub(sadb.sapfriendtext, "(#spell#)", GetSpellLink(spellID))
                local message = gsub(sapfriendtext, "(#friend#)", destName)
                if not sadb.chatgroups.NONE then
                    for channel, enabled in pairs(sadb.chatgroups) do
                        if enabled and channel ~= "NONE" then
                            SendChatMessage(message, channel, nil, nil)
                        end
                    end
                end
            elseif ((spellID == 51514 and sadb.hexselffriend) or
                (spellID == 642 and sadb.bubbleselffriend) or
                (spellID == 33786 and sadb.cycloneselffriend) or
                ((spellID == 6215 or spellID == 17928 or spellID == 5484) and sadb.fearselffriend) or
                ((spellID == 12826 or spellID == 118 or spellID == 28271 or spellID == 28272) and sadb.polyenemy) or
                (spellID == 2094 and sadb.blindselffriend)) then
                    local form1 = gsub(sadb.friendchat, "(#spell#)", GetSpellLink(spellID))
                    local form2 = gsub(form1, "(#friend#)", destName)
                    local message = gsub(form2, "(#enemy#)", sourceName)
                    if not sadb.chatgroups.NONE then
                        for channel, enabled in pairs(sadb.chatgroups) do
                            if enabled and channel ~= "NONE" then
                                SendChatMessage(message, channel, nil, nil)
                            end
                        end
                    end
            end
        end
    end
end

function SoundAlerter:HandleAuraRemoved(sourceGUID, destGUID, destName, spellID)
    local currentZoneType, pvpType = IsInInstance()
    
    if desttype[COMBATLOG_FILTER_HOSTILE_PLAYERS] and ((sourcetype[COMBATLOG_FILTER_ME] or (destuid.target or destuid.focus))) then
        if sourcetype[COMBATLOG_FILTER_FRIENDLY_UNITS] and ((destuid.target or (currentZoneType == "arena" or pvpType == "arena")) and not sadb.dArenaPartner) then
            self:PlaySpell(self.spellList.enemyDebuffdownAP, spellID)
        elseif sourcetype[COMBATLOG_FILTER_ME] and not sadb.dEnemyDebuffDown then
            self:PlaySpell(self.spellList.enemyDebuffdown, spellID)
        elseif sourcetype[COMBATLOG_FILTER_HOSTILE_PLAYERS] and not sadb.aruaRemoved then
            self:PlaySpell(self.spellList.auraRemoved, spellID)
        end
        
        if (not sadb.chatalerts and ((sourcetype[COMBATLOG_FILTER_ME] and sadb.chatdownself) or ((not sadb.caonlyTF or destuid.target or destuid.focus) and sadb.chatdownfriend))) then
            if ((spellID == 33786 and sadb.cycloneenemy) or 
                (spellID == 51514 and sadb.hexenemy) or
                (spellID == 2094 and sadb.blindenemy) or
                ((spellID == 6770 or spellID == 11297 or spellID == 51724) and sadb.sapenemy) or 
                ((spellID == 12826 or spellID == 118 or spellID == 28271 or spellID == 28272) and sadb.polyenemy) or 
                ((spellID == 6215 or spellID == 5484 or spellID == 17928) and sadb.fearenemy)) then
                    SendChatMessage(GetSpellLink(spellID).." down on "..destName)
            end
        end
    end
end

function SoundAlerter:HandleCastSuccess(sourceGUID, sourceName, destName, spellID)
    local currentZoneType, pvpType = IsInInstance()
    
    if sourcetype[COMBATLOG_FILTER_HOSTILE_PLAYERS] then
        if (not sadb.chatalerts) then
            -- Check for Vanish (retail: 26889, Ascension: 1126889)
            local isVanish = (spellID == 26889 or spellID == 1126889)
            -- Check for Stealth (retail: 1784/1785, Ascension: 1101784/1101785)
            local isStealth = (spellID == 1784 or spellID == 1785 or spellID == 1101784 or spellID == 1101785)
            -- Check for Prowl (retail: 5215/6783/9913, Ascension: 1105215/1106783/1109913)
            local isProwl = (spellID == 5215 or spellID == 6783 or spellID == 9913 or spellID == 1105215 or spellID == 1106783 or spellID == 1109913)

            if (
                ((sadb.vanishenemy and isVanish) or (sadb.stealthenemy and isStealth) or (sadb.prowlenemy and isProwl))
                and
                ( (sourceuid.target or sourceuid.focus) or ((sadb.vanishTF and isVanish) or (sadb.stealthTF and isStealth) or (sadb.prowlTF and isProwl)) )
            ) then
                local message = gsub(gsub(sadb.enemychat,"(#spell#)", GetSpellLink(spellID)),"(#enemy#)", sourceName)
                if not sadb.chatgroups.NONE then
                    for channel, enabled in pairs(sadb.chatgroups) do
                        if enabled and channel ~= "NONE" then
                            SendChatMessage(message, channel, nil, nil)
                        end
                    end
                end
            end
        end
        
        -- Trinket alerts: Check both retail and Ascension (11-prefixed) spell IDs
        if ((spellID == 42292 or spellID == 59752 or spellID == 1142292 or spellID == 1159752) and sadb.trinket) then
            if ((currentZoneType == "arena" or pvpType == "arena") or (sourceuid.target or sourceuid.focus)) then
                local c = self:ArenaClass(sourceGUID)
                if (c and sadb.class) then
                    PlaySoundFile(sadb.sapath..c..".mp3");
                    self:ScheduleTimer("PlayTrinket", 0.4);
                else
                    self:PlayTrinket()
                end
            end
        elseif ((sadb.myself and (sourceuid.target or sourceuid.focus)) or sadb.enemyinrange) and not sadb.castSuccess then    
            if not (sadb.enemyinrange and (spellID == 2825 or spellID == 32182)) then
                self:PlaySpell(self.spellList.castSuccess, spellID)
            elseif (sourceuid.target or sourceuid.focus) then
                self:PlaySpell(self.spellList.castSuccess, spellID)
            end
        end                       
    elseif (desttype[COMBATLOG_FILTER_FRIENDLY_UNITS] and not desttype[COMBATLOG_FILTER_ME] and ((destuid.target or destuid.focus) or (currentZoneType == "arena" or pvpType == "arena")) and not sadb.dArenaPartner) then
        self:PlaySpell(self.spellList.friendCCSuccess, spellID)
    end
end

function SoundAlerter:HandleInterrupt(sourceName, destName, spellID, extraSpellID)
    local interruptedSpellLink = GetSpellLink(extraSpellID)
    local interruptedSpellName = GetSpellInfo(extraSpellID)
    local replacementText = interruptedSpellLink or interruptedSpellName or ""
    
    if (desttype[COMBATLOG_FILTER_ME] and not sadb.interrupt) then
        PlaySoundFile(sadb.sapath.."lockout.mp3");
        if (not sadb.chatalerts) then
            if (sadb.interruptself) then
                local it = gsub(sadb.InterruptSelfText, "(#spell#)", (GetSpellLink(spellID) or ""))
                
                local new_it, count = gsub(it, "#interruptedspellname#", replacementText)
                it = new_it
                
                local finalMessage = gsub(it, "(#enemy#)", sourceName)
                finalMessage = string.gsub(finalMessage, "[\\]", "")
                
                if not sadb.chatgroups.NONE then
                    for channel, enabled in pairs(sadb.chatgroups) do
                        if enabled and channel ~= "NONE" then
                            SendChatMessage(finalMessage, channel, nil, nil)
                        end
                    end
                end
            end
        end
    elseif (sourcetype[COMBATLOG_FILTER_ME] and not sadb.interrupt) then
        if ((destuid.target or destuid.focus) and (desttype[COMBATLOG_FILTER_HOSTILE_PLAYERS] or desttype[COMBATLOG_FILTER_HOSTILE_UNITS])) then
            PlaySoundFile(sadb.sapath.."lockout.mp3");
            if (not sadb.chatalerts) then
                if (sadb.interruptenemy) then
                    local it = gsub(sadb.InterruptEnemyText, "(#spell#)", (GetSpellLink(spellID) or ""))
                    
                    local new_it, count = gsub(it, "#interruptedspellname#", replacementText)
                    it = new_it

                    local finalMessage = gsub(it, "(#enemy#)", destName)
                    finalMessage = string.gsub(finalMessage, "[\\]", "")

                    if not sadb.chatgroups.NONE then
                        for channel, enabled in pairs(sadb.chatgroups) do
                            if enabled and channel ~= "NONE" then
                                SendChatMessage(finalMessage, channel, nil, nil)
                            end
                        end
                    end
                end
            end
        end
    end
end

function SoundAlerter:HandleCastStart(sourceGUID, sourceName, spellID)
    local currentZoneType, pvpType = IsInInstance()

    if sourcetype[COMBATLOG_FILTER_HOSTILE_PLAYERS] then
        if not sadb.castStart and (sadb.myself and (sourceuid.target or sourceuid.focus) or sadb.enemyinrange) then
            self:PlaySpell(self.spellList.castStart, spellID)
        elseif ((currentZoneType == "arena") or (pvpType == "arena")) and not sadb.dArenaPartner then
            for i = 1, 6 do
                if i == 6 then
                    self:PlaySpell(self.spellList.friendCCs, spellID)
                    break
                elseif playerName == UnitName("arena"..i.."target") then
                    self:PlaySpell(self.spellList.castStart, spellID)
                    break
                end
            end
        end
    end
end

function SoundAlerter:COMBAT_LOG_EVENT_UNFILTERED(event , ...)
    local timestamp, event, sourceGUID, sourceName, sourceFlags, destGUID, destName, destFlags, spellID, spellName, _, extraSpellID = select(1, ...);

    local HOSTILE_PLAYERS_FILTER = COMBATLOG_FILTER_HOSTILE_PLAYERS
    local _, currentZoneType = IsInInstance()
    local pvpType = GetZonePVPInfo()

    if spellID == 9931032 and currentZoneType ~= "pvp" and currentZoneType ~= "arena" and pvpType ~= "arena" then
        if event == "SPELL_AURA_APPLIED" then
            self.pveModePlayers[destGUID] = true
            if sadb.debugmode then
                self:Print((destName or "Unknown") .. " entered PVE Mode via combat log")
            end
        elseif event == "SPELL_AURA_REMOVED" then
            self.pveModePlayers[destGUID] = nil
            if sadb.debugmode then
                self:Print((destName or "Unknown") .. " left PVE Mode via combat log")
            end
        end
    end

    local isFFA, faction = GetZonePVPInfo();

    if (not ((pvpType == "contested" and sadb.field) or (pvpType == "hostile" and sadb.field) or (pvpType == "friendly" and sadb.field) or (currentZoneType == "pvp" and sadb.battleground) or (((currentZoneType == "arena") or (pvpType == "arena")) and sadb.arena) or sadb.all)) then
        return
    end

    if sadb.proximityEnabled and sourceGUID and sourceName and CombatLog_Object_IsA(sourceFlags, HOSTILE_PLAYERS_FILTER) then
        if not (sadb.ignorePVEMode and self:IsInPVEMode(sourceGUID)) then
            self:CheckProximityAlertFromCombatLog(sourceGUID, sourceName, sourceFlags)
        end
    end

    if sadb.ignorePVEMode and currentZoneType ~= "pvp" and currentZoneType ~= "arena" and pvpType ~= "arena" then
        if sourceGUID and self:IsInPVEMode(sourceGUID) then
            if sadb.debugmode then
                self:Print("Ignoring event from " .. (sourceName or "unknown") .. " - PVE Mode")
            end
            return
        end

        if destGUID and self:IsInPVEMode(destGUID) then
            if sadb.debugmode then
                self:Print("Ignoring event on " .. (destName or "unknown") .. " - PVE Mode")
            end
            return
        end
    end

    -- Parse all combat flags for spell alert logic
    for k in pairs(self.SA_TYPE) do
        desttype[k] = CombatLog_Object_IsA(destFlags, k)
        sourcetype[k] = CombatLog_Object_IsA(sourceFlags, k)
    end

    for k in pairs(self.SA_UNIT) do
        destuid[k], sourceuid[k] = nil, nil
        if k == "party" and UnitName("party1") ~= nil then
            for i = 1, MAX_PARTY_MEMBERS do
                if destGUID == UnitGUID(k..i) then destuid[k] = true; end
                if sourceGUID == UnitGUID(k..i) then sourceuid[k] = true; end
                if destuid[k] and sourceuid[k] then break end
            end
        elseif k == "arena" and currentZoneType == "arena" then
            for i = 1, 5 do
                if destGUID == UnitGUID(k..i) then destuid[k] = true; end
                if sourceGUID == UnitGUID(k..i) then sourceuid[k] = true; end
                if destuid[k] and sourceuid[k] then break end
            end
        else
            if destGUID then destuid[k] = (UnitGUID(k) == destGUID); end
            if sourceGUID then sourceuid[k] = (UnitGUID(k) == sourceGUID); end
        end
    end
    destuid.any, sourceuid.any = true, true

    if sadb.debugmode and sadb.spelldebug then
        print(spellName, spellID, event, sourceName, destName)
    end
    if sadb.debugmode and spellName == sadb.csname and spellName then
        print("Custom spell name: "..spellName, spellID, event, sourceName, destName)
    end

    if desttype[COMBATLOG_FILTER_HOSTILE_PLAYERS] and event == "SPELL_CREATE" and (spellID == 13809 or spellID == 13810 or spellID == 1499) and ((sadb.myself and (destuid.target or destuid.focus)) or sadb.enemyinrange) then
        self:PlaySpell(self.spellList.castSuccess, spellID)
    end
    
    if event == "SPELL_AURA_APPLIED" then
        self:HandleAuraApplied(sourceGUID, sourceName, destGUID, destName, spellID)
    elseif event == "SPELL_AURA_REMOVED" then
        self:HandleAuraRemoved(sourceGUID, destGUID, destName, spellID)
    elseif event == "SPELL_CAST_SUCCESS" then
        self:HandleCastSuccess(sourceGUID, sourceName, destName, spellID)
    elseif event == "SPELL_INTERRUPT" then
        self:HandleInterrupt(sourceName, destName, spellID, extraSpellID)
    elseif event == "SPELL_CAST_START" then
        self:HandleCastStart(sourceGUID, sourceName, spellID)
    end

    for k, css in pairs(sadb.custom) do
        destuid.custom = (css.destuidfilter == "custom" and destName == css.destcustomname)
        sourceuid.custom = (css.sourceuidfilter == "custom" and sourceName == css.sourcecustomname)
        
        if sadb.debugmode and css.name == sadb.cspell and (spellID == tonumber(css.spellid) or (css.acceptSpellName and (css.spellname == spellName))) then
            log(css.name..": event: "..(css.eventtype[event] and "true" or "false")..", actual event: "..event..", dest spell: "..(destuid[css.destuidfilter] and "true" or "false")..", dest type: "..(desttype[css.desttypefilter] and "true" or "false")..", sourceunit: "..(sourceuid[css.sourceuidfilter] and "true" or "false")..", source type: "..(sourcetype[css.sourcetypefilter] and "true" or "false"))
        end
        
        if css.eventtype[event] and destuid[css.destuidfilter] and desttype[css.desttypefilter] and sourceuid[css.sourceuidfilter] and sourcetype[css.sourcetypefilter] and (spellID == tonumber(css.spellid) or (css.acceptSpellName and (css.spellname == spellName))) then
            if sadb.debugmode then
                self:Print("playing css "..css.name)
            end
            
            if not css.chatAlert then
                PlaySoundFile("Interface\\Addons\\SoundAlerter\\CustomSounds\\"..css.soundfilepath,"Master")
            else
                local spell = gsub(css.chatalerttext, "([#]spell[#])", GetSpellLink(spellID))
                local targetName = destuid[css.destuidfilter] and destName or sourceName
                
                local message = ""
                if event == "SPELL_CAST_START" then
                    message = gsub(spell, "([#]enemy[#])", "")
                else
                    message = gsub(spell, "([#]enemy[#])", targetName)
                end
                
                if not sadb.chatgroups.NONE then
                    for channel, enabled in pairs(sadb.chatgroups) do
                        if enabled and channel ~= "NONE" then
                            SendChatMessage(message, channel, nil, nil)
                        end
                    end
                end
            end
        end
    end
end

local DRINK_SPELL = GetSpellInfo(57073)
function SoundAlerter:UNIT_AURA(event, uid)
    local currentZoneType, pvpType = IsInInstance()
    if ((currentZoneType == "arena") or (pvpType == "arena")) and sadb.drinking then
        if UnitAura(uid, DRINK_SPELL) then
            PlaySoundFile(sadb.sapath.."drinking.mp3");
        end
    end
end

-- ========================================
-- PROXIMITY ALERT SYSTEM
-- ========================================

-- Class name mapping for audio files (lowercase to match file names)
local CLASS_AUDIO_MAP = {
    ["WARRIOR"] = "Warrior",
    ["MAGE"] = "Mage",
    ["PRIEST"] = "Priest",
    ["ROGUE"] = "Rogue",
    ["HUNTER"] = "Hunter",
    ["DRUID"] = "druid",
    ["PALADIN"] = "Paladin",
    ["WARLOCK"] = "Warlock",
    ["SHAMAN"] = "Shaman",
    ["DEATHKNIGHT"] = "Deathknight"
}

function SoundAlerter:GetClassFromGUID(guid, currentZoneType, pvpType)
    local startTime = GetTime()

    -- Phase 0: Track total detections (safety check)
    if self.classDetectionStats then
        self.classDetectionStats.totalDetections = self.classDetectionStats.totalDetections + 1
    end

    -- 1. Check memory cache (session)
    local cachedClass = rawget(self.guidToClassCache, guid)
    if cachedClass then
        if self.classDetectionStats then
            self.classDetectionStats.cacheHits = self.classDetectionStats.cacheHits + 1
            self.classDetectionStats.totalLookupTime = self.classDetectionStats.totalLookupTime + (GetTime() - startTime)
        end
        return cachedClass
    end

    -- Phase 3: Check persistent learned cache (ALL zones)
    if sadb.learnedClassesEnabled and self.learnedClasses and self.learnedClasses[guid] then
        local learnedClass = self.learnedClasses[guid]
        self.guidToClassCache[guid] = learnedClass  -- Warm up L1 cache
        if self.classDetectionStats then
            self.classDetectionStats.learnedCacheHits = self.classDetectionStats.learnedCacheHits + 1
            self.classDetectionStats.totalLookupTime = self.classDetectionStats.totalLookupTime + (GetTime() - startTime)
        end
        return learnedClass
    end

    -- Phase 1: Check negative lookup cache (ALL zones)
    if sadb.negativeCacheEnabled and self.failedGUIDLookups and self.failedGUIDLookups[guid] then
        local failTime = self.failedGUIDLookups[guid]
        local negativeTTL = sadb.negativeCacheTTL or 5
        if GetTime() - failTime < negativeTTL then
            -- Skip expensive scan
            if self.classDetectionStats then
                self.classDetectionStats.negativeCacheHits = self.classDetectionStats.negativeCacheHits + 1
                self.classDetectionStats.totalLookupTime = self.classDetectionStats.totalLookupTime + (GetTime() - startTime)
            end
            return nil
        end
    end

    local unitClass = nil

    -- Check common units first
    if UnitExists("target") and UnitGUID("target") == guid then
        _, unitClass = UnitClass("target")
    elseif UnitExists("mouseover") and UnitGUID("mouseover") == guid then
        _, unitClass = UnitClass("mouseover")
    elseif UnitExists("focus") and UnitGUID("focus") == guid then
        _, unitClass = UnitClass("focus")
    else
        -- Arena units
        if currentZoneType == "arena" or pvpType == "arena" then
            for i = 1, 5 do
                local arenaUnit = "arena" .. i
                if UnitExists(arenaUnit) and UnitGUID(arenaUnit) == guid then
                    _, unitClass = UnitClass(arenaUnit)
                    break
                end
            end
        end

        -- Battleground raid targets (MAJOR BOTTLENECK - learned cache helps most here!)
        if not unitClass and currentZoneType == "pvp" then
            local numRaidMembers = GetNumRaidMembers()
            if numRaidMembers > 0 then
                for i = 1, numRaidMembers do
                    local bgUnit = "raid" .. i .. "target"
                    if UnitExists(bgUnit) and UnitGUID(bgUnit) == guid then
                        _, unitClass = UnitClass(bgUnit)
                        break
                    end
                end
            end
        end
    end

    -- Phase 3: Try GetPlayerInfoByGUID (ALL zones)
    if not unitClass then
        local _, apiClass = GetPlayerInfoByGUID(guid)
        if apiClass then
            unitClass = apiClass
            if self.classDetectionStats then
                self.classDetectionStats.apiLookups = self.classDetectionStats.apiLookups + 1
            end
        end
    end

    if unitClass then
        -- Cache the result
        self.guidToClassCache[guid] = unitClass
        if self.classDetectionStats then
            self.classDetectionStats.unitLookups = self.classDetectionStats.unitLookups + 1
        end

        -- Phase 3: Persist to learned cache (ALL zones)
        if sadb.learnedClassesEnabled and self.learnedClasses then
            self.learnedClasses[guid] = unitClass
            self.learnedClassesDirty = true
        end
    else
        -- Phase 1: Mark as failed lookup (ALL zones)
        if sadb.negativeCacheEnabled and self.failedGUIDLookups then
            self.failedGUIDLookups[guid] = GetTime()
        end
        if self.classDetectionStats then
            self.classDetectionStats.failedLookups = self.classDetectionStats.failedLookups + 1
        end
    end

    if self.classDetectionStats then
        self.classDetectionStats.totalLookupTime = self.classDetectionStats.totalLookupTime + (GetTime() - startTime)
    end
    return unitClass
end

function SoundAlerter:CheckProximityAlert(unit)
    if not sadb.proximityEnabled then return end

    if not UnitExists(unit) then return end
    if not UnitIsPlayer(unit) then return end
    if not UnitIsEnemy("player", unit) then return end
    if not UnitIsVisible(unit) then return end

    local guid = UnitGUID(unit)
    if not guid then return end

    local guidType = tonumber(guid:sub(5, 5), 16)
    if guidType == 3 or guidType == 4 or guidType == 6 then return end

    if sadb.ignorePVEMode and self:IsInPVEMode(guid) then
        if sadb.debugmode then
            self:Print("Proximity: Skipping " .. UnitName(unit) .. " - PVE Mode")
        end
        return
    end

    -- Cooldown check
    local currentTime = GetTime()
    local cooldown = sadb.proximityCooldown or 30
    if self.proximityAlertCache[guid] then
        local timeElapsed = currentTime - self.proximityAlertCache[guid]
        if timeElapsed < cooldown then return end
    end

    if currentTime - self.enterWorldTime < 10 then return end

    -- Zone checks
    local currentZoneType, pvpType = IsInInstance()
    local zonePvpType = GetZonePVPInfo()

    local inArena = (currentZoneType == "arena") or (pvpType == "arena")
    local inBattleground = (currentZoneType == "pvp")
    local inWorld = (zonePvpType == "contested" or zonePvpType == "hostile" or zonePvpType == "friendly")

    if inArena and not sadb.proximityArena then return end
    if inBattleground and not sadb.proximityBattleground then return end
    if inWorld and not sadb.proximityWorld then return end
    if not (inArena or inBattleground or inWorld) then return end

    local unitName = UnitName(unit)
    local _, unitClass = UnitClass(unit)
    local unitLevel = UnitLevel(unit)

    if not unitName or not unitClass then return end

    self.guidToClassCache[guid] = unitClass
    self.proximityAlertCache[guid] = currentTime

    local classAudioFile = CLASS_AUDIO_MAP[unitClass]
    if classAudioFile then
        PlaySoundFile(sadb.sapath .. classAudioFile .. ".mp3", "Master")
        self:ScheduleTimer(function()
            PlaySoundFile(sadb.sapath .. "detected.mp3", "Master")
        end, 0.8)

        -- Record statistics for proximity alerts
        if sadb.statistics and sadb.statistics.enabled then
            self:RecordAlert("proximityAlerts")
        end
    end

    if sadb.proximityToasts and sadb.proximityToasts.enabled and self.ProximityToasts then
        self.ProximityToasts:ShowToast(unitName, unitClass, nil, guid, unitLevel, unit)
    end

    -- Chat alert
    if sadb.proximityChat and sadb.proximityChatText then
        local chatText = gsub(sadb.proximityChatText, "#class#", unitClass)
        chatText = gsub(chatText, "#player#", unitName)

        if not sadb.chatgroups.NONE then
            for channel, enabled in pairs(sadb.chatgroups) do
                if enabled and channel ~= "NONE" then
                    SendChatMessage(chatText, channel, nil, nil)
                end
            end
        end
    end

    if sadb.debugmode then
        self:Print("Proximity Alert: " .. unitClass .. " " .. unitName .. " detected!")
    end
end

function SoundAlerter:CheckProximityAlertFromCombatLog(guid, name, flags)
    if rawget(self.proximityRecentGUIDs, guid) then return end
    if not sadb.proximityEnabled then return end
    if not guid or not name then return end

    local guidType = tonumber(guid:sub(5, 5), 16)
    if guidType == 3 or guidType == 4 or guidType == 6 then return end

    if sadb.ignorePVEMode and self:IsInPVEMode(guid) then
        if sadb.debugmode then
            self:Print("Proximity (CombatLog): Skipping " .. name .. " - PVE Mode")
        end
        return
    end

    -- Cooldown check
    local currentTime = GetTime()
    local cooldown = sadb.proximityCooldown or 30
    local cachedTime = rawget(self.proximityAlertCache, guid)
    if cachedTime then
        if currentTime - cachedTime < cooldown then
            self.proximityRecentGUIDs[guid] = true
            return
        end
    end

    -- Graceful startup (skip alerts first 10 seconds after loading)
    if currentTime - self.enterWorldTime < 10 then return end

    -- Zone checks (expensive API calls after all cache checks)
    local currentZoneType, pvpType = IsInInstance()
    local zonePvpType = GetZonePVPInfo()

    local zoneAllowed = (
        ((currentZoneType == "arena" or pvpType == "arena") and sadb.proximityArena) or
        (currentZoneType == "pvp" and sadb.proximityBattleground) or
        ((zonePvpType == "contested" or zonePvpType == "hostile" or zonePvpType == "friendly") and sadb.proximityWorld)
    )
    if not zoneAllowed then return end

    local unitClass = self:GetClassFromGUID(guid, currentZoneType, pvpType)

    self.proximityAlertCache[guid] = currentTime
    self.proximityRecentGUIDs[guid] = true

    if unitClass then
        local classAudioFile = CLASS_AUDIO_MAP[unitClass]
        if classAudioFile then
            PlaySoundFile(sadb.sapath .. classAudioFile .. ".mp3", "Master")
            self:ScheduleTimer(function()
                PlaySoundFile(sadb.sapath .. "detected.mp3", "Master")
            end, 0.8)
        else
            PlaySoundFile(sadb.sapath .. "detected.mp3", "Master")
        end
    else
        PlaySoundFile(sadb.sapath .. "enemy.mp3", "Master")
        self:ScheduleTimer(function()
            PlaySoundFile(sadb.sapath .. "detected.mp3", "Master")
        end, 0.8)
    end

    -- Record statistics for proximity alerts (combat log-based)
    if sadb.statistics and sadb.statistics.enabled then
        self:RecordAlert("proximityAlerts")
    end

    if sadb.proximityToasts and sadb.proximityToasts.enabled and self.ProximityToasts then
        self.ProximityToasts:ShowToast(name, unitClass, nil, guid, nil, nil)
    end

    -- Chat alert
    if sadb.proximityChat and sadb.proximityChatText then
        local chatText = gsub(sadb.proximityChatText, "#class#", unitClass or "Enemy")
        chatText = gsub(chatText, "#player#", name)

        if not sadb.chatgroups.NONE then
            for channel, enabled in pairs(sadb.chatgroups) do
                if enabled and channel ~= "NONE" then
                    SendChatMessage(chatText, channel, nil, nil)
                end
            end
        end
    end

    if sadb.debugmode then
        if unitClass then
            self:Print("Proximity Alert (Combat Log): " .. unitClass .. " " .. name .. " detected!")
        else
            self:Print("Proximity Alert (Combat Log): Enemy " .. name .. " detected!")
        end
    end
end

-- Event handler for target changes
function SoundAlerter:PLAYER_TARGET_CHANGED()
    self:CheckProximityAlert("target")
end

-- Event handler for mouseover changes
function SoundAlerter:UPDATE_MOUSEOVER_UNIT()
    self:CheckProximityAlert("mouseover")
end