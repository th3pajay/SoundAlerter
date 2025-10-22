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
    
    self.db1.RegisterCallback(self, "OnProfileChanged", "ChangeProfile")
    self.db1.RegisterCallback(self, "OnProfileCopied", "ChangeProfile")
    self.db1.RegisterCallback(self, "OnProfileReset", "ChangeProfile")
    
    self:RegisterChatCommand("SoundAlerter", "ShowConfig")
    self:RegisterChatCommand("SALERTER", "ShowConfig")
    self:RegisterChatCommand("sa", "ShowConfig")

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
end

function SoundAlerter:OnEnable()
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    self:RegisterEvent("UNIT_AURA")
    
    if not self.SA_LANGUAGE[sadb.path] then sadb.path = self.SA_LOCALEPATH[GetLocale()] end
    self.throttled = {}
    self.smarter = 0
    
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
end

function SoundAlerter:Interrupted()
    PlaySoundFile(sadb.sapath.."Interrupted.mp3");
end

function SoundAlerter:PlaySpell(list, spellID, ...)
    if list[spellID] then
        if not sadb[list[spellID]] then return end
        if sadb.debugmode then print("<SA> DEBUG: Playing sound file: "..list[spellID]..".mp3"); end
        PlaySoundFile(sadb.sapath..list[spellID]..".mp3");
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

function SoundAlerter:PLAYER_ENTERING_WORLD()
    CombatLogClearEntries()
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
                    SendChatMessage(gsub(ccenemychat, "(#enemy#)", destName), sadb.chatgroup, nil, nil)
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
                        SendChatMessage(gsub(form2, "(#enemy#)", sourceName), sadb.chatgroup, nil, nil)
                elseif (spellID == 6770 or spellID == 11297 or spellID == 51724) and sadb.sapselffriend then
                        SendChatMessage(gsub(sadb.sapselftext, "(#spell#)", GetSpellLink(spellID)), sadb.chatgroup, nil, nil)
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
                SendChatMessage(gsub(sapfriendtext, "(#friend#)", destName), sadb.chatgroup, nil, nil)
            elseif ((spellID == 51514 and sadb.hexselffriend) or 
                (spellID == 642 and sadb.bubbleselffriend) or 
                (spellID == 33786 and sadb.cycloneselffriend) or 
                ((spellID == 6215 or spellID == 17928 or spellID == 5484) and sadb.fearselffriend) or
                ((spellID == 12826 or spellID == 118 or spellID == 28271 or spellID == 28272) and sadb.polyenemy) or
                (spellID == 2094 and sadb.blindselffriend)) then
                    local form1 = gsub(sadb.friendchat, "(#spell#)", GetSpellLink(spellID))
                    local form2 = gsub(form1, "(#friend#)", destName)
                    SendChatMessage(gsub(form2, "(#enemy#)", sourceName), sadb.chatgroup, nil, nil)
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
            if (
                ((sadb.vanishenemy and spellID == 26889) or (sadb.stealthenemy and spellID == 1784) or (sadb.prowlenemy and spellID == 1105215)) 
                and 
                ( (sourceuid.target or sourceuid.focus) or ((sadb.vanishTF and spellID == 26889) or (sadb.stealthTF and spellID == 1784) or (sadb.prowlTF and spellID == 1105215)) ) 
            ) then
                SendChatMessage(gsub(gsub(sadb.enemychat,"(#spell#)", GetSpellLink(spellID)),"(#enemy#)", sourceName),sadb.chatgroup,nil,nil)
            end
        end
        
        if ((spellID == 42292 or spellID == 59752) and sadb.trinket) then
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
    local _, currentZoneType = IsInInstance()
    local pvpType, isFFA, faction = GetZonePVPInfo();
    
    if (not ((pvpType == "contested" and sadb.field) or (pvpType == "hostile" and sadb.field) or (pvpType == "friendly" and sadb.field) or (currentZoneType == "pvp" and sadb.battleground) or (((currentZoneType == "arena") or (pvpType == "arena")) and sadb.arena) or sadb.all)) then
        return
    end
    
    local timestamp, event, sourceGUID, sourceName, sourceFlags, destGUID, destName, destFlags, spellID, spellName, _, extraSpellID = select(1, ...);
    
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