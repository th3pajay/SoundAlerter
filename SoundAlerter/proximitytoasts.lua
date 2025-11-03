local SoundAlerter = LibStub("AceAddon-3.0"):GetAddon("SoundAlerter")
if not SoundAlerter then
    DEFAULT_CHAT_FRAME:AddMessage("|cffFF0000[ProximityToasts] ERROR: Could not get SoundAlerter addon!|r")
    return
end

local ProximityToasts = {}
SoundAlerter.ProximityToasts = ProximityToasts

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

local function CreateToastFrame(index)
    local toast = CreateFrame("Frame", "SoundAlerterToast"..index, UIParent)
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

    toast.startTime = 0
    toast.displayDuration = 0
    toast.elapsedTime = 0
    toast.poolIndex = index
    toast.inUse = false
    toast.creationTime = 0

    return toast
end

function ProximityToasts:Initialize()
    if self.initialized then
        return
    end

    for i = 1, MAX_TOASTS do
        local success, result = pcall(function()
            return CreateToastFrame(i)
        end)
        if success then
            self.toastPool[i] = result
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cffFF0000[ProximityToasts] ERROR creating toast " .. i .. ": " .. tostring(result) .. "|r")
            return
        end
    end

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

    toast.titleText:SetText("")
    toast.levelText:SetText("")
    toast.detailText:SetText("")
    toast:SetBackdropColor(0, 0, 0, 0.85)
    toast.icon:SetTexture(nil)

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

function ProximityToasts:ShowToast(unitName, className, distance, guid, level)
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

    toast.titleText:SetText(className and (className .. " NEARBY!") or "ENEMY NEARBY!")

    toast.levelText:SetText(level and ("Level " .. level) or "")

    local detailText = ""
    if sadb.proximityToasts.showPlayerName and unitName then
        detailText = unitName
    end
    if sadb.proximityToasts.showDistance and distance then
        detailText = (detailText ~= "") and (detailText .. " - " .. distance .. " yards") or (distance .. " yards")
    end
    toast.detailText:SetText(detailText)

    toast.creationTime = GetTime()
    table.insert(self.activeToasts, toast)
    self:UpdateLayout()

    toast.startTime = GetTime()
    toast.displayDuration = sadb.proximityToasts.displayDuration or 3.0

    toast:SetAlpha(0)
    toast:SetScale(1.0)
    toast:Show()

    toast:SetScript("OnUpdate", function(self, elapsed)
        local now = GetTime()
        local elapsed = now - self.startTime

        if elapsed < FADE_IN_DURATION then
            local progress = elapsed / FADE_IN_DURATION
            self:SetAlpha(progress)
            local scale = 1.15 - (0.15 * progress)
            self:SetScale(scale)
        elseif elapsed < (FADE_IN_DURATION + self.displayDuration) then
            self:SetAlpha(1)
            self:SetScale(1.0)
        elseif elapsed < (FADE_IN_DURATION + self.displayDuration + FADE_OUT_DURATION) then
            local fadeProgress = (elapsed - FADE_IN_DURATION - self.displayDuration) / FADE_OUT_DURATION
            self:SetAlpha(1 - fadeProgress)
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

SLASH_SATOAST1 = "/satoast"
SlashCmdList["SATOAST"] = function(msg)
    if msg == "test" then
        DEFAULT_CHAT_FRAME:AddMessage("|cff00FFFF[Debug] Testing toast...|r")
        if SoundAlerter.ProximityToasts then
            DEFAULT_CHAT_FRAME:AddMessage("|cff00FFFF[Debug] ProximityToasts module exists|r")
            DEFAULT_CHAT_FRAME:AddMessage("|cff00FFFF[Debug] Initialized: " .. tostring(SoundAlerter.ProximityToasts.initialized) .. "|r")
            DEFAULT_CHAT_FRAME:AddMessage("|cff00FFFF[Debug] Config enabled: " .. tostring(SoundAlerter.db1.profile.proximityToasts.enabled) .. "|r")
            SoundAlerter.ProximityToasts:ShowToast("DebugEnemy", "ROGUE", nil, nil)
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cffFF0000[Debug] ProximityToasts module NOT found!|r")
        end
    elseif msg == "init" then
        if SoundAlerter.ProximityToasts then
            SoundAlerter.ProximityToasts:Initialize()
        end
    elseif msg == "enable" then
        SoundAlerter.db1.profile.proximityToasts.enabled = true
        DEFAULT_CHAT_FRAME:AddMessage("|cff00FF00[Debug] Toasts enabled|r")
    elseif msg == "status" then
        if SoundAlerter.ProximityToasts then
            DEFAULT_CHAT_FRAME:AddMessage("|cff00FFFF=== Toast Status ===|r")
            DEFAULT_CHAT_FRAME:AddMessage("|cff00FFFF Module exists: true|r")
            DEFAULT_CHAT_FRAME:AddMessage("|cff00FFFF Initialized: " .. tostring(SoundAlerter.ProximityToasts.initialized) .. "|r")
            DEFAULT_CHAT_FRAME:AddMessage("|cff00FFFF Pool size: " .. #SoundAlerter.ProximityToasts.toastPool .. "|r")
            DEFAULT_CHAT_FRAME:AddMessage("|cff00FFFF Active toasts: " .. #SoundAlerter.ProximityToasts.activeToasts .. "|r")
            DEFAULT_CHAT_FRAME:AddMessage("|cff00FFFF Config enabled: " .. tostring(SoundAlerter.db1.profile.proximityToasts.enabled) .. "|r")
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cffFF0000Module NOT found!|r")
        end
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cff00FFFF/satoast commands:|r")
        DEFAULT_CHAT_FRAME:AddMessage("|cffFFFF00  test|r - Show test toast")
        DEFAULT_CHAT_FRAME:AddMessage("|cffFFFF00  init|r - Manually initialize")
        DEFAULT_CHAT_FRAME:AddMessage("|cffFFFF00  enable|r - Enable toasts")
        DEFAULT_CHAT_FRAME:AddMessage("|cffFFFF00  status|r - Show debug status")
    end
end
