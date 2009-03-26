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
local JSON = LibStub("LibJSON-1.0")

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
    for k,_ in ipairs(mod.db.profile.redo) do
      mod.db.profile.redo[k] = nil
    end
    table.insert(mod.db.profile.log,
                 {GetTimestamp(), kind, name, reason, amount})
    callbacks:Fire("LogChanged", #mod.db.profile.log)
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
  return #self.db.profile.log
end

function mod:GetLogRecord(i)
  local logsize = #self.db.profile.log
  assert(i >= 0 and i < #self.db.profile.log, "Index "..i.." is out of bounds")

  return LogRecordToString(self.db.profile.log[logsize - i])
end

function mod:CanUndo()
  if not CanEditOfficerNote() or not GS:IsCurrentState() then
    return false
  end
  return #self.db.profile.log ~= 0
end

function mod:UndoLastAction()
  assert(#self.db.profile.log ~= 0)

  local record = table.remove(self.db.profile.log)
  table.insert(self.db.profile.redo, record)

  local timestamp, kind, name, reason, amount = unpack(record)

  local ep, gp, main = EPGP:GetEPGP(name)

  if kind == "EP" then
    EPGP:IncEPBy(name, L["Undo"].." "..reason, -amount, false, true)
  elseif kind == "GP" then
    EPGP:IncGPBy(name, L["Undo"].." "..reason, -amount, false, true)
  else
    assert(false, "Unknown record in the log")
  end

  callbacks:Fire("LogChanged", #self.db.profile.log)
  return true
end

function mod:CanRedo()
  if not CanEditOfficerNote() or not GS:IsCurrentState() then
    return false
  end

  return #self.db.profile.redo ~= 0
end

function mod:RedoLastUndo()
  assert(#self.db.profile.redo ~= 0)

  local record = table.remove(self.db.profile.redo)
  local timestamp, kind, name, reason, amount = unpack(record)

  local ep, gp, main = EPGP:GetEPGP(name)
  if kind == "EP" then
    EPGP:IncEPBy(name, L["Redo"].." "..reason, amount, false, true)
    table.insert(self.db.profile.log, record)
  elseif kind == "GP" then
    EPGP:IncGPBy(name, L["Redo"].." "..reason, amount, false, true)
    table.insert(self.db.profile.log, record)
  else
    assert(false, "Unknown record in the log")
  end

  callbacks:Fire("LogChanged", #self.db.profile.log)
  return true
end

function mod:Snapshot()
  local t = self.db.profile.snapshot
  if not t then
    t = {}
    self.db.profile.snapshot = t
  end
  t.time = GetTimestamp()
  GS:Snapshot(t)
end

function mod:Rollback()
  assert(self.db.profile.snapshot)
  local t = self.db.profile.snapshot

  -- Restore all notes
  GS:Rollback(t)

end

function mod:Export()
  local d = {}
  d.guild = select(1, GetGuildInfo("player"))
  d.realm = GetRealmName()
  d.base_gp = EPGP:GetBaseGP()
  d.min_ep = EPGP:GetMinEP()
  d.decay_p = EPGP:GetDecayPercent()
  d.extras_p = EPGP:GetExtrasPercent()
  d.timestamp = GetTimestamp()

  d.roster = EPGP:ExportRoster()

  return JSON.Serialize(d):gsub("\124", "\124\124")
end

function mod:Import(jsonStr)
  local success, d = pcall(JSON.Deserialize, jsonStr)
  if not success then
    EPGP:Error(L["The imported data is invalid"])
    return
  end

  if d.guild ~= select(1, GetGuildInfo("player")) or
     d.realm ~= GetRealmName() then
    EPGP:Error(L["The imported data is invalid"])
    return
  end

  local types = {
    timestamp = "number",
    roster = "table",
    decay_p = "number",
    extras_p = "number",
    min_ep = "number",
    base_gp = "number",
  }
  for k,t in pairs(types) do
    if type(d[k]) ~= t then
      EPGP:Error(L["The imported data is invalid"])
      return
    end
  end

  for _, entry in pairs(d.roster) do
    if type(entry) ~= "table" then
      EPGP:Error(L["The imported data is invalid"])
      return
    else
      local types = {
        [1] = "string",
        [2] = "number",
        [3] = "number",
      }
      for k,t in pairs(types) do
        if type(entry[k]) ~= t then
          EPGP:Error(L["The imported data is invalid"])
          return
        end
      end
    end
  end

  EPGP:Warning(L["Importing data snapshot taken at: %s"]:format(
                 date("%Y-%m-%d %H:%M", d.timestamp)))
  EPGP:ImportRoster(d.roster, d.base_gp)
  EPGP:SetGlobalConfiguration(d.decay_p, d.extras_p, d.base_gp, d.min_ep)

  -- Trim the log if necessary.
  local timestamp = d.timestamp
  while true do
    local records = #self.db.profile.log
    if records == 0 then
      break
    end
    
    if self.db.profile.log[records][1] > timestamp then
      table.remove(self.db.profile.log)
    else
      break
    end
  end
  -- Add the redos back to the log if necessary.
  while #self.db.profile.redo ~= 0 do
    local record = table.remove(self.db.profile.redo)
    if record[1] < timestamp then
      table.insert(self.db.profile.log, record)
    end
  end

  callbacks:Fire("LogChanged", #self.db.profile.log)
end

mod.dbDefaults = {
  profile = {
    enabled = true,
    log = {},
    redo = {},
  }
}

function mod:OnEnable()
  EPGP.RegisterCallback(mod, "EPAward", AppendToLog, "EP")
  EPGP.RegisterCallback(mod, "GPAward", AppendToLog, "GP")

  -- Upgrade the logs from older dbs
  if EPGP.db.profile.log then
    self.db.profile.log = EPGP.db.profile.log
    EPGP.db.profile.log = nil
  end
  if EPGP.db.profile.redo then
    self.db.profile.redo = EPGP.db.profile.redo
    EPGP.db.profile.redo = nil
  end
end
