EPGP = AceLibrary("AceAddon-2.0"):new("AceConsole-2.0", "AceDB-2.0", "AceDebug-2.0", "AceEvent-2.0")

EPGP:RegisterDB("EPGP_DB")

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
  self:RegisterEvent("RAID_ROSTER_UPDATE")
  self:RegisterEvent("PARTY_MEMBERS_CHANGED")
  self:RegisterEvent("CHAT_MSG_COMBAT_HOSTILE_DEATH")
end

function EPGP:OnDisable()

end

-------------------------------------------------------------------------------
-- Slash commands
-------------------------------------------------------------------------------
EPGP:RegisterChatCommand({ "/epgp" }, {
  type = "group",
  args = {
    dbg_el = {
      name = "dbg_el",
      type = "execute",
      desc = "Mark raid start",
      func = function () EPGP:EventLog_Debug(EPGP:GetOrCreateEventLog()) end
    }
  }
})

-------------------------------------------------------------------------------
-- Event log manipulation
-------------------------------------------------------------------------------

-- Generates a new event_log if the last raid is closed or returns the last one
-- Returns the new raid_id
function EPGP:GetOrCreateEventLog()
  local last_index = table.getn(self.db.profile.event_log)
  local last_event_log = self:GetEventLog(last_index)
  if (EPGP:EventLog_Has_END(last_event_log)) then
    return self:GetEventLog(last_index+1)
  end
  return last_event_log
end

-- Get the event_log for the specified raid_id
-- Returns the event_log
function EPGP:GetEventLog(raid_id)
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
    if (zone == self.db.profile.current_zone) then
      table.insert(roster, name)
    end
  end
  if (table.getn(roster) == 0) then table.insert(UnitName("player")) end
  return roster
end

-------------------------------------------------------------------------------
-- Event Handlers for tracking interesting events
-------------------------------------------------------------------------------
function EPGP:ZONE_CHANGED_NEW_AREA()
  self.db.profile.current_zone = GetRealZoneText()
  if (self.db.profile.zones[self.db.profile.current_zone]) then
    self:Debug(string.format("Tracked zone: [%s]", self.db.profile.current_zone))
  else
    self:Debug(string.format("Not tracked zone: [%s]", self.db.profile.current_zone))
  end
end

function EPGP:CHAT_MSG_LOOT(msg)
  local receiver, count, itemlink = EPGP_ParseLootMsg(msg)
  self:Debug(string.format("Player: [%s] Count: [%d] Loot: [%s]",
             receiver, count, itemlink))
  self:EventLog_Add_LOOT(self:GetOrCreateEventLog(), receiver, count, itemlink)
end

function EPGP:RAID_ROSTER_UPDATE()
  -- Need to figure out who entered/left in order to send event
  self:Debug("Raid roster changed")
end

function EPGP:PARTY_MEMBERS_CHANGED()
  self:Debug("Party members changed")
end

function EPGP:CHAT_MSG_COMBAT_HOSTILE_DEATH(msg)
  -- Message can be of two forms:
  --   1. "Greater Duskbat dies."
  --   2. "You have slain Greater Duskbat."
  -- We only care about the first since we always get it. The second one we
  -- get it in addition to the first if we did the killing blow.

  local dead_mob = EPGP_ParseHostileDeath(msg)
  if (not dead_mob) then return end
  
  local mob_value = self.db.profile.bosses[dead_mob]
  if (self:IsDebugging()) then mob_value = 1 end
  if (mob_value) then
    self:Debug(string.format("Boss kill: %s value: %d", dead_mob, mob_value))
    self:EventLog_Add_BOSSKILL(self:GetOrCreateEventLog(), dead_mob)
  else
    self:Debug(string.format("Trash kill: %s", dead_mob))
  end
end

function EPGP:CHAT_MSG_ADDON(prefix, msg, type, sender)
  -- This is where sync should happen
  self:Debug(string.format("Prefix: [%s] Msg: [%s] Type: [%s] Sender: [%s]",
                           prefix, msg, type, sender))
end
