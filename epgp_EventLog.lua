local EPGP_EVENTLOG_TYPE_START = "start"
local EPGP_EVENTLOG_TYPE_BOSSKILL = "bosskill"
local EPGP_EVENTLOG_TYPE_LOOT = "loot"
local EPGP_EVENTLOG_TYPE_END = "end"

local EPGP_EVENTLOG_KEY_TYPE = "type"
local EPGP_EVENTLOG_KEY_HOURS = "hours"
local EPGP_EVENTLOG_KEY_MINUTES = "minutes"
local EPGP_EVENTLOG_KEY_ROSTER = "roster"
local EPGP_EVENTLOG_KEY_RECEIVER = "receiver"
local EPGP_EVENTLOG_KEY_COUNT = "count"
local EPGP_EVENTLOG_KEY_ITEM = "item"
local EPGP_EVENTLOG_KEY_ZONE = "zone"
local EPGP_EVENTLOG_KEY_BOSS = "boss"

function EPGP:EventLog_Add_START(event_log, zone, roster)
  local hours, minutes = GetGameTime()
  table.insert(event_log, {
    [EPGP_EVENTLOG_KEY_TYPE] = EPGP_EVENTLOG_TYPE_START,
    [EPGP_EVENTLOG_KEY_HOURS] = hours,
    [EPGP_EVENTLOG_KEY_MINUTES] = minutes,
    [EPGP_EVENTLOG_KEY_ZONE] = zone,
    [EPGP_EVENTLOG_KEY_ROSTER] = roster
  })
end

function EPGP:EventLog_Add_BOSSKILL(event_log, dead_boss, roster)
  local hours, minutes = GetGameTime()
  table.insert(event_log, {
    [EPGP_EVENTLOG_KEY_TYPE] = EPGP_EVENTLOG_TYPE_BOSSKILL,
    [EPGP_EVENTLOG_KEY_HOURS] = hours,
    [EPGP_EVENTLOG_KEY_MINUTES] = minutes,
    [EPGP_EVENTLOG_KEY_BOSS] = dead_boss,
    [EPGP_EVENTLOG_KEY_ROSTER] = roster
  })
end

function EPGP:EventLog_Parse_BOSSKILL(event)
  if (event[EPGP_EVENTLOG_KEY_TYPE] ~= EPGP_EVENTLOG_TYPE_BOSSKILL) then
    return nil, nil, nil, nil
  end
  return event[EPGP_EVENTLOG_KEY_HOURS],
         event[EPGP_EVENTLOG_KEY_MINUTES],
         event[EPGP_EVENTLOG_KEY_BOSS],
         event[EPGP_EVENTLOG_KEY_ROSTER]
end

function EPGP:EventLog_Add_LOOT(event_log, receiver, count, itemlink)
  local hours, minutes = GetGameTime()
  table.insert(event_log, {
    [EPGP_EVENTLOG_KEY_TYPE] = EPGP_EVENTLOG_TYPE_LOOT,
    [EPGP_EVENTLOG_KEY_HOURS] = hours,
    [EPGP_EVENTLOG_KEY_MINUTES] = minutes,
    [EPGP_EVENTLOG_KEY_RECEIVER] = receiver,
    [EPGP_EVENTLOG_KEY_COUNT] = count,
    [EPGP_EVENTLOG_KEY_ITEM] = itemlink
  })
end

function EPGP:EventLog_Add_END(event_log, roster)
  local hours, minutes = GetGameTime()
  table.insert(event_log, {
    [EPGP_EVENTLOG_KEY_TYPE] = EPGP_EVENTLOG_TYPE_END,
    [EPGP_EVENTLOG_KEY_HOURS] = hours,
    [EPGP_EVENTLOG_KEY_MINUTES] = minutes,
    [EPGP_EVENTLOG_KEY_ZONE] = zone,
    [EPGP_EVENTLOG_KEY_ROSTER] = roster
  })
end

function EPGP:EventLog_Has_END(event_log)
  local last_event = event_log[table.getn(event_log)]
  if (not last_event) then return false end
  return last_event[EPGP_EVENTLOG_KEY_TYPE] == EPGP_EVENTLOG_TYPE_END
end

-------------------------------------------------------------------------------
-- Event log manipulation
-------------------------------------------------------------------------------

-- Generates a new event_log if the last raid is closed or returns the last one
-- Returns the new raid_id
function EPGP:GetLastEventLog()
  local last_index = self:GetLastRaidId()
  local last_event_log = self:GetOrCreateEventLog(last_index)
  if (self:EventLog_Has_END(last_event_log)) then
    return self:GetOrCreateEventLog(last_index+1)
  end
  return last_event_log
end

-- Returns the last raid_id
function EPGP:GetLastRaidId()
  return math.max(1, table.getn(EPGP.db.profile.event_log))
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
  
  self:Debug("roster size: %d", table.getn(roster))
  if (table.getn(roster) == 0) then
    local player, _ = UnitName("player")
    table.insert(roster, player)
  end
  return roster
end
