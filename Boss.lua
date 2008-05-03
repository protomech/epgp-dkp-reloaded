local L = EPGPGlobalStrings
local deformat = AceLibrary("Deformat-2.0")
local BB = AceLibrary("Babble-Boss-2.2")

local mod = EPGP:NewModule("EPGP_Boss", "AceEvent-2.0")

local BOSSES = {
  -- The Black Temple
  [22887] = BB["High Warlord Naj'entus"],
  [22898] = BB["Supremus"],
  [22841] = BB["Shade of Akama"],
  [22871] = BB["Teron Gorefiend"],
  [22948] = BB["Gurtogg Bloodboil"],
  [23420] = BB["Reliquary of Souls"],
  [22947] = BB["Mother Shahraz"],
  [23426] = BB["Illidari Council"],
  [22917] = BB["Illidan Stormrage"],

  -- Sunwell Plateau
  [24892] = BB["Sathrovarr the Corruptor"],
  [24882] = BB["Brutallus"],
  [25038] = BB["Felmyst"],
  -- TODO(alkis): Add all bosses

  -- The Eye
  [19516] = BB["Void Reaver"],
  [19514] = BB["Al'ar"],
  [18805] = BB["High Astromancer Solarian"],
  [19622] = BB["Kael'thas Sunstrider"],

  -- Serpentshrine Cavern
  [21216] = BB["Hydross the Unstable"],
  [21217] = BB["The Lurker Below"],
  [21215] = BB["Leotheras the Blind"],
  [21214] = BB["Fathom-Lord Karathress"],
  [21213] = BB["Morogrim Tidewalker"],
  [21212] = BB["Lady Vashj"],

  -- Hyjal Summit
  [17767] = BB["Rage Winterchill"],
  [17767] = BB["Anetheron"],
  [17888] = BB["Kaz'rogal"],
  [17842] = BB["Azgalor"],
  [17968] = BB["Archimonde"],

  -- Gruul's Lair
  [18831] = BB["High King Maulgar"],
  [19044] = BB["Gruul the Dragonkiller"],

  -- Magtheridon's Lair
  [17257] = BB["Magtheridon"],

  -- Karazhan
  [16181] = BB["Rokad the Ravager"],
  [16180] = BB["Shadikith the Glider"],
  [16179] = BB["Hyakiss the Lurker"],
  [16152] = BB["Attumen the Huntsman"],
  [15687] = BB["Moroes"],
  [16457] = BB["Maiden of Virtue"],
  [18168] = BB["The Crone"],
  [17521] = BB["The Big Bad Wolf"],
  [17533] = BB["Romulo & Julianne"],
  [17534] = BB["Romulo & Julianne"],
  [15691] = BB["The Curator"],
  [15688] = BB["Terestian Illhoof"],
  [16524] = BB["Shade of Aran"],
  [15689] = BB["Netherspite"],
  [17225] = BB["Nightbane"],
  [15690] = BB["Prince Malchezaar"],

  -- Zul'Aman
  [23574] = BB["Akil'zon"],
  [23576] = BB["Nalorakk"],
  [23578] = BB["Jan'alai"],
  [24239] = BB["Hex Lord Malacrass"],
  [23863] = BB["Zul'jin"],

  [21816] = "Ironspine Chomper - LOL",
}

function mod:OnEnable()
  self:RegisterEvent("RAID_ROSTER_UPDATE")
  self:RegisterEvent("PLAYER_ENTERING_WORLD")
end

local function IsRLorML()
  if UnitInRaid("player") then
    local loot_method, ml_party_id, ml_raid_id = GetLootMethod()
    if loot_method == "master" and ml_party_id == 0 then return true end
    if loot_method ~= "master" and IsRaidLeader() then return true end
  end
  return false
end

local monitoring = false
function mod:RAID_ROSTER_UPDATE()
  if IsRLorML() and EPGP.db.profile.boss_tracking then
    if not monitoring then
      monitoring = true
      self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    end
  else
    if monitoring then
      monitoring = false
      self:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    end
  end
end

local function TriggerInstanceEvent()
  local in_instance, instance_type = IsInInstance()
  if in_instance and instance_type == "raid" then
    mod:TriggerEvent("EPGP_ENTER_INSTANCE", GetRealZoneText())
  end
end

function mod:PLAYER_ENTERING_WORLD()
  local in_instance, instance_type = IsInInstance()
  if in_instance and instance_type == "raid" then
    self:ScheduleEvent(TriggerInstanceEvent, 3)
  end
end

function mod:COMBAT_LOG_EVENT_UNFILTERED(timestamp, event,
                                         source, source_name, source_flags,
                                         dest, dest_name, dest_flags,
                                         ...)
  -- bitlib does not support 64 bit integers so we are going to do some
  -- string hacking to get what we want. For an NPC:
  --   guid & 0x00F0000000000000 == 3
  -- and the NPC id is:
  --   (guid & 0x0000FFFFFF000000) >> 24
  if event == "UNIT_DIED" and dest:sub(5, 5) == "3" then
    local npc_id = tonumber(string.sub(dest, -12, -7), 16)
    if BOSSES[npc_id] then
      self:TriggerEvent("EPGP_BOSS_KILLED", BOSSES[npc_id])
    end
  end
end
