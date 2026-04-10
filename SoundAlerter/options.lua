local sadb
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local AceConfig = LibStub("AceConfig-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("SoundAlerter")
local self, SoundAlerter = SoundAlerter, SoundAlerter

-- Voice Alerts search state storage
local voiceAlertSearchQueries = {
	spellauraApplied = "",
	spellAuraRemoved = "",
	spellCastStart = "",
	spellCastSuccess = "",
	enemydebuff = "",
	enemydebuffdown = ""
}

-- Spell Tracker add spell form state
local spellTrackerAddForm = {
	spellID = "",
	unit = "player",
	auraType = "HELPFUL"
}

-- Spell Tracker selection state for UI
local spellTrackerSelectedIndex = nil  -- Currently selected spell index (1-20) or nil

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

    local widget = AceConfigDialog.OpenFrames[configName]
    if widget and widget.frame and widget.frame:IsVisible() then
        widget:Hide()
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

-- Helper function to count spells in a list
function countSpells(spellList)
	local count = 0
	for k,v in pairs(spellList) do
		count = count + 1
	end
	return count
end

-- Helper function to create search bar widget for Voice Alerts sections
-- @param sectionKey: The key identifying which Voice Alert section this is for
-- @return: Table containing the search bar configuration
local function createSearchBar(sectionKey)
	return {
		searchBarGroup = {
			type = 'group',
			inline = true,
			name = "|TInterface\\Icons\\INV_Misc_Spyglass_02:20|t  Search Spells",
			order = 1000, -- Place at bottom of section
			args = {
				searchInput = {
					type = 'input',
					name = "Search for spell names",
					desc = "Type to filter spells by name. Search is case-insensitive and shows only matching spells.",
					width = "full",
					order = 1,
					get = function()
						return voiceAlertSearchQueries[sectionKey] or ""
					end,
					set = function(info, value)
						voiceAlertSearchQueries[sectionKey] = value:lower()
						-- Force refresh of the config panel to update visibility
						AceConfigDialog:Open("SoundAlerter")
					end,
				},
				clearButton = {
					type = 'execute',
					name = "Clear Search",
					desc = "Clear the search filter and show all spells",
					order = 2,
					width = "half",
					func = function()
						voiceAlertSearchQueries[sectionKey] = ""
						-- Force refresh of the config panel
						AceConfigDialog:Open("SoundAlerter")
					end,
					disabled = function()
						return not voiceAlertSearchQueries[sectionKey] or voiceAlertSearchQueries[sectionKey] == ""
					end,
				},
			},
		},
	}
end

-- Helper function to check if a spell should be hidden based on search filter
-- @param spellID: The spell ID to check
-- @param sectionKey: The key identifying which Voice Alert section this is for
-- @return: true if spell should be hidden, false if it should be shown
local function shouldHideSpell(spellID, sectionKey)
	local query = voiceAlertSearchQueries[sectionKey]
	if not query or query == "" then
		return false -- No search query, show all spells
	end

	local spellName = GetSpellInfo(spellID)
	if not spellName then
		return true -- Can't get spell name, hide it
	end

	-- Case-insensitive search
	return not string.find(spellName:lower(), query, 1, true)
end

function listOption(spellList, listType, sectionKey, ...)
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

			-- Add hidden property for search filtering if sectionKey is provided
			if sectionKey then
				option.hidden = function()
					return shouldHideSpell(v, sectionKey)
				end
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

function SoundAlerter:OnOptionsProfileChanged()
	sadb = self.db1.profile
	sadb.custom = sadb.custom or {}
	sadb.proximityToasts = sadb.proximityToasts or {}
end

function SoundAlerter:OnOptionsCreate()
	sadb = self.db1.profile
	self:AddOption("profiles", LibStub("AceDBOptions-3.0"):GetOptionsTable(self.db1))
	self.options.args.profiles.order = -1

	-- ===========================
	-- QUICK START TAB (SLC: Simple)
	-- ===========================
	self:AddOption('QuickStart', {
		type = 'group',
		name = "Quick Start",
		desc = "Get arena-ready in 60 seconds. Select your PvP zones and essential alerts. Advanced users can customize 450+ spells in Voice Alerts.",
		order = 0.5,
		args = {
			description = {
				type = 'description',
				name = "|cff00FF00Welcome to SoundAlerter!|r\n\nThis Quick Start guide will help you configure the essential settings to get started in PvP. For advanced customization, visit the Voice Alerts and other tabs.\n",
				fontSize = "medium",
				order = 1,
			},
			enableZones = {
				type = 'group',
				inline = true,
				name = "1. Enable Zones",
				desc = "Select where you want SoundAlerter to be active",
				set = setOption,
				get = getOption,
				order = 2,
				args = {
					arena = {
						type = 'toggle',
						name = "Arena",
						desc = "Enable voice alerts in Arena matches (recommended for competitive PvP)",
						width = "full",
						order = 1,
					},
					battleground = {
						type = 'toggle',
						name = "Battleground",
						desc = "Enable voice alerts in Battlegrounds (recommended for large-scale PvP)",
						width = "full",
						order = 2,
					},
					field = {
						type = 'toggle',
						name = "World PvP",
						desc = "Enable voice alerts in open world PvP zones",
						width = "full",
						order = 3,
					},
				},
			},
			alertScope = {
				type = 'group',
				inline = true,
				name = "2. Alert Scope",
				desc = "Choose how many enemies trigger alerts",
				set = setOption,
				get = getOption,
				order = 3,
				args = {
					scopeDescription = {
						type = 'description',
						name = "|cffFFD700Recommended:|r Target/Focus for Arena, All Enemies for Battlegrounds\n",
						order = 1,
					},
					myself = {
						type = 'toggle',
						name = "Target and Focus Only",
						desc = "Only alert when your current target/focus casts spells, or when enemies cast spells on you (best for Arena)",
						disabled = function() return sadb.enemyinrange end,
						width = "full",
						order = 2,
					},
					enemyinrange = {
						type = 'toggle',
						name = "All Enemies in Range",
						desc = "Alert for all enemy spells in combat log range (best for Battlegrounds)",
						disabled = function() return sadb.myself end,
						width = "full",
						order = 3,
					},
				},
			},
			essentialAlerts = {
				type = 'group',
				inline = true,
				name = "3. Essential Alerts (Pre-configured)",
				desc = "Critical spells that should always be announced",
				order = 4,
				args = {
					essentialDescription = {
						type = 'description',
						name = "These essential PvP spells are |cff00FF00enabled by default|r. Fine-tune individual spells in the Voice Alerts tab.\n\n|cffFFFFFFEnemy Defensives:|r Divine Shield, Ice Block, Barkskin\n|cffFFFFFFEnemy Crowd Control:|r Cyclone, Polymorph, Blind, Fear, Hex\n|cffFFFFFFSelf Alerts:|r CC effects on you (Cyclone, Poly, etc.)\n",
						fontSize = "medium",
						order = 1,
					},
				},
			},
			audioSettings = {
				type = 'group',
				inline = true,
				name = "4. Audio Settings",
				desc = "Volume and language preferences",
				order = 5,
				args = {
					volumeDescription = {
						type = 'description',
						name = "Volume is controlled by WoW's Master Volume slider. Voice alerts will respect your game volume settings.\n",
						order = 1,
					},
					languageNote = {
						type = 'description',
						name = "|cffFFD700Current Language:|r " .. (GetLocale() == "esES" and "Spanish (Limited)" or "English") .. "\n\nTo change languages, modify your WoW client locale. SoundAlerter auto-detects your game language.\n",
						order = 2,
					},
				},
			},
			nextSteps = {
				type = 'group',
				inline = true,
				name = "Next Steps",
				order = 6,
				args = {
					nextStepsDescription = {
						type = 'description',
						name = "|cff00FF00You're all set!|r Enter an arena or battleground to hear voice alerts.\n\n|cffFFFFFFAdvanced Configuration:|r\n• |cffFFD700Voice Alerts|r - Customize 450+ spell alerts per class\n• |cffFFD700Proximity Alerts|r - Detect enemies nearby\n• |cffFFD700Chat Alerts|r - Send spell announcements to party/raid chat\n\n|cffFF0000Need Help?|r Type |cffFFD700/sa|r to reopen this menu anytime.\n\n|cffADD8E6th3pajay|r",
						fontSize = "medium",
						order = 1,
					},
				},
			},
		},
	})

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
					zoneNote = {
						type = 'description',
						name = "|cffFFD700Zone Settings:|r Configure which zones have alerts enabled in the |cff00FF00Quick Start|r tab.\n",
						fontSize = "small",
						order = 0,
					},
					all = {
						type = 'toggle',
						name = "Enable Everything",
						desc = "Enables Sound Alerter for BGs, world and arena",
						order = 1,
					},
					ignorePVEMode = {
						type = 'toggle',
						name = "Ignore PVE Mode Players",
						desc = "Don't alert for players in PVE Mode in World PvP (not active in BGs/Arenas)",
						order = 5,
					},
					AlertConditions = {
						type = 'group',
						inline = true,
						order = 9,
						name = "Alert Conditions",
						args = {
							scopeNote = {
								type = 'description',
								name = "|cffFFD700Alert Scope:|r Configure target/focus vs all enemies in the |cff00FF00Quick Start|r tab.\n",
								fontSize = "small",
								order = 0,
							},
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
										sadb.custom = {}
								end,
							},
							export = {
								type = 'execute',
								name = "Export encapsulation",
								order = 2,
								func = function()
								if not sadb.custom or not next(sadb.custom) then sadb.exportbox = "@#" return end
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

	-- ===========================
	-- PROXIMITY ALERTS TAB - UX REDESIGNED
	-- ===========================
	self:AddOption('ProximityAlerts', {
		type = 'group',
		name = "Proximity Alerts",
		desc = "Detect enemy stealthed players nearby and get voice alerts. Perfect for spotting Rogues and Druids in stealth.",
		order = 2.5,
		args = {
			-- ===========================
			-- INTRODUCTION DESCRIPTION
			-- ===========================
			description = {
				type = 'description',
				name = "|cffFFD700Proximity Alerts|r detect hostile players near you by checking targets and mouseovers.\n\nThis feature is especially useful for:\n• Detecting stealthed Rogues and Druids\n• Awareness in world PvP \n• Preventing ganks and ambushes\n\n|cffFF0000Important:|r Proximity detection only works when you target or mouseover an enemy player. Limited alerts are available based on combat logs.\n",
				fontSize = "medium",
				order = 1,
			},

			-- ===========================
			-- SECTION 1: BASIC SETUP
			-- ===========================
			basicSetup = {
				type = 'group',
				inline = true,
				name = "1. Basic Setup",
				desc = "Core settings to enable and configure proximity detection",
				set = setOption,
				get = getOption,
				order = 2,
				args = {
					proximityEnabled = {
						type = 'toggle',
						name = "Enable Proximity Alerts",
						desc = "Master toggle for proximity detection system. Enable this first to activate all proximity features.",
						width = "full",
						order = 1,
					},
					spacer1 = {
						type = 'description',
						name = " ",
						order = 2,
					},
					zoneHeader = {
						type = 'header',
						name = "Active Zones",
						order = 3,
					},
					zoneDescription = {
						type = 'description',
						name = "Select where proximity alerts should be active:",
						fontSize = "medium",
						order = 4,
					},
					proximityWorld = {
						type = 'toggle',
						name = "World PvP",
						desc = "Enable proximity alerts in open world PvP zones",
						disabled = function() return not sadb.proximityEnabled end,
						width = "full",
						order = 5,
					},
					proximityBattleground = {
						type = 'toggle',
						name = "Battlegrounds",
						desc = "Enable proximity alerts in battlegrounds (useful for detecting flag carriers and node defenders)",
						disabled = function() return not sadb.proximityEnabled end,
						width = "full",
						order = 6,
					},
					proximityArena = {
						type = 'toggle',
						name = "Arena",
						desc = "Enable proximity alerts in arenas (less useful due to small arena size)",
						disabled = function() return not sadb.proximityEnabled end,
						width = "full",
						order = 7,
					},
					spacer2 = {
						type = 'description',
						name = " ",
						order = 8,
					},
					cooldownHeader = {
						type = 'header',
						name = "Alert Cooldown",
						order = 9,
					},
					proximityCooldown = {
						type = 'range',
						name = "Cooldown Duration (seconds)",
						desc = "Time before the same player can trigger another proximity alert. Prevents spam while still alerting to threats.",
						min = 5,
						max = 120,
						step = 5,
						disabled = function() return not sadb.proximityEnabled end,
						width = "full",
						order = 10,
					},
				},
			},

			-- ===========================
			-- SECTION 2: NOTIFICATION METHODS
			-- ===========================
			notificationMethods = {
				type = 'group',
				inline = true,
				name = "2. Notification Methods",
				desc = "Choose how you want to be alerted to nearby enemies",
				set = setOption,
				get = getOption,
				order = 3,
				args = {
					methodsInfo = {
						type = 'description',
						name = "Choose how proximity alerts notify you when enemies are detected nearby:",
						fontSize = "medium",
						order = 1,
					},
					audioHeader = {
						type = 'header',
						name = "Audio Alerts",
						order = 2,
					},
					audioNote = {
						type = 'description',
						name = "|cff00FF00Enabled by default.|r Voice alerts are configured in the main Voice Alerts tab.\n",
						fontSize = "medium",
						order = 3,
					},
					chatHeader = {
						type = 'header',
						name = "Chat Alerts",
						order = 4,
					},
					proximityChat = {
						type = 'toggle',
						name = "Send Chat Messages",
						desc = "Announce proximity detections in chat (useful for alerting teammates)",
						disabled = function() return not sadb.proximityEnabled end,
						width = "full",
						order = 5,
					},
					proximityChatText = {
						type = 'input',
						name = "Chat Message Template",
						desc = "Customize the chat message. Available placeholders:\n#class# - Enemy class name\n#player# - Enemy player name\n\nExample: [#class#] #player# detected nearby!",
						disabled = function() return not sadb.proximityEnabled or not sadb.proximityChat end,
						width = 'full',
						order = 6,
					},
					toastHeader = {
						type = 'header',
						name = "Visual Toast Notifications",
						order = 7,
					},
					toastDescription = {
						type = 'description',
						name = "Show pop-up notifications for proximity alerts:",
						fontSize = "medium",
						order = 8,
					},
					toastEnabled = {
						type = 'toggle',
						name = "Enable Toast Notifications",
						desc = "Show visual pop-up toasts when enemies are detected nearby. Additional customization options appear below when enabled.",
						disabled = function() return not sadb.proximityEnabled end,
						width = "full",
						order = 9,
						set = function(info, value)
							sadb.proximityToasts.enabled = value
							if not value and SoundAlerter.ProximityToasts then
								SoundAlerter.ProximityToasts:OnDisable()
							end
						end,
						get = function(info)
							return sadb.proximityToasts.enabled
						end,
					},
					displayDuration = {
						type = 'range',
						name = "Display Duration (seconds)",
						desc = "How long the toast remains visible on screen",
						min = 2,
						max = 8,
						step = 0.5,
						disabled = function() return not sadb.proximityEnabled or not sadb.proximityToasts.enabled end,
						width = "full",
						order = 10,
						set = function(info, value)
							sadb.proximityToasts.displayDuration = value
						end,
						get = function(info)
							return sadb.proximityToasts.displayDuration
						end,
					},
					maxConcurrent = {
						type = 'range',
						name = "Max Concurrent Toasts",
						desc = "Maximum number of toasts to show at once (older toasts fade out early if limit is exceeded)",
						min = 1,
						max = 5,
						step = 1,
						disabled = function() return not sadb.proximityEnabled or not sadb.proximityToasts.enabled end,
						width = "full",
						order = 11,
						set = function(info, value)
							sadb.proximityToasts.maxConcurrent = value
						end,
						get = function(info)
							return sadb.proximityToasts.maxConcurrent
						end,
					},
				},
			},

			-- ===========================
			-- SECTION 3: VISUAL ALERTS
			-- ===========================
			toastAppearance = {
				type = 'group',
				inline = true,
				name = "3. Visual Alerts",
				desc = "Customize the visual style of toast notifications",
				set = setOption,
				get = getOption,
				order = 4,
				args = {
					appearanceInfo = {
						type = 'description',
						name = "Customize how toast notifications look:",
						fontSize = "medium",
						order = 1,
					},
					showPlayerName = {
						type = 'toggle',
						name = "Show Player Name",
						desc = "Display enemy player name in toast",
						disabled = function() return not sadb.proximityEnabled or not sadb.proximityToasts.enabled end,
						width = "full",
						order = 2,
						set = function(info, value)
							sadb.proximityToasts.showPlayerName = value
						end,
						get = function(info)
							return sadb.proximityToasts.showPlayerName
						end,
					},
					useClassColors = {
						type = 'toggle',
						name = "Use Class Colors",
						desc = "Color toast background based on enemy class (e.g., red for Warrior, purple for Warlock)",
						disabled = function() return not sadb.proximityEnabled or not sadb.proximityToasts.enabled end,
						width = "full",
						order = 3,
						set = function(info, value)
							sadb.proximityToasts.useClassColors = value
						end,
						get = function(info)
							return sadb.proximityToasts.useClassColors
						end,
					},
					rainbowBorder = {
						type = 'toggle',
						name = "Rainbow Border Animation",
						desc = "Enable smooth, slow rainbow color transitions on toast borders. Creates a visually distinct effect.",
						disabled = function() return not sadb.proximityEnabled or not sadb.proximityToasts.enabled end,
						width = "full",
						order = 4,
						set = function(info, value)
							sadb.proximityToasts.rainbowBorder = value
						end,
						get = function(info)
							return sadb.proximityToasts.rainbowBorder
						end,
					},
				},
			},

			-- ===========================
			-- SECTION 4: TOAST POSITION & TESTING
			-- ===========================
			toastPosition = {
				type = 'group',
				inline = true,
				name = "4. Toast Position & Testing",
				desc = "Adjust where toasts appear on screen and preview your settings",
				set = setOption,
				get = getOption,
				order = 5,
				args = {
					positionInfo = {
						type = 'description',
						name = "Adjust the screen position of toast notifications:",
						fontSize = "medium",
						order = 1,
					},
					positionX = {
						type = 'range',
						name = "Horizontal Position",
						desc = "Adjust horizontal position on screen (0 = center, negative = left, positive = right)",
						min = -500,
						max = 500,
						step = 10,
						disabled = function() return not sadb.proximityEnabled or not sadb.proximityToasts.enabled end,
						width = "normal",
						order = 2,
						set = function(info, value)
							sadb.proximityToasts.positionX = value
							if SoundAlerter.ProximityToasts then
								SoundAlerter.ProximityToasts:UpdateLayout()
							end
						end,
						get = function(info)
							return sadb.proximityToasts.positionX
						end,
					},
					positionY = {
						type = 'range',
						name = "Vertical Position",
						desc = "Adjust vertical position on screen (0 = center, negative = down from top, positive = up from bottom)",
						min = -500,
						max = 500,
						step = 10,
						disabled = function() return not sadb.proximityEnabled or not sadb.proximityToasts.enabled end,
						width = "normal",
						order = 3,
						set = function(info, value)
							sadb.proximityToasts.positionY = value
							if SoundAlerter.ProximityToasts then
								SoundAlerter.ProximityToasts:UpdateLayout()
							end
						end,
						get = function(info)
							return sadb.proximityToasts.positionY
						end,
					},
					spacer = {
						type = 'description',
						name = " ",
						order = 4,
					},
					testButton = {
						type = 'execute',
						name = "Test Toast Notification",
						desc = "Show a test toast notification to preview the current settings (position, appearance, duration)",
						disabled = function() return not sadb.proximityEnabled or not sadb.proximityToasts.enabled end,
						width = "full",
						order = 5,
						func = function()
							if SoundAlerter.ProximityToasts then
								SoundAlerter.ProximityToasts:ShowToast("TestEnemy", "ROGUE", nil, nil)
							end
						end,
					},
				},
			},

			-- ===========================
			-- SECTION 5: ADVANCED - CLICK INTERACTIONS
			-- ===========================
			clickInteractions = {
				type = 'group',
				inline = true,
				name = "5. Advanced: Click Interactions",
				desc = "Power user feature: Click toast notifications to target enemies",
				set = setOption,
				get = getOption,
				order = 6,
				args = {
					advancedWarning = {
						type = 'description',
						name = "|cffFF6600Advanced Feature:|r Click toast notifications to quickly target enemies.\n\n|cffFF0000World PvP Only:|r These features only work in contested/hostile open-world zones. They do NOT work in arenas or battlegrounds.\n",
						fontSize = "medium",
						order = 1,
					},
					clickEnabled = {
						type = 'toggle',
						name = "Enable Click Interaction",
						desc = "Allow clicking toast notifications to interact with enemies (world PvP only). Enable this to unlock click-to-target features.",
						disabled = function() return not sadb.proximityEnabled or not sadb.proximityToasts.enabled end,
						width = "full",
						order = 2,
						set = function(info, value)
							sadb.proximityToasts.clickEnabled = value
						end,
						get = function(info)
							return sadb.proximityToasts.clickEnabled
						end,
					},
					spacer1 = {
						type = 'description',
						name = " ",
						order = 3,
					},
					clickOptionsHeader = {
						type = 'header',
						name = "Click Actions",
						order = 4,
					},
					enableClickToTarget = {
						type = 'toggle',
						name = "Left-Click: Target Enemy",
						desc = "Normal left-click on toast: Automatically target the detected enemy player",
						disabled = function() return not sadb.proximityEnabled or not sadb.proximityToasts.enabled or not sadb.proximityToasts.clickEnabled end,
						width = "full",
						order = 5,
						set = function(info, value)
							sadb.proximityToasts.enableClickToTarget = value
						end,
						get = function(info)
							return sadb.proximityToasts.enableClickToTarget
						end,
					},
					enableFocusTarget = {
						type = 'toggle',
						name = "Shift+Click: Set Focus Target",
						desc = "Hold Shift and click on toast: Target enemy and set as focus target (useful for tracking stealthers)",
						disabled = function() return not sadb.proximityEnabled or not sadb.proximityToasts.enabled or not sadb.proximityToasts.clickEnabled end,
						width = "full",
						order = 6,
						set = function(info, value)
							sadb.proximityToasts.enableFocusTarget = value
						end,
						get = function(info)
							return sadb.proximityToasts.enableFocusTarget
						end,
					},
				},
			},
		},
	})

	-- ===========================
	-- BATTLEGROUND ALERTS TAB
	-- ===========================
	self:AddOption('BattlegroundAlerts', {
		type = 'group',
		name = "Battleground Alerts",
		desc = "Track battlefield objectives: flag pickups, captures, base assaults, and more.",
		order = 2.7,
		args = {
			-- ===========================
			-- INTRODUCTION DESCRIPTION
			-- ===========================
			description = {
				type = 'description',
				name = "|cffFFD700Battleground Alerts|r track objective events in battlegrounds.\n\n" ..
				       "|cffFFFFFFSupported Battlegrounds:|r\n" ..
				       "• Warsong Gulch (flag pickups, drops, captures)\n" ..
				       "• Eye of the Storm (flag events)\n" ..
				       "• Arathi Basin (base assaults, captures) - |cffAAAAAAComing Soon|r\n" ..
				       "• Alterac Valley (towers, graveyards) - |cffAAAAAAComing Soon|r\n\n" ..
				       "|cffFF0000Note:|r These alerts only work in battlegrounds.\n",
				fontSize = "medium",
				order = 1,
			},

			-- ===========================
			-- SECTION 1: BASIC SETUP
			-- ===========================
			enableGroup = {
				type = 'group',
				inline = true,
				name = "1. Basic Setup",
				order = 2,
				args = {
					battlegroundAlertsEnabled = {
						type = 'toggle',
						name = "Enable Battleground Alerts",
						desc = "Master toggle for all battlefield objective alerts. Enable this first to activate all battleground features.",
						get = function() return sadb.battlegroundAlertsEnabled end,
						set = function(_, val)
							sadb.battlegroundAlertsEnabled = val
							if SoundAlerter.FlagAlerts then
								if val then
									SoundAlerter.FlagAlerts:Enable()
								else
									SoundAlerter.FlagAlerts:Disable()
								end
								-- Update minimap button icon to reflect new state
								if SoundAlerter.UpdateMinimapButtonIcon then
									SoundAlerter:UpdateMinimapButtonIcon()
								end
							else
								SoundAlerter:Print("|cffFF0000Error: FlagAlerts module not loaded. Try /reload|r")
							end
						end,
						width = "full",
						order = 1,
					},
				},
			},

			-- ===========================
			-- SECTION 2: FLAG EVENTS
			-- ===========================
			flagAlerts = {
				type = 'group',
				inline = true,
				name = "2. Flag Events (WSG, EOTS)",
				desc = "Audio alerts for flag pickups, drops, and captures",
				order = 3,
				args = {
					flagPickupAudio = {
						type = 'toggle',
						name = "Flag Pickups",
						desc = "Alert when a player picks up a flag (e.g., 'Rogue picked up flag')",
						get = function() return sadb.flagPickupAudio end,
						set = function(_, val) sadb.flagPickupAudio = val end,
						disabled = function() return not sadb.battlegroundAlertsEnabled end,
						width = "full",
						order = 1,
					},
					flagDropAudio = {
						type = 'toggle',
						name = "Flag Drops",
						desc = "Alert when a flag is dropped",
						get = function() return sadb.flagDropAudio end,
						set = function(_, val) sadb.flagDropAudio = val end,
						disabled = function() return not sadb.battlegroundAlertsEnabled end,
						width = "full",
						order = 2,
					},
					flagCaptureAudio = {
						type = 'toggle',
						name = "Flag Captures",
						desc = "Alert when a flag is captured",
						get = function() return sadb.flagCaptureAudio end,
						set = function(_, val) sadb.flagCaptureAudio = val end,
						disabled = function() return not sadb.battlegroundAlertsEnabled end,
						width = "full",
						order = 3,
					},
					flagReturnAudio = {
						type = 'toggle',
						name = "Flag Returns",
						desc = "Alert when a flag is returned to base",
						get = function() return sadb.flagReturnAudio end,
						set = function(_, val) sadb.flagReturnAudio = val end,
						disabled = function() return not sadb.battlegroundAlertsEnabled end,
						width = "full",
						order = 4,
					},
				},
			},

			-- ===========================
			-- SECTION 3: VISUAL ALERTS
			-- ===========================
			toastIntegration = {
				type = 'group',
				inline = true,
				name = "3. Visual Alerts",
				desc = "Show toast notifications for flag events",
				order = 4,
				args = {
					flagToastsEnabled = {
						type = 'toggle',
						name = "Show Toast Notifications",
						desc = "Display visual toasts for flag carriers (uses proximity toast settings for appearance)",
						get = function() return sadb.flagToastsEnabled end,
						set = function(_, val) sadb.flagToastsEnabled = val end,
						disabled = function() return not sadb.battlegroundAlertsEnabled end,
						width = "full",
						order = 1,
					},
					rainbowBorder = {
						type = 'toggle',
						name = "Rainbow Border on Toasts",
						desc = "Animated rainbow-colored border effect on toast notifications (shared with Proximity Alerts)",
						disabled = function() return not sadb.battlegroundAlertsEnabled end,
						width = "full",
						order = 2,
						set = function(info, value)
							sadb.proximityToasts.rainbowBorder = value
						end,
						get = function(info)
							return sadb.proximityToasts.rainbowBorder
						end,
					},
					spacer1 = {
						type = 'description',
						name = " ",
						order = 3,
					},
					-- Team-based background colors
					flagTeamBackgroundColors = {
						type = 'toggle',
						name = "Team-based Background Colors",
						desc = "Enable color-coded backgrounds for flag alerts:\n" ..
						       "|cffFF5555• Red transparent background|r = Enemy team flag carrier\n" ..
						       "|cff55FF55• Green transparent background|r = Friendly team flag carrier\n\n" ..
						       "This helps you quickly identify which team picked up the flag without reading the toast.",
						get = function() return sadb.flagTeamBackgroundColors end,
						set = function(_, val) sadb.flagTeamBackgroundColors = val end,
						disabled = function() return not sadb.battlegroundAlertsEnabled or not sadb.flagToastsEnabled end,
						width = "full",
						order = 4,
					},
					flagEnemyRedBackground = {
						type = 'toggle',
						name = "  Enemy Team: Red Background",
						desc = "Show a red transparent background when an enemy team member picks up the flag. " ..
						       "This provides instant visual recognition of threats.",
						get = function() return sadb.flagEnemyRedBackground end,
						set = function(_, val) sadb.flagEnemyRedBackground = val end,
						disabled = function()
							return not sadb.battlegroundAlertsEnabled or
							       not sadb.flagToastsEnabled or
							       not sadb.flagTeamBackgroundColors
						end,
						width = "full",
						order = 5,
					},
					flagFriendlyGreenBackground = {
						type = 'toggle',
						name = "  Friendly Team: Green Background",
						desc = "Show a green transparent background when a friendly team member picks up the flag. " ..
						       "Useful for tracking your team's flag carrier.",
						get = function() return sadb.flagFriendlyGreenBackground end,
						set = function(_, val) sadb.flagFriendlyGreenBackground = val end,
						disabled = function()
							return not sadb.battlegroundAlertsEnabled or
							       not sadb.flagToastsEnabled or
							       not sadb.flagTeamBackgroundColors
						end,
						width = "full",
						order = 6,
					},
					flagEnemyTexture = {
						type = 'select',
						name = "  Enemy Team: Background Texture",
						desc = "Select the background texture pattern for enemy flag carrier toasts.\n\n" ..
						       "• |cffFFFFFFSolid|r - Clean, simple background (default)\n" ..
						       "• |cffFFFFFFDialog Box|r - Standard dialog texture\n" ..
						       "• |cffFFFFFFRock|r - Rough stone texture\n" ..
						       "• |cffFFFFFFMarble|r - Smooth marble texture\n\n" ..
						       "Texture is combined with the red color to help distinguish enemy flag carriers.",
						values = {
							["Solid"] = "Solid (Default)",
							["DialogBox"] = "Dialog Box",
							["Rock"] = "Rock",
							["Marble"] = "Marble",
						},
						get = function() return sadb.flagEnemyTexture or "Solid" end,
						set = function(_, val) sadb.flagEnemyTexture = val end,
						disabled = function()
							return not sadb.battlegroundAlertsEnabled or
							       not sadb.flagToastsEnabled or
							       not sadb.flagTeamBackgroundColors
						end,
						width = "full",
						order = 6.5,
					},
					flagFriendlyTexture = {
						type = 'select',
						name = "  Friendly Team: Background Texture",
						desc = "Select the background texture pattern for friendly flag carrier toasts.\n\n" ..
						       "• |cffFFFFFFSolid|r - Clean, simple background (default)\n" ..
						       "• |cffFFFFFFDialog Box|r - Standard dialog texture\n" ..
						       "• |cffFFFFFFRock|r - Rough stone texture\n" ..
						       "• |cffFFFFFFMarble|r - Smooth marble texture\n\n" ..
						       "Texture is combined with the green color to help identify friendly flag carriers.",
						values = {
							["Solid"] = "Solid (Default)",
							["DialogBox"] = "Dialog Box",
							["Rock"] = "Rock",
							["Marble"] = "Marble",
						},
						get = function() return sadb.flagFriendlyTexture or "Solid" end,
						set = function(_, val) sadb.flagFriendlyTexture = val end,
						disabled = function()
							return not sadb.battlegroundAlertsEnabled or
							       not sadb.flagToastsEnabled or
							       not sadb.flagTeamBackgroundColors
						end,
						width = "full",
						order = 6.6,
					},
					testTexturesButton = {
						type = 'execute',
						name = "Test Flag Alert Toasts",
						desc = "Shows test toasts with your selected textures and colors:\n" ..
						       "• Red enemy flag carrier toast (with your enemy texture)\n" ..
						       "• Green friendly flag carrier toast (with your friendly texture)\n\n" ..
						       "Test toasts appear at the EXACT position where real alerts will show.\n" ..
						       "Use the position sliders below to adjust placement.",
						func = function()
							if SoundAlerter.FlagAlerts then
								-- Use the actual FlagAlerts system for testing
								-- This ensures test position matches real alert position
								SoundAlerter.FlagAlerts:ShowFlagToast(
									"TestEnemy",      -- playerName
									"ROGUE",          -- playerClass
									"PICKUP",         -- eventType
									"HORDE_TEAM"      -- carrierTeam (enemy team = red)
								)

								-- Test friendly texture (1.2 second delay)
								SoundAlerter:ScheduleTimer(function()
									SoundAlerter.FlagAlerts:ShowFlagToast(
										"TestFriendly",   -- playerName
										"PALADIN",        -- playerClass
										"PICKUP",         -- eventType
										"ALLIANCE_TEAM"   -- carrierTeam (friendly team = green)
									)
								end, 1.2)

								DEFAULT_CHAT_FRAME:AddMessage("|cff00FF00SoundAlerter:|r Test flag toasts displayed at actual alert position!")
							else
								DEFAULT_CHAT_FRAME:AddMessage("|cffFF0000SoundAlerter:|r FlagAlerts module not loaded. Try /reload|r")
							end
						end,
						disabled = function()
							return not sadb.battlegroundAlertsEnabled or
							       not sadb.flagToastsEnabled
						end,
						width = "full",
						order = 6.7,
					},
					spacer2 = {
						type = 'description',
						name = "\n|cffFFD700Toast Position:|r",
						fontSize = "medium",
						order = 6.8,
					},
					flagPositionX = {
						type = 'range',
						name = "Horizontal Position (X)",
						desc = "Adjust horizontal position of flag alert toasts.\n" ..
						       "0 = Center of screen\n" ..
						       "Negative = Left of center\n" ..
						       "Positive = Right of center",
						min = -600,
						max = 600,
						step = 10,
						disabled = function()
							return not sadb.battlegroundAlertsEnabled or
							       not sadb.flagToastsEnabled
						end,
						width = "normal",
						order = 6.9,
						set = function(info, value)
							if not sadb.flagToasts then
								sadb.flagToasts = {}
							end
							sadb.flagToasts.positionX = value
							-- Update layout immediately if FlagAlerts is loaded
							if SoundAlerter.FlagAlerts then
								SoundAlerter.FlagAlerts:UpdateFlagToastLayout()
							end
						end,
						get = function(info)
							return sadb.flagToasts and sadb.flagToasts.positionX or 0
						end,
					},
					flagPositionY = {
						type = 'range',
						name = "Vertical Position (Y)",
						desc = "Adjust vertical position of flag alert toasts.\n" ..
						       "0 = Top of screen\n" ..
						       "Negative = Lower on screen (recommended: -200 to -400)\n" ..
						       "Default: -300 (below proximity alerts)",
						min = -800,
						max = 200,
						step = 10,
						disabled = function()
							return not sadb.battlegroundAlertsEnabled or
							       not sadb.flagToastsEnabled
						end,
						width = "normal",
						order = 6.95,
						set = function(info, value)
							if not sadb.flagToasts then
								sadb.flagToasts = {}
							end
							sadb.flagToasts.positionY = value
							-- Update layout immediately if FlagAlerts is loaded
							if SoundAlerter.FlagAlerts then
								SoundAlerter.FlagAlerts:UpdateFlagToastLayout()
							end
						end,
						get = function(info)
							return sadb.flagToasts and sadb.flagToasts.positionY or -300
						end,
					},
					toastNote = {
						type = 'description',
						name = "\n|cffAAAAAANote: Flag alert toasts have their own position separate from Proximity Alerts.|r\n",
						fontSize = "small",
						order = 7,
					},
				},
			},

			-- ===========================
			-- SECTION 4: FILTERING OPTIONS
			-- ===========================
			filteringOptions = {
				type = 'group',
				inline = true,
				name = "4. Filtering Options",
				order = 5,
				args = {
					flagOnlyEnemyTeam = {
						type = 'toggle',
						name = "Only Enemy Team Events",
						desc = "Only alert for enemy flag pickups/captures (recommended for less spam). Automatically disabled when 'Alert All Flag Actions' is enabled.",
						get = function() return sadb.flagOnlyEnemyTeam end,
						set = function(_, val)
							sadb.flagOnlyEnemyTeam = val
							-- Auto-untoggle friendly team filter (mutually exclusive)
							if val then
								sadb.flagOnlyFriendlyTeam = false
							end
						end,
						disabled = function() return not sadb.battlegroundAlertsEnabled or sadb.flagAllActions end,
						width = "full",
						order = 1,
					},
					flagOnlyFriendlyTeam = {
						type = 'toggle',
						name = "Only Friendly Team Events",
						desc = "Only alert for friendly flag pickups/captures. Automatically disabled when 'Alert All Flag Actions' is enabled.",
						get = function() return sadb.flagOnlyFriendlyTeam end,
						set = function(_, val)
							sadb.flagOnlyFriendlyTeam = val
							-- Auto-untoggle enemy team filter (mutually exclusive)
							if val then
								sadb.flagOnlyEnemyTeam = false
							end
						end,
						disabled = function() return not sadb.battlegroundAlertsEnabled or sadb.flagAllActions end,
						width = "full",
						order = 2,
					},
					flagAllActions = {
						type = 'toggle',
						name = "Alert All Flag Actions",
						desc = "Alert for ALL flag events (pickup, drop, capture, return) for BOTH enemy and friendly teams. Enabling this will automatically disable team-specific filters above. May be spammy in active battlegrounds.",
						get = function() return sadb.flagAllActions end,
						set = function(_, val)
							sadb.flagAllActions = val
							-- Auto-untoggle team filters when enabling (contradictory logic)
							if val then
								sadb.flagOnlyEnemyTeam = false
								sadb.flagOnlyFriendlyTeam = false
							end
						end,
						disabled = function() return not sadb.battlegroundAlertsEnabled end,
						width = "full",
						order = 3,
					},
				},
			},

			-- ===========================
			-- SECTION 5: CHAT INTEGRATION
			-- ===========================
			chatIntegration = {
				type = 'group',
				inline = true,
				name = "5. Chat Integration",
				order = 6,
				args = {
					flagChatEnabled = {
						type = 'toggle',
						name = "Send Chat Messages",
						desc = "Announce flag events in chat channels",
						get = function() return sadb.flagChatEnabled end,
						set = function(_, val) sadb.flagChatEnabled = val end,
						disabled = function() return not sadb.battlegroundAlertsEnabled end,
						width = "full",
						order = 1,
					},
					flagChatText = {
						type = 'input',
						name = "Chat Message Template",
						desc = "Customize the chat message. Available placeholders:\n" ..
						       "#class# - Enemy class name\n" ..
						       "#player# - Player name\n" ..
						       "#action# - Action (picked up flag, captured flag, etc.)\n\n" ..
						       "Example: [#class#] #player# #action#!",
						get = function() return sadb.flagChatText end,
						set = function(_, val) sadb.flagChatText = val end,
						disabled = function() return not sadb.battlegroundAlertsEnabled or not sadb.flagChatEnabled end,
						width = 'full',
						order = 2,
					},
					flagChatChannel = {
						type = 'select',
						name = "Chat Channel",
						desc = "Which channel to send flag alerts to",
						values = {
							["SAY"] = "Say",
							["PARTY"] = "Party",
							["RAID"] = "Raid",
							["BATTLEGROUND"] = "Battleground",
						},
						get = function() return sadb.flagChatChannel end,
						set = function(_, val) sadb.flagChatChannel = val end,
						disabled = function() return not sadb.battlegroundAlertsEnabled or not sadb.flagChatEnabled end,
						order = 3,
					},
				},
			},

			-- ===========================
			-- SECTION 6: PERFORMANCE & DEBUGGING
			-- ===========================
			performanceSection = {
				type = 'group',
				inline = true,
				name = "6. Performance & Debugging",
				order = 7,
				args = {
					metricsButton = {
						type = 'execute',
						name = "Show Performance Metrics",
						desc = "Display processing time, cache hit rate, and other performance data",
						func = function()
							if SoundAlerter.FlagAlerts then
								SoundAlerter.FlagAlerts:PrintMetrics()
							else
								SoundAlerter:Print("|cffFF0000Error: FlagAlerts module not loaded|r")
							end
						end,
						order = 1,
					},
					resetMetricsButton = {
						type = 'execute',
						name = "Reset Metrics",
						desc = "Clear performance tracking data",
						func = function()
							if SoundAlerter.FlagAlerts then
								SoundAlerter.FlagAlerts:ResetMetrics()
							else
								SoundAlerter:Print("|cffFF0000Error: FlagAlerts module not loaded|r")
							end
						end,
						order = 2,
					},
				},
			},

			-- ===========================
			-- SECTION 7: FUTURE FEATURES
			-- ===========================
			futureObjectives = {
				type = 'group',
				inline = true,
				name = "7. Future Features",
				order = 8,
				args = {
					futureDescription = {
						type = 'description',
						name = "|cffAAAAAAThe following objective types are planned for future versions:|r\n\n" ..
						       "• Base Assaults/Captures (Arathi Basin, Eye of the Storm)\n" ..
						       "• Graveyard Assaults (Alterac Valley)\n" ..
						       "• Tower Destruction (Alterac Valley)\n" ..
						       "• Node Captures (Isle of Conquest)\n\n" ..
						       "These will be added in future updates with the same configuration pattern.\n",
						fontSize = "medium",
						order = 1,
					},
				},
			},
		},
	})


	-- ===========================
	-- RESOURCE MANAGEMENT TAB
	-- ===========================
	self:AddOption('ResourceBar', {
		type = 'group',
		name = "Resource Management",
		desc = "Unified resource tracking for Energy, Rage, Health, and Mana bars with Combo Points. Enable the bars you need and drag them into position.",
		order = 2.8,
		args = {
			description = {
				type = 'description',
				name = "|cffFFD700Resource Management|r provides flexible resource tracking for your character.\n\n" ..
				       "Choose which resource bars to display based on your needs. All bars are independently draggable and configurable.\n\n" ..
				       "|cffFFFFFFAvailable Bars:|r\n" ..
				       "• Energy Bar - For Rogues and Druids in Cat Form\n" ..
				       "• Rage Bar - For Warriors and Druids in Bear Form\n" ..
				       "• Health Bar - Universal health tracking\n" ..
				       "• Mana Bar - For casters and healers\n" ..
				       "• Combo Points - For Rogues and Druids (with optional text display)\n\n" ..
				       "|cffFF0000Note:|r Unlock bars to drag them into position. Positions persist through /reload and client restarts.\n",
				fontSize = "medium",
				order = 1,
			},

			generalGroup = {
				type = 'group',
				inline = true,
				name = "General Settings",
				order = 2,
				args = {
					lockToggle = {
						type = 'toggle',
						name = "Lock Bars",
						desc = "Lock all resource bars in place. Unlock to drag and reposition.",
						get = function() return SoundAlerter.db1.profile.resourceBar.locked end,
						set = function(info, value)
							SoundAlerter.db1.profile.resourceBar.locked = value
							if SoundAlerter.ResourceBar then
								SoundAlerter.ResourceBar:SetLocked(value)
							end
						end,
						width = "full",
						order = 1,
					},
				barTexture = {
					type = 'select',
					name = "Bar Texture",
					desc = "Choose the visual texture for all resource bars (Health, Mana, Energy, Rage). This provides a unified look across all bars.",
					values = {
						default = "Default (WoW StatusBar)",
						solid = "Solid (Clean Fill)",
						transparent = "Transparent (Semi-Opaque)",
					},
					get = function() return SoundAlerter.db1.profile.resourceBar.barTexture end,
					set = function(info, value)
						SoundAlerter.db1.profile.resourceBar.barTexture = value
						if SoundAlerter.ResourceBar then
							SoundAlerter.ResourceBar:ApplyBarTexture()
						end
					end,
					width = "full",
					order = 2,
				},
				},
			},

			energyGroup = {
				type = 'group',
				inline = true,
				name = "Energy Bar",
				order = 3,
				args = {
					energyEnabled = {
						type = 'toggle',
						name = "Show Energy Bar",
						desc = "Display energy bar (for Rogues, Druids in Cat Form).",
						get = function() return SoundAlerter.db1.profile.resourceBar.energyEnabled end,
						set = function(info, value)
							SoundAlerter.db1.profile.resourceBar.energyEnabled = value
							if SoundAlerter.ResourceBar then
								SoundAlerter.ResourceBar:UpdateVisibility()
							end
						end,
						width = "full",
						order = 1,
					},
					energyScale = {
						type = 'range',
						name = "Energy Bar Scale",
						desc = "Adjust the size of the energy bar.",
						min = 0.5,
						max = 2.0,
						step = 0.05,
						get = function() return SoundAlerter.db1.profile.resourceBar.energyScale end,
						set = function(info, value)
							SoundAlerter.db1.profile.resourceBar.energyScale = value
							if SoundAlerter.ResourceBar and SoundAlerter.ResourceBar.energyFrame then
								SoundAlerter.ResourceBar.energyFrame:SetScale(value)
							end
						end,
						disabled = function() return not SoundAlerter.db1.profile.resourceBar.energyEnabled end,
						width = "full",
						order = 2,
					},
					energyColor = {
						type = 'color',
						name = "Energy Color",
						desc = "Color of the energy bar.",
						get = function()
							local c = SoundAlerter.db1.profile.resourceBar.energyColor
							return c.r, c.g, c.b
						end,
						set = function(info, r, g, b)
							SoundAlerter.db1.profile.resourceBar.energyColor = {r = r, g = g, b = b}
							if SoundAlerter.ResourceBar then
								SoundAlerter.ResourceBar:UpdateEnergyBar()
							end
						end,
						disabled = function() return not SoundAlerter.db1.profile.resourceBar.energyEnabled end,
						order = 3,
					},
				},
			},

			rageGroup = {
				type = 'group',
				inline = true,
				name = "Rage Bar",
				order = 4,
				args = {
					rageEnabled = {
						type = 'toggle',
						name = "Show Rage Bar",
						desc = "Display rage bar (for Warriors, Druids in Bear Form).",
						get = function() return SoundAlerter.db1.profile.resourceBar.rageEnabled end,
						set = function(info, value)
							SoundAlerter.db1.profile.resourceBar.rageEnabled = value
							if SoundAlerter.ResourceBar then
								SoundAlerter.ResourceBar:UpdateVisibility()
							end
						end,
						width = "full",
						order = 1,
					},
					rageScale = {
						type = 'range',
						name = "Rage Bar Scale",
						desc = "Adjust the size of the rage bar.",
						min = 0.5,
						max = 2.0,
						step = 0.05,
						get = function() return SoundAlerter.db1.profile.resourceBar.rageScale end,
						set = function(info, value)
							SoundAlerter.db1.profile.resourceBar.rageScale = value
							if SoundAlerter.ResourceBar and SoundAlerter.ResourceBar.rageFrame then
								SoundAlerter.ResourceBar.rageFrame:SetScale(value)
							end
						end,
						disabled = function() return not SoundAlerter.db1.profile.resourceBar.rageEnabled end,
						width = "full",
						order = 2,
					},
					rageColor = {
						type = 'color',
						name = "Rage Color",
						desc = "Color of the rage bar.",
						get = function()
							local c = SoundAlerter.db1.profile.resourceBar.rageColor
							return c.r, c.g, c.b
						end,
						set = function(info, r, g, b)
							SoundAlerter.db1.profile.resourceBar.rageColor = {r = r, g = g, b = b}
							if SoundAlerter.ResourceBar then
								SoundAlerter.ResourceBar:UpdateRageBar()
							end
						end,
						disabled = function() return not SoundAlerter.db1.profile.resourceBar.rageEnabled end,
						order = 3,
					},
				},
			},

			healthGroup = {
				type = 'group',
				inline = true,
				name = "Health Bar",
				order = 5,
				args = {
					healthEnabled = {
						type = 'toggle',
						name = "Show Health Bar",
						desc = "Display health bar.",
						get = function() return SoundAlerter.db1.profile.resourceBar.healthEnabled end,
						set = function(info, value)
							SoundAlerter.db1.profile.resourceBar.healthEnabled = value
							if SoundAlerter.ResourceBar then
								SoundAlerter.ResourceBar:UpdateVisibility()
							end
						end,
						width = "full",
						order = 1,
					},
					healthScale = {
						type = 'range',
						name = "Health Bar Scale",
						desc = "Adjust the size of the health bar.",
						min = 0.5,
						max = 2.0,
						step = 0.05,
						get = function() return SoundAlerter.db1.profile.resourceBar.healthScale end,
						set = function(info, value)
							SoundAlerter.db1.profile.resourceBar.healthScale = value
							if SoundAlerter.ResourceBar and SoundAlerter.ResourceBar.healthFrame then
								SoundAlerter.ResourceBar.healthFrame:SetScale(value)
							end
						end,
						disabled = function() return not SoundAlerter.db1.profile.resourceBar.healthEnabled end,
						width = "full",
						order = 2,
					},
					healthHeight = {
						type = 'range',
						name = "Health Bar Height",
						desc = "Adjust the height of the health bar.",
						min = 10,
						max = 40,
						step = 1,
						get = function() return SoundAlerter.db1.profile.resourceBar.healthHeight end,
						set = function(info, value)
							SoundAlerter.db1.profile.resourceBar.healthHeight = value
							if SoundAlerter.ResourceBar then
								SoundAlerter.ResourceBar:LoadSettings()
							end
						end,
						disabled = function() return not SoundAlerter.db1.profile.resourceBar.healthEnabled end,
						width = "full",
						order = 3,
					},
					healthColor = {
						type = 'color',
						name = "Health Color",
						desc = "Color of the health bar.",
						get = function()
							local c = SoundAlerter.db1.profile.resourceBar.healthColor
							return c.r, c.g, c.b
						end,
						set = function(info, r, g, b)
							SoundAlerter.db1.profile.resourceBar.healthColor = {r = r, g = g, b = b}
							if SoundAlerter.ResourceBar then
								SoundAlerter.ResourceBar:UpdateHealthBar()
							end
						end,
						disabled = function() return not SoundAlerter.db1.profile.resourceBar.healthEnabled end,
						order = 4,
					},
				},
			},

			manaGroup = {
				type = 'group',
				inline = true,
				name = "Mana Bar",
				order = 6,
				args = {
					manaEnabled = {
						type = 'toggle',
						name = "Show Mana Bar",
						desc = "Display mana bar (for casters).",
						get = function() return SoundAlerter.db1.profile.resourceBar.manaEnabled end,
						set = function(info, value)
							SoundAlerter.db1.profile.resourceBar.manaEnabled = value
							if SoundAlerter.ResourceBar then
								SoundAlerter.ResourceBar:UpdateVisibility()
							end
						end,
						width = "full",
						order = 1,
					},
					manaScale = {
						type = 'range',
						name = "Mana Bar Scale",
						desc = "Adjust the size of the mana bar.",
						min = 0.5,
						max = 2.0,
						step = 0.05,
						get = function() return SoundAlerter.db1.profile.resourceBar.manaScale end,
						set = function(info, value)
							SoundAlerter.db1.profile.resourceBar.manaScale = value
							if SoundAlerter.ResourceBar and SoundAlerter.ResourceBar.manaFrame then
								SoundAlerter.ResourceBar.manaFrame:SetScale(value)
							end
						end,
						disabled = function() return not SoundAlerter.db1.profile.resourceBar.manaEnabled end,
						width = "full",
						order = 2,
					},
					manaColor = {
						type = 'color',
						name = "Mana Color",
						desc = "Color of the mana bar.",
						get = function()
							local c = SoundAlerter.db1.profile.resourceBar.manaColor
							return c.r, c.g, c.b
						end,
						set = function(info, r, g, b)
							SoundAlerter.db1.profile.resourceBar.manaColor = {r = r, g = g, b = b}
							if SoundAlerter.ResourceBar then
								SoundAlerter.ResourceBar:UpdateManaBar()
							end
						end,
						disabled = function() return not SoundAlerter.db1.profile.resourceBar.manaEnabled end,
						order = 3,
					},
				},
			},

			comboGroup = {
				type = 'group',
				inline = true,
				name = "Combo Points",
				order = 7,
				args = {
					comboEnabled = {
						type = 'toggle',
						name = "Show Combo Points",
						desc = "Display combo points (for Rogues, Druids in Cat Form).",
						get = function() return SoundAlerter.db1.profile.resourceBar.comboEnabled end,
						set = function(info, value)
							SoundAlerter.db1.profile.resourceBar.comboEnabled = value
							if SoundAlerter.ResourceBar then
								SoundAlerter.ResourceBar:UpdateVisibility()
							end
						end,
						width = "full",
						order = 1,
					},
					comboScale = {
						type = 'range',
						name = "Combo Points Scale",
						desc = "Adjust the size of the combo points.",
						min = 0.5,
						max = 2.0,
						step = 0.05,
						get = function() return SoundAlerter.db1.profile.resourceBar.comboScale end,
						set = function(info, value)
							SoundAlerter.db1.profile.resourceBar.comboScale = value
							if SoundAlerter.ResourceBar and SoundAlerter.ResourceBar.comboFrame then
								SoundAlerter.ResourceBar.comboFrame:SetScale(value)
							end
						end,
						disabled = function() return not SoundAlerter.db1.profile.resourceBar.comboEnabled end,
						width = "full",
						order = 2,
					},
				comboStyle = {
					type = 'select',
					name = "Combo Point Shape",
					desc = "Choose the visual shape for combo points.",
					values = {
						circle = "Circle",
						square = "Square",
					},
					get = function() return SoundAlerter.db1.profile.resourceBar.comboStyle end,
					set = function(info, value)
						SoundAlerter.db1.profile.resourceBar.comboStyle = value
						if SoundAlerter.ResourceBar then
							SoundAlerter.ResourceBar:ApplyCPStyle()
						end
					end,
					disabled = function() return not SoundAlerter.db1.profile.resourceBar.comboEnabled end,
					width = "full",
					order = 2.5,
				},
					comboTextEnabled = {
						type = 'toggle',
						name = "Show Combo Text",
						desc = "Display combo points as text (e.g., '3/5').",
						get = function() return SoundAlerter.db1.profile.resourceBar.comboTextEnabled end,
						set = function(info, value)
							SoundAlerter.db1.profile.resourceBar.comboTextEnabled = value
							if SoundAlerter.ResourceBar then
								SoundAlerter.ResourceBar:UpdateVisibility()
							end
						end,
						disabled = function() return not SoundAlerter.db1.profile.resourceBar.comboEnabled end,
						width = "full",
						order = 3,
					},
					comboActiveColor = {
						type = 'color',
						name = "Active Combo Color",
						desc = "Color of active combo points (1-4).",
						get = function()
							local c = SoundAlerter.db1.profile.resourceBar.comboActiveColor
							return c.r, c.g, c.b
						end,
						set = function(info, r, g, b)
							SoundAlerter.db1.profile.resourceBar.comboActiveColor = {r = r, g = g, b = b}
							if SoundAlerter.ResourceBar then
								SoundAlerter.ResourceBar:UpdateComboPoints()
							end
						end,
						disabled = function() return not SoundAlerter.db1.profile.resourceBar.comboEnabled end,
						order = 4,
					},
					comboMaxColor = {
						type = 'color',
						name = "Max Combo Color",
						desc = "Color of combo points at maximum (5).",
						get = function()
							local c = SoundAlerter.db1.profile.resourceBar.comboMaxColor
							return c.r, c.g, c.b
						end,
						set = function(info, r, g, b)
							SoundAlerter.db1.profile.resourceBar.comboMaxColor = {r = r, g = g, b = b}
							if SoundAlerter.ResourceBar then
								SoundAlerter.ResourceBar:UpdateComboPoints()
							end
						end,
						disabled = function() return not SoundAlerter.db1.profile.resourceBar.comboEnabled end,
						order = 5,
					},
				fullCPSound = {
					type = 'toggle',
					name = "5 CP Sound",
					desc = "Play a satisfying chime when reaching 5 combo points.",
					get = function() return SoundAlerter.db1.profile.resourceBar.fullCPSound end,
					set = function(info, value)
						SoundAlerter.db1.profile.resourceBar.fullCPSound = value
					end,
					disabled = function() return not SoundAlerter.db1.profile.resourceBar.comboEnabled end,
					width = "full",
					order = 6,
				},
				},
			},
		},
	})

	-- ===========================
	-- CASTING BARS TAB
	-- ===========================
	self:AddOption('CastingBars', {
		type = 'group',
		name = "Casting Bars",
		desc = "Display casting and channeling progress for player, target, and focus with precise timing information.",
		order = 2.85,
		args = {
			description = {
				type = 'description',
				name = "|cffFFD700Casting Bars|r provide real-time visual feedback for spell casting and channeling.\n\n" ..
				       "|cffFFFFFFFeatures:|r\n" ..
				       "• Configurable time format (milliseconds or centiseconds)\n" ..
				       "• Optional spell icons next to casting bars\n" ..
				       "• Latency shadow for predicting server-side cast completion\n" ..
				       "• Subtle pulse animation at cast start\n" ..
				       "• Blue bars for regular casts, purple for channeling\n" ..
				       "• Multiple texture options (Default, Solid, Transparent, Banto, Halcyone)\n" ..
				       "• Independent positioning and sizing\n\n" ..
				       "|cffFF0000Note:|r Unlock bars to drag them into position. When locked, bars only appear during active casts. All bars are disabled by default.\n",
				fontSize = "medium",
				order = 1,
			},

			generalGroup = {
				type = 'group',
				inline = true,
				name = "General Settings",
				order = 2,
				args = {
					lockToggle = {
						type = 'toggle',
						name = "Lock Bars",
						desc = "Lock all casting bars in place. Unlock to drag and reposition.",
						get = function() return SoundAlerter.db1.profile.castingBars.locked end,
						set = function(info, value)
							SoundAlerter.db1.profile.castingBars.locked = value
							-- Call SetLocked to update visibility
							if SoundAlerter.CastingBars then
								SoundAlerter.CastingBars:SetLocked(value)
							end
						end,
						width = "full",
						order = 1,
					},
					barTexture = {
						type = 'select',
						name = "Bar Texture",
						desc = "Choose the visual texture for all casting bars. Matches resource bar texture options for consistency.",
						values = {
							default = "Default (WoW StatusBar)",
							solid = "Solid (Clean Fill)",
							transparent = "Transparent (Semi-Opaque)",
							banto = "Banto",
							halcyone = "Halcyone",
						},
						get = function() return SoundAlerter.db1.profile.castingBars.barTexture end,
						set = function(info, value)
							SoundAlerter.db1.profile.castingBars.barTexture = value
							if SoundAlerter.CastingBars then
								SoundAlerter.CastingBars:UpdateTexture()
							end
						end,
						width = "full",
						order = 2,
					},
					timeFormat = {
						type = 'select',
						name = "Time Format",
						desc = "Choose how cast time is displayed.\n\nSS.sss = Seconds with milliseconds (e.g., 02.450)\nSS.ss = Seconds with centiseconds (e.g., 02.45)",
						values = {
							milliseconds = "SS.sss (Milliseconds)",
							centiseconds = "SS.ss (Centiseconds)",
						},
						get = function() return SoundAlerter.db1.profile.castingBars.timeFormat end,
						set = function(info, value)
							SoundAlerter.db1.profile.castingBars.timeFormat = value
						end,
						width = "full",
						order = 3,
					},
					showSpellIcon = {
						type = 'toggle',
						name = "Show Spell Icons",
						desc = "Display spell icons to the left of casting bars.",
						get = function() return SoundAlerter.db1.profile.castingBars.showSpellIcon end,
						set = function(info, value)
							SoundAlerter.db1.profile.castingBars.showSpellIcon = value
						end,
						width = "full",
						order = 4,
					},
					showLatency = {
						type = 'toggle',
						name = "Show Latency Shadow",
						desc = "Display a red shadow at the end of the player casting bar representing network latency. Helps predict when the spell will actually cast on the server.",
						get = function() return SoundAlerter.db1.profile.castingBars.showLatency end,
						set = function(info, value)
							SoundAlerter.db1.profile.castingBars.showLatency = value
						end,
						width = "full",
						order = 5,
					},
				},
			},

			playerGroup = {
				type = 'group',
				inline = true,
				name = "Player Casting Bar",
				order = 3,
				args = {
					playerEnabled = {
						type = 'toggle',
						name = "Show Player Casting Bar",
						desc = "Display casting bar for your own spells. Shows casting time in mm:ss.SSS format.",
						get = function() return SoundAlerter.db1.profile.castingBars.player.enabled end,
						set = function(info, value)
							SoundAlerter.db1.profile.castingBars.player.enabled = value
							if SoundAlerter.CastingBars then
								SoundAlerter.CastingBars:LoadSettings()
							end
						end,
						width = "full",
						order = 1,
					},
					playerWidth = {
						type = 'range',
						name = "Width",
						desc = "Width of the player casting bar.",
						min = 100,
						max = 500,
						step = 10,
						get = function() return SoundAlerter.db1.profile.castingBars.player.width end,
						set = function(info, value)
							SoundAlerter.db1.profile.castingBars.player.width = value
							if SoundAlerter.CastingBars then
								SoundAlerter.CastingBars:LoadSettings()
							end
						end,
						disabled = function() return not SoundAlerter.db1.profile.castingBars.player.enabled end,
						width = "full",
						order = 2,
					},
					playerHeight = {
						type = 'range',
						name = "Height",
						desc = "Height of the player casting bar.",
						min = 12,
						max = 50,
						step = 2,
						get = function() return SoundAlerter.db1.profile.castingBars.player.height end,
						set = function(info, value)
							SoundAlerter.db1.profile.castingBars.player.height = value
							if SoundAlerter.CastingBars then
								SoundAlerter.CastingBars:LoadSettings()
							end
						end,
						disabled = function() return not SoundAlerter.db1.profile.castingBars.player.enabled end,
						width = "full",
						order = 3,
					},
				},
			},

			targetGroup = {
				type = 'group',
				inline = true,
				name = "Target Casting Bar",
				order = 4,
				args = {
					targetEnabled = {
						type = 'toggle',
						name = "Show Target Casting Bar",
						desc = "Display casting bar for your target's spells. Essential for PvP interrupt timing.",
						get = function() return SoundAlerter.db1.profile.castingBars.target.enabled end,
						set = function(info, value)
							SoundAlerter.db1.profile.castingBars.target.enabled = value
							if SoundAlerter.CastingBars then
								SoundAlerter.CastingBars:LoadSettings()
							end
						end,
						width = "full",
						order = 1,
					},
					targetWidth = {
						type = 'range',
						name = "Width",
						desc = "Width of the target casting bar.",
						min = 100,
						max = 500,
						step = 10,
						get = function() return SoundAlerter.db1.profile.castingBars.target.width end,
						set = function(info, value)
							SoundAlerter.db1.profile.castingBars.target.width = value
							if SoundAlerter.CastingBars then
								SoundAlerter.CastingBars:LoadSettings()
							end
						end,
						disabled = function() return not SoundAlerter.db1.profile.castingBars.target.enabled end,
						width = "full",
						order = 2,
					},
					targetHeight = {
						type = 'range',
						name = "Height",
						desc = "Height of the target casting bar.",
						min = 12,
						max = 50,
						step = 2,
						get = function() return SoundAlerter.db1.profile.castingBars.target.height end,
						set = function(info, value)
							SoundAlerter.db1.profile.castingBars.target.height = value
							if SoundAlerter.CastingBars then
								SoundAlerter.CastingBars:LoadSettings()
							end
						end,
						disabled = function() return not SoundAlerter.db1.profile.castingBars.target.enabled end,
						width = "full",
						order = 3,
					},
				},
			},

			focusGroup = {
				type = 'group',
				inline = true,
				name = "Focus Casting Bar",
				order = 5,
				args = {
					focusEnabled = {
						type = 'toggle',
						name = "Show Focus Casting Bar",
						desc = "Display casting bar for your focus target's spells. Perfect for arena focus target tracking.",
						get = function() return SoundAlerter.db1.profile.castingBars.focus.enabled end,
						set = function(info, value)
							SoundAlerter.db1.profile.castingBars.focus.enabled = value
							if SoundAlerter.CastingBars then
								SoundAlerter.CastingBars:LoadSettings()
							end
						end,
						width = "full",
						order = 1,
					},
					focusWidth = {
						type = 'range',
						name = "Width",
						desc = "Width of the focus casting bar.",
						min = 100,
						max = 500,
						step = 10,
						get = function() return SoundAlerter.db1.profile.castingBars.focus.width end,
						set = function(info, value)
							SoundAlerter.db1.profile.castingBars.focus.width = value
							if SoundAlerter.CastingBars then
								SoundAlerter.CastingBars:LoadSettings()
							end
						end,
						disabled = function() return not SoundAlerter.db1.profile.castingBars.focus.enabled end,
						width = "full",
						order = 2,
					},
					focusHeight = {
						type = 'range',
						name = "Height",
						desc = "Height of the focus casting bar.",
						min = 12,
						max = 50,
						step = 2,
						get = function() return SoundAlerter.db1.profile.castingBars.focus.height end,
						set = function(info, value)
							SoundAlerter.db1.profile.castingBars.focus.height = value
							if SoundAlerter.CastingBars then
								SoundAlerter.CastingBars:LoadSettings()
							end
						end,
						disabled = function() return not SoundAlerter.db1.profile.castingBars.focus.enabled end,
						width = "full",
						order = 3,
					},
				},
			},
		},
	})

	-- ===========================
	-- SPELL TRACKER TAB
	-- ===========================

	-- Forward declaration for RebuildSpellTrackerOptions (defined below, called by BuildAddSpellPanel and BuildConfigPanel)
	local RebuildSpellTrackerOptions

	-- Build add spell panel (shown when no spell selected)
	local function BuildAddSpellPanel()
		return {
			addDescription = {
				type = 'description',
				name = "Add a new spell to track. Enter the spell ID and configure settings below.",
				fontSize = "medium",
				order = 1,
			},
			addSpellID = {
				type = 'input',
				name = "Spell ID",
				desc = "Enter numeric spell ID",
				get = function() return spellTrackerAddForm.spellID end,
				set = function(info, value) spellTrackerAddForm.spellID = value end,
				width = "full",
				order = 2,
			},
			addUnit = {
				type = 'select',
				name = "Track On",
				desc = "Which unit to track this aura on",
				values = { player = "Player (Self)", target = "Target" },
				get = function() return spellTrackerAddForm.unit end,
				set = function(info, value) spellTrackerAddForm.unit = value end,
				width = "full",
				order = 3,
			},
			addAuraType = {
				type = 'select',
				name = "Aura Type",
				desc = "Type of aura to track",
				values = { HELPFUL = "Buff (Helpful)", HARMFUL = "Debuff (Harmful)" },
				get = function() return spellTrackerAddForm.auraType end,
				set = function(info, value) spellTrackerAddForm.auraType = value end,
				width = "full",
				order = 4,
			},
			addButton = {
				type = 'execute',
				name = "Add Spell",
				desc = "Add this spell to the tracker",
				func = function()
					local spellID = tonumber(spellTrackerAddForm.spellID)
					if not spellID or spellID <= 0 then
						SoundAlerter:Print("|cffff0000Invalid spell ID.|r")
						return
					end

					if SoundAlerter.SpellTracker then
						local success = SoundAlerter.SpellTracker:AddTrackedSpell(
							spellID, spellTrackerAddForm.unit, spellTrackerAddForm.auraType)
						if success then
							SoundAlerter:Print("|cff00ff00Added spell " .. spellID .. " to tracker.|r")
							spellTrackerAddForm.spellID = ""
							RebuildSpellTrackerOptions()
							LibStub("AceConfigRegistry-3.0"):NotifyChange("SoundAlerter")
						end
					end
				end,
				width = "full",
				order = 5,
			},
		}
	end

	-- Build config panel for selected spell
	local function BuildConfigPanel()
		if not spellTrackerSelectedIndex then
			-- No selection - show add spell form
			return {
				type = 'group',
				inline = true,
				name = "Add New Spell",
				order = 6,
				args = BuildAddSpellPanel(),
			}
		end

		-- Spell selected - show config options
		local i = spellTrackerSelectedIndex
		local config = SoundAlerter.db1.profile.spellTracker.icons[i]
		if not config then
			return {
				type = 'group',
				inline = true,
				name = "Error",
				order = 6,
				args = {
					errorMsg = {
						type = 'description',
						name = "|cffff0000Selected spell not found.|r",
						order = 1,
					}
				}
			}
		end

		local spellName = GetSpellInfo(config.spellID) or "Unknown"
		local _, _, icon = GetSpellInfo(config.spellID)

		return {
			type = 'group',
			inline = true,
			name = "Configure: " .. spellName,
			order = 6,
			args = {
				spellHeader = {
					type = 'description',
					name = string.format("|T%s:24|t |cffFFD700%s|r\nSpell ID: %d",
						icon or "Interface\\Icons\\INV_Misc_QuestionMark",
						spellName,
						config.spellID),
					fontSize = "large",
					order = 1,
				},
				enabled = {
					type = 'toggle',
					name = "Enabled",
					desc = "Enable tracking for this spell",
					get = function()
						local iconConfig = SoundAlerter.db1.profile.spellTracker.icons[i]
						return iconConfig and iconConfig.enabled
					end,
					set = function(info, value)
						local iconConfig = SoundAlerter.db1.profile.spellTracker.icons[i]
						if iconConfig then
							iconConfig.enabled = value
							if SoundAlerter.SpellTracker then
								SoundAlerter.SpellTracker:LoadSettings()
							end
						end
					end,
					width = "full",
					order = 2,
				},
				unit = {
					type = 'select',
					name = "Track On",
					desc = "Which unit to track this aura on",
					values = { player = "Player (Self)", target = "Target" },
					get = function()
						local iconConfig = SoundAlerter.db1.profile.spellTracker.icons[i]
						return iconConfig and iconConfig.unit or "player"
					end,
					set = function(info, value)
						local iconConfig = SoundAlerter.db1.profile.spellTracker.icons[i]
						if iconConfig then
							iconConfig.unit = value
							if SoundAlerter.SpellTracker then
								SoundAlerter.SpellTracker:LoadSettings()
							end
						end
					end,
					width = "full",
					order = 3,
				},
				auraType = {
					type = 'select',
					name = "Aura Type",
					desc = "Type of aura to track",
					values = { HELPFUL = "Buff (Helpful)", HARMFUL = "Debuff (Harmful)" },
					get = function()
						local iconConfig = SoundAlerter.db1.profile.spellTracker.icons[i]
						return iconConfig and iconConfig.auraType or "HELPFUL"
					end,
					set = function(info, value)
						local iconConfig = SoundAlerter.db1.profile.spellTracker.icons[i]
						if iconConfig then
							iconConfig.auraType = value
							if SoundAlerter.SpellTracker then
								SoundAlerter.SpellTracker:LoadSettings()
							end
						end
					end,
					width = "full",
					order = 4,
				},
				size = {
					type = 'range',
					name = "Icon Size",
					desc = "Size of the spell tracker icon in pixels",
					min = 24,
					max = 80,
					step = 4,
					get = function()
						local iconConfig = SoundAlerter.db1.profile.spellTracker.icons[i]
						return iconConfig and iconConfig.size or 48
					end,
					set = function(info, value)
						local iconConfig = SoundAlerter.db1.profile.spellTracker.icons[i]
						if iconConfig then
							iconConfig.size = value
							if SoundAlerter.SpellTracker then
								SoundAlerter.SpellTracker:LoadSettings()
							end
						end
					end,
					width = "full",
					order = 5,
				},
				showWhenInactive = {
					type = 'toggle',
					name = "Show When Inactive",
					desc = "Display icon (faded) even when aura is not active",
					get = function()
						local iconConfig = SoundAlerter.db1.profile.spellTracker.icons[i]
						return iconConfig and iconConfig.showWhenInactive
					end,
					set = function(info, value)
						local iconConfig = SoundAlerter.db1.profile.spellTracker.icons[i]
						if iconConfig then
							iconConfig.showWhenInactive = value
							if SoundAlerter.SpellTracker then
								SoundAlerter.SpellTracker:LoadSettings()
							end
						end
					end,
					width = "full",
					order = 5.5,
				},
				trackCooldown = {
					type = 'toggle',
					name = "Track Cooldown",
					desc = "Display spell cooldown timer (integer seconds) at icon center.\n\n" ..
						   "|cffFF0000Limitation:|r Only tracks YOUR cooldowns (spells on your action bars). " ..
						   "Does NOT track enemy cooldowns.\n\n" ..
						   "Shows when the spell is ready to cast again (independent from aura duration).",
					get = function()
						local iconConfig = SoundAlerter.db1.profile.spellTracker.icons[i]
						return iconConfig and iconConfig.trackCooldown or false
					end,
					set = function(info, value)
						local iconConfig = SoundAlerter.db1.profile.spellTracker.icons[i]
						if iconConfig then
							iconConfig.trackCooldown = value
							if SoundAlerter.SpellTracker then
								SoundAlerter.SpellTracker:LoadSettings()
							end
						end
					end,
					width = "full",
					order = 6,
				},
				cooldownTextSize = {
					type = 'range',
					name = "Cooldown Text Size",
					desc = "Font size for the cooldown countdown text (in points). Only visible when 'Track Cooldown' is enabled.",
					min = 8,
					max = 32,
					step = 1,
					get = function()
						local iconConfig = SoundAlerter.db1.profile.spellTracker.icons[i]
						return iconConfig and iconConfig.cooldownTextSize or 14
					end,
					set = function(info, value)
						local iconConfig = SoundAlerter.db1.profile.spellTracker.icons[i]
						if iconConfig then
							iconConfig.cooldownTextSize = value
							if SoundAlerter.SpellTracker then
								SoundAlerter.SpellTracker:LoadSettings()
							end
						end
					end,
					width = "full",
					order = 6.5,
				},
				deleteButton = {
					type = 'execute',
					name = "Delete Spell",
					desc = "Remove this spell from the tracker",
					func = function()
						local iconConfig = SoundAlerter.db1.profile.spellTracker.icons[i]
						if SoundAlerter.SpellTracker and iconConfig then
							local spellName = GetSpellInfo(iconConfig.spellID) or "Unknown"
							SoundAlerter.SpellTracker:RemoveTrackedSpell(i)
							SoundAlerter:Print("|cffff0000Removed " .. spellName .. " from tracker.|r")
							spellTrackerSelectedIndex = nil  -- Clear selection
							RebuildSpellTrackerOptions()
							LibStub("AceConfigRegistry-3.0"):NotifyChange("SoundAlerter")
						end
					end,
					confirm = true,
					confirmText = "Are you sure you want to delete this tracked spell?",
					width = "full",
					order = 10,
				},
			}
		}
	end

	RebuildSpellTrackerOptions = function()
		local spellTrackerTab = SoundAlerter.options.args['SpellTracker']
		if not spellTrackerTab then return end

		-- Clear old dynamic entries (including spell list and config panel)
		for key in pairs(spellTrackerTab.args) do
			if key:match("^spell_%d+$") or key == "spellListGroup" or key == "configPanelGroup" then
				spellTrackerTab.args[key] = nil
			end
		end

		-- Create spell list (left side)
		spellTrackerTab.args.spellListGroup = {
			type = 'group',
			inline = true,
			name = "Tracked Spells",
			order = 5,
			args = {},
		}

		-- Add "Add New Spell" button at the top
		spellTrackerTab.args.spellListGroup.args.addNewButton = {
			type = 'execute',
			name = "Add New Spell",
			desc = "Click to show the add spell form",
			func = function()
				spellTrackerSelectedIndex = nil  -- Deselect current spell
				RebuildSpellTrackerOptions()
				LibStub("AceConfigRegistry-3.0"):NotifyChange("SoundAlerter")
			end,
			width = "full",
			order = 1,
		}

		-- Add compact spell entries
		if SoundAlerter.db1.profile.spellTracker.icons then
			for i, config in ipairs(SoundAlerter.db1.profile.spellTracker.icons) do
				local spellName = GetSpellInfo(config.spellID) or "Unknown"
				local statusText = config.enabled and "[ON]" or "[OFF]"
				local unitText = config.unit == "player" and "P" or "T"
				local typeText = config.auraType == "HELPFUL" and "Buff" or "Debuff"

				spellTrackerTab.args.spellListGroup.args["spell_" .. i] = {
					type = 'execute',
					name = string.format("%s %s (%d) - %s/%s",
						statusText, spellName, config.spellID, unitText, typeText),
					desc = "Click to configure this spell",
					func = function()
						spellTrackerSelectedIndex = i
						RebuildSpellTrackerOptions()
						LibStub("AceConfigRegistry-3.0"):NotifyChange("SoundAlerter")
					end,
					width = "full",
					order = 100 + i,
				}
			end
		end

		-- Create config panel (right side) - dynamically shows add form or config panel
		spellTrackerTab.args.configPanelGroup = BuildConfigPanel()
	end

	self:AddOption('SpellTracker', {
		type = 'group',
		name = "Spell Tracker",
		desc = "Track important buffs and debuffs with cooldown overlays and countdown timers.",
		order = 2.87,
		args = {
			description = {
				type = 'description',
				name = "|cffFFD700Spell Tracker|r allows you to monitor specific auras with visual icons and cooldown indicators.\n\n" ..
				       "|cffFFFFFFFeatures:|r\n" ..
				       "• Track up to 20 different spell buffs/debuffs\n" ..
				       "• Configure per-spell: player or target, buff or debuff\n" ..
				       "• Optional countdown timer in SS.ss format (30 updates/sec)\n" ..
				       "• Clockwise cooldown spiral overlay\n" ..
				       "• Icons fade when inactive, visible when active\n" ..
				       "• Drag icons to reposition (when unlocked)\n" ..
				       "• Resize icons individually\n\n" ..
				       "|cffFF0000Usage:|r Use the 'Add Tracked Spell' section below to track a new spell. Enter the spell ID and configure its settings.\n",
				fontSize = "medium",
				order = 1,
			},

			generalGroup = {
				type = 'group',
				inline = true,
				name = "General Settings",
				order = 2,
				args = {
					lockToggle = {
						type = 'toggle',
						name = "Lock Icons",
						desc = "Lock all spell tracker icons in place. Unlock to drag and reposition individual icons.",
						get = function() return SoundAlerter.db1.profile.spellTracker.locked end,
						set = function(info, value)
							SoundAlerter.db1.profile.spellTracker.locked = value
							if SoundAlerter.SpellTracker then
								SoundAlerter.SpellTracker:SetLocked(value)
							end
						end,
						width = "full",
						order = 1,
					},
					showTimerText = {
						type = 'toggle',
						name = "Show Aura Duration Numbers",
						desc = "Display aura duration countdown (SS.ss format) at bottom of spell tracker icons. This shows how long the buff/debuff lasts.",
						get = function() return SoundAlerter.db1.profile.spellTracker.showTimerText end,
						set = function(info, value)
							SoundAlerter.db1.profile.spellTracker.showTimerText = value
						end,
						width = "full",
						order = 2,
					},
					showCooldownText = {
						type = 'toggle',
						name = "Show Spell Cooldown Numbers",
						desc = "Display spell cooldown countdown (integer seconds) at center of spell tracker icons. " ..
						       "Only affects spells with 'Track Cooldown' enabled.\n\n" ..
						       "|cffFF7D0ANote:|r This tracks YOUR spell cooldowns (when the ability is ready to use again), " ..
						       "not enemy cooldowns or aura durations.",
						get = function() return SoundAlerter.db1.profile.spellTracker.showCooldownText end,
						set = function(info, value)
							SoundAlerter.db1.profile.spellTracker.showCooldownText = value
						end,
						width = "full",
						order = 3,
					},
				},
			},

			addSpellGroup = {
				type = 'group',
				inline = true,
				name = "Add Tracked Spell",
				order = 3,
				args = {
					addDescription = {
						type = 'description',
						name = "Add a new spell to track. You can track player buffs, player debuffs, target buffs, or target debuffs.\n\n" ..
						       "Find spell IDs by enabling 'Show IDs in tooltips' in WoW settings, or use the Spell Finder tab.",
						fontSize = "small",
						order = 1,
					},
					addSpellID = {
						type = 'input',
						name = "Spell ID",
						desc = "Enter the spell ID to track (numeric value).",
						get = function() return spellTrackerAddForm.spellID end,
						set = function(info, value) spellTrackerAddForm.spellID = value end,
						width = "normal",
						order = 2,
					},
					addUnit = {
						type = 'select',
						name = "Track On",
						desc = "Choose whether to track this spell on yourself (player) or on your current target.",
						values = {
							player = "Player (Self)",
							target = "Target",
						},
						get = function() return spellTrackerAddForm.unit end,
						set = function(info, value) spellTrackerAddForm.unit = value end,
						width = "normal",
						order = 3,
					},
					addAuraType = {
						type = 'select',
						name = "Aura Type",
						desc = "Choose whether to track buffs (helpful effects) or debuffs (harmful effects).",
						values = {
							HELPFUL = "Buff (Helpful)",
							HARMFUL = "Debuff (Harmful)",
						},
						get = function() return spellTrackerAddForm.auraType end,
						set = function(info, value) spellTrackerAddForm.auraType = value end,
						width = "normal",
						order = 4,
					},
					addButton = {
						type = 'execute',
						name = "Add Spell",
						desc = "Add this spell to the tracker list.",
						func = function()
							local spellID = tonumber(spellTrackerAddForm.spellID)

							if not spellID or spellID <= 0 then
								SoundAlerter:Print("|cffff0000Invalid spell ID. Please enter a numeric spell ID.|r")
								return
							end

							if SoundAlerter.SpellTracker then
								local success = SoundAlerter.SpellTracker:AddTrackedSpell(spellID, spellTrackerAddForm.unit, spellTrackerAddForm.auraType)
								if success then
									SoundAlerter:Print("|cff00ff00Added spell " .. spellID .. " to tracker.|r")
									spellTrackerAddForm.spellID = ""
									RebuildSpellTrackerOptions()
									LibStub("AceConfigRegistry-3.0"):NotifyChange("SoundAlerter")
								end
							end
						end,
						width = "normal",
						order = 5,
					},
				},
			},

			trackedSpellsHeader = {
				type = 'header',
				name = "Tracked Spells",
				order = 4,
			},
		},
	})

	RebuildSpellTrackerOptions()

	-- ===========================
	-- STATISTICS TAB
	-- ===========================
	self:AddOption('Statistics', {
		type = 'group',
		name = "Statistics",
		desc = "View alert statistics and performance metrics. Statistics are saved per profile.",
		order = 2.9,
		args = {
			-- Header description
			description = {
				type = 'description',
				name = "|cffFFD700Alert Statistics|r\n\n" ..
				       "Track your alert history to understand which spells and situations you encounter most often.\n\n" ..
				       "|cffFF7D0ANote:|r Statistics are saved per profile. Switching profiles will show different stats.\n",
				fontSize = "medium",
				order = 0,
			},

			-- Enable/Disable toggle
			enableTracking = {
				type = 'toggle',
				name = "Enable Statistics Tracking",
				desc = "Track alert statistics (minimal performance impact: <0.02ms per alert)",
				width = "full",
				order = 0.5,
				set = function(info, value)
					sadb.statistics.enabled = value
					if value then
						-- Initialize on enable
						local Statistics = SoundAlerter:GetModule("Statistics")
						if Statistics then
							Statistics:InitializeStatistics()
						end
						SoundAlerter:Print("Statistics tracking enabled")
					else
						SoundAlerter:Print("Statistics tracking disabled (existing data preserved)")
					end
				end,
				get = function() return sadb.statistics and sadb.statistics.enabled end,
			},

			-- Session Statistics Group
			sessionStats = {
				type = 'group',
				inline = true,
				name = "Session Statistics",
				desc = "Statistics for this play session (resets on logout/reload)",
				order = 1,
				hidden = function() return not sadb.statistics or not sadb.statistics.enabled end,
				args = {
					sessionDisplay = {
						type = 'description',
						name = function()
							if not sadb.statistics or not sadb.statistics.session then
								return "|cffFF0000No session data available|r"
							end

							local session = sadb.statistics.session
							local elapsed = GetTime() - (session.startTime or 0)
							local minutes = math.floor(elapsed / 60)
							local hours = math.floor(minutes / 60)
							local remainingMinutes = minutes % 60

							local timeStr
							if hours > 0 then
								timeStr = string.format("%dh %dm", hours, remainingMinutes)
							else
								timeStr = string.format("%d min", minutes)
							end

							local alertsPerMin = minutes > 0 and (session.totalAlerts / minutes) or 0

							local byCategory = session.byCategory or {}
							return string.format(
								"|cff00FF00 Session Active:|r %s\n" ..
								"|cff00FF00 Total Alerts:|r %d\n" ..
								"|cff00FF00 Alerts/Minute:|r %.1f\n\n" ..
								"|cff00FF00Category Breakdown:|r\n" ..
								"  Spell Alerts: %d\n" ..
								"  Proximity Alerts: %d\n" ..
								"  Trinket Alerts: %d\n" ..
								"  Flag Alerts: %d",
								timeStr,
								session.totalAlerts or 0,
								alertsPerMin,
								byCategory.spellAlerts or 0,
								byCategory.proximityAlerts or 0,
								byCategory.trinketAlerts or 0,
								byCategory.flagAlerts or 0
							)
						end,
						fontSize = "medium",
						order = 1,
					},
				},
			},

			-- All-Time Statistics Group
			allTimeStats = {
				type = 'group',
				inline = true,
				name = "All-Time Statistics",
				desc = "Lifetime statistics for this profile",
				order = 2,
				hidden = function() return not sadb.statistics or not sadb.statistics.enabled end,
				args = {
					allTimeDisplay = {
						type = 'description',
						name = function()
							if not sadb.statistics or not sadb.statistics.allTime then
								return "|cffFF0000No all-time data available|r"
							end

							local allTime = sadb.statistics.allTime
							local avgPerSession = (allTime.totalSessions or 0) > 0 and
								((allTime.totalAlerts or 0) / allTime.totalSessions) or 0

							local byCategory = allTime.byCategory or {}
							local byZone = allTime.byZone or {}

							return string.format(
								"|cffFFD700 Total Alerts:|r %d\n" ..
								"|cffFFD700 Total Sessions:|r %d\n" ..
								"|cffFFD700 Avg/Session:|r %.1f\n\n" ..
								"|cffFFD700Category Totals:|r\n" ..
								"  Spell Alerts: %d\n" ..
								"  Proximity Alerts: %d\n" ..
								"  Trinket Alerts: %d\n" ..
								"  Flag Alerts: %d\n\n" ..
								"|cffFFD700Zone Distribution:|r\n" ..
								"  Arena: %d\n" ..
								"  Battleground: %d\n" ..
								"  World PvP: %d",
								allTime.totalAlerts or 0,
								allTime.totalSessions or 0,
								avgPerSession,
								byCategory.spellAlerts or 0,
								byCategory.proximityAlerts or 0,
								byCategory.trinketAlerts or 0,
								byCategory.flagAlerts or 0,
								byZone.arena or 0,
								byZone.battleground or 0,
								byZone.worldPvP or 0
							)
						end,
						fontSize = "medium",
						order = 1,
					},
				},
			},

			-- Top Spells Group
			topSpellsTable = {
				type = 'group',
				inline = true,
				name = "Top 20 Alerted Spells",
				desc = "Most frequently alerted spells with detailed analytics",
				order = 3,
				hidden = function() return not sadb.statistics or not sadb.statistics.enabled end,
				args = {
					sortDropdown = {
						type = 'select',
						name = "Sort By",
						desc = "Choose how to sort the spell list",
						values = {
							count_desc = "Most Alerts (High to Low)",
							count_asc = "Fewest Alerts (Low to High)",
							name_asc = "Spell Name (A-Z)",
							name_desc = "Spell Name (Z-A)",
							trend = "Trend (Increasing First)",
							class = "Top Class",
							zone = "Top Zone",
							time = "Most Recent"
						},
						width = "full",
						order = 1,
						set = function(info, value)
							local Statistics = SoundAlerter:GetModule("Statistics")
							Statistics:SetSortState("topSpells", value)
						end,
						get = function()
							local Statistics = SoundAlerter:GetModule("Statistics")
							local sortState = Statistics:GetSortState()
							return sortState.topSpells.sortType or "count_desc"
						end
					},

					tableDisplay = {
						type = 'description',
						name = function()
							local Statistics = SoundAlerter:GetModule("Statistics")
							return Statistics:GetTopSpellsTable()
						end,
						fontSize = "medium",
						order = 2
					},

					refreshButton = {
						type = 'execute',
						name = "Refresh",
						desc = "Refresh the statistics display",
						width = "normal",
						func = function()
							LibStub("AceConfigRegistry-3.0"):NotifyChange("SoundAlerter")
						end,
						order = 3
					}
				}
			},

			enemiesTable = {
				type = 'group',
				inline = true,
				name = "Top 20 Encountered Enemies",
				desc = "Players who trigger the most alerts",
				order = 4,
				hidden = function() return not sadb.statistics or not sadb.statistics.enabled end,
				args = {
					sortDropdown = {
						type = 'select',
						name = "Sort By",
						values = {
							alerts_desc = "Most Alerts (High to Low)",
							alerts_asc = "Fewest Alerts (Low to High)",
							name_asc = "Name (A-Z)",
							name_desc = "Name (Z-A)",
							danger = "Danger Rating (High to Low)",
							class = "Class",
							time = "Most Recent"
						},
						width = "full",
						order = 1,
						set = function(info, value)
							local Statistics = SoundAlerter:GetModule("Statistics")
							Statistics:SetSortState("enemies", value)
						end,
						get = function()
							local Statistics = SoundAlerter:GetModule("Statistics")
							local sortState = Statistics:GetSortState()
							return sortState.enemies.sortType or "alerts_desc"
						end
					},

					tableDisplay = {
						type = 'description',
						name = function()
							local Statistics = SoundAlerter:GetModule("Statistics")
							return Statistics:GetEnemiesTable()
						end,
						fontSize = "medium",
						order = 2
					}
				}
			},

			classDistributionTable = {
				type = 'group',
				inline = true,
				name = "Class Distribution Analysis",
				desc = "Alert breakdown by enemy class",
				order = 5,
				hidden = function() return not sadb.statistics or not sadb.statistics.enabled end,
				args = {
					sortDropdown = {
						type = 'select',
						name = "Sort By",
						values = {
							alerts_desc = "Most Alerts (High to Low)",
							alerts_asc = "Fewest Alerts (Low to High)",
							class_asc = "Class Name (A-Z)",
							players = "Most Players",
							avg = "Highest Avg/Player"
						},
						width = "full",
						order = 1,
						set = function(info, value)
							local Statistics = SoundAlerter:GetModule("Statistics")
							Statistics:SetSortState("classes", value)
						end,
						get = function()
							local Statistics = SoundAlerter:GetModule("Statistics")
							local sortState = Statistics:GetSortState()
							return sortState.classes.sortType or "alerts_desc"
						end
					},

					tableDisplay = {
						type = 'description',
						name = function()
							local Statistics = SoundAlerter:GetModule("Statistics")
							return Statistics:GetClassDistributionTable()
						end,
						fontSize = "medium",
						order = 2
					}
				}
			},

			-- Management Group
			management = {
				type = 'group',
				inline = true,
				name = "Management",
				desc = "Reset statistics or export data",
				order = 99,
				hidden = function() return not sadb.statistics or not sadb.statistics.enabled end,
				args = {
					resetSession = {
						type = 'execute',
						name = "Reset Session Stats",
						desc = "Reset statistics for this session only (all-time stats preserved)",
						width = "normal",
						func = function()
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
								SoundAlerter:Print("Session statistics reset")
							end
						end,
						order = 1,
					},

					resetAllTime = {
						type = 'execute',
						name = "Reset All-Time Stats",
						desc = "Reset all statistics including session and all-time data",
						width = "normal",
						confirm = function()
							if not sadb.statistics or not sadb.statistics.allTime then
								return false
							end

							return string.format(
								"Delete all statistics?\n\n" ..
								"Total alerts: %d\n" ..
								"Total sessions: %d\n" ..
								"Top spells tracked: %d\n\n" ..
								"|cffFF0000This cannot be undone!|r",
								sadb.statistics.allTime.totalAlerts or 0,
								sadb.statistics.allTime.totalSessions or 0,
								sadb.statistics.allTime.topSpells and
									(function()
										local count = 0
										for _ in pairs(sadb.statistics.allTime.topSpells) do count = count + 1 end
										return count
									end)() or 0
							)
						end,
						func = function()
							if sadb.statistics then
								-- Reset session
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

								-- Reset all-time
								sadb.statistics.allTime = {
									totalAlerts = 0,
									totalSessions = 1,  -- Current session
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

								SoundAlerter:Print("|cffFF0000All statistics reset|r")
							end
						end,
						order = 2,
					},

					spacer = {
						type = 'description',
						name = " ",
						order = 3,
					},

					info = {
						type = 'description',
						name = "|cffAAAAAA Statistics are saved per profile. Each character/spec can have separate tracking.|r",
						fontSize = "small",
						order = 4,
					},
				},
			},
		},
	})

	-- ===========================
	-- VOICE ALERTS TAB (SLC: Lovable)
	-- ===========================
	self:AddOption('Spells', {
		type = 'group',
		name = "Voice Alerts",
		desc = "Customize which enemy and friendly spells trigger voice alerts. Organized by strategic purpose to help you focus on what matters in PvP.",
		order = 2,
		args = {
			spellGeneral = {
				type = 'group',
				name = "Global Category Toggles",
				desc = "Master toggles to disable entire spell categories. Uncheck to silence all alerts in that category.",
				inline = true,
				set = setOption,
				get = getOption,
				order = -1,
				args = {
					globalNote = {
						type = 'description',
						name = "|cffFFD700Note:|r These toggles disable entire categories. Use per-spell toggles below for fine-grained control.\n",
						fontSize = "small",
						order = 0,
					},
					aruaApplied = {
						type = 'toggle',
						name = "Silence Buff Applied Alerts",
						desc = "When checked: Disables ALL sound notifications when enemy buffs are applied",
						order = 1,
					},
					auraRemoved = {
						type = 'toggle',
						name = "Silence Buff Removed Alerts",
						desc = "When checked: Disables ALL sound notifications when enemy buffs expire",
						order = 2,
					},
					castStart = {
						type = 'toggle',
						name = "Silence Spell Casting Alerts",
						desc = "When checked: Disables ALL notifications when enemies start casting spells",
						order = 3,
					},
					castSuccess = {
						type = 'toggle',
						name = "Silence Enemy Cooldown Alerts",
						desc = "When checked: Disables ALL sound notifications of enemy cooldown abilities",
						order = 4,
					},
					chatalerts = {
						type = 'toggle',
						name = "Silence Chat Alerts",
						desc = "When checked: Disables ALL chat notifications of special abilities",
						order = 5,
					},
					interrupt = {
						type = 'toggle',
						name = "Silence Interrupt Alerts",
						desc = "When checked: Disables notifications of friendly interrupted spells",
						order = 6,
					},
					dArenaPartner = {
						type = 'toggle',
						name = "Silence Arena Partner CC Alerts",
						desc = "When checked: Disables notifications when arena partners are CC'd",
						order = 7,
					},
					dSelfDebuff = {
						type = 'toggle',
						name = "Silence Self Debuff Alerts",
						desc = "When checked: Disables notifications when YOU are debuffed/CC'd",
						order = 8,
					},
					dEnemyDebuff = {
						type = 'toggle',
						name = "Silence Enemy Debuff Alerts",
						desc = "When checked: Disables notifications of enemy debuffs/CC",
						order = 9,
					},
					dEnemyDebuffDown = {
						type = 'toggle',
						name = "Silence Enemy Debuff Expired Alerts",
						desc = "When checked: Disables notifications when enemy debuffs/CC expire",
						order = 10,
					},
				},
			},
			spellauraApplied = {
				type = 'group',
				--inline = true,
				name = "Enemy Defensives & Buffs",
				desc = "Alert when enemies use defensive cooldowns or gain important buffs. Track when to pressure or wait out immunities. Use the search bar below to quickly find specific spells.",
				set = setOption,
				get = getOption,
				disabled = function() return sadb.aruaApplied end,
				order = 2,
				args = {
					class = {
						type = 'toggle',
						name = "Alert Class calling for trinketing in Arena",
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
						name = "|TInterface\\Icons\\ClassIcon_Druid:20|t  |cffFF7D0ADruid|r",
						order = 5,
						args = listOption({1161336,1129166,1122812,1117116,1153312,1122842,1153201,1150334,1101850,1398191,1169369},"auraApplied","spellauraApplied"),
					},
					dk	= {
						type = 'group',
						inline = true,
						name = "|TInterface\\Icons\\ClassIcon_DeathKnight:20|t  |cffC41F3BDeath Knight|r",
						order = 6,
						args = listOption({1149039,1148792,1155233,1148707,1149222,1149016},"auraApplied","spellauraApplied"),
					},
					hunter = {
						type = 'group',
						inline = true,
						name = "|TInterface\\Icons\\ClassIcon_Hunter:20|t  |cffABD473Hunter|r",
						order = 7,
						args = listOption({1134471,1119263,1153480},"auraApplied","spellauraApplied"),
					},
					mage = {
						type = 'group',
						inline = true,
						name = "|TInterface\\Icons\\ClassIcon_Mage:20|t  |cff69CCF0Mage|r",
						order = 8,
						args = listOption({1145438,1112042,1112472,1112043,1128682},"auraApplied","spellauraApplied"),
					},
					paladin = {
						type = 'group',
						inline = true,
						name = "|TInterface\\Icons\\ClassIcon_Paladin:20|t  |cffF58CBAPaladin|r",
						order = 9,
						args = listOption({1131821,1110278,1101044,11642,1106940,1100498,1164205,1154428,1180101},"auraApplied","spellauraApplied")
					},
					priest	= {
						type = 'group',
						inline = true,
						name = "|TInterface\\Icons\\ClassIcon_Priest:20|t  |cffFFFFFFPriest|r",
						order = 10,
						args = listOption({1133206,1110060,1106346,1147585,1114751,1147788},"auraApplied","spellauraApplied")
					},
					rogue = {
						type = 'group',
						inline = true,
						name = "|TInterface\\Icons\\ClassIcon_Rogue:20|t  |cffFFF569Rogue|r",
						order = 11,
						args = listOption({1111305,1114177,1151713,1131224,1113750,1126669},"auraApplied","spellauraApplied")
					},
					shaman	= {
						type = 'group',
						inline = true,
						name = "|TInterface\\Icons\\ClassIcon_Shaman:20|t  |cff0070DEShaman|r",
						order = 12,
						args = listOption({1130823,1100379,1157960,1116166},"auraApplied","spellauraApplied"),
					},
					warrior	= {
						type = 'group',
						inline = true,
						name = "|TInterface\\Icons\\ClassIcon_Warrior:20|t  |cffC79C6EWarrior|r",
						order = 13,
						args = listOption({1101719,1155694,1100871,1112975,1118499,1120230,1123920,1112328,1146924,1112292},"auraApplied","spellauraApplied")
					},
					warlock	= {
						type = 'group',
						inline = true,
						name = "|TInterface\\Icons\\ClassIcon_Warlock:20|t  |cff9482C9Warlock|r",
						order = 14,
						args = listOption({1117941,1147241,2304512},"auraApplied","spellauraApplied"),
						},
					races = {
						type = 'group',
						inline = true,
						name = "|cffFFFFFFGeneral Races|r",
						order = 15,
						args = listOption({58984,1126297,1120594,1133702,7744,1128880},"auraApplied","spellauraApplied"),
					},

					-- Search bar (placed at bottom via high order value)
					searchBarGroup = createSearchBar("spellauraApplied").searchBarGroup,
					}
				},
			spellAuraRemoved = {
				type = 'group',
				--inline = true,
				name = "Enemy Defensives Expired",
				desc = "Alert when enemy defensive cooldowns expire. Know when it's safe to go offensive again. Use the search bar below to quickly find specific spells.",
				set = setOption,
				get = getOption,
				disabled = function() return sadb.auraRemoved end,
				order = 3,
				args = {
					druid = {
						type = 'group',
						inline = true,
						name = "|TInterface\\Icons\\ClassIcon_Druid:20|t  |cffFF7D0ADruid|r",
						order = 1,
						args = listOption({1153201},"auraRemoved","spellAuraRemoved"),
					},
					dk = {
						type = 'group',
						inline = true,
						name = "|TInterface\\Icons\\ClassIcon_DeathKnight:20|t  |cffC41F3BDeath Knight|r",
						order = 2,
						args = listOption({1148707,1148792,1149039},"auraRemoved","spellAuraRemoved"),
					},
					hunter = {
						type = 'group',
						inline = true,
						name = "|TInterface\\Icons\\ClassIcon_Hunter:20|t  |cffABD473Hunter|r",
						order = 3,
						args = listOption({1119263,1134471},"auraRemoved","spellAuraRemoved"),
					},
					mage = {
						type = 'group',
						inline = true,
						name = "|TInterface\\Icons\\ClassIcon_Mage:20|t  |cff69CCF0Mage|r",
						order = 4,
						args = listOption({1145438},"auraRemoved","spellAuraRemoved"),
					},
					paladin = {
						type = 'group',
						inline = true,
						name = "|TInterface\\Icons\\ClassIcon_Paladin:20|t  |cffF58CBAPaladin|r",
						order = 5,
						args = listOption({1100498,1110278,11642},"auraRemoved","spellAuraRemoved"),
					},
					priest	= {
						type = 'group',
						inline = true,
						name = "|TInterface\\Icons\\ClassIcon_Priest:20|t  |cffFFFFFFPriest|r",
						order = 6,
						args = listOption({1147585,1133206},"auraRemoved","spellAuraRemoved"),
					},
					rogue = {
						type = 'group',
						inline = true,
						name = "|TInterface\\Icons\\ClassIcon_Rogue:20|t  |cffFFF569Rogue|r",
						order = 7,
						args = listOption({1131224,1126669},"auraRemoved","spellAuraRemoved"),
					},
					warrior = {
						type = 'group',
						inline = true,
						name = "|TInterface\\Icons\\ClassIcon_Warrior:20|t  |cffC79C6EWarrior|r",
						order = 8,
						args = listOption({1101719,1100871,1112292,1146924},"auraRemoved","spellAuraRemoved"),
					},	

				-- Search bar (placed at bottom via high order value)
				searchBarGroup = createSearchBar("spellAuraRemoved").searchBarGroup,
				}
			},
			spellCastStart = {
				type = 'group',
				--inline = true,
				name = "Enemy Crowd Control (Cast Start)",
				desc = "Alert when enemies start casting CC spells like Polymorph, Cyclone, or Fear. Gives you time to interrupt or react. Use the search bar below to quickly find specific spells.",
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
						name = "|TInterface\\Icons\\ClassIcon_Druid:20|t  |cffFF7D0ADruid|r",
						order = 3,
						args = listOption({1102637,1133786, 1148465, 1100740},"castStart","spellCastStart"),
					},
					hunter = {
						type = 'group',
						inline = true,
						name = "|TInterface\\Icons\\ClassIcon_Hunter:20|t  |cffABD473Hunter|r",
						order = 4,
						args = listOption({982,1114327},"castStart","spellCastStart"),
					},
					mage = {
						type = 'group',
						inline = true,
						name = "|TInterface\\Icons\\ClassIcon_Mage:20|t  |cff69CCF0Mage|r",
						order = 5,
						args = listOption({118,954854},"castStart","spellCastStart"),
					},
					paladin = {
						type = 'group',
						inline = true,
						name = "|TInterface\\Icons\\ClassIcon_Paladin:20|t  |cffF58CBAPaladin|r",
						order = 6,
						args = listOption({1110326},"castStart","spellCastStart"),
					},
					priest	= {
						type = 'group',
						inline = true,
						name = "|TInterface\\Icons\\ClassIcon_Priest:20|t  |cffFFFFFFPriest|r",
						order = 7,
						args = listOption({1108129,1109484,1164843,11605},"castStart","spellCastStart"),
					},
					shaman	= {
						type = 'group',
						inline = true,
						name = "|TInterface\\Icons\\ClassIcon_Shaman:20|t  |cff0070DEShaman|r",
						order = 8,
						args = listOption({1151514,1160043},"castStart","spellCastStart"),
						},
					
					warlock	= {
						type = 'group',
						inline = true,
						name = "|TInterface\\Icons\\ClassIcon_Warlock:20|t  |cff9482C9Warlock|r",
						order = 9,
						args = listOption({6215,1117928,710,11712},"castStart","spellCastStart"),
					},

				-- Search bar (placed at bottom via high order value)
				searchBarGroup = createSearchBar("spellCastStart").searchBarGroup,
				},
			},
			spellCastSuccess = {
				type = 'group',
				--inline = true,
				name = "Enemy Offensive Cooldowns",
				desc = "Alert when enemies use major offensive cooldowns. Know when burst damage windows are active and when to play defensively. Use the search bar below to quickly find specific spells.",
				disabled = function() return sadb.castSuccess end,
				set = setOption,
				get = getOption,
				order = 5,
				args = {
					druid = {
						type = 'group',
						inline = true,
						name = "|TInterface\\Icons\\ClassIcon_Druid:20|t  |cffFF7D0ADruid|r",
						order = 1,
						args = listOption({1133831,1398193,1398192,2304523,1105215},"castSuccess","spellCastSuccess"),
					},
					dk	= {
						type = 'group',
						inline = true,
						name = "|TInterface\\Icons\\ClassIcon_DeathKnight:20|t  |cffC41F3BDeath Knight|r",
						order = 2,
						args = listOption({1147528,1147476,1147568,1149206,1149203,1149005},"castSuccess","spellCastSuccess"),
					},
					hunter = {
						type = 'group',
						inline = true,
						name = "|TInterface\\Icons\\ClassIcon_Hunter:20|t  |cffABD473Hunter|r",
						order = 3,
						args = listOption({1153271,1123989,1119386,1134490,1149050,1114311,1113810,1133044},"castSuccess","spellCastSuccess"),
					},
					mage = {
						type = 'group',
						inline = true,
						name = "|TInterface\\Icons\\ClassIcon_Mage:20|t  |cff69CCF0Mage|r",
						order = 4,
						args = listOption({1144445,1112051,1144572,1111958,1102139,1100066,2110161,1436397,2110021},"castSuccess","spellCastSuccess"),
					},
					paladin = {
						type = 'group',
						inline = true,
						name = "|TInterface\\Icons\\ClassIcon_Paladin:20|t  |cffF58CBAPaladin|r",
						order = 5,
						args = listOption({1120066,1110308,1131884},"castSuccess","spellCastSuccess"),
					},
					priest	= {
						type = 'group',
						inline = true,
						name = "|TInterface\\Icons\\ClassIcon_Priest:20|t  |cffFFFFFFPriest|r",
						order = 6,
						args = listOption({1110890,1134433,1164044,1148173},"castSuccess","spellCastSuccess"),
					},
					rogue = {
						type = 'group',
						inline = true,
						name = "|TInterface\\Icons\\ClassIcon_Rogue:20|t  |cffFFF569Rogue|r",
						order = 7,
						args = listOption({1151722,1151724,2094,1766,1114185,1126889,1113877,1784,2304501},"castSuccess","spellCastSuccess"),
					},
					shaman	= {
						type = 'group',
						inline = true,
						name = "|TInterface\\Icons\\ClassIcon_Shaman:20|t  |cff0070DEShaman|r",
						order = 8,
						args = listOption({1108143,1116190,1102484,1108177,1132182,1102825,1398198},"castSuccess","spellCastSuccess"),
					},
					warrior	= {
						type = 'group',
						inline = true,
						name = "|TInterface\\Icons\\ClassIcon_Warrior:20|t  |cffC79C6EWarrior|r",
						order = 9,
						args = listOption({1102457,1102458,1100071,1180851,1100676,1165930,1106552,1100072},"castSuccess","spellCastSuccess"),
					},
					warlock = {
						type = 'group',
						inline = true,
						name = "|TInterface\\Icons\\ClassIcon_Warlock:20|t  |cff9482C9Warlock|r",
						order = 10,
						args = listOption({1105138,1119647,1148020,1147860,1106358,2304566,2304611,1117925,2304521},"castSuccess","spellCastSuccess"),
					},

				-- Search bar (placed at bottom via high order value)
				searchBarGroup = createSearchBar("spellCastSuccess").searchBarGroup,
				},
			},
			enemydebuff = {
				type = 'group',
				--inline = true,
				name = "Your CC on Enemies",
				desc = "Alert when you or your arena partner successfully land crowd control on enemies. Confirms CC application for coordination. Use the search bar below to quickly find specific spells.",
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
						args = listOption({2094,1151724,1151514,1112826,118,1133786},"enemyDebuffs","enemydebuff"),
					},
					fromarenapartner = {
						type = 'group',
						inline = true,
						name = "|cffFFF569From Arena Partner or affecting your Target|r",
						order = 2,
						args = listOption({2094,1151724,1151514,1112826,118,1133786},"friendCCenemy","enemydebuff"),
					},

					-- Search bar (placed at bottom via high order value)
					searchBarGroup = createSearchBar("enemydebuff").searchBarGroup,
				},
			},
			enemydebuffdown = {
				type = 'group',
				--inline = true,
				name = "Your CC Expired on Enemies",
				desc = "Alert when your crowd control effects on enemies expire. Know when enemies are free and can act again. Use the search bar below to quickly find specific spells.",
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
						args = listOption({2094,1151724,1151514,1112826,118,1133786},"enemyDebuffdown","enemydebuffdown"),
					},
					fromarenapartner = {
						type = 'group',
						inline = true,
						name = "|cffFFF569From Arena Partner or affecting your Target|r",
						desc = "Alerts you if your arena partner casts a spell or your target gets afflicted by a spell",
						order = 2,
						args = listOption({2094,1151724,1151514,1112826,118,1133786},"enemyDebuffdownAP","enemydebuffdown"),
					},

					-- Search bar (placed at bottom via high order value)
					searchBarGroup = createSearchBar("enemydebuffdown").searchBarGroup,
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
				name = "Arena Partner Under Attack",
				desc = "Alert when enemies cast spells targeting your arena partner. React quickly to peel or assist your teammate.",
				disabled = function() return sadb.dArenaPartner end,
				set = setOption,
				get = getOption,
				order = 8,
				args = listOption({1151514,118,1133786,6215},"friendCCs"),
			},
			FriendDebuffSuccess = {
			type = 'group',
			name = "Arena Partner CC'd",
			desc = "Alert when your arena partner gets crowd controlled. Coordinate defensive cooldowns or peels to protect your teammate.",
			disabled = function() return sadb.dArenaPartner end,
			set = setOption,
			get = getOption,
			order = 9,
			args = listOption({1114309,2094,1110308,1151514,1112826,1133786,6215,1102139,1151724},"friendCCSuccess"),
			},
			selfDebuffs = {
				type = 'group',
				--inline = true,
				name = "CC on You",
				desc = "Alert when you get crowd controlled by enemies. Know immediately when to trinket or call for help from teammates.",
				disabled = function() return sadb.dSelfDebuff end,
				set = setOption,
				get = getOption,
				order = 10,
				args = listOption({1133786,1151514,118,6215,1114309,1113809,1165930,1117928,2094,1151724,1110308,1147860,115138,1144572,1120066,1134490,1119434,1147476,1151722,1149005,1119386,1106358},"selfDebuff"),
			},
		},
	})
	-- Find Spell Tab
	-- ===========================
	-- DEVELOPER TOOLS TAB (SLC: Complete)
	-- ===========================
	self:AddOption('FindSpell', {
		type = 'group',
		name = "Developer Tools",
		desc = "Advanced tools for addon developers and power users. Find spell IDs, rebuild database, and access debug features.",
		order = 5,
		args = {
			-- Premium Header Section
			headerWelcome = {
				type = 'description',
				name = "|cff00D4FF===================================|r\n" ..
					   "|cffFFD700        DEVELOPER TOOLS|r\n" ..
					   "|cff00D4FF===================================|r\n\n" ..
					   "|cffADD8E6Advanced utilities for addon development and spell database management.|r\n" ..
					   "|cff888888Power user features for extending SoundAlerter functionality.|r\n",
				fontSize = "medium",
				order = 0.5,
			},

			-- Spell Finder Section
			finderSection = {
				type = 'group',
				inline = true,
				name = "|TInterface\\Icons\\INV_Misc_Spyglass_02:20|t  Spell Database Search",
				order = 1,
				args = {
					finderDescription = {
						type = 'description',
						name = "|cffFFFFFFInteractive spell finder with 70,000+ indexed spells.|r\n\n" ..
							   "|cff00FF00Features:|r Search by name, filter by rank, view tooltips, copy IDs\n" ..
							   "|cffFFD700Use Case:|r Finding spell IDs when adding new spells to spellist.lua\n",
						fontSize = "medium",
						order = 1,
					},
					openFinder = {
						type = 'execute',
						name = "|cff00D4FF[LAUNCH SPELL FINDER]|r",
						desc = "Open the interactive spell search window with real-time results and tooltip previews",
						width = "full",
						order = 2,
						func = function()
							if not SoundAlerter.findSpellFrame then
								SoundAlerter.findSpellFrame = SoundAlerter:CreateFindSpellFrame()
							end
							SoundAlerter.findSpellFrame:Show()
							-- Bring to front
							if SoundAlerter.findSpellFrame.frame then
								SoundAlerter.findSpellFrame.frame:Raise()
							end
						end,
					},
					quickTip = {
						type = 'description',
						name = "\n|cffFFD700Quick Tip:|r Press |cffFFFFFFEnter|r to search, hover results for tooltips\n",
						fontSize = "small",
						order = 3,
					},
					autoSearch = {
						type = 'toggle',
						name = "Auto-Search As You Type",
						desc = "Enable auto-search with 200ms debounce. When enabled, searches automatically as you type (minimum 2 characters). Press Enter to search immediately.",
						width = "full",
						order = 4,
						get = function(info)
							return SoundAlerter.db1.profile.findSpell and SoundAlerter.db1.profile.findSpell.autoSearch or false
						end,
						set = function(info, value)
							if not SoundAlerter.db1.profile.findSpell then
								SoundAlerter.db1.profile.findSpell = {}
							end
							SoundAlerter.db1.profile.findSpell.autoSearch = value
							SoundAlerter:Print(value and "|cFF00FF00Auto-search enabled|r" or "|cFFFF0000Auto-search disabled|r")
						end,
					},
				},
			},

			-- Database Management Section
			databaseSection = {
				type = 'group',
				inline = true,
				name = "|TInterface\\Icons\\INV_Misc_Gear_01:20|t  Database Management",
				order = 2,
				args = {
					dbDescription = {
						type = 'description',
						name = "|cffFFFFFFRebuild the spell database from WoW's spell library.|r\n\n" ..
							   "|cffFFAA00Warning:|r Scans 70,000 spell IDs (takes 3-4 seconds)\n" ..
							   "|cff888888Only needed if database corruption occurs or after major game patches.|r\n",
						fontSize = "medium",
						order = 1,
					},
					rebuild = {
						type = 'execute',
						name = "|cffFFAA00[REBUILD DATABASE]|r",
						desc = "Perform a full database rebuild. This will scan all spell IDs and may cause a brief frame stutter.",
						width = "full",
						order = 2,
						confirm = true,
						confirmText = "This will scan 70,000 spell IDs and take 3-4 seconds. Continue?",
						func = function()
							SoundAlerter:RebuildSpellDatabase()
						end,
					},
				},
			},

			-- Database Stats Section
			statsSection = {
				type = 'group',
				inline = true,
				name = "|TInterface\\Icons\\INV_Misc_Book_09:20|t  Database Statistics",
				order = 3,
				args = {
					dbstats = {
						type = 'description',
						name = function()
							local db = SoundAlerter.spellDatabase
							local count = SoundAlerter:CountSpells()
							local status = ""

							-- Header with visual separator
							status = status .. "|cff00D4FF━━━━━━━━━━━━━━━━━━━━━━━━━━━━|r\n"

							if db.isBuilding then
								-- Building state with progress bar
								local progressBar = ""
								local progressPercent = db.progress or 0
								local filledBlocks = math.floor(progressPercent / 5)
								for i = 1, 20 do
									if i <= filledBlocks then
										progressBar = progressBar .. "|cffFFAA00█|r"
									else
										progressBar = progressBar .. "|cff444444█|r"
									end
								end

								status = status .. "|cffFFFFFF● Status:|r |cFFFFAA00BUILDING DATABASE|r\n"
								status = status .. string.format("|cffFFFFFF● Progress:|r %.1f%% complete\n", progressPercent)
								status = status .. "|cffFFFFFF● Visual:|r " .. progressBar .. "\n"
								status = status .. string.format("|cffFFFFFF● Scanned:|r %s / 70,000 spell IDs\n",
									string.format("%d", db.totalScanned):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", ""))
							else
								-- Ready state with formatted numbers
								local countFormatted = string.format("%d", count):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")

								status = status .. "|cffFFFFFF● Status:|r |cFF00FF00READY|r |cff00FF00✓|r\n"
								status = status .. string.format("|cffFFFFFF● Spells Indexed:|r |cffFFD700%s|r spells\n", countFormatted)

								if db.lastUpdate and db.lastUpdate > 0 then
									local age = time() - db.lastUpdate
									local ageText
									local ageColor = "|cff00FF00" -- Green for recent

									if age < 60 then
										ageText = "just now"
										ageColor = "|cff00FF00"
									elseif age < 3600 then
										ageText = math.floor(age / 60) .. " minutes ago"
										ageColor = "|cff88FF88"
									elseif age < 86400 then
										ageText = math.floor(age / 3600) .. " hours ago"
										ageColor = "|cffFFD700"
									else
										ageText = math.floor(age / 86400) .. " days ago"
										ageColor = "|cffFFAA00"
									end
									status = status .. string.format("|cffFFFFFF● Last Updated:|r %s%s|r\n", ageColor, ageText)
								end
							end

							-- Memory estimate with color coding
							local memKB = math.floor((count * 5 + #db.names * 25) / 1024)
							local memColor = "|cff00FF00" -- Green
							if memKB > 500 then
								memColor = "|cffFFAA00" -- Orange for larger sizes
							end
							status = status .. string.format("|cffFFFFFF● Memory Usage:|r %s~%d KB|r\n", memColor, memKB)

							-- Compatibility note
							status = status .. "|cffFFFFFF● Compatibility:|r Retail + Ascension (11-prefix)\n"

							-- Footer separator
							status = status .. "|cff00D4FF━━━━━━━━━━━━━━━━━━━━━━━━━━━━|r\n"

							return status
						end,
						fontSize = "medium",
						order = 1,
					},
				},
			},

			-- Usage Guide Section
			guideSection = {
				type = 'group',
				inline = true,
				name = "|TInterface\\Icons\\INV_Misc_Note_01:20|t  Quick Start Guide",
				order = 4,
				args = {
					guideIntro = {
						type = 'description',
						name = "|cffFFD700How to find and use spell IDs:|r\n",
						fontSize = "medium",
						order = 1,
					},
					step1 = {
						type = 'description',
						name = "|cff00D4FF[1]|r |cffFFFFFFClick|r |cffFFD700'Launch Spell Finder'|r |cffFFFFFFabove to open the search window|r\n",
						order = 2,
					},
					step2 = {
						type = 'description',
						name = "|cff00D4FF[2]|r |cffFFFFFFType a spell name|r (e.g., 'Healing Touch', 'Polymorph', 'Cyclone')\n",
						order = 3,
					},
					step3 = {
						type = 'description',
						name = "|cff00D4FF[3]|r |cffFFFFFF(Optional)|r Filter by rank number to narrow results\n",
						order = 4,
					},
					step4 = {
						type = 'description',
						name = "|cff00D4FF[4]|r |cffFFFFFFPress|r |cffFFD700Enter|r |cffFFFFFF or click Search to display results|r\n",
						order = 5,
					},
					step5 = {
						type = 'description',
						name = "|cff00D4FF[5]|r |cffFFFFFFHover over results to see detailed spell tooltips|r\n",
						order = 6,
					},
					step6 = {
						type = 'description',
						name = "|cff00D4FF[6]|r |cffFFFFFFCopy the spell ID and add it to|r |cffFFD700spellist.lua|r\n",
						order = 7,
					},
					proTips = {
						type = 'description',
						name = "\n|cffFFD700Pro Tips:|r\n" ..
							   "|cff888888• Database shows both retail IDs (e.g., 51514) and Ascension IDs (1151514)|r\n" ..
							   "|cff888888• Partial spell names work (e.g., 'Poly' finds all Polymorph variants)|r\n" ..
							   "|cff888888• Results are sorted by spell ID for easy browsing|r\n" ..
							   "|cff888888• Tooltip previews help verify you found the correct spell|r\n",
						fontSize = "small",
						order = 8,
					},
				},
			},

			-- Footer
			footer = {
				type = 'description',
				name = "\n|cff00D4FF━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━|r\n" ..
					   "|cff888888Developer Tools v1.0 | SoundAlerter Addon Framework|r\n" ..
					   "|cff00D4FF━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━|r\n",
				fontSize = "small",
				order = 10,
			},
		}
	})
	-- ===========================
	-- ADVANCED TAB (SLC: Complete)
	-- ===========================
	self:AddOption('custom', {
		type = 'group',
		name = "Advanced",
		desc = "Advanced customization: create custom alerts, configure event filters, and fine-tune addon behavior for power users.",
		order = 4,
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
						if sadb.custom[value] then SoundAlerter:Print(L["same name already exists"]) return end
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