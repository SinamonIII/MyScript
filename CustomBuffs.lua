--New one function solution

--Known bugs:
--issue with taint on show() causing invalid combat show errors sometimes; unsure of cause

--Create table to contain stuff for the script
if not CustomBuffs then
    CustomBuffs = {
    --[[
        CustomBuffsFrame        :   Frame

        playerClass             :   String

        canMassDispel           :   boolean
        canDispelMagic          :   boolean
        canDispelCurse          :   boolean
        canDispelPoison         :   boolean
        canDispelDisease        :   boolean
        dispelType              :   number
        dispelValues            :   Table

        layoutNeedsUpdate       :   boolean

        units                   :   Table

        lookupIDByName          :   Table ??

        MAX_DEBUFFS             :   number
        BUFF_SCALE_FACTOR       :   number
        BIG_BUFF_SCALE_FACTOR   :   number

        INTERRUPTS              :   Table
        CDS                     :   Table
        EXTERNALS               :   Table
        EXTRA_RAID_BUFFS        :   Table
        THROUGHPUT_CDS          :   Table
        EXTERNAL_THROUGHPUT_CDS :   Table
        BOSS_BUFFS              :   Table
        CC                      :   Table

        inRaidGroup             :   boolean
    --]]
    };
end

--Create a frame so that we can listen for and handle events
if not CustomBuffs.CustomBuffsFrame then
    CustomBuffs.CustomBuffsFrame = CreateFrame("Frame","CustomBuffsFrame");
end

--Create units table
if not CustomBuffs.units then
    CustomBuffs.units = {};
end

--Set up values for dispel types; used to quickly
--determine whether a spell is dispellable by the player class;
--used to increase the debuff priority of dispellable debuffs
if not CustomBuffs.dispelValues then
    CustomBuffs.dispelValues = {
        ["magic"] = 0x1,
        ["curse"] = 0x2,
        ["poison"] = 0x4,
        ["disease"] = 0x8,
        ["massDispel"] = 0x10,
        ["purge"] = 0x20    --Tracked for things like MC
    };
end

--TODO: add options for these rather than hard coding

--Set Max Debuffs
if not CustomBuffs.MAX_DEBUFFS then
    CustomBuffs.MAX_DEBUFFS = 15;
end

--Set Buff Scale Factor
if not CustomBuffs.BUFF_SCALE_FACTOR then
    CustomBuffs.BUFF_SCALE_FACTOR = 10;
    CustomBuffs.BIG_BUFF_SCALE_FACTOR = 1.5;
end

CustomBuffs.inRaidGroup = false;

--Deal with combat breaking frames by disabling CompactRaidFrameContainer's layoutFrames function
--while in combat so players joining or leaving the group/raid in combat won't break anyone else's frames
local oldUpdateLayout = CompactRaidFrameContainer_LayoutFrames;
CompactRaidFrameContainer_LayoutFrames = function(self)
    if InCombatLockdown() then
        CustomBuffs.layoutNeedsUpdate = true;
    else
        oldUpdateLayout(self);
    end
end

----------------------
----    Tables    ----
----------------------

--Each table is responsible for tracking a different type of aura.  Every table of auras maps
--a different pool of buffs/debuffs to a specific priority level and display location.  Smaller
--priority level values correspond to higher priority.

--[[
Priority level for standard buff frames:
    1) Blizzard specified boss buffs that fall through
    2) Custom boss buffs from BOSS_BUFFS that fall through
    3) Throughput CDs from THROUGHPUT_CDS that fall through
    3) External throughput CDs from EXTERNAL_THROUGHPUT_CDS that fall through
    4) Personal CDs from CDS
    4) External CDs from EXTERNALS
    5) Any other tracked buffs from EXTRA_RAID_BUFFS
    6) Pad out remaining buff frames with any remaining buffs flagged for display by Blizzard

Priority level for standard debuff frames:
    1) Blizzard specified boss debuffs that fall through
    2) Dispellable CC debuffs from CC that fall through
    3) Undispellable CC debuffs from CC that fall through
    4) Blizzard flagged priority debuffs (Forbearance)
    5) Pad out remaining debuff frames with any remaining debuffs flagged for display by Blizzard

Priority level for boss debuff frames:
    1) Active interrupts
    2) Blizzard specified boss debuffs
    2) Blizzard specified boss buffs
    3) Dispellable CC debuffs from CC
    4) Undispellable CC debuffs from CC
    5) Custom boss buffs from BOSS_BUFFS
    UNUSED BOSS DEBUFF FRAMES ARE HIDDEN, NOT PADDED OUT

Priority level for throughput frames:
    1) High priority flagged throughput CDs from THROUGHPUT_CDS or EXTERNAL_THROUGHPUT_CDS
    2) Non flagged Throughput CDs from THROUGHPUT_CDS
    3) Non flagged external throughput CDs from EXTERNAL_THROUGHPUT_CDS
    UNUSED THROUGHPUT FRAMES ARE HIDDEN, NOT PADDED OUT

--]]

--Table of interrupts and their durations from BigDebuffs
CustomBuffs.INTERRUPTS = {
    [1766] =   { duration = 5 }, -- Kick (Rogue)
    [2139] =   { duration = 6 }, -- Counterspell (Mage)
    [6552] =   { duration = 4 }, -- Pummel (Warrior)
    [19647] =  { duration = 6 }, -- Spell Lock (Warlock)
    [47528] =  { duration = 3 }, -- Mind Freeze (Death Knight)
    [57994] =  { duration = 3 }, -- Wind Shear (Shaman)
    [91802] =  { duration = 2 }, -- Shambling Rush (Death Knight)
    [96231] =  { duration = 4 }, -- Rebuke (Paladin)
    [106839] = { duration = 4 }, -- Skull Bash (Feral)
    [115781] = { duration = 6 }, -- Optical Blast (Warlock)
    [116705] = { duration = 4 }, -- Spear Hand Strike (Monk)
    [132409] = { duration = 6 }, -- Spell Lock (Warlock)
    [147362] = { duration = 3 }, -- Countershot (Hunter)
    [171138] = { duration = 6 }, -- Shadow Lock (Warlock)
    [183752] = { duration = 3 }, -- Consume Magic (Demon Hunter)
    [187707] = { duration = 3 }, -- Muzzle (Hunter)
    [212619] = { duration = 6 }, -- Call Felhunter (Warlock)
    [231665] = { duration = 3 }, -- Avengers Shield (Paladin)
    ["Solar Beam"] = { duration = 5 },

    --Non player interrupts BETA FEATURE
    ["Quaking"] = { duration = 5 }
};


--CDs show self-applied class-specific buffs in the standard buff location
    --Display Location:     standard buff
    --Aura Sources:         displayed unit
    --Aura Type:            buff
    --Standard Priority Level:
local CDStandard = {["sbPrio"] = 4, ["sdPrio"] = nil, ["bdPrio"] = nil, ["tbPrio"] = nil};
        CustomBuffs.CDS = {
            [ 6 ] = { --Death Knight
                ["Icebound Fortitude"] =        CDStandard,
                ["Anti-Magic Shell"] =          CDStandard,
                ["Vampiric Blood"] =            CDStandard,
                ["Corpse Shield"] =             CDStandard,
                ["Bone Shield"] =               CDStandard,
                ["Dancing Rune Weapon"] =       CDStandard,
                ["Hemostasis"] =                CDStandard
            } ,
            [ 11 ] = { --Druid
                ["Survival Instincts"] =        CDStandard,
                ["Barkskin"] =                  CDStandard,
                ["Ironfur"] =                   CDStandard,
                ["Frenzied Regeneration"] =     CDStandard
            } ,
            [ 3 ] = { --Hunter
                ["Aspect of the Turtle"] =      CDStandard,
                ["Survival of the Fittest"] =   CDStandard
            } ,
            [ 8 ] = { --Mage
                ["Ice Block"] =                 CDStandard,
                ["Evanesce"] =                  CDStandard,
                ["Greater Invisibility"] =      CDStandard,
                ["Alter Time"] =                CDStandard,
                ["Temporal Shield"] =           CDStandard
            } ,
            [ 10 ] = { --Monk
                ["Zen Meditation"] =            CDStandard,
                ["Diffuse Magic"] =             CDStandard,
                ["Dampen Harm"] =               CDStandard,
                ["Touch of Karma"] =            CDStandard,
                ["Fortifying Brew"] =           CDStandard
            } ,
            [ 2 ] = { --Paladin
                ["Divine Shield"] =             CDStandard,
                ["Divine Protection"] =         CDStandard,
                ["Ardent Defender"] =           CDStandard,
                ["Aegis of Light"] =            CDStandard,
                ["Eye for an Eye"] =            CDStandard,
                ["Shield of Vengeance"] =       CDStandard,
                ["Guardian of Ancient Kings"] = CDStandard,
                ["Seraphim"] =                  CDStandard,
                ["Guardian of the fortress"] =  CDStandard,
                ["Shield of the Righteous"] =   CDStandard
            } ,
            [ 5 ] = { --Priest
                ["Dispersion"] =                CDStandard,
                ["Fade"] =                      CDStandard,
                ["Greater Fade"] =              CDStandard
            } ,
            [ 4 ] = { --Rogue
                ["Evasion"] =                   CDStandard,
                ["Cloak of Shadows"] =          CDStandard,
                ["Feint"] =                     CDStandard,
                ["Readiness"] =                 CDStandard,
                ["Riposte"] =                   CDStandard,
                ["Crimson Vial"] =              CDStandard
            } ,
            [ 7 ] = { --Shaman
                ["Astral Shift"] =              CDStandard,
                ["Shamanistic Rage"] =          CDStandard,
                ["Harden Skin"] =               CDStandard
            } ,
            [ 9 ] = { --Warlock
                ["Unending Resolve"] =          CDStandard,
                ["Dark Pact"] =                 CDStandard,
                ["Netherward"] =                CDStandard
            } ,
            [ 1 ] = { --Warrior
                ["Shield Wall"] =               CDStandard,
                ["Spell Reflection"] =          CDStandard,
                ["Shield Block"] =              CDStandard,
                ["Last Stand"] =                CDStandard,
                ["Die By The Sword"] =          CDStandard,
                ["Defensive Stance"] =          CDStandard
            },
            [ 12 ] = { --Demon Hunter
                ["Netherwalk"] =                CDStandard,
                ["Blur"] =                      CDStandard,
                ["Darkness"] =                  CDStandard,
                ["Demon Spikes"] =              CDStandard,
                ["Soul Fragments"] =            CDStandard
            }
        };
--Externals show important buffs applied by units other than the player in the standard buff location
    --Display Location:     standard buff
    --Aura Sources:         non player (formerly to prevent duplicates for player casted versions)
    --Aura Type:            buff
    --Standard Priority Level:
local EStandard = {["sbPrio"] = 4, ["sdPrio"] = nil, ["bdPrio"] = nil, ["tbPrio"] = nil};
CustomBuffs.EXTERNALS = {
    --Major Externals
    ["Ironbark"] =                  EStandard,
    ["Life Cocoon"] =               EStandard,
    ["Vampiric Aura"] =             EStandard,
    ["Blessing of Protection"] =    EStandard,
    ["Blessing of Sacrifice"] =     EStandard,
    ["Blessing of Spellwarding"] =  EStandard,
    ["Pain Suppression"] =          EStandard,
    ["Guardian Spirit"] =           EStandard,
    ["Roar of Sacrifice"] =         EStandard,
    ["Innervate"] =                 EStandard,
    ["Cenarion Ward"] =             EStandard,
    ["Safeguard"] =                 EStandard,
    ["Vigilance"] =                 EStandard,
    ["Earth Shield"] =              EStandard,
    ["Tiger's Lust"] =              EStandard,
    ["Beacon of Virtue"] =          EStandard,
    ["Beacon of Faith"] =           EStandard,
    ["Beacon of Light"] =           EStandard,
    ["Lifebloom"] =                 EStandard,
    ["Spirit Mend"] =               EStandard,
    ["Misdirection"] =              EStandard,
    ["Tricks of the Trade"] =       EStandard,
    --Show party/raid member's stealth status in buffs
    ["Stealth"] =                   EStandard,
    ["Vanish"] =                    EStandard,
    ["Prowl"] =                     EStandard,

    --For Druids
    --["Cultivation"] = true--,
    --["Spring Blossoms"] = true


    --[[ Filler Buffs
    "Power Word: Shield",
    "Enveloping Mist",
    "Lifebloom",
    "Focused Growth",
    "Wild Growth",
    --"Attonement",
    "Renewing Mist",
    "Rejuvenation",
    "Rejuvenation (Germination)"
    --]]
};

--Extra raid buffs show untracked buffs from any source in the standard buff location
    --Display Location:     standard buff
    --Aura Sources:         player
    --Aura Type:            buff
    --Standard Priority Level:
local ERBStandard = {["sbPrio"] = 5, ["sdPrio"] = nil, ["bdPrio"] = nil, ["tbPrio"] = nil};
CustomBuffs.EXTRA_RAID_BUFFS = {
    ["Coastal Surge"] =         ERBStandard,
    ["Quickening"] =            ERBStandard,
    ["Ancient Flame"] =         ERBStandard,
    ["Blessed Portents"] =      ERBStandard,
    ["Concentrated Mending"] =  ERBStandard,
    ["Cultivation"] =           ERBStandard,
    ["Touch of the Voodoo"] =   ERBStandard,
    ["Grove Tending"] =         ERBStandard,
    ["Spring Blossoms"] =       ERBStandard,
    ["Costal Surge"] =          ERBStandard,
    [290754] =                  ERBStandard, --Lifebloom
    ["Egg on Your Face"] =      ERBStandard,
    ["Luminous Jellyweed"] =    ERBStandard,
    ["Glimmer of Light"] =      ERBStandard,
    ["Ancestral Vigor"] =       ERBStandard
};


--Throughput CDs show important CDs cast by the unit in a special set of throughput buff frames
    --Display Location:     throughtput frames
    --Aura Sources:         displayed unit
    --Aura Type:            buff
    --Standard Priority Level:
local TCDStandard = {["sbPrio"] = 3, ["sdPrio"] = nil, ["bdPrio"] = nil, ["tbPrio"] = 2};
CustomBuffs.THROUGHPUT_CDS = {
    [ 6 ] = { -- dk
        ["Pillar of Frost"] =                   TCDStandard,
        ["Unholy Frenzy"] =                     TCDStandard
    } ,
    [ 11 ] = { --druid
        ["Incarnation: Tree of Life"] =         TCDStandard,
        ["Incarnation: King of the Jungle"] =   TCDStandard,
        ["Berserk"] =                           TCDStandard,
        ["Incarnation: Guardian of Ursoc"] =    TCDStandard,
        ["Incarnation: Chosen of Elune"] =      TCDStandard,
        ["Celestial Alignment"] =               TCDStandard,
        ["Essence of G'Hanir"] =                TCDStandard,
        ["Tiger's Fury"] =                      TCDStandard

    } ,
    [ 3 ] = { -- hunter
        ["Aspect of the Wild"] =                TCDStandard,
        ["Aspect of the Eagle"] =               TCDStandard,
        ["Bestial Wrath"] =                     TCDStandard,
        ["Trueshot"] =                          TCDStandard
    } ,
    [ 8 ] = { --mage
        ["Icy Veins"] =                         TCDStandard,
        ["Combustion"] =                        TCDStandard,
        ["Arcane Power"] =                      TCDStandard

    } ,
    [ 10 ] = { --monk
        ["Way of the Crane"] =                  TCDStandard,
        ["Storm, Earth, and Fire"] =            TCDStandard,
        ["Serenity"] =                          TCDStandard,
        ["Thunder Focus Tea"] =                 TCDStandard
    } ,
    [ 2 ] = { --paladin
        ["Avenging Wrath"] =                    TCDStandard,
        ["Avenging Crusader"] =                 TCDStandard,
        ["Holy Avenger"] =                      TCDStandard,
        ["Crusade"] =                           TCDStandard
    } ,
    [ 5 ] = { --priest
        ["Archangel"] =                         TCDStandard,
        ["Dark Archangel"] =                    TCDStandard,
        ["Rapture"] =                           TCDStandard,
        ["Apotheosis"] =                        TCDStandard,
        --["Divinity"] = true,
        ["Voidform"] =                          TCDStandard,
        ["Surrender to Madness"] =              TCDStandard
    } ,
    [ 4 ] = { --rogue
        ["Shadow Blades"] =                     TCDStandard,
        ["Shadow Dance"] =                      TCDStandard,
        ["Shadowy Duel"] =                      TCDStandard,
        ["Adrenaline Rush"] =                   TCDStandard,
        ["Plunder Armor"] =                     TCDStandard
    } ,
    [ 7 ] = { --shaman
        ["Ascendance"] =                        TCDStandard,
        ["Ancestral Guidance"] =                TCDStandard,
        ["Stormkeeper"] =                       TCDStandard,
        ["Icefury"] =                           TCDStandard
    } ,
    [ 9 ] = { --lock
        ["Soul Harvest"] =                      TCDStandard,
        ["Dark Soul: Instability"] =            TCDStandard,
        ["Dark Soul: Misery"] =                 TCDStandard
    } ,
    [ 1 ] = { --warrior
        ["Battle Cry"] =                        TCDStandard,
        ["Avatar"] =                            TCDStandard,
        ["Bladestorm"] =                        TCDStandard,
        ["Bloodbath"] =                         TCDStandard

    },
    [ 12 ] = { --dh
        ["Metamorphosis"] =                     TCDStandard,
        ["Nemesis"] =                           TCDStandard,
        ["Furious Gaze"] =                      {["sbPrio"] = 3, ["sdPrio"] = nil, ["bdPrio"] = nil, ["tbPrio"] = 3}
    }
};

--External Throughput CDs show important CDs cast by anyone in a special set of throughput buff frames
    --Display Location:     throughtput frames
    --Aura Sources:         any
    --Aura Type:            buff
    --Standard Priority Level:
local ETCDStandard = {["sbPrio"] = 3, ["sdPrio"] = nil, ["bdPrio"] = nil, ["tbPrio"] = 3};
CustomBuffs.EXTERNAL_THROUGHPUT_CDS = {
    ["Dark Archangel"] =    ETCDStandard,
    ["Blood Fury"] =        ETCDStandard,
    ["Berserking"] =        ETCDStandard,

    --Other Stuff
    ["Earthen Wall"] =      {["sbPrio"] = 3, ["tbPrio"] = 1}
};


--Boss buffs display custom flagged buffs in the boss debuff frames
    --Display Location:     boss debuff frames
    --Aura Sources:         any
    --Aura Type:            buff
    --Standard Priority Level:
local BBStandard = {["sbPrio"] = 2, ["sdPrio"] = nil, ["bdPrio"] = 5, ["tbPrio"] = nil};
CustomBuffs.BOSS_BUFFS = { --Custom Buffs that should be displayed in the Boss Debuff slots
                        --Custom Buffs are lowest priority, and if they fall outside the
                        --number of available Boss Debuff slots, they  fall through to
                        --the normal buff slots

                        --Only tracks buffs cast by the player

    --["Earthen Wall"] =    BBStandard
};


--CCs display CC debuffs in the boss debuff frames
    --Display Location:     boss debuff frames
    --Aura Sources:         any
    --Aura Type:            debuff
    --Standard Priority Level: (priority is increased one level for debuffs that are currently dispellable)
local CCStandard =      {["sbPrio"] = nil, ["sdPrio"] = 3, ["bdPrio"] = 4, ["tbPrio"] = nil};
local MagicStandard =   {["dispelType"] = "magic", ["sdPrio"] = 3, ["bdPrio"] = 4};
local CurseStandard =   {["dispelType"] = "curse", ["sdPrio"] = 3, ["bdPrio"] = 4};
local DiseaseStandard = {["dispelType"] = "disease", ["sdPrio"] = 3, ["bdPrio"] = 4};
local PoisonStandard =  {["dispelType"] = "poison", ["sdPrio"] = 3, ["bdPrio"] = 4};
local MDStandard =      {["dispelType"] = "massDispel", ["sdPrio"] = 3, ["bdPrio"] = 4};
local PurgeStandard =   {["dispelType"] = "purge", ["sdPrio"] = 3, ["bdPrio"] = 4};
CustomBuffs.CC = {

    --------------------
    --   Dispelable   --
    --------------------

    ["Polymorph"] =             MagicStandard,
    ["Freezing Trap"] =         MagicStandard,
    ["Fear"] =                  MagicStandard,
    ["Howl of Terror"] =        MagicStandard,
    ["Mortal Coil"] =           MagicStandard,
    ["Psychic Scream"] =        MagicStandard,
    ["Psychic Horror"] =        MagicStandard,
    ["Seduction"] =             MagicStandard,
    ["Hammer of Justice"] =     MagicStandard,
    ["Chaos Nova"] =            MagicStandard,
    ["Static Charge"] =         MagicStandard,
    ["Mind Bomb"] =             MagicStandard,
    ["Silence"] =               MagicStandard,
    [65813] =                   MagicStandard, --UA Silence
    ["Sin and Punishment"] =    MagicStandard, --VT dispel fear
    ["Faerie Swarm"] =          MagicStandard,
    [117526] =                  MagicStandard, --Binding Shot CC
    --["Arcane Torrent"] = {["dispelType"] = "magic"},
    --["Earthfury"] = {["dispelType"] = "magic"},
    ["Repentance"] =            MagicStandard,
    ["Lightning Lasso"] =       MagicStandard,
    ["Blinding Light"] =        MagicStandard,
    ["Ring of Frost"] =         MagicStandard,
    ["Dragon's Breath"] =       MagicStandard,
    ["Polymorphed"] =           MagicStandard, --engineering grenade sheep
    ["Shadowfury"] =            MagicStandard,
    ["Imprison"] =              MagicStandard,
    ["Strangulate"] =           MagicStandard,

    --Roots
    ["Frost Nova"] =            MagicStandard,
    ["Entangling Roots"] =      MagicStandard,
    ["Mass Entanglement"] =     MagicStandard,
    ["Earthgrab"] =             MagicStandard,
    ["Ice Nova"] =              MagicStandard,
    ["Freeze"] =                MagicStandard,
    ["Glacial Spike"] =         MagicStandard,

    --poison/curse/disease/MD dispellable
    ["Hex"] =                   CurseStandard,
    ["Mind Control"] =          PurgeStandard,
    ["Wyvern Sting"] =          PoisonStandard,
    ["Spider Sting"] =          PoisonStandard,
    --[233022] = true, --Spider Sting Silence
    ["Cyclone"] =               MDStandard,

    --Not CC but track anyway
    ["Gladiator's Maledict"] =  MagicStandard,
    ["Touch of Karma"] =        MagicStandard, --Touch of karma debuff
    ["Obsidian Claw"] =         MagicStandard,

    --------------------
    -- Not Dispelable --
    --------------------


    ["Blind"] =                 CCStandard,
    ["Asphyxiate"] =            CCStandard,
    ["Bull Rush"] =             CCStandard,
    ["Intimidation"] =          CCStandard,
    ["Kidney Shot"] =           CCStandard,
    ["Maim"] =                  CCStandard,
    ["Enraged Maim"] =          CCStandard,
    ["Between the Eyes"] =      CCStandard,
    ["Mighty Bash"] =           CCStandard,
    ["Sap"] =                   CCStandard,
    ["Storm Bolt"] =            CCStandard,
    ["Cheap Shot"] =            CCStandard,
    ["Leg Sweep"] =             CCStandard,
    ["Intimidating Shout"] =    CCStandard,
    ["Quaking Palm"] =          CCStandard,
    ["Paralysis"] =             CCStandard,

    --Area Denials
    ["Solar Beam"] =            CCStandard,
    [212183] =                  CCStandard, --Smoke Bomb

    --["Vendetta"] =              {["dispelType"] = nil, ["sdPrio"] = 3, ["bdPrio"] = 4},
    --["Counterstrike Totem"] =   {["dispelType"] = nil, ["sdPrio"] = 3, ["bdPrio"] = 4} --Debuff when affected by counterstrike totem
};

------- Setup -------
--Helper function to determine if the dispel type of a debuff matches available dispels
local function canDispelDebuff(debuffInfo)
    if not debuffInfo or not debuffInfo.dispelType or not CustomBuffs.dispelValues[debuffInfo.dispelType] then return false; end
    return bit.band(CustomBuffs.dispelType,CustomBuffs.dispelValues[debuffInfo.dispelType]) ~= 0;
end

--sets a flag on every element of CustomBuffs.CC indicating whether it is currently dispellable
local function precalcCanDispel()
    for _, v in pairs(CustomBuffs.CC)  do
        v.canDispel = canDispelDebuff(v);
    end
end

--Helper function to manage responses to spec changes
function CustomBuffs:updatePlayerSpec()
    --Check if player can dispel magic (is a healing spec or priest)
    --Technically warlocks can sometimes dispel magic with an imp and demon hunters can dispel
    --magic with a pvp talent, but we ignore these cases
    if not CustomBuffs.playerClass then CustomBuffs.playerClass = select(2, UnitClass("player")); end

    --Make sure we can get spec; if not then try again in 5 seconds
    local spec = GetSpecialization();
    if spec then
        local role = select(5, GetSpecializationInfo(GetSpecialization()));
    else
        C_Timer.After(5, function()
            CustomBuffs:updatePlayerSpec();
        end);
        return;
    end

    --All other classes of dispel are class specific, but magic dispels are given by spec
    if (CustomBuffs.playerClass == "PRIEST" or role == "HEALER") then
        CustomBuffs.canDispelMagic = true;
    else
        CustomBuffs.canDispelMagic = false;
    end

    CustomBuffs.dispelType = 0;

    if (CustomBuffs.playerClass == "PRIEST" or CustomBuffs.playerClass == "SHAMAN" or CustomBuffs.playerClass == "DEMONHUNTER"
        or CustomBuffs.playerClass == "MAGE" or CustomBuffs.playerClass == "HUNTER" or CustomBuffs.playerClass == "WARLOCK") then
        CustomBuffs.dispelType = bit.bor(CustomBuffs.dispelType, CustomBuffs.dispelValues.purge);
    end

    --Calculate player's current dispel type

    if CustomBuffs.canDispelMagic then
        CustomBuffs.dispelType = bit.bor(CustomBuffs.dispelType, CustomBuffs.dispelValues.magic);
    end
    if CustomBuffs.canDispelCurse then
        CustomBuffs.dispelType = bit.bor(CustomBuffs.dispelType, CustomBuffs.dispelValues.curse);
    end
    if CustomBuffs.canDispelPoison then
        CustomBuffs.dispelType = bit.bor(CustomBuffs.dispelType, CustomBuffs.dispelValues.poison);
    end
    if CustomBuffs.canDispelDisease then
        CustomBuffs.dispelType = bit.bor(CustomBuffs.dispelType, CustomBuffs.dispelValues.disease);
    end
    if CustomBuffs.canMassDispel then
        CustomBuffs.dispelType = bit.bor(CustomBuffs.dispelType, CustomBuffs.dispelValues.massDispel);
    end

    precalcCanDispel();
end

--Check combat log events for interrupts
local function handleCLEU()

    local _, event, _,_,_,_,_, destGUID, _,_,_, spellID, spellName = CombatLogGetCurrentEventInfo()

    -- SPELL_INTERRUPT doesn't fire for some channeled spells; if the spell isn't a known interrupt we're done
    if (event ~= "SPELL_INTERRUPT" and event ~= "SPELL_CAST_SUCCESS") or (not CustomBuffs.INTERRUPTS[spellID] and not CustomBuffs.INTERRUPTS[spellName]) then return end

    --Maybe needed if combat log events are returning spellIDs of 0
    --if spellID == 0 then spellID = lookupIDByName[spellName] end

    --Find
    for i=1, #CompactRaidFrameContainer.units do
		local unit = CompactRaidFrameContainer.units[i];
        if destGUID == UnitGUID(unit) and (event ~= "SPELL_CAST_SUCCESS" or
            (UnitChannelInfo and select(7, UnitChannelInfo(unit)) == false))
        then
            local duration = (CustomBuffs.INTERRUPTS[spellID] or CustomBuffs.INTERRUPTS[spellName]).duration;
            --local _, class = UnitClass(unit)

            CustomBuffs.units[destGUID] = CustomBuffs.units[destGUID] or {};
            CustomBuffs.units[destGUID].expires = GetTime() + duration;
            CustomBuffs.units[destGUID].spellID = spellID;
            CustomBuffs.units[destGUID].duration = duration;
            CustomBuffs.units[destGUID].spellName = spellName;
            --self.units[destGUID].spellID = spell.parent and spell.parent or spellId

            -- Make sure we clear it after the duration
            C_Timer.After(duration, function()
                --CompactUnitFrame_UpdateAuras();
                CustomBuffs.units[destGUID] = nil;
            end);

            return

        end
    end
end
--Establish player class and set up class based logic

--Look up player class
CustomBuffs.playerClass = select(2, UnitClass("player"));
CustomBuffs.canMassDispel = (CustomBuffs.playerClass == "PRIEST");

if (CustomBuffs.playerClass == "PALADIN") or (CustomBuffs.playerClass == "MONK") then
    --Class can dispel poisons and diseases but not curses
    CustomBuffs.canDispelCurse = false;
    CustomBuffs.canDispelPoison = true;
    CustomBuffs.canDispelDisease = true;

elseif (CustomBuffs.playerClass == "MAGE") or (CustomBuffs.playerClass == "SHAMAN") then
    --Class can dispel curses but not poisons or diseases
    CustomBuffs.canDispelCurse = true;
    CustomBuffs.canDispelPoison = false;
    CustomBuffs.canDispelDisease = false;

elseif CustomBuffs.playerClass == "DRUID" then
    --Class can dispel poisons and curses but not disease
    CustomBuffs.canDispelCurse = true;
    CustomBuffs.canDispelPoison = true;
    CustomBuffs.canDispelDisease = false;

elseif CustomBuffs.playerClass == "PRIEST" then
    --Class can dispel diseases but not curses or poisons
    CustomBuffs.canDispelCurse = false;
    CustomBuffs.canDispelPoison = false;
    CustomBuffs.canDispelDisease = true;

else --[[(CustomBuffs.playerClass == "DEATHKNIGHT") or (CustomBuffs.playerClass == "HUNTER") or (CustomBuffs.playerClass == "ROGUE") or
    (CustomBuffs.playerClass == "DEMONHUNTER") or (CustomBuffs.playerClass == "WARRIOR") or (CustomBuffs.playerClass == "WARLOCK") then ]]

    --Either class was not recognized or class cannot dispel curse, poison or disease
    CustomBuffs.canDispelCurse = false;
    CustomBuffs.canDispelPoison = false;
    CustomBuffs.canDispelDisease = false;
end


--Use spec based information to set CustomBuffs.canDispelMagic
CustomBuffs:updatePlayerSpec();


--Set up flag to track whether there has been an aborted attempt to call
--CompactRaidFrameContainer_LayoutFrames in combat
if not CustomBuffs.layoutNeedsUpdate then
    CustomBuffs.layoutNeedsUpdate = false;
end

CustomBuffs.CustomBuffsFrame:SetScript("OnEvent",function(self, event, ...)
    --Check combat log events for interrupts
    if (event == "COMBAT_LOG_EVENT_UNFILTERED") then
        handleCLEU();

    --Update spec based logic when the player changes spec
    elseif (event == "PLAYER_SPECIALIZATION_CHANGED") then
        CustomBuffs:updatePlayerSpec();

    --Update the layout when the player leaves combat if needed
    elseif (event == "PLAYER_REGEN_ENABLED" and CustomBuffs.layoutNeedsUpdate) then
    oldUpdateLayout(CompactRaidFrameContainer);
    CustomBuffs.layoutNeedsUpdate = false;

    end
end);

--Register frame for events
CustomBuffs.CustomBuffsFrame:RegisterEvent("PLAYER_REGEN_ENABLED");
CustomBuffs.CustomBuffsFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED");
CustomBuffs.CustomBuffsFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED");



local function calcBuffSize(frame)
    if not frame then return 14; end
    return CustomBuffs.BUFF_SCALE_FACTOR * min(frame:GetHeight() / 36, frame:GetWidth() / 72);
end

-------------------------------
--    Aura Frame Managers    --
-------------------------------

local function setUpExtraDebuffFrames(frame)
    if not frame then return; end

    CompactUnitFrame_SetMaxDebuffs(frame, CustomBuffs.MAX_DEBUFFS);
    local s = calcBuffSize(frame);

    if not frame.debuffFrames[CustomBuffs.MAX_DEBUFFS] then
        for i = 4, CustomBuffs.MAX_DEBUFFS do
            local bf = CreateFrame("Button", frame:GetName().."Debuff"..i, frame, "CompactDebuffTemplate");
            bf.baseSize=22;
            bf:Hide();
        end
        frame.debuffsLoaded = true;
    end

    --Set the size of default debuffs
    for i = 1, 3 do
        frame.debuffFrames[i]:SetSize(s, s);
    end

    for i=4, CustomBuffs.MAX_DEBUFFS do
        local bf = frame.debuffFrames[i];

        bf:ClearAllPoints();
        if i > 3 and i < 7 then
            bf:SetPoint("BOTTOMRIGHT", frame.debuffFrames[i-3], "TOPRIGHT", 0, 0);
        elseif i > 6 and i < 10 then
            bf:SetPoint("TOPRIGHT", frame.debuffFrames[1], "TOPRIGHT", -(s * (i - 6) + 5), 0);
        elseif i > 9 then
            bf:SetPoint("BOTTOMRIGHT", frame.debuffFrames[i-3], "TOPRIGHT", 0, 0);
        else
            bf:SetPoint("TOPRIGHT", frame.debuffFrames[1], "TOPRIGHT", -(s * (i - 3)), 0);
        end
        frame.debuffFrames[i]:SetSize(s, s);
    end
end

local function setUpExtraBuffFrames(frame)
        if not frame then return; end

        CompactUnitFrame_SetMaxBuffs(frame, 6);
        local s = calcBuffSize(frame);

        if not frame.buffFrames[6] then
            for i = 4, 6 do
                local bf = CreateFrame("Button", frame:GetName().."Buff"..i, frame, "CompactBuffTemplate");
                bf.baseSize=22;
                bf:Hide();
            end
        end

        --Set the size of default buffs
        for i = 1, 3 do
            frame.buffFrames[i]:SetSize(s, s);
        end

        for i= 4, 6 do
            local bf = frame.buffFrames[i];

            bf:ClearAllPoints();
            if i > 3 then
                bf:SetPoint("BOTTOMRIGHT", frame.buffFrames[i-3], "TOPRIGHT", 0, 0);
            else
                bf:SetPoint("TOPRIGHT", frame.buffFrames[1], "TOPRIGHT", -(s * (i - 3)), 0);
            end
            frame.buffFrames[i]:SetSize(s, s);
        end
end

local function setUpThroughputFrames(frame)
    if not frame then return; end

    if not frame.throughputFrames then
        local bfone = CreateFrame("Button", frame:GetName().."ThroughputBuff1", frame, "CompactBuffTemplate");
        bfone.baseSize = 22;
        bfone:SetSize(frame:GetHeight() / 2, frame:GetHeight() / 2);

        local bftwo = CreateFrame("Button", frame:GetName().."ThroughputBuff2", frame, "CompactBuffTemplate");
        bftwo.baseSize = 22;
        bftwo:SetSize(frame:GetHeight() / 2, frame:GetHeight() / 2);

        frame.throughputFrames = {bfone,bftwo};
    end

    local buffs = frame.throughputFrames;
    local size = calcBuffSize(frame) * 1.2;

    buffs[1]:SetSize(size, size);
    buffs[2]:SetSize(size, size);

    buffs[1]:ClearAllPoints();
    buffs[2]:ClearAllPoints();

    buffs[1]:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1);
    buffs[2]:SetPoint("TOPRIGHT", buffs[1], "TOPLEFT", -1, 0);

    --[[
    buffs[1].ClearAllPoints = function() return; end
    buffs[2].ClearAllPoints = function() return; end
    buffs[1].SetPoint = function() return; end
    buffs[2].SetPoint = function() return; end
    buffs[1].SetSize = function() return; end
    buffs[2].SetSize = function() return; end
    --]]

    buffs[1]:Hide();
    buffs[2]:Hide();

    buffs[1]:SetFrameStrata("MEDIUM");
    buffs[2]:SetFrameStrata("MEDIUM");
end

local function updateBossDebuffs(frame)
    local debuffs = frame.bossDebuffs;
    local size = frame.buffFrames[1]:GetWidth() * 1.5;

    debuffs[1]:SetSize(size, size);
    debuffs[2]:SetSize(size, size);

    debuffs[1]:ClearAllPoints();
    debuffs[2]:ClearAllPoints();

    if debuffs[2]:IsShown() then
        debuffs[1]:SetPoint("TOPRIGHT",frame,"TOP",-1,-1);
    else
        debuffs[1]:SetPoint("TOP",frame,"TOP",0,-1);
    end

    debuffs[2]:SetPoint("LEFT",debuffs[1],"RIGHT",2,0);

    debuffs[1]:SetFrameStrata("MEDIUM");
    debuffs[2]:SetFrameStrata("MEDIUM");
end

local function setUpBossDebuffFrames(frame)
    if not frame then return; end

    if not frame.bossDebuffs then
        local bfone = CreateFrame("Button", frame:GetName().."BossDebuff1", frame, "CompactDebuffTemplate");
        bfone.baseSize = frame.buffFrames[1]:GetWidth() * 1.2;
        bfone.maxHeight= frame.buffFrames[1]:GetWidth() * 1.5;
        bfone:SetSize(frame:GetHeight() / 2, frame:GetHeight() / 2);

        local bftwo = CreateFrame("Button", frame:GetName().."BossDebuff2", frame, "CompactDebuffTemplate");
        bftwo.baseSize = frame.buffFrames[1]:GetWidth() * 1.2;
        bftwo.maxHeight = frame.buffFrames[1]:GetWidth() * 1.5;
        bftwo:SetSize(frame:GetHeight() / 2, frame:GetHeight() / 2);

        frame.bossDebuffs = {bfone,bftwo};

        bfone:Hide();
        bftwo:Hide();
    end

    updateBossDebuffs(frame);
end


--------------------------------
--    Update Aura Function    --
--------------------------------


--If debuffType is not specified in auraData then the aura is considered a buff
local function updateAura(auraFrame, index, auraData)
    local icon, count, expirationTime, duration, debuffType, spellID, isBuff = auraData[1], auraData[2], auraData[3], auraData[4], auraData[5], auraData[6], auraData[7];

    auraFrame.icon:SetTexture(icon);
    if ( count > 1 ) then
        local countText = count;
        if ( count >= 100 ) then
            countText = BUFF_STACKS_OVERFLOW;
        end

        auraFrame.count:Show();
        auraFrame.count:SetText(countText);
    else
        auraFrame.count:Hide();
    end

    --If the aura is a buff or debuff then set the ID of the frame and let
    --Blizzard handle the tooltip; if the aura is custom, handle the tooltip ourselves
    --Currently supported custom auras:
        --[-1]: Lockout tracker for an interrupt
    if index > 0 then
        --Standard Blizzard aura
        auraFrame:SetID(index);
        if auraFrame.int then
            auraFrame.int = nil;
        end

    elseif index == -1 then
        auraFrame.int = spellID;
        --if CUSTOM_BUFFS_TEST_ENABLED then
            --Aura is a lockout tracker for an interrupt; use tooltip for the
            --interrupt responsible for the lockout
            if not auraFrame.custTooltip then
                ----[[  We update scripts as required
                auraFrame.custTooltip = true;
                --Set an OnEnter handler to show the custom tooltip
                auraFrame:SetScript("OnEnter", function(self)
                    if self.int then
                        GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
                        GameTooltip:SetSpellByID(self.int);
                    else
                        GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
                        local id = self:GetID();
                        if id then
                            --[[
                            if self.filter and self.filter == "HELPFUL" then
                                GameTooltip:SetUnitBuff(frame, id);
                            else
                                GameTooltip:SetUnitDebuff(frame, id);
                            end
                            --]]
                            GameTooltip:SetUnitAura(self:GetParent().displayedUnit, id, self.filter);
                        end

                    end
                end);


                auraFrame:SetScript("OnUpdate", function(self)
                    if ( GameTooltip:IsOwned(self) ) then
                        if self.int then
                            GameTooltip:SetSpellByID(self.int);
                        else
                            local id = self:GetID();
                            if id then
                                --[[
                                if self.filter and self.filter == "HELPFUL" then
                                    GameTooltip:SetUnitBuff(frame, id);
                                else
                                    GameTooltip:SetUnitDebuff(frame, id);
                                end
                                --]]
                                GameTooltip:SetUnitAura(self:GetParent().displayedUnit, id, self.filter);
                            end

                        end
                    end
                end);

                --Set an OnExit handler to hide the custom tooltip
                auraFrame:SetScript("OnLeave", function(self)
                    if GameTooltip:IsOwned(self) then
                        GameTooltip:Hide();
                    end
                end);
            end
            --]]
            --[[
            C_Timer.After(duration + 1, function()
                auraFrame:SetScript("OnEnter", function(self)
                    GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT");
                    --GameTooltip:SetFrameLevel(self:GetFrameLevel() + 2);
                    GameTooltip:SetUnitAura(frame, self:GetID(), self.filter);
                end);
            end);
            --]]

        --end
    end

    if ( expirationTime and expirationTime ~= 0 ) then
        local startTime = expirationTime - duration;
        CooldownFrame_Set(auraFrame.cooldown, startTime, duration, true);
    else
        CooldownFrame_Clear(auraFrame.cooldown);
    end

    --If the aura is a debuff then we have some more work to do
    if auraFrame.border then
        --We know that the frame is a debuff frame but it might contain some form
        --of bossBuff which should be flagged as a buff instead of a debuff
        auraFrame.filter = (isBuff) and "HELPFUL" or "HARMFUL";
        auraFrame.isBossBuff = isBuff;

        --Either way we need to either color the debuff border or hide it
        local color = DebuffTypeColor[debuffType] or DebuffTypeColor["none"];
	    auraFrame.border:SetVertexColor(color.r, color.g, color.b);
    end

    auraFrame:Show();

end

-------------------------------
-- Main Aura Update function --
-------------------------------

hooksecurefunc("CompactUnitFrame_UpdateAuras", function(frame)
    if (not frame or frame:IsForbidden() or not frame:IsShown() or not frame:GetName():match("^Compact") or not frame.optionTable or not frame.optionTable.displayNonBossDebuffs) then return; end

    --Handle pre calculation logic
    if frame.optionTable.displayBuffs then frame.optionTable.displayBuffs = false; end                          --Tell buff frames to skip blizzard logic
    if frame.optionTable.displayDebuffs then frame.optionTable.displayDebuffs = false; end                      --Tell debuff frames to skip blizzard logic
    if frame.optionTable.displayDispelDebuffs then frame.optionTable.displayDispelDebuffs = false; end          --Prevent blizzard frames from showing dispel debuff frames
    if frame.optionTable.displayNameWhenSelected then frame.optionTable.displayNameWhenSelected = false; end    --Don't show names when the frame is selected to prevent bossDebuff overlap

    --if not frame.debuffsLoaded or not frame.bossDebuffs or not frame.throughputFrames then
        --FIXME: currently updating on every call because something in Blizzard code is
        --overriding our settings sometimes; figure out workaround so we don't have to update every call
        setUpExtraDebuffFrames(frame);
        setUpExtraBuffFrames(frame);
        setUpThroughputFrames(frame);
        setUpBossDebuffFrames(frame);
    --end

    --If our custom aura frames have not yet loaded do nothing
    if not frame.debuffsLoaded or not frame.bossDebuffs or not frame.throughputFrames then return; end

    --Update debuff display mode; allow 9 extra overflow debuff frames that grow out
    --of the left side of the unit frame when the player's group is less than 6 people.
    --Frames are disabled when the player's group grows past 5 players because most UI
    --configurations wrap to a new column after 5 players.
    if GetNumGroupMembers() <= 5 then
        CustomBuffs.MAX_DEBUFFS = 15;
        CustomBuffs.BUFF_SCALE_FACTOR = 10;

        if CustomBuffs.inRaidGroup then
            CustomBuffs.inRaidGroup = false;
            setUpExtraDebuffFrames(frame);
        end
    else
        CustomBuffs.MAX_DEBUFFS = 6;
        CustomBuffs.BUFF_SCALE_FACTOR = 10;

        if not CustomBuffs.inRaidGroup then
            CustomBuffs.inRaidGroup = true;
            setUpExtraDebuffFrames(frame);
        end
    end

    --We will sort the auras out into their preffered display locations
    local bossDebuffs, throughputBuffs, buffs, debuffs = {}, {}, {}, {};

    --Check for interrupts
    local guid = UnitGUID(frame.displayedUnit);
    if guid and CustomBuffs.units[guid] and CustomBuffs.units[guid].expires and CustomBuffs.units[guid].expires > GetTime() then
        --index of -1 for interrupts
        tinsert(bossDebuffs, { ["index"] = -1, ["bdPrio"] = 1, ["auraData"] = {
            --{icon, count, expirationTime, duration}
            GetSpellTexture(CustomBuffs.units[guid].spellID),
            1,
            CustomBuffs.units[guid].expires,
            CustomBuffs.units[guid].duration,
            nil,                                --Interrupts do not have a dispel type
            CustomBuffs.units[guid].spellID     --Interrupts need a special field containing the spellID of the interrupt used
                                                --in order to construct a mouseover tooltip for their aura frames
        }});

    end

    --Handle Debuffs
    for index = 1, 40 do
        local name, icon, count, debuffType, duration, expirationTime, unitCaster, _, _, spellID, canApplyAura, isBossAura = UnitDebuff(frame.displayedUnit, index);
        if name then
            if isBossAura then
                --[[ Debug
                if not debuffType then
                    print("potential bug for :", name, ":");
                end
                -- end debug ]]

                --Add to bossDebuffs
                tinsert(bossDebuffs, {
                    ["index"] = index,
                    ["bdPrio"] = 2,
                    ["sdPrio"] = 1,
                    ["auraData"] = {icon, count, expirationTime, duration, debuffType},
                    ["type"] = "debuff"
                });
            elseif (CustomBuffs.CC[name] or CustomBuffs.CC[spellID]) then
                --Add to bossDebuffs; adjust priority if dispellable
                local auraData = CustomBuffs.CC[name] or CustomBuffs.CC[spellID];
                local bdPrio, sdPrio = auraData.bdPrio, auraData.sdPrio;

                if auraData.canDispel then
                    bdPrio = bdPrio - 1;
                    sdPrio = sdPrio - 1;
                end

                tinsert(bossDebuffs, {
                    ["index"] = index,
                    ["bdPrio"] = bdPrio,
                    ["sdPrio"] = sdPrio,
                    ["auraData"] = {icon, count, expirationTime, duration, debuffType},
                    ["type"] = "debuff"
                });
            elseif CompactUnitFrame_Util_IsPriorityDebuff(name, icon, count, debuffType, duration, expirationTime, unitCaster, nil, nil, spellID) then
                --Add to debuffs
                tinsert(debuffs, {
                    ["index"] = index,
                    ["sdPrio"] = 4,
                    ["auraData"] = {icon, count, expirationTime, duration, debuffType},
                    ["type"] = "debuff"
                });
            elseif CompactUnitFrame_Util_ShouldDisplayDebuff(name, icon, count, debuffType, duration, expirationTime, unitCaster, nil, nil, spellID, canApplyAura, isBossAura) then
                --Add to debuffs
                tinsert(debuffs, {
                    ["index"] = index,
                    ["sdPrio"] = 5,
                    ["auraData"] = {icon, count, expirationTime, duration, debuffType},
                    ["type"] = "debuff"
                });
            end
        else
            break;
        end
    end

    --Update Buffs
    for index = 1, 40 do
        local name, icon, count, debuffType, duration, expirationTime, unitCaster, _, _, spellID, canApplyAura, isBossAura = UnitBuff(frame.displayedUnit, index);
        local _, _, displayedClass = UnitClass(frame.displayedUnit);
        if name then
            if isBossAura then
                --Debug
                --print("Found boss buff :", name, ":");
                --end debug

                --Add to bossDebuffs
                tinsert(bossDebuffs, {
                    ["index"] = index,
                    ["bdPrio"] = 2,
                    ["sbPrio"] = 1,
                    ["auraData"] = {icon, count, expirationTime, duration, nil, nil, true}
                });
            elseif CustomBuffs.THROUGHPUT_CDS[displayedClass] and (CustomBuffs.THROUGHPUT_CDS[displayedClass][name] or CustomBuffs.THROUGHPUT_CDS[displayedClass][spellID]) then
                --Add to throughputBuffs
                local auraData = CustomBuffs.THROUGHPUT_CDS[displayedClass][name] or CustomBuffs.THROUGHPUT_CDS[displayedClass][spellID];
                tinsert(throughputBuffs, {
                    ["index"] = index,
                    ["tbPrio"] = auraData.tbPrio;
                    ["sbPrio"] = auraData.sbPrio,
                    ["auraData"] = {icon, count, expirationTime, duration}
                });
            elseif CustomBuffs.EXTERNAL_THROUGHPUT_CDS[name] or CustomBuffs.EXTERNAL_THROUGHPUT_CDS[spellID] then
                --Add to throughputBuffs
                local auraData = CustomBuffs.EXTERNAL_THROUGHPUT_CDS[name] or CustomBuffs.EXTERNAL_THROUGHPUT_CDS[spellID];
                tinsert(throughputBuffs, {
                    ["index"] = index,
                    ["tbPrio"] = auraData.tbPrio;
                    ["sbPrio"] = auraData.sbPrio,
                    ["auraData"] = {icon, count, expirationTime, duration}
                });
            elseif (CustomBuffs.CDS[displayedClass] and (CustomBuffs.CDS[displayedClass][name] or CustomBuffs.CDS[displayedClass][spellID])) then
                --Add to buffs
                local auraData = CustomBuffs.CDS[displayedClass][name] or CustomBuffs.CDS[displayedClass][spellID];
                tinsert(buffs, {
                    ["index"] = index,
                    ["sbPrio"] = auraData.sbPrio,
                    ["auraData"] = {icon, count, expirationTime, duration}
                });
            elseif (CustomBuffs.EXTERNALS[name] or CustomBuffs.EXTERNALS[spellID]) and unitCaster ~= "player" and unitCaster ~= "pet" then
                --Add to buffs
                local auraData = CustomBuffs.EXTERNALS[name] or CustomBuffs.EXTERNALS[spellID];
                tinsert(buffs, {
                    ["index"] = index,
                    ["sbPrio"] = auraData.sbPrio,
                    ["auraData"] = {icon, count, expirationTime, duration}
                });
            elseif (CustomBuffs.EXTRA_RAID_BUFFS[name] or CustomBuffs.EXTRA_RAID_BUFFS[spellID]) and (unitCaster == "player" or unitCaster == "pet") then
                --Add to buffs
                local auraData = CustomBuffs.EXTRA_RAID_BUFFS[name] or CustomBuffs.EXTRA_RAID_BUFFS[spellID];
                tinsert(buffs, {
                    ["index"] = index,
                    ["sbPrio"] = auraData.sbPrio,
                    ["auraData"] = {icon, count, expirationTime, duration}
                });
            elseif CompactUnitFrame_UtilShouldDisplayBuff(name, icon, count, debuffType, duration, expirationTime, unitCaster, nil, nil, spellID, canApplyAura, isBossAura) then
                --Add to buffs
                tinsert(buffs, {
                    ["index"] = index,
                    ["sbPrio"] = 5,
                    ["auraData"] = {icon, count, expirationTime, duration}
                });
            end
        else
            break;
        end
    end


    --Assign auras to aura frames

    --Sort bossDebuffs in priority order
    table.sort(bossDebuffs, function(a,b)
        if not a or not b then return true; end
        return a.bdPrio < b.bdPrio;
    end);

    --If there are more bossDebuffs than frames, copy extra auras into appropriate fallthrough locations
    for i = 3, #bossDebuffs do
        --Buffs fall through to buffs, debuffs fall through to debuffs
        if bossDebuffs[i].type then
            tinsert(debuffs, bossDebuffs[i]);
        else
            --[[ debug stuff
            local name, _, _, _, _, _, _, _, _, _, _, _ = UnitBuff(frame.displayedUnit, bossDebuffs[i].index);
            local name2, _, _, _, _, _, _, _, _, _, _, _ = UnitDebuff(frame.displayedUnit, bossDebuffs[i].index);
            print("Boss buff ", name, " or ", name2, " falling through to buffs.");
            -- end debug stuff ]]

            tinsert(buffs, bossDebuffs[i]);
        end
    end

    --Sort throughputBuffs in priority order
    table.sort(throughputBuffs, function(a,b)
        if not a or not b then return true; end
        return a.tbPrio < b.tbPrio;
    end);

    --If there are more throughputBuffs than frames, copy extra auras into appropriate fallthrough locations
    for i = 3, #throughputBuffs do
        tinsert(buffs, throughputBuffs[i]);
    end

    --Sort debuffs in priority order
    table.sort(debuffs, function(a,b)
        if not a or not b then return true; end
        return a.sdPrio < b.sdPrio;
    end);

    --Sort buffs in priority order
    table.sort(buffs, function(a,b)
        if not a or not b then return true; end
        return a.sbPrio < b.sbPrio;
    end);

    --Update all aura frames

    --Boss Debuffs
    local frameNum = 1;
    while(frameNum <= 2 and bossDebuffs[frameNum]) do
        updateAura(frame.bossDebuffs[frameNum], bossDebuffs[frameNum].index, bossDebuffs[frameNum].auraData);
        frameNum = frameNum + 1;
    end

    --Throughput Frames
    frameNum = 1;
    while(frameNum <= 2 and throughputBuffs[frameNum]) do
        updateAura(frame.throughputFrames[frameNum], throughputBuffs[frameNum].index, throughputBuffs[frameNum].auraData);
        frameNum = frameNum + 1;
    end

    --Standard Debuffs
    frameNum = 1;
    while(frameNum <= frame.maxDebuffs and debuffs[frameNum]) do
        updateAura(frame.debuffFrames[frameNum], debuffs[frameNum].index, debuffs[frameNum].auraData);
        frameNum = frameNum + 1;
    end

    --Standard Buffs
    frameNum = 1;
    while(frameNum <= frame.maxBuffs and buffs[frameNum]) do
        updateAura(frame.buffFrames[frameNum], buffs[frameNum].index, buffs[frameNum].auraData);
        frameNum = frameNum + 1;
    end




    --Hide unused aura frames
    for i = #debuffs + 1, frame.maxDebuffs do
        local auraFrame = frame.debuffFrames[i];
        --if auraFrame ~= frame.bossDebuffs[1] and auraFrame ~= frame.bossDebuffs[2] then auraFrame:Hide(); end
        auraFrame:Hide();
    end

    for i = #bossDebuffs + 1, 2 do
        frame.bossDebuffs[i]:Hide();
    end

    for i = #buffs + 1, frame.maxBuffs do
        local auraFrame = frame.buffFrames[i];
        --if auraFrame ~= frame.throughputFrames[1] and auraFrame ~= frame.throughputFrames[2] then auraFrame:Hide(); end
        auraFrame:Hide();
    end

    for i = #throughputBuffs + 1, 2 do
        frame.throughputFrames[i]:Hide();
    end


    --Hide the name text for frames with active bossDebuffs
    if frame.bossDebuffs[1]:IsShown() then
        frame.name:Hide();
    else
        frame.name:Show();
    end

    --Boss debuff location is variable, so we need to update their location every update
    updateBossDebuffs(frame);

end);






--Clean Up Names
hooksecurefunc("CompactUnitFrame_UpdateName", function(frame)
    --if (frame and not frame:IsForbidden()) then
    if (not frame or frame:IsForbidden() or not frame:IsShown() or not frame:GetName():match("^Compact") or not frame.optionTable or not frame.optionTable.displayNonBossDebuffs) then return; end
        local name = "";
        if (frame.optionTable and frame.optionTable.displayName) then
            if frame.bossDebuffs and frame.bossDebuffs[1] and frame.bossDebuffs[1]:IsShown() then
                frame.name:Hide();
                return;
            end
            name = GetUnitName(frame.unit, false);
            if not name then return; end

            --FIXME: Currently doesn't handle special characters gracefully; consider updating logic
            --Limit the name to 9 characters and hide realm names
            local lastChar, _ = string.find(name, " ");
            if not lastChar or lastChar > 9 then lastChar = 9; end
            name = strsub(name,1,lastChar)
        end
        frame.name:SetText(name);
    --end
end);







--Debug Stuff
if CustomBuffs and not CustomBuffs.DeepCopy then
    CustomBuffs.DeepCopy = function(obj, seen)
      -- Handle non-tables and previously-seen tables.
      if type(obj) ~= 'table' then return obj end
      if seen and seen[obj] then return seen[obj] end

      -- New table; mark it as seen an copy recursively.
      local s = seen or {}
      local res = setmetatable({}, getmetatable(obj))
      s[obj] = res
      for k, v in pairs(obj) do res[CustomBuffs.DeepCopy(k, s)] = CustomBuffs.DeepCopy(v, s) end
      return res
    end
end

if CustomBuffs and not CustomBuffs.DebugPrintTable then
    CustomBuffs.DebugPrintTable = function(node)
        -- to make output beautiful
        local function tab(amt)
            local str = ""
            for i=1,amt do
                str = str .. "\t"
            end
            return str
        end

        local cache, stack, output = {},{},{}
        local depth = 1
        local output_str = "{\n"

        while true do
            local size = 0
            for k,v in pairs(node) do
                size = size + 1
            end

            local cur_index = 1
            for k,v in pairs(node) do
                if (cache[node] == nil) or (cur_index >= cache[node]) then

                    if (string.find(output_str,"}",output_str:len())) then
                        output_str = output_str .. ",\n"
                    elseif not (string.find(output_str,"\n",output_str:len())) then
                        output_str = output_str .. "\n"
                    end

                    -- This is necessary for working with HUGE tables otherwise we run out of memory using concat on huge strings
                    table.insert(output,output_str)
                    output_str = ""

                    local key
                    if (type(k) == "number" or type(k) == "boolean") then
                        key = "["..tostring(k).."]"
                    else
                        key = "['"..tostring(k).."']"
                    end

                    if (type(v) == "number" or type(v) == "boolean") then
                        output_str = output_str .. tab(depth) .. key .. " = "..tostring(v)
                    elseif (type(v) == "table") then
                        output_str = output_str .. tab(depth) .. key .. " = {\n"
                        table.insert(stack,node)
                        table.insert(stack,v)
                        cache[node] = cur_index+1
                        break
                    else
                        output_str = output_str .. tab(depth) .. key .. " = '"..tostring(v).."'"
                    end

                    if (cur_index == size) then
                        output_str = output_str .. "\n" .. tab(depth-1) .. "}"
                    else
                        output_str = output_str .. ","
                    end
                else
                    -- close the table
                    if (cur_index == size) then
                        output_str = output_str .. "\n" .. tab(depth-1) .. "}"
                    end
                end

                cur_index = cur_index + 1
            end

            if (size == 0) then
                output_str = output_str .. "\n" .. tab(depth-1) .. "}"
            end

            if (#stack > 0) then
                node = stack[#stack]
                stack[#stack] = nil
                depth = cache[node] == nil and depth + 1 or depth - 1
            else
                break
            end
        end

        -- This is necessary for working with HUGE tables otherwise we run out of memory using concat on huge strings
        table.insert(output,output_str)
        output_str = table.concat(output)

        return output_str
    end
end
