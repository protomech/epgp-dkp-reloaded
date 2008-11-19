--
-- GetNumRecords(): Returns the number of log records.
--
-- GetLogRecord(i): Returns the ith log record starting 0.
--
-- ExportLog(): Returns a string with the data of the exported log for
-- import into the web application.
--
-- UndoLastAction(): Removes the last entry from the log and undoes
-- its action. The undone action is not logged.
--
-- This module also fires the following messages.
--
-- LogChanged(n): Fired when the log is changed. n is the new size of
-- the log.
--

local mod = EPGP:NewModule("EPGP_Log")

local L = LibStub:GetLibrary("AceLocale-3.0"):GetLocale("EPGP")

local CallbackHandler = LibStub("CallbackHandler-1.0")
if not mod.callbacks then
  mod.callbacks = CallbackHandler:New(mod)
end
local callbacks = mod.callbacks

local timestamp_t = {}
local function GetTimestamp()
  timestamp_t.month = select(2, CalendarGetDate())
  timestamp_t.day = select(3, CalendarGetDate())
  timestamp_t.year = select(4, CalendarGetDate())
  timestamp_t.hour = select(1, GetGameTime())
  timestamp_t.min = select(2, GetGameTime())
  return time(timestamp_t)
end

local function AppendToLog(kind, event_type, name, reason, amount, mass, undo)
  if not undo then
    table.insert(EPGP.db.profile.log,
                 {GetTimestamp(), kind, name, reason, amount})
    callbacks:Fire("LogChanged", #EPGP.db.profile.log)
  end
end

local function LogRecordToString(record)
  local timestamp, kind, name, reason, amount = unpack(record)

  if kind == "EP" then
    return string.format(L["%s: %+d EP (%s) to %s"],
                         date("%Y-%m-%d %H:%M", timestamp), amount, reason, name)
  elseif kind == "GP" then
    return string.format(L["%s: %+d GP (%s) to %s"],
                         date("%Y-%m-%d %H:%M", timestamp), amount, reason, name)
  else
    assert(false, "Unknown record in the log")
  end
end

function mod:GetNumRecords()
  return #EPGP.db.profile.log
end

function mod:GetLogRecord(i)
  local logsize = #EPGP.db.profile.log
  assert(i >= 0 and i < #EPGP.db.profile.log, "Index "..i.." is out of bounds")

  return LogRecordToString(EPGP.db.profile.log[logsize - i])
end

function mod:UndoLastAction()
  if #EPGP.db.profile.log == 0 then
    return false
  end

  local record = table.remove(EPGP.db.profile.log)
  local timestamp, kind, name, reason, amount = unpack(record)

  local ep, gp, main = EPGP:GetEPGP(name)

  if kind == "EP" then
    EPGP:IncEPBy(name, L["Undo"].." "..reason, -amount, false, true)
  elseif kind == "GP" then
    EPGP:IncGPBy(name, L["Undo"].." "..reason, -amount, false, true)
  else
    assert(false, "Unknown record in the log")
  end

  callbacks:Fire("LogChanged", #EPGP.db.profile.log)
  return true
end

function mod:OnEnable()
  EPGP.RegisterCallback(mod, "EPAward", AppendToLog, "EP")
  EPGP.RegisterCallback(mod, "GPAward", AppendToLog, "GP")
end
