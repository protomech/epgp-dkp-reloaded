local EPGP_EVENTLOG_TYPE_START = "start"
local EPGP_EVENTLOG_TYPE_ATTENDANCE = "attendance"
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

-- Reconfigures the addon depending on what mode it needs to run on
function EPGP:Reconfigure()
  -- Update commandline options
  self:RegisterChatCommand({ "/epgp" },
    EPGP:BuildOptions()
  )
  -- Register for events if we need to track raid
  if (self:CanTrackRaid()) then
    -- Check loot
    self:RegisterEvent("CHAT_MSG_LOOT")
    -- Check for boss deaths
    self:RegisterEvent("CHAT_MSG_COMBAT_HOSTILE_DEATH")
    -- Check attendance every 5 minutes
    self:ScheduleRepeatingEvent(EPGP_EVENTLOG_TYPE_ATTENDANCE,
                                self.EventLogAdd_ATTENDANCE,
                                300,
                                self)
  else
    self:UnregisterEvent("CHAT_MSG_LOOT")
    self:UnegisterEvent("CHAT_MSG_COMBAT_HOSTILE_DEATH")
    self:CancelScheduledEvent(EPGP_EVENTLOG_TYPE_ATTENDANCE)
  end
end

-- Returns the last raid_id
function EPGP:GetLastRaidId()
  return math.max(1, table.getn(EPGP.db.profile.event_log))
end

-- Get the event_log for the specified raid_id or create a new one
-- if it doesn't exist
-- Returns the event_log
function EPGP:GetOrCreateEventLog(raid_id)
  local event_log = self.db.profile.event_log[raid_id]
  if (not event_log) then
    event_log = { }
    self.db.profile.event_log[raid_id] = event_log
  end
  return event_log
end

-- Marks the start of a new raid and starts the attendance event
-- Only Raid Leaders can access this function
function EPGP:StartNewRaid()
  assert(self:CanTrackRaid())
  local event_log = self:GetOrCreateEventLog(self:GetLastRaidId())
  if (not self:EventLogHas_START(event_log)) then
    self:Print("You cannot start a new raid while being in a raid already.")
  else
    self:EventLogAdd_START(event_log)
  end
end

-- Marks the end of this raid and stops all event handlers
-- Only Raid Leaders can access this function
function EPGP:EndRaid()
  assert(self:CanTrackRaid())
  local event_log = self:GetOrCreateEventLog(self:GetLastRaidId())
  if (self:EventLogHas_END(event_log)) then
    self:Print("You cannot end an already finsihed raid.")
  else
    self:EventLogAdd_END(event_log)
  end
end

-- Generates a new event_log if the last raid is closed or returns the last one
-- Returns the new raid_id
function EPGP:GetLastEventLog()
  local last_index = self:GetLastRaidId()
  local last_event_log = self:GetOrCreateEventLog(last_index)
  if (self:EventLogHas_END(last_event_log)) then
    return self:GetOrCreateEventLog(last_index+1)
  end
  return last_event_log
end

-- Get the names of the people in the party, that are in the same zone as ourselves
-- Returns a table of the names
function EPGP:GetCurrentRoster()
  local roster = { }
  for i = 1, GetNumRaidMembers() do
    local name, rank, subgroup, level, class, fileName, zone, online = GetRaidRosterInfo(i)
    if (zone == current_zone) then
      table.insert(roster, name)
    end
  end
  
  if (table.getn(roster) == 0) then
    local player, _ = UnitName("player")
    table.insert(roster, player)
  end
  return roster
end

-------------------------------------------------------------------------------
-- Event log manipulation functions
-------------------------------------------------------------------------------

function EPGP:EventLogAdd_START(event_log)
  local hours, minutes = GetGameTime()
  table.insert(event_log, {
    [EPGP_EVENTLOG_KEY_TYPE] = EPGP_EVENTLOG_TYPE_START,
    [EPGP_EVENTLOG_KEY_HOURS] = hours,
    [EPGP_EVENTLOG_KEY_MINUTES] = minutes,
    [EPGP_EVENTLOG_KEY_ZONE] = self.current_zone,
    [EPGP_EVENTLOG_KEY_ROSTER] = self:GetCurrentRoster()
  })
end

function EPGP:EventLogHas_START(event_log)
  local first_event = event_log[1]
  if (not first_event) then return false end
  return first_event[EPGP_EVENTLOG_KEY_TYPE] == EPGP_EVENTLOG_TYPE_START
end

function EPGP:EventLogAdd_ATTENDANCE(event_log)
  local hours, minutes = GetGameTime()
  table.insert(event_log, {
    [EPGP_EVENTLOG_KEY_TYPE] = EPGP_EVENTLOG_TYPE_START,
    [EPGP_EVENTLOG_KEY_HOURS] = hours,
    [EPGP_EVENTLOG_KEY_MINUTES] = minutes,
    [EPGP_EVENTLOG_KEY_ROSTER] = self:GetCurrentRoster()
  })
end

function EPGP:EventLogAdd_BOSSKILL(event_log, dead_boss)
  local hours, minutes = GetGameTime()
  table.insert(event_log, {
    [EPGP_EVENTLOG_KEY_TYPE] = EPGP_EVENTLOG_TYPE_BOSSKILL,
    [EPGP_EVENTLOG_KEY_HOURS] = hours,
    [EPGP_EVENTLOG_KEY_MINUTES] = minutes,
    [EPGP_EVENTLOG_KEY_BOSS] = dead_boss,
    [EPGP_EVENTLOG_KEY_ROSTER] = self:GetCurrentRoster()
  })
end

function EPGP:EventLogParse_BOSSKILL(event)
  if (event[EPGP_EVENTLOG_KEY_TYPE] ~= EPGP_EVENTLOG_TYPE_BOSSKILL) then
    return nil, nil, nil, nil
  end
  return event[EPGP_EVENTLOG_KEY_HOURS],
         event[EPGP_EVENTLOG_KEY_MINUTES],
         event[EPGP_EVENTLOG_KEY_BOSS],
         event[EPGP_EVENTLOG_KEY_ROSTER]
end

function EPGP:EventLogAdd_LOOT(event_log, receiver, count, itemlink)
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

function EPGP:EventLogAdd_END(event_log)
  local hours, minutes = GetGameTime()
  table.insert(event_log, {
    [EPGP_EVENTLOG_KEY_TYPE] = EPGP_EVENTLOG_TYPE_END,
    [EPGP_EVENTLOG_KEY_HOURS] = hours,
    [EPGP_EVENTLOG_KEY_MINUTES] = minutes,
    [EPGP_EVENTLOG_KEY_ZONE] = zone,
    [EPGP_EVENTLOG_KEY_ROSTER] = self:GetCurrentRoster()
  })
end

function EPGP:EventLogHas_END(event_log)
  local last_event = event_log[table.getn(event_log)]
  if (not last_event) then return false end
  return last_event[EPGP_EVENTLOG_KEY_TYPE] == EPGP_EVENTLOG_TYPE_END
end

