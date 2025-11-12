local SoundAlerter = LibStub("AceAddon-3.0"):GetAddon("SoundAlerter")
if not SoundAlerter then
    return
end

local ProximityToasts = {}
SoundAlerter.ProximityToasts = ProximityToasts

-- Performance: Cache combat state to reduce InCombatLockdown() calls
ProximityToasts.inCombat = false

local MAX_TOASTS = 5
local TOAST_WIDTH = 300
local TOAST_HEIGHT = 72
local VERTICAL_SPACING = 8
local FADE_IN_DURATION = 0.2
local FADE_OUT_DURATION = 0.5

local RAID_CLASS_COLORS = RAID_CLASS_COLORS
local CLASS_ICONS = {
    WARRIOR = "Interface\\Icons\\ClassIcon_Warrior",
    PALADIN = "Interface\\Icons\\ClassIcon_Paladin",
    HUNTER = "Interface\\Icons\\ClassIcon_Hunter",
    ROGUE = "Interface\\Icons\\ClassIcon_Rogue",
    PRIEST = "Interface\\Icons\\ClassIcon_Priest",
    DEATHKNIGHT = "Interface\\Icons\\ClassIcon_DeathKnight",
    SHAMAN = "Interface\\Icons\\ClassIcon_Shaman",
    MAGE = "Interface\\Icons\\ClassIcon_Mage",
    WARLOCK = "Interface\\Icons\\ClassIcon_Warlock",
    DRUID = "Interface\\Icons\\ClassIcon_Druid",
}

local classColorCache = {}

ProximityToasts.toastPool = {}
ProximityToasts.activeToasts = {}
ProximityToasts.lastToastTime = {}
ProximityToasts.initialized = false

-- Performance: Pre-built unit scan list (built once, reused)
-- Ordered by likelihood: common units first, then party/raid/arena
local unitScanOrder = {
    "target", "mouseover", "focus", "targettarget", "focustarget",
    "player", "pet", "pettarget",
    "party1", "party2", "party3", "party4",
    "party1target", "party2target", "party3target", "party4target",
    "partypet1", "partypet2", "partypet3", "partypet4",
}

-- Add raid members 1-40 (all possible slots)
for i = 1, 40 do
    table.insert(unitScanOrder, "raid" .. i)
    table.insert(unitScanOrder, "raid" .. i .. "target")
    table.insert(unitScanOrder, "raidpet" .. i)
end

-- Add arena opponents 1-5
for i = 1, 5 do
    table.insert(unitScanOrder, "arena" .. i)
    table.insert(unitScanOrder, "arena" .. i .. "target")
    table.insert(unitScanOrder, "arenapet" .. i)
end

-- Optimized targeting function for WoW 3.3.5 (WotLK)
-- Performance: Pre-built scan list, early exit on success
local function TargetByNameCompat(targetName)
    if not targetName then return false end

    -- Scan pre-built unit list with early exit
    for _, unitId in ipairs(unitScanOrder) do
        if UnitExists(unitId) and UnitName(unitId) == targetName then
            TargetUnit(unitId)
            return true
        end
    end

    return false
end

local function GetClassColor(className)
    if not className then return 0.5, 0.5, 0.5 end

    if not classColorCache[className] then
        local classColor = RAID_CLASS_COLORS[className]
        if classColor then
            classColorCache[className] = {classColor.r * 0.35, classColor.g * 0.35, classColor.b * 0.35}
        else
            classColorCache[className] = {0.175, 0.175, 0.175}
        end
    end

    local cached = classColorCache[className]
    return cached[1], cached[2], cached[3]
end

-- Helper function to calculate rainbow colors using sine waves
-- Returns smooth RGB values that cycle over time
local function GetRainbowColor(time)
    -- Slow cycle: full rainbow every 6 seconds
    local frequency = math.pi * 2 / 6.0

    -- Phase-shifted sine waves for smooth RGB transitions
    -- Each channel offset by 120 degrees (2π/3) for full color spectrum
    local r = math.sin(frequency * time + 0) * 0.5 + 0.5
    local g = math.sin(frequency * time + 2.0944) * 0.5 + 0.5  -- 2π/3 ≈ 2.0944
    local b = math.sin(frequency * time + 4.1888) * 0.5 + 0.5  -- 4π/3 ≈ 4.1888

    return r, g, b
end

-- Helper function to update countdown bar segments
local function UpdateCountdownSegments(toast, displayElapsed)
    if not toast.countdownBar or not toast.cachedSegmentData then
        return
    end

    local duration = toast.cachedSegmentData.duration
    local secondsElapsed = math.floor(displayElapsed)
    local segmentProgress = (displayElapsed % 1)  -- 0-1 progress within current second

    -- Fade current segment progressively
    local currentSegmentIndex = secondsElapsed + 1
    if currentSegmentIndex <= duration and toast.countdownBar.segments[currentSegmentIndex] then
        toast.countdownBar.segments[currentSegmentIndex]:SetAlpha(1 - segmentProgress)
    end

    -- Hide newly elapsed segments only (avoid redundant SetAlpha calls)
    local lastHidden = toast.cachedSegmentData.lastHiddenSegment or 0
    for i = lastHidden + 1, secondsElapsed do
        if toast.countdownBar.segments[i] then
            toast.countdownBar.segments[i]:SetAlpha(0)
        end
    end
    toast.cachedSegmentData.lastHiddenSegment = secondsElapsed
end

local function CreateToastFrame(index)
    local toast = CreateFrame("Button", "SoundAlerterToast"..index, UIParent)
    toast:SetSize(TOAST_WIDTH, TOAST_HEIGHT)
    toast:SetFrameStrata("HIGH")
    toast:SetFrameLevel(100)
    toast:Hide()
    toast:SetAlpha(0)

    toast:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = {left = 4, right = 4, top = 4, bottom = 4}
    })
    toast:SetBackdropColor(0, 0, 0, 0.85)
    toast:SetBackdropBorderColor(0.8, 0.2, 0.2, 1)

    toast.icon = toast:CreateTexture(nil, "ARTWORK")
    toast.icon:SetSize(56, 56)
    toast.icon:SetPoint("LEFT", 8, 0)

    toast.titleText = toast:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    toast.titleText:SetPoint("TOPLEFT", toast.icon, "TOPRIGHT", 10, -4)
    toast.titleText:SetPoint("RIGHT", -8, 0)
    toast.titleText:SetJustifyH("LEFT")
    toast.titleText:SetTextColor(1, 1, 1)

    toast.levelText = toast:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    toast.levelText:SetPoint("BOTTOMLEFT", toast.icon, "BOTTOMRIGHT", 10, 2)
    toast.levelText:SetTextColor(1, 0.82, 0)

    toast.detailText = toast:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    toast.detailText:SetPoint("TOPLEFT", toast.titleText, "BOTTOMLEFT", 0, -4)
    toast.detailText:SetPoint("RIGHT", -8, 0)
    toast.detailText:SetJustifyH("LEFT")
    toast.detailText:SetTextColor(0.8, 0.8, 0.8)

    -- Create countdown bar (3px height at bottom of toast)
    toast.countdownBar = CreateFrame("Frame", nil, toast)
    toast.countdownBar:SetHeight(3)
    toast.countdownBar:SetPoint("BOTTOMLEFT", toast, "BOTTOMLEFT", 4, 4)
    toast.countdownBar:SetPoint("BOTTOMRIGHT", toast, "BOTTOMRIGHT", -4, 4)
    toast.countdownBar:SetFrameLevel(toast:GetFrameLevel() + 2)
    toast.countdownBar.segments = {}

    -- Pre-create segment pool (max 30 seconds)
    local MAX_SEGMENTS = 30
    for i = 1, MAX_SEGMENTS do
        local segment = toast.countdownBar:CreateTexture(nil, "OVERLAY")
        segment:SetTexture("Interface\\Buttons\\WHITE8X8")
        segment:SetHeight(3)
        segment:SetVertexColor(0.8, 0.2, 0.2, 1)  -- Red color
        segment:Hide()
        toast.countdownBar.segments[i] = segment
    end

    toast.startTime = 0
    toast.displayDuration = 0
    toast.elapsedTime = 0
    toast.poolIndex = index
    toast.inUse = false
    toast.creationTime = 0

    -- Pause state table for hover pause functionality
    toast.pauseState = {
        active = false,
        startTime = 0,
        totalTime = 0
    }

    -- Cached segment data (set in ShowToast)
    toast.cachedSegmentData = nil

    -- User data table for storing target information
    toast.userData = {
        unitName = nil,
        guid = nil,
        className = nil,
        unitToken = nil,
    }

    -- Create nested SecureActionButton for secure targeting (out of combat)
    -- Performance: Pre-configure static attributes once
    if not InCombatLockdown() then
        toast.secureButton = CreateFrame("Button", nil, toast, "SecureActionButtonTemplate")
        toast.secureButton:SetAllPoints(toast)
        toast.secureButton:SetFrameLevel(toast:GetFrameLevel() + 1)
        toast.secureButton:RegisterForClicks("AnyUp", "AnyDown")

        -- Pre-configure secure attributes (set once, update macrotext dynamically)
        toast.secureButton:SetAttribute("type", "macro")
        toast.secureButton:SetAttribute("shift-type1", "macro")

        -- PostClick handler with lightweight OnUpdate delay
        toast.secureButton:SetScript("PostClick", function(self, button, down)
            if not down then
                local parent = self:GetParent()
                if parent and parent.inUse then
                    -- Lightweight 150ms delay using OnUpdate instead of AceTimer
                    local dismissTime = GetTime() + 0.15
                    parent.pendingDismiss = true
                    parent.dismissTime = dismissTime

                    parent:SetScript("OnUpdate", function(frame, elapsed)
                        if frame.pendingDismiss and GetTime() >= frame.dismissTime then
                            frame.pendingDismiss = false
                            frame:SetScript("OnUpdate", nil)
                            ProximityToasts:ReleaseToast(frame)
                        end
                    end)
                end
            end
        end)

        -- Hover handlers for pause functionality (when secureButton is active)
        toast.secureButton:SetScript("OnEnter", function(self)
            local parent = self:GetParent()
            if not parent.inUse or parent.pendingDismiss then
                return
            end

            -- Only pause during display phase (after fade-in, before fade-out)
            local elapsed = GetTime() - parent.startTime - parent.pauseState.totalTime
            if elapsed >= FADE_IN_DURATION and elapsed < (FADE_IN_DURATION + parent.displayDuration) then
                parent.pauseState.active = true
                parent.pauseState.startTime = GetTime()
            end
        end)

        toast.secureButton:SetScript("OnLeave", function(self)
            local parent = self:GetParent()
            if parent.pauseState.active then
                parent.pauseState.active = false
                local pauseDuration = GetTime() - parent.pauseState.startTime
                parent.pauseState.totalTime = parent.pauseState.totalTime + pauseDuration
                parent.pauseState.startTime = 0
            end
        end)
    end

    -- Enable mouse for hover detection (set once during creation, never toggle)
    -- This prevents taint errors when ShowToast() is called during combat
    toast:EnableMouse(true)

    -- Insecure fallback handler (used during combat)
    toast:RegisterForClicks("LeftButtonDown")
    toast:SetScript("OnClick", function(self, button)
        local sadb = SoundAlerter.db1.profile

        if not sadb.proximityToasts or not sadb.proximityToasts.clickEnabled then
            return
        end

        -- Zone check: World PvP only
        local currentZoneType, pvpType = IsInInstance()
        local zonePvpType = GetZonePVPInfo()
        local inWorld = (zonePvpType == "contested" or zonePvpType == "hostile" or zonePvpType == "friendly")

        if not inWorld then
            return
        end

        local targetName = self.userData and self.userData.unitName
        local unitToken = self.userData and self.userData.unitToken

        if not targetName then
            return
        end

        -- Try direct targeting if we have unit token
        local targetSuccess = false
        if unitToken and UnitExists(unitToken) then
            TargetUnit(unitToken)
            targetSuccess = (UnitExists("target") and UnitName("target") == targetName)
        end

        -- Fallback to name scan if direct targeting failed
        if not targetSuccess then
            targetSuccess = TargetByNameCompat(targetName)
        end

        if not targetSuccess then
            return
        end

        -- Shift-click: Set focus target
        if IsShiftKeyDown() then
            if sadb.proximityToasts.enableFocusTarget then
                FocusUnit("target")
            end
        end

        -- Lightweight delayed dismissal using OnUpdate
        local dismissTime = GetTime() + 0.15
        self.pendingDismiss = true
        self.dismissTime = dismissTime

        self:SetScript("OnUpdate", function(frame, elapsed)
            if frame.pendingDismiss and GetTime() >= frame.dismissTime then
                frame.pendingDismiss = false
                frame:SetScript("OnUpdate", nil)
                ProximityToasts:ReleaseToast(frame)
            end
        end)
    end)

    -- Pause on hover (only during display phase)
    toast:SetScript("OnEnter", function(self)
        if not self.inUse or self.pendingDismiss then
            return
        end

        -- Only pause during display phase (after fade-in, before fade-out)
        local elapsed = GetTime() - self.startTime - self.pauseState.totalTime
        if elapsed >= FADE_IN_DURATION and elapsed < (FADE_IN_DURATION + self.displayDuration) then
            self.pauseState.active = true
            self.pauseState.startTime = GetTime()
        end
    end)

    -- Resume on mouse leave
    toast:SetScript("OnLeave", function(self)
        if self.pauseState.active then
            self.pauseState.active = false
            local pauseDuration = GetTime() - self.pauseState.startTime
            self.pauseState.totalTime = self.pauseState.totalTime + pauseDuration
            self.pauseState.startTime = 0
        end
    end)

    return toast
end

function ProximityToasts:Initialize()
    if self.initialized then
        return
    end

    -- Ensure configuration table exists
    local sadb = SoundAlerter.db1.profile
    if not sadb.proximityToasts then
        sadb.proximityToasts = {}
    end

    -- Set default values for missing fields (backwards compatibility)
    if sadb.proximityToasts.clickEnabled == nil then
        sadb.proximityToasts.clickEnabled = true
    end
    if sadb.proximityToasts.enableClickToTarget == nil then
        sadb.proximityToasts.enableClickToTarget = true
    end
    if sadb.proximityToasts.enableFocusTarget == nil then
        sadb.proximityToasts.enableFocusTarget = true
    end

    -- Create toast frame pool
    for i = 1, MAX_TOASTS do
        local success, result = pcall(function()
            return CreateToastFrame(i)
        end)
        if success then
            self.toastPool[i] = result
        else
            return
        end
    end

    -- Register combat state events for caching
    local combatFrame = CreateFrame("Frame")
    combatFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    combatFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    combatFrame:SetScript("OnEvent", function(self, event)
        if event == "PLAYER_REGEN_DISABLED" then
            ProximityToasts.inCombat = true
        elseif event == "PLAYER_REGEN_ENABLED" then
            ProximityToasts.inCombat = false
        end
    end)

    self.initialized = true
    self:StartCleanupTimer()

    if SoundAlerter.db1.profile.debugmode then
        SoundAlerter:Print("Proximity Toasts initialized with " .. MAX_TOASTS .. " frame pool")
    end
end

function ProximityToasts:AcquireToast()
    for i = 1, MAX_TOASTS do
        local toast = self.toastPool[i]
        if not toast.inUse then
            toast.inUse = true
            return toast
        end
    end

    if #self.activeToasts > 0 then
        local oldest = self.activeToasts[1]
        if oldest then
            self:ReleaseToast(oldest)
            oldest.inUse = true
            return oldest
        end
    end

    return nil
end

function ProximityToasts:ReleaseToast(toast)
    toast:SetScript("OnUpdate", nil)
    toast:Hide()
    toast:SetAlpha(0)
    toast:SetScale(1.0)
    toast.inUse = false
    toast.creationTime = 0
    toast.startTime = 0
    toast.displayDuration = 0
    toast.pendingDismiss = false

    -- Reset pause state
    toast.pauseState.active = false
    toast.pauseState.startTime = 0
    toast.pauseState.totalTime = 0

    -- Reset cached segment data
    toast.cachedSegmentData = nil

    -- Hide all countdown segments
    if toast.countdownBar and toast.countdownBar.segments then
        for i = 1, #toast.countdownBar.segments do
            toast.countdownBar.segments[i]:Hide()
            toast.countdownBar.segments[i]:SetAlpha(1)
        end
    end

    toast.titleText:SetText("")
    toast.levelText:SetText("")
    toast.detailText:SetText("")
    toast:SetBackdropColor(0, 0, 0, 0.85)
    toast:SetBackdropBorderColor(0.8, 0.2, 0.2, 1)  -- Reset to default red border
    toast.icon:SetTexture(nil)

    -- Performance: Reuse userData table (prevents GC pressure)
    if toast.userData then
        toast.userData.unitName = nil
        toast.userData.guid = nil
        toast.userData.className = nil
        toast.userData.unitToken = nil
    end

    for i = #self.activeToasts, 1, -1 do
        if self.activeToasts[i] == toast then
            table.remove(self.activeToasts, i)
            break
        end
    end

    self:UpdateLayout()
end

function ProximityToasts:UpdateLayout()
    local sadb = SoundAlerter.db1.profile
    local baseX = sadb.proximityToasts.positionX or 0
    local baseY = sadb.proximityToasts.positionY or -200

    table.sort(self.activeToasts, function(a, b)
        return a.creationTime < b.creationTime
    end)

    for i, toast in ipairs(self.activeToasts) do
        toast:ClearAllPoints()
        if i == 1 then
            toast:SetPoint("TOP", UIParent, "TOP", baseX, baseY)
        else
            toast:SetPoint("TOP", self.activeToasts[i-1], "BOTTOM", 0, -VERTICAL_SPACING)
        end
    end
end

function ProximityToasts:ShouldShowToast(guid)
    if not guid then return true end

    local now = GetTime()
    local cooldown = 0.5
    local lastTime = self.lastToastTime[guid] or 0

    if now - lastTime < cooldown then
        return false
    end

    self.lastToastTime[guid] = now
    return true
end

function ProximityToasts:CleanupHistory()
    local now = GetTime()
    for guid, time in pairs(self.lastToastTime) do
        if now - time > 30 then
            self.lastToastTime[guid] = nil
        end
    end
end

function ProximityToasts:ShowToast(unitName, className, distance, guid, level, unitToken)
    local sadb = SoundAlerter.db1.profile

    if not self.initialized or not sadb.proximityToasts or not sadb.proximityToasts.enabled or not unitName then
        return
    end

    if guid and not self:ShouldShowToast(guid) then
        return
    end

    local maxConcurrent = sadb.proximityToasts.maxConcurrent or 3
    if #self.activeToasts >= maxConcurrent then
        local oldest = self.activeToasts[1]
        if oldest then self:ReleaseToast(oldest) end
    end

    local toast = self:AcquireToast()
    if not toast then return end

    toast.icon:SetTexture(CLASS_ICONS[className] or "Interface\\Icons\\Ability_Rogue_Ambush")

    if sadb.proximityToasts.useClassColors and className then
        local r, g, b = GetClassColor(className)
        toast:SetBackdropColor(r, g, b, 0.85)
    else
        toast:SetBackdropColor(0, 0, 0, 0.85)
    end

    -- Set initial border color (will be overridden by rainbow animation if enabled)
    if not sadb.proximityToasts.rainbowBorder then
        toast:SetBackdropBorderColor(0.8, 0.2, 0.2, 1)  -- Default red border
    end

    toast.titleText:SetText(className and (className .. " NEARBY!") or "ENEMY NEARBY!")

    -- Display level information, showing "High Level" for targets too high level to inspect
    if level then
        if level == -1 then
            toast.levelText:SetText("High Level")
        else
            toast.levelText:SetText("Level " .. level)
        end
    else
        toast.levelText:SetText("")
    end

    local detailText = ""
    if sadb.proximityToasts.showPlayerName and unitName then
        detailText = unitName
    end
    toast.detailText:SetText(detailText)

    -- Store user data for click-to-target functionality
    if toast.userData then
        toast.userData.unitName = unitName
        toast.userData.guid = guid
        toast.userData.className = className
        toast.userData.unitToken = unitToken
    end

    -- Configure secure button if available and out of combat
    -- Performance: Use cached combat state, only update macrotext
    if toast.secureButton and not self.inCombat then
        -- Update macrotext only (attributes pre-configured on creation)
        local macroText = "/targetexact " .. unitName
        toast.secureButton:SetAttribute("macrotext", macroText)
        toast.secureButton:SetAttribute("shift-macrotext1", macroText .. "\n/focus")

        -- Enable secure button for clicks (higher frame level = priority)
        -- Toast mouse is always enabled (set once during creation)
        toast.secureButton:Show()
        toast.secureButton:EnableMouse(true)
    else
        -- Combat or no secure button - use insecure fallback
        -- Toast mouse is always enabled (no need to toggle, prevents taint)
        if toast.secureButton then
            toast.secureButton:EnableMouse(false)
            toast.secureButton:Hide()
        end
    end

    toast.creationTime = GetTime()
    table.insert(self.activeToasts, toast)
    self:UpdateLayout()

    toast.startTime = GetTime()
    toast.displayDuration = sadb.proximityToasts.displayDuration or 3.0

    -- Initialize countdown bar segments
    local duration = math.ceil(toast.displayDuration)  -- Round up to ensure full coverage
    local segmentWidth = (TOAST_WIDTH - 8) / duration  -- Minus left/right insets

    -- Cache segment data for OnUpdate performance
    toast.cachedSegmentData = {
        duration = duration,
        segmentWidth = segmentWidth,
        lastHiddenSegment = 0  -- Track last hidden segment for optimization
    }

    -- Position and show required segments
    for i = 1, duration do
        local segment = toast.countdownBar.segments[i]
        if segment then
            segment:ClearAllPoints()
            segment:SetPoint("LEFT", toast.countdownBar, "LEFT", (i-1) * segmentWidth, 0)
            segment:SetWidth(segmentWidth - 2)  -- 2px gap between segments for better visual separation
            segment:SetAlpha(1)
            segment:Show()
        end
    end

    -- Hide unused segments (if previous toast had longer duration)
    for i = duration + 1, #toast.countdownBar.segments do
        toast.countdownBar.segments[i]:Hide()
    end

    -- Reset pause state for new toast
    toast.pauseState.active = false
    toast.pauseState.startTime = 0
    toast.pauseState.totalTime = 0

    toast:SetAlpha(0)
    toast:SetScale(1.0)
    toast:Show()

    toast:SetScript("OnUpdate", function(self, frameDelta)
        -- Skip all timing updates while paused
        if self.pauseState.active then
            return
        end

        local now = GetTime()
        local elapsed = now - self.startTime - self.pauseState.totalTime

        -- Update rainbow border if enabled
        if sadb.proximityToasts.rainbowBorder then
            local r, g, b = GetRainbowColor(now)
            self:SetBackdropBorderColor(r, g, b, 1)
        end

        -- Phase 1: Fade In
        if elapsed < FADE_IN_DURATION then
            local progress = elapsed / FADE_IN_DURATION
            self:SetAlpha(progress)
            local scale = 1.15 - (0.15 * progress)
            self:SetScale(scale)

        -- Phase 2: Display with countdown animation
        elseif elapsed < (FADE_IN_DURATION + self.displayDuration) then
            self:SetAlpha(1)
            self:SetScale(1.0)

            -- Update countdown bar segments
            local displayElapsed = elapsed - FADE_IN_DURATION
            UpdateCountdownSegments(self, displayElapsed)

        -- Phase 3: Fade Out
        elseif elapsed < (FADE_IN_DURATION + self.displayDuration + FADE_OUT_DURATION) then
            local fadeProgress = (elapsed - FADE_IN_DURATION - self.displayDuration) / FADE_OUT_DURATION
            self:SetAlpha(1 - fadeProgress)

            -- Hide countdown segments during fade out (only active segments)
            if self.countdownBar and self.cachedSegmentData then
                local duration = self.cachedSegmentData.duration
                for i = 1, duration do
                    self.countdownBar.segments[i]:SetAlpha(0)
                end
            end

        -- Phase 4: Cleanup
        else
            self:SetScript("OnUpdate", nil)
            self:Hide()
            ProximityToasts:ReleaseToast(self)
        end
    end)
end

function ProximityToasts:OnProfileChanged()
    for _, toast in ipairs(self.activeToasts) do
        self:ReleaseToast(toast)
    end
    wipe(self.lastToastTime)

    if SoundAlerter.db1.profile.debugmode then
        SoundAlerter:Print("Proximity Toasts: Profile changed")
    end
end

function ProximityToasts:OnDisable()
    if self.cleanupTimer then
        SoundAlerter:CancelTimer(self.cleanupTimer)
        self.cleanupTimer = nil
    end

    for i = #self.activeToasts, 1, -1 do
        self:ReleaseToast(self.activeToasts[i])
    end
end

function ProximityToasts:StartCleanupTimer()
    if not self.cleanupTimer then
        self.cleanupTimer = SoundAlerter:ScheduleRepeatingTimer(function()
            ProximityToasts:CleanupHistory()
        end, 60)
    end
end

-- Debug slash command for testing
SLASH_SATOAST1 = "/satoast"
SlashCmdList["SATOAST"] = function(msg)
    local command, args = msg:match("^(%S*)%s*(.-)$")

    if command == "test" then
        if SoundAlerter.ProximityToasts then
            local wasDisabled = not SoundAlerter.db1.profile.proximityToasts.enabled
            if wasDisabled then
                SoundAlerter.db1.profile.proximityToasts.enabled = true
            end

            -- Parse optional duration argument
            local duration = tonumber(args)
            if duration and duration > 0 then
                local savedDuration = SoundAlerter.db1.profile.proximityToasts.displayDuration
                SoundAlerter.db1.profile.proximityToasts.displayDuration = duration
                SoundAlerter.ProximityToasts:ShowToast("TestEnemy", "ROGUE", nil, "Player-Test-12345", 80, nil)
                DEFAULT_CHAT_FRAME:AddMessage("|cff00FF00Test toast displayed with " .. duration .. "s duration.|r")
                SoundAlerter.db1.profile.proximityToasts.displayDuration = savedDuration
            else
                SoundAlerter.ProximityToasts:ShowToast("TestEnemy", "ROGUE", nil, "Player-Test-12345", 80, nil)
                DEFAULT_CHAT_FRAME:AddMessage("|cff00FF00Test toast displayed.|r")
            end

            if wasDisabled then
                SoundAlerter.db1.profile.proximityToasts.enabled = false
            end
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cffFF0000ProximityToasts module not found!|r")
        end
    elseif command == "multi" then
        -- Create multiple test toasts
        local count = tonumber(args) or 3
        if SoundAlerter.ProximityToasts then
            local wasDisabled = not SoundAlerter.db1.profile.proximityToasts.enabled
            if wasDisabled then
                SoundAlerter.db1.profile.proximityToasts.enabled = true
            end

            local classes = {"WARRIOR", "PALADIN", "ROGUE", "MAGE", "WARLOCK"}
            for i = 1, math.min(count, 5) do
                SoundAlerter.ProximityToasts:ShowToast("TestEnemy"..i, classes[i], nil, "Player-Test-"..i, 80, nil)
            end
            DEFAULT_CHAT_FRAME:AddMessage("|cff00FF00Created " .. count .. " test toasts.|r")

            if wasDisabled then
                SoundAlerter.db1.profile.proximityToasts.enabled = false
            end
        end
    elseif command == "countdown" then
        -- Show countdown debug info for active toasts
        if SoundAlerter.ProximityToasts then
            DEFAULT_CHAT_FRAME:AddMessage("|cff00FFFF=== Countdown Debug ===|r")
            for i, toast in ipairs(SoundAlerter.ProximityToasts.activeToasts) do
                if toast.cachedSegmentData then
                    local elapsed = GetTime() - toast.startTime - toast.pauseState.totalTime
                    local displayElapsed = math.max(0, elapsed - FADE_IN_DURATION)
                    DEFAULT_CHAT_FRAME:AddMessage("Toast " .. i .. ":")
                    DEFAULT_CHAT_FRAME:AddMessage("  Duration: " .. toast.displayDuration .. "s")
                    DEFAULT_CHAT_FRAME:AddMessage("  Segments: " .. toast.cachedSegmentData.duration)
                    DEFAULT_CHAT_FRAME:AddMessage("  Elapsed: " .. string.format("%.2f", displayElapsed) .. "s")
                    DEFAULT_CHAT_FRAME:AddMessage("  Paused: " .. tostring(toast.pauseState.active))
                    DEFAULT_CHAT_FRAME:AddMessage("  Total Pause Time: " .. string.format("%.2f", toast.pauseState.totalTime) .. "s")
                end
            end
        end
    elseif command == "init" then
        if SoundAlerter.ProximityToasts then
            SoundAlerter.ProximityToasts:Initialize()
        end
    elseif command == "enable" then
        SoundAlerter.db1.profile.proximityToasts.enabled = true
        DEFAULT_CHAT_FRAME:AddMessage("|cff00FF00Toasts enabled|r")
    elseif command == "status" then
        if SoundAlerter.ProximityToasts then
            DEFAULT_CHAT_FRAME:AddMessage("|cff00FFFF=== Toast Status ===|r")
            DEFAULT_CHAT_FRAME:AddMessage("Initialized: " .. tostring(SoundAlerter.ProximityToasts.initialized))
            DEFAULT_CHAT_FRAME:AddMessage("Pool size: " .. #SoundAlerter.ProximityToasts.toastPool)
            DEFAULT_CHAT_FRAME:AddMessage("Active toasts: " .. #SoundAlerter.ProximityToasts.activeToasts)
            DEFAULT_CHAT_FRAME:AddMessage("In combat: " .. tostring(SoundAlerter.ProximityToasts.inCombat))
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cffFF0000Module NOT found!|r")
        end
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cff00FFFF/satoast commands:|r")
        DEFAULT_CHAT_FRAME:AddMessage("  test [duration] - Show test toast (optional: specify duration in seconds)")
        DEFAULT_CHAT_FRAME:AddMessage("  multi [count] - Create multiple test toasts (default: 3)")
        DEFAULT_CHAT_FRAME:AddMessage("  countdown - Show countdown debug info for active toasts")
        DEFAULT_CHAT_FRAME:AddMessage("  init - Manually initialize")
        DEFAULT_CHAT_FRAME:AddMessage("  enable - Enable toasts")
        DEFAULT_CHAT_FRAME:AddMessage("  status - Show debug status")
        DEFAULT_CHAT_FRAME:AddMessage("|cffFFFF00Examples:|r")
        DEFAULT_CHAT_FRAME:AddMessage("  /satoast test 5.0 - Test with 5 second duration")
        DEFAULT_CHAT_FRAME:AddMessage("  /satoast multi 5 - Create 5 test toasts")
    end
end
