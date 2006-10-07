-- Shrink events to just attendance, bosskill, loot. Mark start and end events
-- can be removed. They can be added to the event log as non-indexed key, value
-- pairs.

local EPGP_EVENTLOG_TYPE_ATTENDANCE = "attendance"
local EPGP_EVENTLOG_TYPE_BOSSKILL = "bosskill"
local EPGP_EVENTLOG_TYPE_LOOT = "loot"

local EPGP_EVENTLOG_KEY_TYPE = "type"
local EPGP_EVENTLOG_KEY_HOURS = "hours"
local EPGP_EVENTLOG_KEY_MINUTES = "minutes"
local EPGP_EVENTLOG_KEY_ROSTER = "roster"
local EPGP_EVENTLOG_KEY_RECEIVER = "receiver"
local EPGP_EVENTLOG_KEY_COUNT = "count"
local EPGP_EVENTLOG_KEY_ITEM = "item"
local EPGP_EVENTLOG_KEY_ITEM_INFO = "item_info"
local EPGP_EVENTLOG_KEY_ZONE = "zone"
local EPGP_EVENTLOG_KEY_BOSS = "boss"

-- Reconfigures the addon depending on what mode it needs to run on
function EPGP:Reconfigure()
  -- Raid leader for now...
  local raid_promoted = false
  for i = 1, GetNumRaidMembers() do
    local name, rank, _, _, _, _, _, _ = GetRaidRosterInfo(i)
    if (name == UnitName("player") and rank > 1) then
      raid_promoted = true
    end
  end
  
  -- Avoid reconfiguration if our status didn't change
  if (self.track_raid == raid_promoted) then
    return
  else
    self.track_raid = raid_promoted
  end

  -- Make sure menu is up to date
  self:UpdateData()
end

function EPGP:StartTracking()
  -- Check loot
  self:RegisterEvent("CHAT_MSG_LOOT")
  -- Check for boss deaths
  self:RegisterEvent("CHAT_MSG_COMBAT_HOSTILE_DEATH")
  self:Print("Started tracking raid in %s", self:GetRaidZone(self:GetOrCreateEventLog(self:GetLastRaidId())))
end

function EPGP:StopTracking()
  if (self:IsEventRegistered("CHAT_MSG_LOOT")) then
    self:UnregisterEvent("CHAT_MSG_LOOT")
  end
  if (self:IsEventRegistered("CHAT_MSG_COMBAT_HOSTILE_DEATH")) then
    self:UnregisterEvent("CHAT_MSG_COMBAT_HOSTILE_DEATH")
  end
  self:Print("Stopped tracking raid in %s", self:GetRaidZone(self:GetOrCreateEventLog(self:GetLastRaidId())))
end

function EPGP:IsTracking()
  return self:IsEventRegistered("CHAT_MSG_LOOT") or
         self:IsEventRegistered("CHAT_MSG_COMBAT_HOSTILE_DEATH")
end

function EPGP:NewRaid()
  assert(self:CanTrackRaid())
  local raid_id = self:GetLastRaidId()
  local event_log = self:GetOrCreateEventLog(raid_id)
  self:Print("Starting new raid in %s", self.current_zone)
  self:SetRaidZone(event_log, self.current_zone)
  self:StartTracking()
end

-- Returns the last raid_id
function EPGP:GetLastRaidId()
  return math.max(1, table.getn(self.db.profile.event_log))
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

function EPGP:GetLastEventLog()
  return self:GetOrCreateEventLog(self:GetLastRaidId())
end

function EPGP:SetEventLog(raidid, event_log)
  self.db.profile.event_log[raidid] = event_log
end

-- Get the names of the people in the party, that are in the same zone as ourselves
-- Returns a table of the names
function EPGP:GetCurrentRoster()
  local roster = { }
  for i = 1, GetNumRaidMembers() do
    local name, _, _, _, _, _, zone, _, _ = GetRaidRosterInfo(i)
    if (zone == self.current_zone) then
      table.insert(roster, name)
      self:Debug("%s is in %s", name, zone)
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

-- Sets the zone of this raid
function EPGP:GetRaidZone(event_log)
  return event_log[EPGP_EVENTLOG_KEY_ZONE]
end

-- Sets the zone of this raid
function EPGP:SetRaidZone(event_log, zone)
  event_log[EPGP_EVENTLOG_KEY_ZONE] = zone
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

function EPGP:EventLogAdd_LOOT(event_log, receiver, count, itemlink, item_info)
  local hours, minutes = GetGameTime()
  table.insert(event_log, {
    [EPGP_EVENTLOG_KEY_TYPE] = EPGP_EVENTLOG_TYPE_LOOT,
    [EPGP_EVENTLOG_KEY_HOURS] = hours,
    [EPGP_EVENTLOG_KEY_MINUTES] = minutes,
    [EPGP_EVENTLOG_KEY_RECEIVER] = receiver,
    [EPGP_EVENTLOG_KEY_COUNT] = count,
    [EPGP_EVENTLOG_KEY_ITEM] = itemlink,
    [EPGP_EVENTLOG_KEY_ITEM_INFO] = item_info
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
         event[EPGP_EVENTLOG_KEY_ITEM],
         event[EPGP_EVENTLOG_KEY_ITEM_INFO]
end

-------------------------------------------------------------------------------
-- Compute report tablrs
-------------------------------------------------------------------------------

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
    for k, v in ipairs(EPGP:GetOrCreateEventLog(i)) do
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
        local hours, minutes, receiver, count, item, item_info = EPGP:EventLogParse_LOOT(v)
        self:Debug("%d:%d %s %dx%s", hours, minutes, receiver, count, item)
        local name_index = name_indices[receiver]
        if (name_index) then
          standings[name_index][3] = standings[name_index][3] + self:GetItemGP(item_info)
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
