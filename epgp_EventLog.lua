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

local function EventToString(event)
  local str = ""
  if (type(event) == "table") then
    for k, v in pairs(event) do
      str = str .. string.format("%s=%s ", EventToString(k), EventToString(v))
    end
  elseif (type(event) == "string") then
    str = str .. event
  else
    str = str .. tostring(event)
  end
  return str
end

function EPGP:EventLog_Debug(event_log)
  if (not self:IsDebugging()) then return end

  self:Debug("-- Event log begin --")
  for i, e in pairs(event_log) do
    self:Debug(string.format("%d:", i) .. EventToString(e))
  end
  self:Debug("-- Event log end --")
end
