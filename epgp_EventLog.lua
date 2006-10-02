-- Shrink events to just attendance, bosskill, loot. Mark start and end events
-- can be removed. They can be added to the event log as non-indexed key, value
-- pairs.

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
  local raid_L_or_A = false
  for i = 1, GetNumRaidMembers() do
    local name, rank, subgroup, level, class, fileName, zone, online = GetRaidRosterInfo(i)
    if (name == UnitName("player") and rank > 0) then
      raid_L_or_A = true
    end
  end
  
  if (self.raid_leader_or_officer == raid_L_or_A) then
    return
  else
    self.raid_leader_or_officer = raid_L_or_A
  end

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
                                5*60,
                                self,
                                self:GetOrCreateEventLog(self:GetLastRaidId()))
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

-- Compute a table of the current EPGP standings sorted on priority
-- The table is a table of tables of the form:
-- { name, ep_total, gp_total, priority }
-- The final table is sorted on priority
function EPGP:ComputeStandings()
  local standings = { }
  local name_indices = { }
  -- Call GuildRoster first to make sure the list is p to date
  GuildRoster()
  local num_guild_members = GetNumGuildMembers(true)
  for i = 1, num_guild_members do
    local name, _, _, _, _, _, _, _, _, _ = GetGuildRosterInfo(i)
    table.insert(standings, { name, 0, 1, nil })
    name_indices[name] = table.getn(standings)
  end

  -- Compute EPs and GPs
  first_raid_id = 1
  last_raid_id = EPGP:GetLastRaidId()
  first_raid_id = math.max(1, last_raid_id - self.db.profile.raid_window_size)
  for i = first_raid_id, last_raid_id do
    for k, v in EPGP:GetOrCreateEventLog(i) do
      local event_type = v[EPGP_EVENTLOG_KEY_TYPE]
      if (event_type == EPGP_EVENTLOG_TYPE_BOSSKILL) then
        local hours, minutes, boss, roster = EPGP:EventLogParse_BOSSKILL(v)
        table.foreach(roster, function(_, name)
            local name_index = name_indices[name]
            if (name_index) then
              standings[name_index][2] = standings[name_index][2] + self:GetBossEP(boss)
            end
          end
        )
      elseif (event_type == EPGP_EVENTLOG_TYPE_LOOT) then
        local hours, minutes, receiver, count, item = EPGP:EventLogParse_LOOT(v)
        local name_index = name_indices[receiver]
        if (name_index) then
          standings[name_index][3] = standings[name_index][3] + 1
        end
      end
    end
  end

  -- Compute priority
  table.foreach(standings, function(_, stats)
      stats[4] = stats[2] / stats[3]
    end
  )
  
  -- Sort on priority
  table.sort(standings, function(a, b) return a[4] > b[4] end)

  return standings
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
    [EPGP_EVENTLOG_KEY_TYPE] = EPGP_EVENTLOG_TYPE_ATTENDANCE,
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

function EPGP:EventLogParse_LOOT(event)
  if (event[EPGP_EVENTLOG_KEY_TYPE] ~= EPGP_EVENTLOG_TYPE_LOOT) then
    return nil, nil, nil, nil, nil
  end

  return event[EPGP_EVENTLOG_KEY_HOURS],
         event[EPGP_EVENTLOG_KEY_MINUTES],
         event[EPGP_EVENTLOG_KEY_RECEIVER],
         event[EPGP_EVENTLOG_KEY_COUNT],
         event[EPGP_EVENTLOG_KEY_ITEM]
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

