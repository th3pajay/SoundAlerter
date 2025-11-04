--[[
SoundAlerter Spells List Data

This table, SoundAlerterSpells, stores all World of Warcraft spell IDs
used by the addon for voice alerts. The structure maps spell events
to a nested table where the key is the Spell ID and the value is the 
name of the corresponding MP3 file (without the .mp3 extension).
]]

SoundAlerterSpells = {
    -- Key: WoW Spell ID (11spellid format)
    -- Value: Sound File Name (.mp3)

    auraApplied = {					-- SPELL_AURA_APPLIED: Buffs/Debuffs cast by or on player/targets
        --Races
        [58984] = "Shadowmeld",
        [1126297] = "berserking",
        [1120594] = "stoneform",
        [1120572] = "BloodFury",
        [1133702] = "BloodFury",
        [7744] = "willoftheforsaken",
        [1128880] = "giftofthenaaru",
        --Druid
        [1161336] = "survivalInstincts",
        [1129166] = "innervate",
        [1122812] = "barkskin",
        [1117116] = "naturesSwiftness",
        [1117329] = "naturesGrasp",	--Natures Grasp rank 6
        [1127009] = "naturesGrasp",	--Natures Grasp rank 7
        [1153312] = "naturesGrasp",	--Natures Grasp rank 8
        [1122842] = "frenziedRegeneration",
        [1148505] = "starfall",	--Starfall rank 1
        [1153199] = "starfall",	--Starfall rank 2
        [1153200] = "starfall",	--Starfall rank 3
        [1153201] = "starfall",	--Starfall rank 4
        [1150334] = "berserk",
		[1169369] = "predatorystrikes",
        [1101850] = "dash",	--Dash rank 1
        [119821] = "dash",	--Dash rank 2
        [1133357] = "dash",	--Dash rank 3
		[1398191] = "ursolsvortex",
        --Paladin
        [1131821] = "auraMastery",
        [111022] = "handOfProtection",	--Hand of Protection rank 1
        [115599] = "handOfProtection",	--Hand of Protection rank 2
        [1110278] = "handOfProtection",	--Hand of Protection rank 3
        [1101044] = "handOfFreedom",
        [11642] = "divineShield",
        [1106940] = "handofsacrifice",
        [1164205] = "divineSacrifice",
        [1100498] = "DivineProtection",
        [1154428] = "divinePlea",
        --Rogue
        [112983] = "sprint",	--Sprint rank 1
        [118696] = "sprint",	--Sprint rank 3
        [1111305] = "sprint",	--Sprint rank 2
        [1151713] = "shadowDance",
        [1131224] = "cloakOfShadows",
        [1113750] = "adrenalineRush",
        [115277] = "evasion", --Evasion rank 1
        [1126669] = "evasion", --Evasion rank 2
        [1114177] = "coldBlood",
        --Warrior
        [1155694] = "EnragedRegeneration",
        [1101719] = "Recklessness",
        [1100871] = "shieldWall",
        [1112975] = "lastStand",
        [1118499] = "berserkerRage",
        [1120230] = "Retaliation",
        [1123920] = "spellReflection",
        [1112328] = "sweepingStrikes",
        [1146924] = "bladestorm",
        [1112292] = "deathWish",
        --Priest
        [1133206] = "painSuppression",
        [1110060] = "powerInfusion",
        [1106346] = "fearWard",
        [1147585] = "dispersion",
        [1114751] = "innerfocus",
        [1147788] = "GuardianSpirit",
        --Shaman
        [1130823] = "shamanisticRage",
        [1100379] = "earthShield",	--Earth Shield rank 1
        [1132593] = "earthShield",	--Earth Shield rank 2
        [1132594] = "earthShield",	--Earth Shield rank 3
        [1149283] = "earthShield",	--Earth Shield rank 4
        [1149284] = "earthShield",	--Earth Shield rank 5
        [1152127] = "waterShield",	--Water Shield rank 1
        [1152129] = "waterShield",	--Water Shield rank 2
        [1152131] = "waterShield",	--Water Shield rank 3
        [1152134] = "waterShield",	--Water Shield rank 4
        [1152136] = "waterShield",	--Water Shield rank 5
        [1152138] = "waterShield",	--Water Shield rank 6
        [1124398] = "waterShield",	--Water Shield rank 7
        [1133736] = "waterShield",	--Water Shield rank 8
        [1157960] = "waterShield",	--Water Shield rank 9
        [1116166] = "ElementalMastery",
        --Mage
        [1145438] = "iceBlock",
        [1112042] = "arcanePower",
        [1112472] = "icyveins",
        [1112043] = "PresenceofMind",
        [1128682] = "combustion",
        --DK
        [1149039] = "lichborne",
        [1148792] = "iceboundFortitude",
        [1155233] = "vampiricBlood",
        [1148707] = "antimagicshell",
        [1149222] = "boneshield",
        [1149016] = "hysteria",
        --Hunter
        [1153480] = "roarofsacrifice",
        [1134471] = "theBeastWithin",
        [1119263] = "deterrence",
        --Warlock
        [1117941] = "shadowtrance",
    },
    auraRemoved = { -- SPELL_AURA_REMOVED: Important buffs/debuffs falling off
        --Warrior
        [1146924] = "bladestormdown",
        [1101719] = "RecklessnessDown",
        [1100871] = "shieldWallDown",
        [1112292] = "deathWishdown",
        --Paladin
        [1100498] = "DivineProtectionDown",
        [1110278] = "protectionDown",
        [11642] = "bubbleDown",
        --Rogue
        [1131224] = "cloakDown",
        [1126669] = "evasionDown",
        --Priest
        [1133206] = "PSDown",
        [1147585] = "dispersionDown",
        --Mage
        [1145438] = "iceBlockDown",
        --DK
        [1148792] = "iceboundFortitudeDown",
        [1149039] = "lichborneDown",
        [1148707] = "antimagicshelldown",
        --Druid
        [1148505] = "Starfalldown",	--Starfall rank 1
        [1153199] = "Starfalldown",	--Starfall rank 2
        [1153200] = "Starfalldown",	--Starfall rank 3
        [1153201] = "Starfalldown",	--Starfall rank 4
        --Hunter
        [1119263] = "Deterrencedown",
        [1134471] = "beastwithindown",
    },
    castStart = { -- SPELL_CAST_START: Long-cast important spells (CC, Big Heals)
        --general
        [11635] = "bigHeal",	--Holy Light rank 1
        [11639] = "bigHeal",	--Holy Light rank 2
        [11647] = "bigHeal",	--Holy Light rank 3
        [111026] = "bigHeal",	--Holy Light rank 4
        [111042] = "bigHeal",	--Holy Light rank 5
        [113472] = "bigHeal",	--Holy Light rank 6
        [1110328] = "bigHeal",	--Holy Light rank 7
        [1110329] = "bigHeal",	--Holy Light rank 8
        [1125292] = "bigHeal",	--Holy Light rank 9
        [1127135] = "bigHeal",	--Holy Light rank 10
        [1127136] = "bigHeal",	--Holy Light rank 11
        [1148782] = "bigHeal",	--Holy Light rank 12
        [112054] = "bigHeal",		--Heal rank 1
        [112055] = "bigHeal",		--Heal rank 2
        [116063] = "bigHeal",		--Heal rank 3
        [116064] = "bigHeal",		--Heal rank 4
        [112060] = "bigHeal",		--Greater Heal rank 1
        [11332] = "bigHeal",	--Healing Wave rank 2
        [11547] = "bigHeal",	--Healing Wave rank 3
        [11913] = "bigHeal",	--Healing Wave rank 4
        [11939] = "bigHeal",	--Healing Wave rank 5
        [11959] = "bigHeal",	--Healing Wave rank 6
        [118005] = "bigHeal",	--Healing Wave rank 7
        [1110395] = "bigHeal",	--Healing Wave rank 8
        [1110396] = "bigHeal",	--Healing Wave rank 9
        [1125357] = "bigHeal",	--Healing Wave rank 10
        [1125391] = "bigHeal",	--Healing Wave rank 11
        [1125396] = "bigHeal",	--Healing Wave rank 12
        [1149272] = "bigHeal",	--Healing Wave rank 13
        [1149273] = "bigHeal",	--Healing Wave rank 14
        [115185] = "bigHeal",		--Healing Touch rank 1
        [115186] = "bigHeal",		--Healing Touch rank 2
        [115187] = "bigHeal",		--Healing Touch rank 3
        [115188] = "bigHeal",		--Healing Touch rank 4
        [115189] = "bigHeal",		--Healing Touch rank 5
        [116778] = "bigHeal",		--Healing Touch rank 6
        [118903] = "bigHeal",		--Healing Touch rank 7
        [119758] = "bigHeal",		--Healing Touch rank 8
        [119888] = "bigHeal",		--Healing Touch rank 9
        [119889] = "bigHeal",		--Healing Touch rank 10
        [1125297] = "bigHeal",		--Healing Touch rank 11
        [1126978] = "bigHeal",		--Healing Touch rank 12
        [1126979] = "bigHeal",		--Healing Touch rank 13
        [1148377] = "bigHeal",		--Healing Touch rank 14
        [1148378] = "bigHeal",		--Healing Touch rank 15
        [112006] = "resurrection",	--Resurrection (priest) rank 1
        [112010] = "resurrection",	--Resurrection (priest) rank 2
        [1110880] = "resurrection",	--Resurrection (priest) rank 3
        [1110881] = "resurrection",	--Resurrection (priest) rank 4
        [1120770] = "resurrection",	--Resurrection (priest) rank 5
        [1125435] = "resurrection",	--Resurrection (priest) rank 6
        [1148171] = "resurrection",	--Resurrection (priest) rank 7
        [117328] = "resurrection",	--Redemption rank 1
        [1110322] = "resurrection",	--Redemption rank 2
        [1110324] = "resurrection",	--Redemption rank 3
        [1120772] = "resurrection",	--Redemption rank 4
        [1120773] = "resurrection",	--Redemption rank 5
        [1148949] = "resurrection",	--Redemption rank 6
        [1148950] = "resurrection",	--Redemption rank 7
        [112008] = "resurrection",	--Ancestral Spirit rank 1
        [1120609] = "resurrection",	--Ancestral Spirit rank 2
        [1150769] = "resurrection",	--Revive rank 1
        [1150768] = "resurrection",	--Revive rank 2
        [1150767] = "resurrection",	--Revive rank 3
        [1150766] = "resurrection",	--Revive rank 4
        [1150765] = "resurrection",	--Revive rank 5
        [1150764] = "resurrection",	--Revive rank 6
        [1150763] = "resurrection",	--Revive rank 7
        --druid
        [1118658] = "hibernate",
        [1102637] = "hibernate",
        [1133786] = "cyclone",
		[1100740] = "Tranquility",
        [1148465] = "starfire", --rank 10
        --paladin
        [1110326] = "turnEvil", --unimplemented
        --rogue
        --warrior
        --priest		
        [1108129] = "manaBurn",
        [1109484] = "shackleUndead",
        [1164843] = "divineHymn",
        [11605] = "mindControl",
        --shaman
        [1151514] = "hex",
        [1160043] = "lavaburst",
        --mage
        [118] = "polymorph", --Can be poly:turtle, cat, sheep, etc
        [1112826] = "polymorph",
        [1128272] = "polymorph",
        [1161305] = "polymorph",
        [1161721] = "polymorph",
        [1161025] = "polymorph",
        [1161780] = "polymorph",
        [1128271] = "polymorph",
		[1398221] = "ringoffrost",
        --Hunter
        [982] = "revivePet",
        [1114327] = "scareBeast",
        --Warlock
        [6215] = "fear",
        [115484] = "fear2", -- Howl of Terror
        [1117928] = "fear2", --Howl of Terror
        [710] = "banish",
        [11688] = "summonpet",
        [11691] = "summonpet",
        [11712] =  "summonpet",
        [11697] = "summonpet",
        [1130146] = "summonpet", --felguard, works
		[1398206] = "handofguldan",
    },
    castSuccess = { -- SPELL_CAST_SUCCESS: Instant spells or spells completing a cast that are important
        --general (all classes)
        [42292] = "Trinket",    -- PvP Trinket (retail)
        [59752] = "Trinket",    -- Every Man for Himself - Human racial (retail)
        [1142292] = "Trinket",  -- PvP Trinket (Ascension 11-prefix)
        [1159752] = "Trinket",  -- Every Man for Himself (Ascension 11-prefix)
        --mage
        [1112051] = "evocation",
        [1111958] = "coldSnap",
        [1144572] = "deepFreeze",
        [1144445] = "hotStreak", --double check spell ID
        [1102139] = "counterspell",
        [1100066] = "invisibility",
		[1398172] = "meteor",
		[1398160] = "altertime",
        --DK
        [1147528] = "mindFreeze",
        [1147476] = "strangulate",
        [1147568] = "runeWeapon",
        [1149206] = "gargoyle",
        [1149203] = "hungeringCold",
        [1149005] = "markofblood",
        --hunter
        [1123989] = "readiness",
        [1119386] = "wyvernSting",
        [1149010] = "wyvernSting",
        [1134490] = "silencingshot",
        [1119434] = "aimedshot", --Aimed Shot rank 1
        [1149050] = "aimedshot", --Aimed Shot rank 9
        [1153271] = "masterscall",
        [1160192] = "freezingtrap", --double check
        [1114309] = "freezingtrap", --Freezing trap effect
        [1113810] = "frosttrap", --Frost trap aura
        [1113809] = "frosttrap", --Frost trap aura
        [1114311] = "freezingtrap",
        [111499] = "frosttrap",
		[1133044] = "powershot",
        --warlock
        [115138] = "DrainMana",
        [1117928] = "fear2", --Howl of Terror
        [1119647] = "spellLock",
        [1148020] = "demonicCircleTeleport",
        [116789] = "deathcoil",
        [1147860] = "deathcoil",
        [1106358] = "Seduction",
		[1398195] = "unendingresolve",
		[1398197] = "bloodhorror",
		--druid
        [1133831] = "forceofnature",
		[1398193] = "stampendingroar",
		[1398192] = "massentanglement",
		[2304523] = "solarbeam",
		[5215] = "prowl",       -- Prowl rank 1 (retail)
		[1105215] = "prowl",    -- Prowl rank 1 (Ascension 11-prefix)
		[6783] = "prowl",       -- Prowl rank 2 (retail)
		[1106783] = "prowl",    -- Prowl rank 2 (Ascension 11-prefix)
		[9913] = "prowl",       -- Prowl rank 3 (retail)
		[1109913] = "prowl",    -- Prowl rank 3 (Ascension 11-prefix)
        --paladin
        [1120066] = "repentance",
        [1110308] = "hammerofjustice",
        [1131884] = "avengingWrath",
        --rogue
        [1151722] = "disarm2", --dismantle
        [1151724] = "sap",
        [1111297] = "sap",
        [116770] = "sap",
        [2094] = "blind",
        [1766] = "kick",
        [1114185] = "preparation",
        [26889] = "vanish",     -- Vanish (retail)
        [1126889] = "vanish",   -- Vanish (Ascension 11-prefix)
        [1113877] = "bladeflurry",
        [1784] = "stealth",     -- Stealth (retail)
        [1101784] = "stealth",  -- Stealth (Ascension 11-prefix)
        [1785] = "stealth",     -- Stealth rank 2 (retail)
        [1101785] = "stealth",  -- Stealth rank 2 (Ascension)
		[1398189] = "smokebomb",
        --shaman
        [1102825] = "bloodlust",
        [1132182] = "heroism",
        [1108143] = "tremorTotem",
        [1165992] = "tremorTotem", --dont know which one
        [1116190] = "manaTide",
        [1102484] = "earthbind",
        [1108177] = "grounding",
		[1398198] = "capacitortotem",
        --warrior
        [1102457] = "battlestance",
        [1100071] = "defensestance",
        [1102458] = "berserkerstance",
		[1180850] = "gladiatorstance",
        [1100676] = "disarm",
        [1165930] = "fear3", --Intimidating shout
        [1106552] = "pummel",
        [1100072] = "shieldBash",
        --priest
        [1110890] = "fear4", -- Psychic Scream
        [1134433] = "shadowFiend", -- works
        [1164044] = "disarm3", --Psychic horror
        [1148173] = "desperatePrayer",
    },
    enemyDebuffs = { -- CC applied by me to a hostile player
        [2094] = "Enemyblinded",
        [1151724] = "Enemysapped",
        [1112826] = "EnemyPollied",
        [118] = "EnemyPollied",
        [1133786] = "EnemyCycloned",--menu
        [1151514] = "EnemyHexxed",
    },
    enemyDebuffdown = { -- CC applied by me to a hostile player fading
        [2094] = "blinddown",
        [1151724] = "sapdown",
        [118] = "polydown",
        [1112826] = "polydown",
        [1133786] = "cyclonedown",
        [1151514] = "hexdown",
    },
    interruptFriend = { -- Interrupts by a friendly unit
        [1102139] = "friendcountered",
        [1150613] = "friendcountered",
        [1766] = "friendcountered",
        [1157994] = "friendcountered",
        [1172] = "friendcountered",
        [1147528] = "friendcountered",
    },
    friendCCs = { -- Cast start of a CC spell targeting a friendly unit
        [1133786] = "cyclonefriend",
        [1151514] = "hexfriend",
        [1112826] = "polyfriend",
        [118] = "polyfriend",
        [1128272] = "polyfriend",
        [1161305] = "polyfriend",
        [1161721] = "polyfriend",
        [1161025] = "polyfriend",
        [1161780] = "polyfriend",
        [1128271] = "polyfriend",
        [6215] = "fearfriend",
    },
    friendCCSuccess = { -- Successful CC application on a friendly unit
        [1114309] = "friendfrozen",
        [2094] = "blindfriend",
        [1165930] = "friendfeared", --Intimidating shout
        [1151724] = "friendsapped",
        [1133786] = "friendcycloned",
        [1110308] = "friendstunned",
        [1102139] = "friendcountered",
        [1151514] = "friendhexxed",
        [118] = "friendpoly",
        [1112826] = "friendpoly",
        [6215] = "friendfeared",
        [1110890] = "friendfeared",
        [1117928] = "friendfeared",
    },
    friendCCenemy = { -- CC applied by a friendly unit to a hostile player
        [2094] = "enemyblinded",
        [1151724] = "enemysapped",
        [1151514] = "enemyhexxed",
        [1112826] = "enemypollied",
        [118] = "enemypollied",
        [1133786] = "enemycycloned",
    },
    enemyDebuffdownAP = { -- CC fading on hostile player (used for arena partners)
        [2094] = "Blinddown",
        [1151724] = "Sapdown",
        [1151514] = "Hexdown",
        [1112826] = "Polydown",
        [118] = "Polydown",
        [1133786] = "CycloneDown",
    },
    selfDebuff = { -- CC/Important Debuffs applied to *me*
        [1133786] = "Cyclone",
        [1151514] = "Hex",
        [1112826] = "Polymorph",
        [118] = "Polymorph",
        [1128272] = "Polymorph",
        [1161305] = "Polymorph",
        [1161721] = "Polymorph",
        [1161025] = "Polymorph",
        [1161780] = "Polymorph",
        [1128271] = "Polymorph",
        [6215] = "Fear",
        [1160192] = "Freezingtrap", --double check
        [1114309] = "Freezingtrap", --Freezing trap effect
        [1113810] = "Frosttrap", --Frost trap aura
        [1113809] = "Frosttrap", --Frost trap aura
        [1114311] = "Freezingtrap",
        [111499] = "Frosttrap",
        [1165930] = "Fear3", --Intimidating shout
        [1117928] = "Fear2", --Howl of Terror
        [2094] = "Blind",
        [1151724] = "Sap",
        [1111297] = "Sap",
        [116770] = "Sap",
        [1110308] = "Hammerofjustice",
        [1110890] = "Fear4", -- Psychic Scream
        [1147860] = "Deathcoil",
        [115138] = "drainMana",
        [1144572] = "DeepFreeze",
        [1120066] = "Repentance",
        [1134490] = "Silencingshot",
        [1119434] = "Aimedshot", --Aimed Shot rank 1
        [1149050] = "Aimedshot", --Aimed Shot rank 9
        [1147476] = "Strangulate",
        [1151722] = "Disarm2", --Dismantle
        [1149005] = "Markofblood",
        [1119386] = "wyvernSting",
        [1149010] = "wyvernSting",
        [1106358] = "seduction",
    },
}


-- =========================================================================
-- Private Server Compatibility Patch
-- Adds the non-prefixed (retail) ID for every existing 11-prefixed ID.
-- This ensures maximum compatibility with combat logs.
-- =========================================================================

local function addNonPrefixedIDs(spellTable)
    local newIDs = {}
    for prefixedID, soundName in pairs(spellTable) do
        -- Only process IDs that start with "11" and are at least 3 digits long (after "11")
        if type(prefixedID) == "number" and tostring(prefixedID):sub(1, 2) == "11" then
            local baseIDString = tostring(prefixedID):sub(3)
            local baseID = tonumber(baseIDString)
            if baseID and baseID > 0 then
                newIDs[baseID] = soundName
            end
        end
    end
    -- Merge the new non-prefixed IDs into the original table
    for baseID, soundName in pairs(newIDs) do
        spellTable[baseID] = soundName
    end
end

-- Apply the prefixing logic to all spell categories
for category, spellTable in pairs(SoundAlerterSpells) do
    if type(spellTable) == "table" then
        addNonPrefixedIDs(spellTable)
    end
end