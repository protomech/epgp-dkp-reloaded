EPGP = AceLibrary("AceAddon-2.0"):new("AceConsole-2.0", "AceDB-2.0", "AceDebug-2.0", "AceEvent-2.0")

EPGP:RegisterDB("EPGP_DB")

CURRENT_ZONE = nil

function EPGP:OnInitialize()
  self:SetDebugging(true)
  local guild_name, guild_rank_name, guild_rank_index = GetGuildInfo("player")
  if (not guild_name) then guild_name = "EPGP_testing_guild" end
  self:SetProfile(guild_name)
end

function EPGP:OnEnable()
  self:Print("EPGP addon is enabled")
  self:RegisterEvent("ZONE_CHANGED_NEW_AREA")
  self:RegisterEvent("CHAT_MSG_LOOT")
  self:RegisterEvent("CHAT_MSG_COMBAT_HOSTILE_DEATH")
end

function EPGP:OnDisable()

end

-------------------------------------------------------------------------------
-- Event log manipulation
-------------------------------------------------------------------------------

-- Generates a new event_log if the last raid is closed or returns the last one
-- Returns the new raid_id
function EPGP:GetLastEventLog()
  local last_index = self:GetLastRaidId()
  local last_event_log = self:GetOrCreateEventLog(last_index)
  if (EPGP:EventLog_Has_END(last_event_log)) then
    return self:GetOrCreateEventLog(last_index+1)
  end
  return last_event_log
end

-- Returns the last raid_id
function EPGP:GetLastRaidId()
  return math.max(1, table.getn(self.db.profile.event_log))
end

-- Get the event_log for the specified raid_id
-- Returns the event_log
function EPGP:GetOrCreateEventLog(raid_id)
  local event_log = self.db.profile.event_log[raid_id]
  if (not event_log) then
    event_log = { }
    self.db.profile.event_log[raid_id] = event_log
  end
  return event_log
end

-- Get the names of the people in the party, that are in the same zone as ourselves
-- Returns a table of the names
function EPGP:GetCurrentRoster()
  local roster = { }
  for i = 1, GetNumRaidMembers() do
    local name, rank, subgroup, level, class, fileName, zone, online = GetRaidRosterInfo(i)
    if (zone == CURRENT_ZONE) then
      table.insert(roster, name)
    end
  end
  
  EPGP:Debug("roster size: %d", table.getn(roster))
  if (table.getn(roster) == 0) then
    local player, _ = UnitName("player")
    table.insert(roster, player)
  end
  return roster
end

-------------------------------------------------------------------------------
-- Event Handlers for tracking interesting events
-------------------------------------------------------------------------------
function EPGP:ZONE_CHANGED_NEW_AREA()
  CURRENT_ZONE = GetRealZoneText()
  if (self.db.profile.zones[CURRENT_ZONE]) then
    self:Debug("Tracked zone: [%s]", CURRENT_ZONE)
  else
    self:Debug("Not tracked zone: [%s]", CURRENT_ZONE)
  end
end

function EPGP:CHAT_MSG_LOOT(msg)
  local receiver, count, itemlink = EPGP_ParseLootMsg(msg)
  self:Debug("Player: [%s] Count: [%d] Loot: [%s]", receiver, count, itemlink)
  self:EventLog_Add_LOOT(self:GetOrLastEventLog(), receiver, count, itemlink)
end

function EPGP:CHAT_MSG_COMBAT_HOSTILE_DEATH(msg)
  -- Message can be of two forms:
  --   1. "Greater Duskbat dies."
  --   2. "You have slain Greater Duskbat."
  -- We only care about the first since we always get it. The second one we
  -- get it in addition to the first if we did the killing blow.

  local dead_mob = EPGP_ParseHostileDeath(msg)
  if (not dead_mob) then return end
  
  local mob_value = self:GetBossEP(dead_mob)
  if (mob_value) then
    self:Debug("Boss kill: %s value: %d", dead_mob, mob_value)
    self:EventLog_Add_BOSSKILL(
      self:GetLastEventLog(), dead_mob, self:GetCurrentRoster())
  else
    self:Debug(string.format("Trash kill: %s", dead_mob))
  end
end

function EPGP:CHAT_MSG_ADDON(prefix, msg, type, sender)
  -- This is where sync should happen
  self:Debug("Prefix: [%s] Msg: [%s] Type: [%s] Sender: [%s]",
             prefix, msg, type, sender)
end
