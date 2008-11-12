-- This is the core addon. It implements all functions dealing with
-- administering and configuring EPGP. It implements the following
-- functions:
--
-- StandingsSort(order): Sorts the standings list using the specified
-- sort order. Valid values are: NAME, EP, GP, PR. If there is no
-- parameter it returns the current value.
--
-- StandingsShowEveryone(val): Sets listing everyone or not in the
-- standings. If there is no parameter it returns the current
-- value. Not showing everyone means no alts when not in raid and only
-- raid members when in raid.
--
-- GetNumMembers(): Returns the number of members in the standings.
--
-- GetMember(i): Returns the ith member in the standings based on the
-- current sort.
--
-- GetMain(name): Returns the main character for this member. 
--
-- GetNumAlts(name): Returns the number of alts for this member.
--
-- GetAlt(name, i): Returns the ith alt for this member.
--
-- StandingsAddExtraMember(name): Add member to the standings. Returns true
-- if the member was added, false otherwise.
--
-- StandingsRemoveExtraMember(name): Remove member from the
-- standings. Returns true if the member was added, false otherwise.
--
-- IsMemberInStandings(name): Returns true if member is in standings.
--
-- IsMemberInStandingsExtra(name): Returns true if member is in
-- standings as an extra.
--
-- ResetEPGP(): Resets all EP and GP to 0.
--
-- DecayEPGP(): Decays all EP and GP by the configured decay percent
-- (GetDecayPercent()).
--
-- CanIncEPBy(reason, amount): Return true reason and amount are
-- reasonable values for IncEPBy.
--
-- IncEPBy(name, reason, amount): Increases the EP of member <name> by
-- <amount>. It uses <reason> to log into the log. Returns the member's
-- main character name.
--
-- CanIncGPBy(reason, amount): Return true if reason and amount
-- are reasonable values for IncGPBy.
--
-- IncGPBy(name, reason, amount): Increases the GP of member <name> by
-- <amount>. It uses <reason to log into the log. Returns the member's 
-- main character name.
--
-- IncStandingsEPBy(reason, amount): Increases the EP of all members
-- currently in the standings.
--
-- RecurringEP(val): Sets recurring EP to true/false. If val is nil it
-- returns the current value.
--
-- RecurringEPPeriodMinutes(val): Sets the recurring EP period in
-- minutes. If val is nil it returns the current value.
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
-- GetClass(name): Returns the class of member <name>. It returns nil
-- if the class is unknown.
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

local decay_p = 0
local min_ep = 0
local base_gp = 1
local ep_data = {}
local gp_data = {}
local main_data = {}
local alt_data = {}
local player
local db
local standings = {}
local extras = {}

local function DecodeNote(note)
  local ep, gp = string.match(note, "^(%d+),(%d+)$")
  if ep then
    return tonumber(ep), tonumber(gp)
  end

  return 0, 0
end

local function EncodeNote(ep, gp)
  return string.format("%d,%d", math.max(ep, 0), math.max(gp - base_gp, 0))
end

-- A wrapper function to handle sort logic for extras and min_ep
local function ComparatorWrapper(f)
  return function(a, b)
           if db.profile.show_everyone then
             return f(a, b)
           end

           local a_extra = extras[a]
           local b_extra = extras[b]

           if a_extra == b_extra then
             return f(a, b)
           else
             return b_extra
           end
         end
end

local comparators = {
  NAME = function(a, b)
           return a < b
         end,
  EP = function(a, b)
         local a_ep, a_gp = EPGP:GetEPGP(a)
         local b_ep, b_gp = EPGP:GetEPGP(b)

         return a_ep > b_ep
       end,
  GP = function(a, b)
         local a_ep, a_gp = EPGP:GetEPGP(a)
         local b_ep, b_gp = EPGP:GetEPGP(b)

         return a_gp > b_gp
       end,
  PR = function(a, b)
         local a_ep, a_gp = EPGP:GetEPGP(a)
         local b_ep, b_gp = EPGP:GetEPGP(b)

         local a_qualifies = a_ep >= min_ep
         local b_qualifies = b_ep >= min_ep

         if a_qualifies == b_qualifies then
           return a_ep/a_gp > b_ep/b_gp
         else
           return a_qualifies
         end
       end,
}
for k,f in pairs(comparators) do
  comparators[k] = ComparatorWrapper(f)
end

local function DestroyStandings()
  -- Remove everything from standings
  for k,v in pairs(standings) do
    standings[k] = nil
  end
  callbacks:Fire("StandingsChanged")
end

local function RefreshStandings(order, showEveryone)
  -- Add all mains
  for n in pairs(ep_data) do
    if showEveryone or EPGP:IsMemberInStandings(n) then
      table.insert(standings, n)
    end
  end

  -- Add alts if we are not in raid view
  if showEveryone and not UnitInRaid("player") then
    for n in pairs(main_data) do
      table.insert(standings, n)
    end
  end
  -- Sort
  table.sort(standings, comparators[order])
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
            DestroyStandings()
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
            DestroyStandings()
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
    if not alt_data[note] then
      alt_data[note] = {}
    end
    table.insert(alt_data[note], name)
    ep_data[name] = nil
    gp_data[name] = nil
  else
    local ep, gp = DecodeNote(note)
    ep_data[name] = ep or 0
    gp_data[name] = gp or base_gp
  end
  DestroyStandings()
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

function EPGP:StandingsSort(order)
  assert(CheckDB())

  if not order then
    return db.profile.sort_order
  end

  assert(comparators[order], "Unknown sort order")

  db.profile.sort_order = order
  DestroyStandings()
end

function EPGP:StandingsShowEveryone(val)
  assert(CheckDB())

  if val == nil then
    return db.profile.show_everyone
  end

  db.profile.show_everyone = not not val
  DestroyStandings()
end

function EPGP:GetNumMembers()
  assert(CheckDB())

  if #standings == 0 then
    RefreshStandings(db.profile.sort_order, db.profile.show_everyone)
  end

  return #standings
end

function EPGP:GetMember(i)
  assert(CheckDB())

  if #standings == 0 then
    RefreshStandings(db.profile.sort_order, db.profile.show_everyone)
  end

  return standings[i]
end

function EPGP:GetNumAlts(name)
  local alts = alt_data[name]
  if not alts then
    return 0
  else
    return #alts
  end
end

function EPGP:GetAlt(name, i)
  return alt_data[name][i]
end

function EPGP:StandingsAddExtra(name)
  if UnitInRaid("player") then
    if not UnitInRaid(name) then
      extras[name] = true
      DestroyStandings()
      return true
    end
  end
  return false
end

function EPGP:StandingsRemoveExtra(name)
  if UnitInRaid("player") then
    if not UnitInRaid(name) and extras[name] then
      extras[name] = nil
      DestroyStandings()
      return true
    end
  end
  return false
end

function EPGP:IsMemberInStandings(name)
  return not UnitInRaid("player") or UnitInRaid(name) or extras[name]
end

function EPGP:IsMemberInStandingsExtra(name)
  return extras[name]
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
  for name,_ in pairs(ep_data) do
    local ep, gp, main = self:GetEPGP(name)
    assert(main == nil, "Corrupt alt data!")
    local decay_ep = math.floor(ep * decay)
    local decay_gp = math.floor(gp * decay)
    GS:SetNote(name, EncodeNote(math.max(ep - decay_ep, 0),
                                math.max(gp - decay_gp, 0)))
    AppendLog(timestamp, "EP", name, reason, -decay_ep)
    AppendLog(timestamp, "GP", name, reason, -decay_gp)
  end
end

function EPGP:GetEPGP(name)
  local main = main_data[name]
  if main then
    name = main
  end
  return ep_data[name], gp_data[name] + base_gp, main
end

function EPGP:GetClass(name)
  return GS:GetClass(name)
end

function EPGP:CanIncEPBy(reason, amount)
  if type(reason) ~= "string" or type(amount) ~= "number" or #reason == 0 then
    return false
  end
  if amount < -99999 or amount > 99999 or amount == 0 then
    return false
  end
  return true
end

function EPGP:IncEPBy(name, reason, amount)
  assert(CheckDB())
  assert(EPGP:CanIncEPBy(reason, amount))
  assert(type(name) == "string")

  local ep, gp, main = self:GetEPGP(name)
  GS:SetNote(main or name, EncodeNote(ep + amount, gp))
  AppendLog(GetTimestamp(), "EP", name, reason, amount)
  
  return main or name
end

function EPGP:CanIncGPBy(reason, amount)
  if type(reason) ~= "string" or type(amount) ~= "number" or #reason == 0 then
    return false
  end
  if amount < -99999 or amount > 99999 or amount == 0 then
    return false
  end
  return true
end

function EPGP:IncGPBy(name, reason, amount)
  assert(CheckDB())
  assert(EPGP:CanIncGPBy(reason, amount))
  assert(type(name) == "string")

  local ep, gp, main = self:GetEPGP(name)
  GS:SetNote(main or name, EncodeNote(ep, gp + amount))
  AppendLog(GetTimestamp(), "GP", name, reason, amount)
  
  return main or name
end

function EPGP:RecurringEP(val)
  assert(CheckDB())
  if val == nil then
    return db.profile.recurring_ep
  end
  db.profile.recurring_ep = not not val
end

function EPGP:RecurringEPPeriodMinutes(val)
  assert(CheckDB())
  if val == nil then
    return db.profile.recurring_ep_period_mins
  end
  db.profile.recurring_ep_period_mins = val
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
  local ep, gp, main = self:GetEPGP(dst)
  if main then
    dst = main
    debug("Rolling back on main toon: ", main)
  end

  if kind == "EP" then
    GS:SetNote(dst, EncodeNote(ep - amount, gp))
  elseif kind == "GP" then
    GS:SetNote(dst, EncodeNote(ep, gp - amount))
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

function EPGP:RAID_ROSTER_UPDATE()
  DestroyStandings()
  -- Make sure no member of the raid is in extras
  for name,_ in pairs(extras) do
    if UnitInRaid(name) then
      extras[name] = nil
    end
  end
end

function EPGP:OnInitialize()
  player = UnitName("player")
  db = AceDB:New("EPGP_DB", {
                   profile = {
                     log = {},
                     show_everyone = false,
                     sort_order = "PR",
                     recurring_ep_period_mins = 15,
                     recurring_ep = false,
                   }
                 })
  GS:RegisterCallback("GuildInfoChanged", ParseGuildInfo)
  GS:RegisterCallback("GuildNoteChanged", ParseGuildNote)
  self:RegisterEvent("RAID_ROSTER_UPDATE")
end

function EPGP:GetMain(name)
  return main_data[name] or name
end

function EPGP:IncStandingsEPBy(reason, amount)
  local awarded = {}
  for i=1,EPGP:GetNumMembers() do
    local name = EPGP:GetMember(i)
    local main = EPGP:GetMain(name)
    if not awarded[main] then
      awarded[EPGP:IncEPBy(name, reason, amount)] = true
    end
  end
end