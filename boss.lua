local mod = EPGP:NewModule("EPGP_Boss", "AceEvent-3.0", "AceTimer-3.0")

local BOSSES = {
  -- The Obsidian Sanctum
  [28860] = "Sartharion",

  -- Eye of Eternity
  [28859] = "Malygos",

  -- Naxxramas
  [15956] = "Anub'Rekhan",
  [15953] = "Grand Widow Faerlina",
  [15952] = "Maexxna",

  [16028] = "Patchwerk",
  [15931] = "Grobbulus",
  [15932] = "Gluth",
  [15928] = "Thaddius",

  [16061] = "Instructor Razuvious",
  [16060] = "Gothik the Harvester",
  -- TODO(alkis): Add Four Horsemen

  [15954] = "Noth the Plaguebringer",
  [15936] = "Heigan the Unclean",
  [16011] = "Loatheb",

  [15989] = "Sapphiron",
  [15990] = "Kel'Thuzad",
}

function mod:OnEnable()
  self:RegisterEvent("RAID_ROSTER_UPDATE")
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
  if EPGP.db.profile.auto_boss and IsRLorML() then
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
      self:SendMessage("BossKilled", dest_name)
    end
  end
end

local in_combat = false
local award_queue = {}
local timer

local function IsRLorML()
  if UnitInRaid("player") then
    local loot_method, ml_party_id, ml_raid_id = GetLootMethod()
    if loot_method == "master" and ml_party_id == 0 then return true end
    if loot_method ~= "master" and IsRaidLeader() then return true end
  end
  return false
end

function mod:PopAwardQueue()
  if in_combat then return end

  if #award_queue == 0 then
    if timer then
      self:CancelTimer(timer, true)
      timer = nil
    end
    return
  end

  if StaticPopup_Visible("EPGP_BOSS_DEAD") then
    return
  end

  local boss_name = table.remove(award_queue, 1)
  local dialog = StaticPopup_Show("EPGP_BOSS_DEAD", boss_name)
  if dialog then
    dialog.reason = boss_name
  end
end

local function BossKilled(event_name, boss_name)
  if CanEditOfficerNote() then
    tinsert(award_queue, boss_name)
    if not timer then
      timer = mod:ScheduleRepeatingTimer("PopAwardQueue", 1)
    end
  end
end

function mod:PLAYER_REGEN_DISABLED()
  in_combat = true
end

function mod:PLAYER_REGEN_ENABLED()
  in_combat = false
end

function mod:Debug()
  BossKilled("BossKilled", "Sapphiron")
end

function mod:OnEnable()
  self:RegisterEvent("PLAYER_REGEN_DISABLED")
  self:RegisterEvent("PLAYER_REGEN_ENABLED")
  self:RegisterMessage("BossKilled", BossKilled)
end
