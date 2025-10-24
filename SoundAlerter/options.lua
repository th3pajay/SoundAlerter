local sadb
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local AceConfig = LibStub("AceConfig-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("SoundAlerter")
local self, SoundAlerter = SoundAlerter, SoundAlerter

local function initOptions()
	if SoundAlerter.options.args.general then
		return
	end
	SoundAlerter:OnOptionsCreate()
	for k, v in SoundAlerter:IterateModules() do
		if type(v.OnOptionsCreate) == "function" then
			v:OnOptionsCreate()
		end
	end
	AceConfig:RegisterOptionsTable("SoundAlerter", SoundAlerter.options)
end

function SoundAlerter:ShowConfig()
	initOptions()
    local configName = "SoundAlerter"
    
    local dialogData = AceConfigDialog.OpenFrames[configName]
    local frame = dialogData and dialogData.frame
    
    if frame and frame:IsVisible() then
        frame:Hide()
    else
	    AceConfigDialog:Open(configName)
    end
end

local function setOption(info, value)
    local name = info[#info]
    sadb[name] = value
    if value then
        PlaySoundFile(sadb.sapath .. name .. ".mp3");
    end
end

local function getOption(info)
	local name = info[#info]
	return sadb[name]
end

function listOption(spellList, listType, ...)
	local args = {}
	for k,v in pairs(spellList) do
		local key = SoundAlerter.spellList[listType] and SoundAlerter.spellList[listType][v]

		if key then
			local option = self:spellOptions(k, v)
			if option.type == 'toggle' and not option.desc then
				option.desc = function()
					if GetSpellLink(v) then
						GameTooltip:SetHyperlink(GetSpellLink(v));
					end
				end
				option.descStyle = "custom"
			end
			rawset(args, key, option)
		else
			if sadb.debugmode then
				print("|cffFF7D0ASoundAlerter|r: Missing spell definition for ID:", v, "in list type:", listType)
			end
		end
	end
	return args
end

function SpellTexture(sid)
	local spellname,_,icon = GetSpellInfo(sid)
	if spellname ~= nil then
		return "\124T"..icon..":24\124t"
	end
end
function SpellTextureName(sid)
	local spellname,_,icon = GetSpellInfo(sid)
	if spellname ~= nil then
		return "\124T"..icon..":24\124t"..spellname
	end
end

function SoundAlerter:OnOptionsCreate()
	sadb = self.db1.profile
	self:AddOption("profiles", LibStub("AceDBOptions-3.0"):GetOptionsTable(self.db1))
	self.options.args.profiles.order = -1
	self:AddOption('General', {
		type = 'group',
		name = "General",
		desc = "General Options",
		order = 1,
		args = {
			enableArea = {
				type = 'group',
				inline = true,
				name = "General options",
				set = setOption,
				get = getOption,
				args = {
					all = {
						type = 'toggle',
						name = "Enable Everything",
						desc = "Enables Sound Alerter for BGs, world and arena",
						order = 1,
					},
					arena = {
						type = 'toggle',
						name = "Arena",
						desc = "Enabled in the arena",
						disabled = function() return sadb.all end,
						order = 2,
					},
					battleground = {
						type = 'toggle',
						name = "Battleground",
						desc = "Enable Battleground",
						disabled = function() return sadb.all end,
						order = 3,
					},
					field = {
						type = 'toggle',
						name = "World",
						desc = "Enabled outside Battlegrounds and arenas",
						disabled = function() return sadb.all end,
						order = 4,
					},
					AlertConditions = {
						type = 'group',
						inline = true,
						order = 9,
						name = "Alert Conditions",
						args = {
							myself = {
								type = 'toggle',
								name = L["Target and Focus only"],
								disabled = function() return sadb.enemyinrange end,
								desc = "Alert works only when your current target casts a spell, or an enemy casts a spell on you",
								order = 5,
							},
							enemyinrange = {
								type = 'toggle',
								name = "All Enemies in Range",
								desc = "Alerts are enabled for all enemies in range",
								disabled = function() return sadb.myself end,
								order = 6,
							},
						},
					},
					volumecontrol = {
						type = 'group',
						inline = true,
						order = 10,
						name = "Volume Control",
						args = {
							volumn = {
								type = 'range',
								max = 1,
								min = 0,
								isPercent = true,
								step = 0.1,
								name = "Master Volume",
								desc = "Sets the master volume so sound alerts can be louder/softer",
								set = function (info, value) SetCVar ("Sound_MasterVolume",tostring (value)) end,
								get = function () return tonumber (GetCVar ("Sound_MasterVolume")) end,
								order = 1,
							},
							volumn2 = {
								type = 'execute',
								width = 'normal',
								name = "Addon sounds only",
								desc = "Sets other sounds to minimum, only hearing the addon sounds",
								func = function() 
										SetCVar ("Sound_AmbienceVolume",tostring ("0")); SetCVar ("Sound_SFXVolume",tostring ("0")); SetCVar ("Sound_MusicVolume",tostring ("0")); 
										print("|cffFF7D0ASoundAlerter|r: Addons will only be heard by your Client. To undo this, click the 'reset sound options' button.");
									end,
								order = 2,
							},
							volumn3 = {
								type = 'execute',
								width = 'normal',
								name = "Reset volume options",
								desc = "Resets sound options",
								func = function() 
										SetCVar ("Sound_MasterVolume",tostring ("1")); SetCVar ("Sound_AmbienceVolume",tostring ("1")); SetCVar ("Sound_SFXVolume",tostring ("1")); SetCVar ("Sound_MusicVolume",tostring ("1")); 
										print("|cffFF7D0ASoundAlerter|r: Sound options reset.");
									end,
								order = 3,
							},
							sapath = {
								type = 'select',
								name = "Language",
								desc = "Language of Sounds",
								values = self.SA_LANGUAGE,
								order = 3,
							},
						},
					},
					advance = {
						type = 'group',
						inline = true,
						name = L["Advanced options"],
						order = 11,
						args = {
							debugmode = {
								type = 'toggle',
								name = "Debug Mode",
								desc = "Enable Debugging",
								order = 3,
							},
						},
					},
					debugopts = {
						type = 'group',
						inline = true,
						order = 11,
						hidden = function() return not sadb.debugmode end,
						name = "Debug options",
						args = {
							cspell = {
							type = 'input',
							name = "Custom spells entry name",
							order = 1,
							},
							spelldebug = {
								type = 'toggle',
								name = "Spell ID output debugging",
								order = 2,
							},
							csname = {
								type = 'input',
								name = "Spell name",
								order = 2,
							},
						},
					},
					importexport = {
						type = 'group',
						inline = true,
						hidden = function() return not sadb.debugmode end,
						name = "Import/Export",
						desc = "Import or export custom sound alerts",
						order = 12,
						args = {
							import = {
								type = 'execute',
								name = "Import custom sound alerts",
								order = 1,
								confirm = true,
								confirmText = "Are you sure? This will remove all of your current sound alerts",
								func = function()
										sadb.custom = nil
								end,
							},
							export = {
								type = 'execute',
								name = "Export encapsulation",
								order = 2,
								func = function()
								local thisw = "@"
										for k,css in pairs (sadb.custom) do
											 thisw = thisw.."|"..css.name..","..css.soundfilepath..","..(css.spellid and css.spellid or "0")..","
												for j,l in pairs (sadb.custom[k].eventtype) do
													thisw = thisw..j..","..tostring(l)..","
												end
										end
										sadb.exportbox = thisw.."#"
								end,
							},
							exportbox = {
								type = 'input',
								name = "Export custom sound alerts",
								order = 3,
							},
						},
					}
				},
			},
		}
	})
	self:AddOption('Spells', {
		type = 'group',
		name = "Spells",
		desc = "Spell Options",
		order = 2,
		args = {
			spellGeneral = {
				type = 'group',
				name = "Spell Disables",
				desc = "Enable certain spell types",
				inline = true,
				set = setOption,
				get = getOption,
				order = -1,
				args = {
					aruaApplied = {
						type = 'toggle',
						name = "Disable buff applied",
						desc = "Disables sound notifications of buffs applied",
						order = 1,
					},
					auraRemoved = {
						type = 'toggle',
						name = "Disable Buff down",
						desc = "Disables sound notifications of buffs down",
						order = 2,
					},
					castStart = {
						type = 'toggle',
						name = "Disable spell casting",
						desc = "Disables spell casting notifications",
						order = 3,
					},
					castSuccess = {
						type = 'toggle',
						name = "Disable enemy cooldown abilities",
						desc = "Disbles sound notifications of cooldown abilities",
						order = 4,
					},
					chatalerts = {
						type = 'toggle',
						name = "Disable Chat Alerts",
						desc = "Disbles Chat notifications of special abilities in the chat bar",
						order = 5,
					},
					interrupt = {
						type = 'toggle',
						name = "Disable Interrupted Spells",
						desc = "Check this option to disable notifications of friendly interrupted spells",
						order = 6,
					},
					dArenaPartner = {
						type = 'toggle',
						name = "Disable Arena Partner debuff/CC alerts",
						desc = "Check this option to disable notifications of Arena Partner debuff/CC alerts",
						order = 7,
					},
					dSelfDebuff = {
						type = 'toggle',
						name = "Disable Self Debuff alerts",
						desc = "Check this option to disable notifications of self debuff/CC alerts",
						order = 8,
					},
					dEnemyDebuff = {
						type = 'toggle',
						name = "Disable Enemy Debuff alerts",
						desc = "Check this option to disable notifications of enemy debuff/CC alerts",
						order = 9,
					},
					dEnemyDebuffDown = {
						type = 'toggle',
						name = "Disable Enemy Debuff down alerts",
						desc = "Check this option to disable notifications of enemy debuff/CC alerts",
						order = 9,
					},
				},
			},
			spellauraApplied = {
				type = 'group',
				--inline = true,
				name = "Enemy Buffs",
				desc = "Alerts you when your enemy gains a buff, or uses a cooldown",
				set = setOption,
				get = getOption,
				disabled = function() return sadb.aruaApplied end,
				order = 2,
				args = {
					class = {
						type = 'toggle',
						name = "Alert Class calling for trinketting in Arena",
						desc = "Alert when an enemy class trinkets in arena",
						confirm = function() PlaySoundFile(sadb.sapath.."paladin.mp3"); self:ScheduleTimer("PlayTrinket", 0.4); end,
						order = 2,
					},
					drinking = {
						type = 'toggle',
						name = "Alert Drinking in Arena",
						desc = "Alert when an enemy drinks in arena",
						order = 3,
					},
					general = {
						type = 'group',
						inline = true,
						name = "General spells",
						order = 4,
						args = {
							trinket = {
								type = 'toggle',
								name = SpellTexture(42292).."PvP Trinket/Every Man for Himself",
								desc = function ()
									GameTooltip:SetHyperlink(GetSpellLink(42292));
								end,
								descStyle = "custom",
								order = 1,
							},
						}
					},
					druid = {
						type = 'group',
						inline = true,
						name = "|cffFF7D0ADruid|r",
						order = 5,
						args = listOption({1161336,1129166,1122812,1117116,1153312,1122842,1153201,1150334,1101850,1116974,1398191,1169369},"auraApplied"),	
					},
					dk	= {
						type = 'group',
						inline = true,
						name = "|cffC41F3BDeath Knight|r",
						order = 6,
						args = listOption({1149039,1148792,1155233,1148707,1149222,1149016},"auraApplied"),
					},
					hunter = {
						type = 'group',
						inline = true,
						name = "|cffABD473Hunter|r",
						order = 7,
						args = listOption({1134471,1119263,1153480},"auraApplied"),
					},
					mage = {
						type = 'group',
						inline = true,
						name = "|cff69CCF0Mage|r",
						order = 8,
						args = listOption({1145438,1112042,1112472,1112043,1128682},"auraApplied"),
					},
					paladin = {
						type = 'group',
						inline = true,
						name = "|cffF58CBAPaladin|r",
						order = 9,
						args = listOption({1131821,1110278,1101044,11642,1106940,1100498,1164205,1154428},"auraApplied")
					},
					priest	= {
						type = 'group',
						inline = true,
						name = "|cffFFFFFFPriest|r",
						order = 10,
						args = listOption({1133206,1110060,1106346,1147585,1114751,1147788},"auraApplied")
					},
					rogue = {
						type = 'group',
						inline = true,
						name = "|cffFFF569Rogue|r",
						order = 11,
						args = listOption({1111305,1114177,1151713,1131224,1113750,1126669},"auraApplied")
					},
					shaman	= {
						type = 'group',
						inline = true,
						name = "|cff0070DEShaman|r",
						order = 12,
						args = listOption({1130823,1100379,1157960,1116166},"auraApplied"),
					},
					warrior	= {
						type = 'group',
						inline = true,
						name = "|cffC79C6EWarrior|r",
						order = 13,
						args = listOption({1101719,1155694,1100871,1112975,1118499,1120230,1123920,1112328,1146924,1112292},"auraApplied")
					},
					warlock	= {
						type = 'group',
						inline = true,
						name = "|cff9482C9Warlock|r",
						order = 14,
						args = listOption({1117941},"auraApplied"),
						},
					races = {
						type = 'group',
						inline = true,
						name = "|cffFFFFFFGeneral Races|r",
						order = 15,
						args = listOption({58984,1126297,1120594,1133702,7744,1128880},"auraApplied"),
					},			
					}
				},
			spellAuraRemoved = {
				type = 'group',
				--inline = true,
				name = "Enemy Buff Down",
				desc = "Alerts you when enemy buffs or used cooldowns are off the enemy",
				set = setOption,
				get = getOption,
				disabled = function() return sadb.auraRemoved end,
				order = 3,
				args = {
					druid = {
						type = 'group',
						inline = true,
						name = "|cffFF7D0ADruid|r",
						order = 1,
						args = listOption({1153201},"auraRemoved"),
					},
					dk = {
						type = 'group',
						inline = true,
						name = "|cffC41F3BDeath Knight|r",
						order = 2,
						args = listOption({1148707,1148792,1149039},"auraRemoved"),
					},
					hunter = {
						type = 'group',
						inline = true,
						name = "|cffABD473Hunter|r",
						order = 3,
						args = listOption({1119263,1134471},"auraRemoved"),
					},
					mage = {
						type = 'group',
						inline = true,
						name = "|cff69CCF0Mage|r",
						order = 4,
						args = listOption({1145438},"auraRemoved"),
					},
					paladin = {
						type = 'group',
						inline = true,
						name = "|cffF58CBAPaladin|r",
						order = 5,
						args = listOption({1100498,1110278,11642},"auraRemoved"),
					},
					priest	= {
						type = 'group',
						inline = true,
						name = "|cffFFFFFFPriest|r",
						order = 6,
						args = listOption({1147585,1133206},"auraRemoved"),
					},
					rogue = {
						type = 'group',
						inline = true,
						name = "|cffFFF569Rogue|r",
						order = 7,
						args = listOption({1131224,1126669},"auraRemoved"),
					},
					warrior = {
						type = 'group',
						inline = true,
						name = "|cffC79C6EWarrior|r",
						order = 8,
						args = listOption({1101719,1100871,1112292,1146924},"auraRemoved"),
					},	
				}
			},
			spellCastStart = {
				type = 'group',
				--inline = true,
				name = "Enemy Spell Casting",
				desc = "Alerts you when an enemy is attempting to cast a spell on you or another player",
				disabled = function() return sadb.castStart end,
				set = setOption,
				get = getOption,
				order = 4,
				args = {
					general = {
						type = 'group',
						inline = true,
						name = "General Spells",
						order = 2,
						args = {
							bigHeal = {
								type = 'toggle',
								name = SpellTexture(48782).."Big Heals",
								desc = "Heal, Holy Light, Healing Wave, Healing Touch",
								order = 1,
							},
							resurrection = {
								type = 'toggle',
								name = SpellTexture(20609).."Resurrection spells", 
								desc = "Ancestral Spirit, Redemption, etc",
								order = 2,
							},
						}
					},
					druid = {
						type = 'group',
						inline = true,
						name = "|cffFF7D0ADruid|r",
						order = 3,
						args = listOption({1102637,1133786, 1148465, 1100740},"castStart"),
					},
					hunter = {
						type = 'group',
						inline = true,
						name = "|cffABD473Hunter|r",
						order = 4,
						args = listOption({982,1114327},"castStart"),
					},
					mage = {
						type = 'group',
						inline = true,
						name = "|cff69CCF0Mage|r",
						order = 5,
						args = listOption({118,1398221},"castStart"),
					},
					paladin = {
						type = 'group',
						inline = true,
						name = "|cffF58CBAPaladin|r",
						order = 6,
						args = listOption({1110326},"castStart"),
					},
					priest	= {
						type = 'group',
						inline = true,
						name = "|cffFFFFFFPriest|r",
						order = 7,
						args = listOption({1108129,1109484,1164843,11605},"castStart"),
					},
					shaman	= {
						type = 'group',
						inline = true,
						name = "|cff0070DEShaman|r",
						order = 8,
						args = listOption({1151514,1160043},"castStart"),
						},
					
					warlock	= {
						type = 'group',
						inline = true,
						name = "|cff9482C9Warlock|r",
						order = 9,
						args = listOption({6215,1117928,710,11712,1398206},"castStart"),
					},
				},
			},
			spellCastSuccess = {
				type = 'group',
				--inline = true,
				name = "Enemy Cooldown Abilities",
				desc = "Alerts you when enemies have used cooldowns",
				disabled = function() return sadb.castSuccess end,
				set = setOption,
				get = getOption,
				order = 5,
				args = {
					druid = {
						type = 'group',
						inline = true,
						name = "|cffFF7D0ADruid|r",
						order = 1,
						args = listOption({1133831,1398193,1398192,2304523,1105215},"castSuccess"),
					},
					dk	= {
						type = 'group',
						inline = true,
						name = "|cffC41F3BDeath Knight|r",
						order = 2,
						args = listOption({1147528,1147476,1147568,1149206,1149203,1149005},"castSuccess"),
					},
					hunter = {
						type = 'group',
						inline = true,
						name = "|cffABD473Hunter|r",
						order = 3,
						args = listOption({1153271,1123989,1119386,1134490,1149050,1114311,1113810,1133044},"castSuccess"),
					},
					mage = {
						type = 'group',
						inline = true,
						name = "|cff69CCF0Mage|r",
						order = 4,
						args = listOption({1144445,1112051,1144572,1111958,1102139,1100066,1398172,1398160},"castSuccess"),
					},
					paladin = {
						type = 'group',
						inline = true,
						name = "|cffF58CBAPaladin|r",
						order = 5,
						args = listOption({1120066,1110308,1131884},"castSuccess"),
					},
					priest	= {
						type = 'group',
						inline = true,
						name = "|cffFFFFFFPriest|r",
						order = 6,
						args = listOption({1110890,1134433,1164044,1148173},"castSuccess"),
					},
					rogue = {
						type = 'group',
						inline = true,
						name = "|cffFFF569Rogue|r",
						order = 7,
						args = listOption({1151722,1151724,2094,1766,1114185,1126889,1113877,1784,1398189},"castSuccess"),
					},
					shaman	= {
						type = 'group',
						inline = true,
						name = "|cff0070DEShaman|r",
						order = 8,
						args = listOption({1108143,1116190,1102484,1108177,1132182,1102825,1398198},"castSuccess"),
					},
					warrior	= {
						type = 'group',
						inline = true,
						name = "|cffC79C6EWarrior|r",
						order = 9,
						args = listOption({1102457,1102458,1100071,1180850,1100676,115246,1106552,1100072},"castSuccess"),
					},
					warlock = {
						type = 'group',
						inline = true,
						name = "|cff9482C9Warlock|r",
						order = 10,
						args = listOption({115138,1119647,1148020,1147860,1106358,1398195,1398197},"castSuccess"),
					},	
				},
			},
			enemydebuff = {
				type = 'group',
				--inline = true,
				name = "Enemy Debuff",
				desc = "Alerts you when you (or your arena partner) have casted a CC on an enemy",
				disabled = function() return sadb.dEnemyDebuff end,
				set = setOption,
				get = getOption,
				order = 6,
				args = {
						fromself = {
						type = 'group',
						inline = true,
						name = "|cffFFF569From Self|r",
						order = 1,
						args = listOption({2094,1151724,1151514,1112826,118,1133786},"enemyDebuffs"),
					},
					fromarenapartner = {
						type = 'group',
						inline = true,
						name = "|cffFFF569From Arena Partner or affecting your Target|r",
						order = 2,
						args = listOption({2094,1151724,1151514,1112826,118,1133786},"friendCCenemy"),
					}
				},
			},
			enemydebuffdown = {
				type = 'group',
				--inline = true,
				name = "Enemy Debuff Down",
				desc = "Alerts you when your (or your arena partner) casted CC's on an enemy is down",
				disabled = function() return sadb.eEnemyDebuffDown end,
				set = setOption,
				get = getOption,
				order = 7,
				args = {
					fromself = {
						type = 'group',
						inline = true,
						name = "|cffFFF569From Self|r",
						order = 1,
						args = listOption({2094,1151724,1151514,1112826,118,1133786},"enemyDebuffdown"),
					},
					fromarenapartner = {
						type = 'group',
						inline = true,
						name = "|cffFFF569From Arena Partner or affecting your Target|r",
						desc = "Alerts you if your arena partner casts a spell or your target gets afflicted by a spell",
						order = 2,
						args = listOption({2094,1151724,1151514,1112826,118,1133786},"enemyDebuffdownAP"),
					}
				},
			},
			chatalerter = {
				type = 'group',
				name = "Chat Alerts",
				desc = "Alerts you and others via sending a chat message",
				disabled = function() return sadb.chatalerts end,
				set = setOption,
				get = getOption,
				order = 1,
				args = {
					caonlyTF = {
						type = 'toggle',
						name = L["Target and Focus only"],
						desc = L["Alerts you when your target or focus is applicable to a sound alert"],
						order = 1,
					},
					chatgroup = {
						type = 'group',
						order = 2,
						name = L["Chat Channels to Alert In"],
						inline = true,
						args = {
							NONE = {
								type = 'toggle',
								order = 0,
								name = L["None (Disable Chat Alerts)"],
								desc = L["Disables all chat alerts globally, overriding other selections."],
								set = function(info, value) sadb.chatgroups.NONE = value end,
								get = function(info) return sadb.chatgroups.NONE end,
							},
							SAY = {
								type = 'toggle',
								order = 1,
								name = L["Say"],
								set = function(info, value) sadb.chatgroups.SAY = value end,
								get = function(info) return sadb.chatgroups.SAY end,
							},
							PARTY = {
								type = 'toggle',
								order = 2,
								name = L["Party"],
								set = function(info, value) sadb.chatgroups.PARTY = value end,
								get = function(info) return sadb.chatgroups.PARTY end,
							},
							RAID = {
								type = 'toggle',
								order = 3,
								name = L["Raid"],
								set = function(info, value) sadb.chatgroups.RAID = value end,
								get = function(info) return sadb.chatgroups.RAID end,
							},
							BATTLEGROUND = {
								type = 'toggle',
								order = 4,
								name = L["Battleground"],
								set = function(info, value) sadb.chatgroups.BATTLEGROUND = value end,
								get = function(info) return sadb.chatgroups.BATTLEGROUND end,
							},
						},
					},
					spells = {
						type = 'group',
						inline = true,
						name = "Spells",
						order = 3,
						args = {
							stealthenemy = {
								type = 'toggle',
								name = SpellTextureName(1784),
								desc = function ()
									GameTooltip:SetHyperlink(GetSpellLink(1784));
								end,
								order = 1,
							},
							prowlenemy = {
                                type = 'toggle',
                                name = SpellTextureName(1105215),
                                desc = function ()
                                    GameTooltip:SetHyperlink(GetSpellLink(1105215));
                                end,
                                order = 2,
                            },
							blindenemy = {
								type = 'toggle',
								name = SpellTexture(2094).."Blind on Enemy",
								desc = "Enemies you blind will be alerted in chat",
								order = 3,
							},
							blindselffriend = {
								type = 'toggle',
								name = SpellTexture(2094).."Blind on Self/Friend",
								desc = "Enemies that have blinded you will be alerted",
								order = 4,
							},
							cycloneenemy = {
								type = 'toggle',
								name = SpellTexture(33786).."Cyclone on Enemy",
								desc = "Enemies you cyclone will be alerted in chat",
								order = 5,
							},
							cycloneselffriend = {
								type = 'toggle',
								name = SpellTexture(33786).."Cyclone on Self/Friend",
								desc = "Enemies you cyclone will be alerted in chat",
								order = 6,
							},
							hexenemy = {
								type = 'toggle',
								name = SpellTexture(51514).."Hex on Enemy",
								desc = "Enemies you hex will be alerted in chat",
								order = 7,
							},
							hexselffriend = {
								type = 'toggle',
								name = SpellTexture(51514).."Hex on Self/Friend",
								desc = "Enemies you hex will be alerted in chat",
								order = 8,
							},
							fearenemy = {
								type = 'toggle',
								name = SpellTexture(5484).."Fear on Enemy",
								desc = "Enemies you fear will be alerted in chat",
								order = 9,
							},
							fearselffriend = {
								type = 'toggle',
								name = SpellTexture(5484).."Fear on Self/friend",
								desc = "Enemies you fear will be alerted in chat",
								order = 10,
							},
							sapenemy = {
								type = 'toggle',
								name = SpellTexture(6770).."Sap on Enemy",
								desc = "Enemies you sapped will be alerted",
								order = 11,
							},
							bubbleenemy = {
								type = 'toggle',
								name = SpellTextureName(642),
								desc = "Enemies that have casted Divine Shield will be alerted",
								order = 12,
							},
							polyenemy = {
								type = 'toggle',
								name = SpellTextureName(118),
								desc = "Enemies that have casted Polymorph will be alerted",
								order = 13,
							},
							vanishenemy = {
								type = 'toggle',
								name = SpellTextureName(26889),
								desc = "Enemies that have casted Vanish will be alerted",
								order = 13,
							},
							trinketalert = {
								type = 'toggle',
								name = GetSpellInfo(42292),
								desc = function ()
									GameTooltip:SetHyperlink(GetSpellLink(42292));
								end,
								order = 14,
							},
							interruptenemy = {
								type = 'toggle',
								name = "Interrupt on Enemy",
								desc = "Sends a chat message if you have interrupted an enemy's spell.",
								order = 15,
							},
							interruptself = {
								type = 'toggle',
								name = "Interrupt on Self",
								desc = "Sends a chat message if an enemy has interrupted you.",
								order = 16,
							},
							chatdownself = {
								type = 'toggle',
								name = "Alert enemy debuff down (from self)",
								desc = "Sends a chat message when an enemies debuff is down that came from yourself (eg. Hex down)",
								order = 17,
							},
							chatdownfriend = {
								type = 'toggle',
								name = "Alert enemy debuff down (from friend)",
								desc = "Sends a chat message when an enemies debuff is down that came from yourself (eg. Hex down)",
								order = 17,
							},
						},
					},
					general = {
						type = "group",
						inline = true,
						name = "General Chat Alerts",
						args = {
							enemychat = {
								type = "input",
								name = "To Enemy",
								desc = "Example: '#spell# up on #enemy#' = [Blind] up on Enemyname",
								order = 1,
								width = "full",
							},
							friendchat = {
								type = "input",
								name = "From Enemy to friend",
								desc = "Example: '#enemy# casted #spell# on #target# = Enemyname casted [Blind] on FriendName",
								order = 2,
								width = "full",
							},
							selfchat = {
								type = "input",
								name = "From Enemy to self",
								desc = "Example: '#enemy# casted #spell# on #target# = Enemyname casted [Blind] on FriendName",
								order = 3,
								width = "full",
							},
							enemybuffchat = {
								type = "input",
								name = "Enemy buffs/cooldowns",
								desc = "Example: '#enemy# casted #spell#  = Enemyname casted [Stealth]",
								order = 4,
								width = "full",
							},
						},
					},
					saptextfriendg = {
						type = "group",
						inline = true,
						hidden = function() if sadb.sapenemy then return false else return true end end,
						name = SpellTexture(6770).."Sap on self/friend",
						order = 13,
						args = {
							sapselftext = {
							type = "input",
							name = "Sap on Self (Avoid using '#enemy# due to unknown enemy when stealthed)",
							order = 1,
							width = "full",
							},
							sapfriendtext = {
							type = "input",
							name = "Sap on Friend (Avoid using '#enemy# due to unknown enemy when stealthed)",
							order = 1,
							width = "full",
							},
						},
					},
				trinketalerttextg = {
						type = "group",
						inline = true,
						hidden = function() if sadb.trinketalert then return false else return true end end,
						name = "PvP trinket text",
						order = 14,	
						args = {
							trinketalerttext = {
							type = 'input',
							name = "Example: '#enemy# casted #spell#!' = Enemyname casted [PvP Trinket]!",
							order = 1,
							width = "full",
							},
						},
					},
				stealthalerttextg = {
						type = "group",
						inline = true,
						hidden = function() if sadb.stealthenemy then return false else return true end end,
						name = SpellTextureName(1784),
						order = 15,
						args = {
							stealthTF = {
							type = 'toggle',
							name = "Ignore target/focus",
							order = 2,
							},
						},
					},
				prowlalerttextg = {
						type = "group",
						inline = true,
						hidden = function() if sadb.prowlenemy then return false else return true end end,
						name = SpellTextureName(1105215),
						order = 16,
						args = {
							prowlTF = {
							type = 'toggle',
							name = "Ignore target/focus",
							order = 3,
							},
						},
					},
				vanishalerttextg = {
						type = "group",
						inline = true,
						hidden = function() if sadb.vanishenemy then return false else return true end end,
						name = SpellTextureName(26889),
						order = 17,	
						args = {
							vanishTF = {
							type = 'toggle',
							name = "Ignore target/focus",
							order = 4,
							},
						},
					},
			InterruptTextg = {
						type = "group",
						inline = true,
						name = "Interrupt Text",
						order = 18,
						args = {
							InterruptEnemyText = {
							name = "Interrupt on Enemy (eg. 'Interrupted #enemy#'s #interruptedspellname# with #spell#.')",
							hidden = function() if sadb.interruptenemy then return false else return true end end,
							type = "input",
							order = 1,
							width = "full",
							},
							InterruptSelfText = {
							name = "Interrupts from Enemy (eg. '#enemy# interrupted my #interruptedspellname# with #spell#.')",
							hidden = function() if sadb.interruptself then return false else return true end end,
							type = "input",
							order = 1,
							width = "full",
							},
						},
					},
				},
			},--end chat alert menu
			FriendDebuff = {
				type = 'group',
				--inline = true,
				name = "Arena partner Enemy Spell Casting",
				desc = "Alerts you when an enemy is casting a spell targetted at your arena partner",
				disabled = function() return sadb.dArenaPartner end,
				set = setOption,
				get = getOption,
				order = 8,
				args = listOption({1151514,118,1133786,6215},"friendCCs"),
			},
			FriendDebuffSuccess = {
			type = 'group',
			name = "Arena partner CCs/Debuffs",
			desc = "Alerts you when your arena partner gets CC'd",
			disabled = function() return sadb.dArenaPartner end,
			set = setOption,
			get = getOption,
			order = 9,
			args = listOption({1114309,2094,1110308,1151514,1112826,1133786,6215,1102139,1151724},"friendCCSuccess"),
			},
			selfDebuffs = {
				type = 'group',
				--inline = true,
				name = "Self Debuffs",
				desc = "Alerts you when you get afflicted by one of these spells when you aren't targeting the enemy.",
				disabled = function() return sadb.dSelfDebuff end,
				set = setOption,
				get = getOption,
				order = 10,
				args = listOption({1133786,1151514,118,6215,1114309,1113809,115246,1117928,2094,1151724,1110308,1147860,115138,1144572,1120066,1134490,1119434,1147476,1151722,1149005,1119386,1106358},"selfDebuff"),
			},
		},
	})
	self:AddOption('custom', {
		type = 'group',
		name = L["Custom Alerts"],
		desc = L["Create a custom sound or chat alert with text or a sound file"],
		order = 3,
		args = {
			newalert = {
				type = 'execute',
				name = function ()
							if sadb.custom[L["New Alert"]] then  
								return L["Rename the New Alert entry"]
							else
								return L["New Alert"]
							end
						end,
				order = -1,
				func = function()
					sadb.custom[L["New Alert"]] = {
						name = L["New Alert"],
						soundfilepath = L["New Alert"]..".[ogg/mp3/wav]",
						sourceuidfilter = "any",
						destuidfilter = "any",
						eventtype = {
							SPELL_CAST_SUCCESS = true,
							SPELL_CAST_START = false,
							SPELL_AURA_APPLIED = false,
							SPELL_AURA_REMOVED = false,
							SPELL_INTERRUPT = false,
							SPELL_SUMMON = false,
						},
						sourcetypefilter = COMBATLOG_FILTER_EVERYTHING,
						desttypefilter = COMBATLOG_FILTER_EVERYTHING,
						order = 0,
					}
					self:OnOptionsCreate()
				end,
				disabled = function ()
					if sadb.custom[L["New Alert"]] then
						return true
					else
						return false
					end
				end,
			},
		}
	})
	local function makeoption(key)
		local keytemp = key
		self.options.args.custom.args[key] = {
			type = 'group',
			name = sadb.custom[key].name,
			set = function(info, value) local name = info[#info] sadb.custom[key][name] = value end,
			get = function(info) local name = info[#info] return sadb.custom[key][name] end,
			order = sadb.custom[key].order,
			args = {
				name = {
					name = L["Spell Entry Name"],
					desc = L["Menu entry for the spell (eg. Hex down on arena partner)"],
					type = 'input',
					set = function(info, value)
						if sadb.custom[value] then log(L["same name already exists"]) return end
						sadb.custom[key].name = value
						sadb.custom[key].order = 100
						sadb.custom[value] = sadb.custom[key]
						sadb.custom[key] = nil
						--makeoption(value)
						self.options.args.custom.args[keytemp].name = value
						key = value
					end,
					order = 1,
				},
				spellname = {
					name = L["Spell Name"],
					type = 'input',
					order = 10,
					hidden = function() return not sadb.custom[key].acceptSpellName end,
				},
				spellid = {
					name = L["Spell ID"],
					desc = L["Can be found on OpenWoW, in the URL"],
					set = function(info, value)
					local name = info[#info] sadb.custom[key][name] = value
						if GetSpellInfo(value) then
							sadb.custom[key].spellname = GetSpellInfo(value)
							self.options.args.custom.args[keytemp].spellname = GetSpellInfo(value)
						else
						sadb.custom[key].spellname = "Invalid Spell ID"
						self.options.args.custom.args[keytemp].spellname = "Invalid Spell ID"
						end
					end,
					type = 'input',
					order = 20,
					pattern = "%d+$",
				},
				remove = {
					type = 'execute',
					order = 25,
					name = L["Remove"],
					confirm = true,
					confirmText = L["Are you sure?"],
					func = function() 
						sadb.custom[key] = nil
						self.options.args.custom.args[keytemp] = nil
					end,
				},
				acceptSpellName = {
					type = 'toggle',
					name = "Use specific spell name",
					desc = "Use this in case there are multiple ranks for this spell",
					order = 26,
				},
				chatAlert = {
					type = 'toggle',
					name = "Chat Alert",
					order = 27,
				},
				test = {
					type = 'execute',
					order = 28,
					name = L["Test"],
					desc = L["If you don't hear anything, try restarting WoW"],
					func = function() PlaySoundFile("Interface\\Addons\\SoundAlerter\\CustomSounds\\"..sadb.custom[key].soundfilepath) end,
					hidden = function() if sadb.custom[key].chatAlert then return true end end,
				},
				soundfilepath = {
					name = L["File Path"],
					desc = L["Place your ogg/mp3 custom sound in the CustomSounds folder in Interface/Addons/SoundAlerter/"],
					type = 'input',
					width = 'double',
					order = 27,
					hidden = function() if sadb.custom[key].chatAlert then return true end end,
				},
				chatalerttext = {
					name = "Chat Alert Text",
					desc = "eg. #enemy# casted #spell# on me! (Use '%t' if you're casting a spell on an enemy. )",
					type = 'input',
					width = 'double',
					order = 28,
					hidden = function() if not sadb.custom[key].chatAlert then return true end end,
				},
				eventtype = {
					type = 'multiselect',
					order = 50,
					name = L["Event type - it's best to have the least amount of event conditions"],
					values = self.SA_EVENT,
					get = function(info, k) return sadb.custom[key].eventtype[k] end,
					set = function(info, k, v) sadb.custom[key].eventtype[k] = v end,
				},
				sourceuidfilter = {
					type = 'select',
					order = 61,
					name = L["Source unit"],
					desc = L["Is the person who casted the spell your target/focus/mouseover?"],
					values = self.SA_UNIT,
				},
				sourcetypefilter = {
					type = 'select',
					order = 60,
					name = L["Source of the spell"],
					desc = L["Who casted the spell? Leave on 'any' if a spell got casted on you"],
					values = self.SA_TYPE,
				},
				sourcecustomname = {
					type= 'input',
					order = 62,
					name = L["Custom source name"],
					desc = L["Example: If the spell came from a specific player or boss"],
					disabled = function() return not (sadb.custom[key].sourceuidfilter == "custom") end,
				},
				destuidfilter = {
					type = 'select',
					order = 65,
					name = L["Spell destination unit"],
					desc = L["Was the spell destination towards your target/focus/mouseover? (Leave on 'player' if it's yourself)"],
					values = self.SA_UNIT,
				},
				desttypefilter = {
					type = 'select',
					order = 63,
					name = L["Spell Destination"],
					desc = L["Who was afflicted by the spell? Leave it on 'any' if it's a spell cast or a buff"],
					values = self.SA_TYPE,
				},
				destcustomname = {
					type= 'input',
					order = 68,
					name = L["Custom destination name"],
					disabled = function() return not (sadb.custom[key].destuidfilter == "custom") end,
				},
				--[[NewLine5 = {
					type = 'header',
					order = 69,
					name = "",
				},]]
			}
		}
	end
	for key, v in pairs(sadb.custom) do
		makeoption(key)
	end
end