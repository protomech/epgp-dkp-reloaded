-- This is the core addon. It implements all functions dealing with
-- administering and configuring EPGP. It implements the following
-- functions:
--
-- StandingsSort(order): Sorts the standings list using the specified
-- sort order. Valid values are: NAME, EP, GP, PR. If there is no
-- parameter it returns the current value.
--
-- StandingsShowAlts(val): Sets listing alts or not in the
-- standings. If there is no paramter it returns the current value.
--
-- GetNumMembers(): Returns the number of members in the standings.
--
-- GetMember(i): Returns the ith member in the standings based on the
-- current sort.
--
-- ResetEPGP(): Resets all EP and GP to 0.
--
-- DecayEPGP(): Decays all EP and GP by the configured decay percent
-- (GetDecayPercent()).
--
-- IncEPBy(name, reason, amount): Increases the EP of member <name> by
-- <amount>. It uses <reason> to log into the log.
--
-- IncGPBy(name, reason, amount): Increases the GP of member <name> by
-- <amount>. It uses <reason to log into the log.
--
-- GetDecayPercent(): Returns the decay percent configured in guild info.
--
-- GetBaseGP(): Returns the base GP configured in guild info.
--
-- GetMinEP(): Returns the min EP configured in guild info.
--
-- GetNumRecords(): Returns the number of log records.
--
-- GetLogRecord(i): Returns the ith log record starting 0.
--
-- ExportLog(): Returns a string with the data of the exported log for
-- import into the web application.
--
-- ImportLog(str): Takes a log export from the web application and
-- imports it into the current log. THIS REPLACES THE CURRENT LOG.
--
-- UndoLastAction(): Removes the last entry from the log and undoes
-- its action. The undone action is not logged.
--
-- GetEPGP(name): Returns <ep, gp, main> for <name>. <main> will be
-- nil if this is the main toon, otherwise it will be the name of the
-- main toon since this is an alt. If <name> is an invalid name or the
-- officer note is empty it returns <0, BaseGP, nil>.
--
-- GetDecayPercent(): Returns the decay % configured in GuildInfo.
--
-- GetBaseGP(): Retuns the base GP configured in GuildInfo.
--
-- GetMinEP(): Retuns the min EP configured in GuildInfo.
--
-- The library also fires the following messages, which you can
-- register for through RegisterCallback and unregister through
-- UnregisterCallback. You can also unregister all messages through
-- UnregisterAllCallbacks.
--
-- LogChanged(n): Fired when the log is changed. n is the new size of
-- the log.
--
-- StandingsChanged: Fired when the standings have changed.
--

EPGP = LibStub:GetLibrary("AceAddon-3.0"):NewAddon(
  "EPGP", "AceEvent-3.0", "AceConsole-3.0")
local EPGP = EPGP
local GS = LibStub:GetLibrary("LibGuildStorage-1.0")
local AceDB = LibStub:GetLibrary("AceDB-3.0")
local CallbackHandler = LibStub:GetLibrary("CallbackHandler-1.0")
if not EPGP.callbacks then
  EPGP.callbacks = CallbackHandler:New(EPGP)
end
local callbacks = EPGP.callbacks

local L = LibStub:GetLibrary("AceLocale-3.0"):GetLocale("EPGP")

local function debug(...)
  ChatFrame1:AddMessage(table.concat({...}, ""))
end

local decay_p
local base_gp
local min_ep
local ep_data = {}
local gp_data = {}
local main_data = {}
local player
local db
local standings = {}
local standings_dirty = true

local function DecodeNote(note)
  local ep, gp = string.match(note, "^(%d+),(%d+)$")
  if ep then
    return tonumber(ep), tonumber(gp)
  end

  return 0, 0
end

local function EncodeNote(ep, gp)
  return string.format("%d,%d", ep, gp)
end

-- Parse options. Options are inside GuildInfo and are inside a -EPGP-
-- block. Possible options are:
--
-- @DECAY_P:<number>
-- @MIN_EP:<number>
-- @BASE_GP:<number>
local function ParseGuildInfo(callback, info)
  decay_p = 0
  min_ep = 0
  base_gp = 1
  local lines = {string.split("\n", info)}
  local in_block = false

  for _,line in pairs(lines) do
    if line == "-EPGP-" then
      in_block = not in_block
    elseif in_block then
      -- Decay percent
      local dp = tonumber(line:match("@DECAY_P:(%d+)"))
      if dp then
        if dp >= 0 and dp <= 100 then
          decay_p = dp
        else
          EPGP:Print(L["Decay Percent should be a number between 0 and 100"])
        end
      end

      -- Min EP
      local mep = tonumber(line:match("@MIN_EP:(%d+)"))
      if mep then
        if mep >= 0 then
          if min_ep ~= mep then
            min_ep = mep
            standings_dirty = true
            callbacks:Fire("StandingsChanged")
          end
        else
          EPGP:Print(L["Min EP should be a positive number"])
        end
      end

      -- Base GP
      local bgp = tonumber(line:match("BASE_GP:(%d+)"))
      if bgp then
        if bgp >= 0 then
          if base_gp ~= bgp then
            base_gp = bgp
            standings_dirty = true
            callbacks:Fire("StandingsChanged")
          end
        else
          EPGP:Print(L["Base GP should be a positive number"])
        end
      end
    end
  end
end

local function ParseGuildNote(callback, name, note)
  debug("ParseGuildNote: ", name, " -> ", note)
  if not note or note == "" then
    ep_data[name] = 0
    gp_data[name] = 0
  elseif note:match("%u%l+") then
    main_data[name] = note
    ep_data[name] = nil
    gp_data[name] = nil
  else
    local ep, gp = DecodeNote(note)
    ep_data[name] = ep or 0
    gp_data[name] = gp or base_gp
  end
  standings_dirty = true
  callbacks:Fire("StandingsChanged")
end

local function CheckDB()
  if not db then return false end
  if not IsInGuild() then return false end
  local guild = GetGuildInfo("player")
  if not guild then return false end
  if db:GetCurrentProfile() ~= guild then
    db:SetProfile(guild)
  end
  return true
end

local timestamp_t = {}
local function GetTimestamp()
  timestamp_t.month = select(2, CalendarGetDate())
  timestamp_t.day = select(3, CalendarGetDate())
  timestamp_t.year = select(4, CalendarGetDate())
  timestamp_t.hour = select(1, GetGameTime())
  timestamp_t.min = select(2, GetGameTime())
  return time(timestamp_t)
end

local function AppendLog(timestamp, kind, dst, reason, amount)
  assert(CheckDB())

  assert(kind == "EP" or kind == "GP")
  assert(type(dst) == "string")
  assert(type(reason) == "string")
  assert(type(amount) == "number")

  table.insert(db.profile.log, {timestamp, kind, player, dst, reason, amount})
  callbacks:Fire("LogChanged", #db.profile.log)
end

local function LogRecordToString(record)
  local timestamp, kind, src, dst, reason, amount = unpack(record)

  if kind == "EP" then
    return string.format("%s: %s awards %d EP to %s for %s",
                         date("%F %R", timestamp), src, amount, dst, reason)
  elseif kind == "GP" then
    return string.format("%s: %s credits %d GP to %s for %s",
                         date("%F %R", timestamp), src, amount, dst, reason)
  else
    debug(tostring(timestamp), tostring(kind), tostring(src), tostring(dst), tostring(reason), tostring(amount))
    assert(false, "Unknown record in the log")
  end
end

local comparators = {
  NAME = function(a, b)
           return a < b
         end,
  EP = function(a, b)
         local main_a = main_data[a]
         if main_a then a = main_a end
         local main_b = main_data[b]
         if main_b then b = main_b end

         local a_ep, b_ep = ep_data[a] or 0, ep_data[b] or 0
         return a_ep > b_ep
       end,
  GP = function(a, b)
         local main_a = main_data[a]
         if main_a then a = main_a end
         local main_b = main_data[b]
         if main_b then b = main_b end

         local a_gp, b_gp = gp_data[a] or 0, gp_data[b] or 0
         return a_gp > b_gp
       end,
  PR = function(a, b)
         local main_a = main_data[a]
         if main_a then a = main_a end
         local main_b = main_data[b]
         if main_b then b = main_b end
         -- TODO(alkis): Fix MIN_EP computation
         local a_ep, b_ep = ep_data[a] or 0
         local b_ep = ep_data[b] or 0
         local a_gp = gp_data[a] + base_gp or base_gp
         local b_gp = gp_data[b] + base_gp or base_gp
         return a_ep/a_gp > b_ep/b_gp
       end,
}

function EPGP:StandingsSort(order)
  assert(CheckDB())

  if not order then
    return db.profile.sort_order
  end

  assert(comparators[order], "Unknown sort order")

  db.profile.sort_order = order
  standings_dirty = true
  callbacks:Fire("StandingsChanged")
end

function EPGP:StandingsShowAlts(val)
  assert(CheckDB())

  if val == nil then
    return db.profile.show_alts
  end

  db.profile.show_alts = not not val
  standings_dirty = true
  callbacks:Fire("StandingsChanged")
end

local function RefreshStandings(order, showAlts)
  -- Remove everything from standings
  for k,v in pairs(standings) do
    standings[k] = nil
  end
  -- Add all mains
  for n in pairs(ep_data) do
    table.insert(standings, n)
  end
  -- Add all alts if necessary
  if showAlts then
    for n in pairs(main_data) do
      table.insert(standings, n)
    end
  end
  -- Sort
  table.sort(standings, comparators[order])
end

function EPGP:GetNumMembers()
  assert(CheckDB())

  if standings_dirty then
    RefreshStandings(db.profile.sort_order, db.profile.show_alts)
    standings_dirty = false
  end

  return #standings
end

function EPGP:GetMember(i)
  assert(CheckDB())

  if standings_dirty then
    RefreshStandings(db.profile.sort_order, db.profile.show_alts)
    standings_dirty = false
  end

  return standings[i]
end

function EPGP:ResetEPGP()
  local zero_note = EncodeNote(0, 0)
  local timestamp = GetTimestamp()
  for n,ep in pairs(ep_data) do
    GS:SetNote(n, zero_note)
    local gp = gp_data[n]
    if ep > 0 then
      AppendLog(timestamp, "EP", n, "Reset", -ep)
    end
    if gp > 0 then
      AppendLog(timestamp, "GP", n, "Reset", -gp)
    end
  end
end

function EPGP:DecayEPGP()
  assert(CheckDB())

  local decay = decay_p  * 0.01
  local reason = string.format("Decay %d%%", decay_p)
  local timestamp = GetTimestamp()
  for name in GetIter("PR") do
    if not main_data[name] then
      local ep, gp = ep_data[name], gp_data[name]
      local decay_ep = math.floor(ep * decay)
      local decay_gp = math.floot((gp + base_gp) * decay)
      GS:SetNote(name, EncodeNote(math.max(ep - decay_ep, 0),
                                  math.max(gp - decay_gp, base_gp)))
      AppendLog(timestamp, "EP", name, reason, new_ep - ep)
      AppendLog(timestamp, "GP", name, reason, new_gp - gp)
    end
  end
end

function EPGP:GetEPGP(name)
  local main = main_data[name]
  if main then
    name = main
  end
  return ep_data[name], gp_data[name] + base_gp, main
end

function EPGP:IncEPBy(name, reason, amount)
  assert(CheckDB())
  assert(reason, "reason cannot be an empty string")

  local main = main_data[name]
  if not main then
    main = name
  end
  local ep, gp = ep_data[main], gp_data[main]
  assert(ep + amount >= 0, "Resulting EP should be positive")

  GS:SetNote(main, EncodeNote(ep + amount, gp))
  AppendLog(GetTimestamp(), "EP", name, reason, amount)
end

function EPGP:IncGPBy(name, reason, amount)
  assert(CheckDB())

  local main = main_data[name]
  if not main then
    main = name
  end
  local ep, gp = ep_data[main], gp_data[main]
  assert(gp + amount >= 0, "Resulting GP should be positive")

  GS:SetNote(main, EncodeNote(ep, gp + amount))
  AppendLog(GetTimestamp(), "GP", name, reason, amount)
end

function EPGP:GetDecayPercent()
  return decay_p
end

function EPGP:GetBaseGP()
  return base_gp
end

function EPGP:GetMinEP()
  return min_ep
end

function EPGP:ExportLog()
  assert(CheckDB())

  local t = {}
  for i, record in ipairs(db.profile.log) do
    table.insert(t, table.concat(record, ","))
  end
  debug("ExportLog: ", unpack(t))
  return table.concat(t, "\n")
end

function EPGP:ImportLog(str)
  assert(CheckDB())

  local records = strsplit(str, "\n")
  for record in records do
    -- TODO(alkis)
  end
end

function EPGP:UndoLastAction()
  assert(CheckDB())
  if #db.profile.log == 0 then
    return false
  end

  local record = table.remove(db.profile.log)
  local timestamp, kind, src, dst, reason, amount = unpack(record)

  debug("Rolling back: ", LogRecordToString(record))
  local main = main_data[dst]
  if not main then
    main = dst
  end
  assert(main, "Cannot find main toon's name!")
  local ep, gp = ep_data[main], gp_data[main]
  if kind == "EP" then
    GS:SetNote(main, EncodeNote(ep - amount, gp))
  elseif kind == "GP" then
    GS:SetNote(main, EncodeNote(ep, gp - amount))
  else
    assert(false, "Unknown record in the log")
  end

  callbacks:Fire("LogChanged", #db.profile.log)
  return true
end

function EPGP:GetNumRecords()
  assert(CheckDB())

  return #db.profile.log
end

function EPGP:GetLogRecord(i)
  assert(CheckDB())

  local logsize = #db.profile.log
  assert(i >= 0 and i < #db.profile.log, "Index "..i.." is out of bounds")

  return LogRecordToString(db.profile.log[logsize - i])
end

function EPGP:OnInitialize()
  player = UnitName("player")
  db = AceDB:New("EPGP_DB", {
                   profile = {
                     log = {},
                     show_alts = false,
                     sort_order = "PR",
                   }
                 })
  GS:RegisterCallback("GuildInfoChanged", ParseGuildInfo)
  GS:RegisterCallback("GuildNoteChanged", ParseGuildNote)
end
