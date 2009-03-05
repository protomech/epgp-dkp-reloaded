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

local mod = EPGP:NewModule("log")

local L = LibStub:GetLibrary("AceLocale-3.0"):GetLocale("EPGP")
local GS = LibStub("LibGuildStorage-1.0")

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
    -- Clear the redo table
    for k,_ in ipairs(EPGP.db.profile.redo) do
      EPGP.db.profile.redo[k] = nil
    end
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

function mod:CanUndo()
  if not CanEditOfficerNote() or not GS:IsCurrentState() then
    return false
  end
  return #EPGP.db.profile.log ~= 0
end

function mod:UndoLastAction()
  assert(#EPGP.db.profile.log ~= 0)

  local record = table.remove(EPGP.db.profile.log)
  table.insert(EPGP.db.profile.redo, record)

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

function mod:CanRedo()
  if not CanEditOfficerNote() or not GS:IsCurrentState() then
    return false
  end

  return #EPGP.db.profile.redo ~= 0
end

function mod:RedoLastUndo()
  assert(#EPGP.db.profile.redo ~= 0)

  local record = table.remove(EPGP.db.profile.redo)
  local timestamp, kind, name, reason, amount = unpack(record)

  local ep, gp, main = EPGP:GetEPGP(name)
  if kind == "EP" then
    EPGP:IncEPBy(name, L["Redo"].." "..reason, amount, false, true)
    table.insert(EPGP.db.profile.log, record)
  elseif kind == "GP" then
    EPGP:IncGPBy(name, L["Redo"].." "..reason, amount, false, true)
    table.insert(EPGP.db.profile.log, record)
  else
    assert(false, "Unknown record in the log")
  end

  callbacks:Fire("LogChanged", #EPGP.db.profile.log)
  return true
end

function mod:Snapshot()
  local t = EPGP.db.profile.snapshot
  if not t then
    t = {}
    EPGP.db.profile.snapshot = t
  end
  t.time = GetTimestamp()
  GS:Snapshot(t)
end

function mod:Rollback()
  assert(EPGP.db.profile.snapshot)
  local t = EPGP.db.profile.snapshot

  -- Restore all notes
  GS:Rollback(t)

  -- Trim the log if necessary.
  local timestamp = t.time
  while true do
    local records = #EPGP.db.profile.log
    if records == 0 then
      break
    end
    
    if EPGP.db.profile.log[records][1] > timestamp then
      table.remove(EPGP.db.profile.log)
    else
      break
    end
  end
  -- Add the redos back to the log if necessary.
  while #EPGP.db.profile.redo ~= 0 do
    local record = table.remove(EPGP.db.profile.redo)
    if record[1] < timestamp then
      table.insert(EPGP.db.profile.log, record)
    end
  end

  callbacks:Fire("LogChanged", #EPGP.db.profile.log)
end

function mod:HasSnapshot()
  return not not EPGP.db.profile.snapshot
end

function mod:GetSnapshotTimeString()
  assert(EPGP.db.profile.snapshot)
  return date("%Y-%m-%d %H:%M", EPGP.db.profile.snapshot.time)
end

function mod:OnEnable()
  EPGP.RegisterCallback(mod, "EPAward", AppendToLog, "EP")
  EPGP.RegisterCallback(mod, "GPAward", AppendToLog, "GP")

  -- Now we setup the auto-snapshot on db shutdown
  EPGP.db.RegisterCallback(self, "OnDatabaseShutdown", "Snapshot")
  -- Save the realm of this guild
  EPGP.db.realm = GetRealmName()
end
