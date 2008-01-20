local L = EPGPGlobalStrings
local deformat = AceLibrary("Deformat-2.0")
local BB = AceLibrary("Babble-Boss-2.2")

local mod = EPGP:NewModule("EPGP_Boss", "AceEvent-2.0")

local bosses = {}
local ignored_bosses = {
  [BB["Krosh Firehand"]] = true,
  [BB["Olm the Summoner"]] = true,
  [BB["Kiggler the Crazed"]] = true,
  [BB["Blindeye the Seer"]] = true,
  [BB["Thaladred the Darkener"]] = true,
  [BB["Master Engineer Telonicus"]] = true,
  [BB["General Drakkisath"]] = true,
  [BB["Grand Astromancer Capernian"]] = true,
  [BB["Lord Sanguinar"]] = true,
  [BB["Hellfire Channeler"]] = true,
  [BB["Baron Kazum"]] = true,
  [BB["Lord Skwol"]] = true,
  [BB["Lord Valthalak"]] = true,
  [BB["Warchief Rend Blackhand"]] = true,
  [BB["Pyroguard Emberseer"]] = true,
  [BB["Essence of Desire"]] = true,
  [BB["Essence of Suffering"]] = true,
  [BB["Eye of C'Thun"]] = true,
}

function mod:OnEnable()
  self:RegisterEvent("RAID_ROSTER_UPDATE")
  self:RegisterEvent("PLAYER_ENTERING_WORLD")
end

local monitoring = false
function mod:RAID_ROSTER_UPDATE()
  if UnitInRaid("player") and IsRaidLeader() and EPGP.db.profile.boss_tracking then
    if not monitoring then
      monitoring = true
      self:RegisterEvent("CHAT_MSG_COMBAT_HOSTILE_DEATH")
      self:RegisterEvent("PLAYER_TARGET_CHANGED")
      self:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
    end
  else
    if monitoring then
      monitoring = false
      self:UnregisterEvent("CHAT_MSG_COMBAT_HOSTILE_DEATH")
      self:UnregisterEvent("PLAYER_TARGET_CHANGED")
      self:UnregisterEvent("UPDATE_MOUSEOVER_UNIT")
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

function mod:CHAT_MSG_COMBAT_HOSTILE_DEATH(msg)
  local mob = deformat(msg, UNITDIESOTHER)
  if mob and bosses[mob] and not ignored_bosses[mob] then
    self:TriggerEvent("EPGP_BOSS_KILLED", mob)
  end
end

function mod:PLAYER_TARGET_CHANGED()
  local class = UnitClassification("target")
  if class and class == "worldboss" then
    bosses[UnitName("target")] = true
  end
end

function mod:UPDATE_MOUSEOVER_UNIT()
  local class = UnitClassification("mouseover")
  if class and class == "worldboss" then
    bosses[UnitName("mouseover")] = true
  end
end
