-- This is the core addon. It implements all functions dealing with
-- administering and configuring EPGP. It implements the following
-- functions:
--
-- StandingsSort(order): Sorts the standings list using the specified
-- sort order. Valid values are: NAME, EP, GP, PR. If order is nil it
-- returns the current value.
--
-- StandingsShowEveryone(val): Sets listing everyone or not in the
-- standings when in raid. If val is nil it returns the current
-- value.
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
-- SelectMember(name): Select the member for award. Returns true if
-- the member was added, false otherwise.
--
-- DeSelectMember(name): Deselect member for award. Returns true if
-- the member was added, false otherwise.
--
-- IsMemberInAwardList(name): Returns true if member is in the award
-- list. When in a raid, this returns true for members in the raid and
-- members selected. When not in raid this returns true for everyone
-- if noone is selected or true if at least one member is selected and
-- the member is selected as well.
--
-- IsMemberInExtrasList(name): Returns true if member is in the award
-- list as an extra. When in a raid, this returns true if the member
-- is not in raid but is selected. When not in raid, this returns
-- false.
--
-- IsAnyMemberInExtrasList(name): Returns true if there is any member
-- in the award list as an extra.
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
-- IncMassEPBy(reason, amount): Increases the EP of all members
-- in the award list. See description of IsMemberInAwardList.
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
-- EPAward(name, reason, amount): Fired when an EP award is made.
--
-- MassEPAward(names, reason, amount): Fired when a mass EP award is made.
--
-- GPAward(name, reason, amount): Fired when a GP award is made.
--
-- DecayPercentChanged(v): Fired when decay percent changes. v is the
-- new value.
--
-- BaseGPChanged(v): Fired when base gp changes. v is the new value.
--
-- MinEPChanged(v): Fired when min ep changes. v is the new value.
--

EPGP = LibStub("AceAddon-3.0"):NewAddon(
  "EPGP", "AceEvent-3.0", "AceConsole-3.0")
local EPGP = EPGP
local GS = LibStub("LibGuildStorage-1.0")
local CallbackHandler = LibStub("CallbackHandler-1.0")
if not EPGP.callbacks then
  EPGP.callbacks = CallbackHandler:New(EPGP)
end
local callbacks = EPGP.callbacks

local L = LibStub("AceLocale-3.0"):GetLocale("EPGP")

local function debug(...)
  ChatFrame1:AddMessage(table.concat({...}, ""))
end

local DEFAULT_DECAY_P = 0
local DEFAULT_MIN_EP = 0
local DEFAULT_BASE_GP = 1

local decay_p = DEFAULT_DECAY_P
local min_ep = DEFAULT_MIN_EP
local base_gp = DEFAULT_BASE_GP

local ep_data = {}
local gp_data = {}
local main_data = {}
local alt_data = {}
local player
local db
local standings = {}
local selected = {}
selected._count = 0  -- This is safe since _ is not allowed in names

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

-- A wrapper function to handle sort logic for selected
local function ComparatorWrapper(f)
  return function(a, b)
           local a_in_raid = not not UnitInRaid(a)
           local b_in_raid = not not UnitInRaid(b)
           if a_in_raid ~= b_in_raid then
             return not b_in_raid
           end

           local a_selected = selected[a]
           local b_selected = selected[b]

           if a_selected ~= b_selected then
             return not b_selected
           end

           return f(a, b)
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
  if UnitInRaid("player") then
    -- If we are in raid:
    ---  showEveryone = true: show all in raid (including alts) and
    ---  all leftover mains
    ---  showEveryone = false: show all in raid (including alts) and
    ---  all selected members
    for n in pairs(ep_data) do
      if showEveryone or UnitInRaid(n) or selected[n] then
        table.insert(standings, n)
      end
    end
    for n in pairs(main_data) do
      if UnitInRaid(n) or selected[n] then
        table.insert(standings, n)
      end
    end
  else
    -- If we are not in raid, show all mains
    for n in pairs(ep_data) do
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
  local lines = {string.split("\n", info)}
  local in_block = false

  for _,line in pairs(lines) do
    if line == "-EPGP-" then
      in_block = not in_block
    elseif in_block then
      -- Decay percent
      local dp = tonumber(line:match("@DECAY_P:(%d+)")) or DEFAULT_DECAY_P
      if dp >= 0 and dp <= 100 then
        if decay_p ~= dp then
          decay_p = dp
          callbacks:Fire("DecayPercentChanged", dp)
        end
      else
        EPGP:Print(L["Decay Percent should be a number between 0 and 100"])
      end

      -- Min EP
      local mep = tonumber(line:match("@MIN_EP:(%d+)")) or DEFAULT_MIN_EP
      if mep >= 0 then
        if min_ep ~= mep then
          min_ep = mep
          callbacks:Fire("MinEPChanged", mep)
          DestroyStandings()
        end
      else
        EPGP:Print(L["Min EP should be a positive number"])
      end

      -- Base GP
      local bgp = tonumber(line:match("BASE_GP:(%d+)")) or DEFAULT_BASE_GP
      if bgp >= 0 then
        if base_gp ~= bgp then
          base_gp = bgp
          callbacks:Fire("BaseGPChanged", bgp)
          DestroyStandings()
        end
      else
        EPGP:Print(L["Base GP should be a positive number"])
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

function EPGP:SelectMember(name)
  if UnitInRaid("player") then
    -- Only allow selecting members that are not in raid when in raid.
    if UnitInRaid(name) then
      return false
    end
  end
  selected[name] = true
  selected._count = selected._count + 1
  DestroyStandings()
  return true
end

function EPGP:DeSelectMember(name)
  if UnitInRaid("player") then
    -- Only allow deselecting members that are not in raid when in raid.
    if UnitInRaid(name) then
      return false
    end
  end
  if not selected[name] then
    return false
  end
  selected[name] = nil
  selected._count = selected._count - 1
  DestroyStandings()
  return true
end

function EPGP:IsMemberInAwardList(name)
  if UnitInRaid("player") then
    -- If we are in raid the member is in the award list if it is in
    -- the raid or the selected list.
    return UnitInRaid(name) or selected[name]
  else
    -- If we are not in raid and there is noone selected everyone will
    -- get an award.
    if selected._count == 0 then
      return true
    end
    return selected[name]
  end
end

function EPGP:IsMemberInExtrasList(name)
  return UnitInRaid("player") and selected[name]
end

function EPGP:IsAnyMemberInExtrasList()
  return selected._count ~= 0
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
    callbacks:Fire("EPAward", name, reason, -decay_ep)
    AppendLog(timestamp, "GP", name, reason, -decay_gp)
    callbacks:Fire("GPAward", name, reason, -decay_gp)
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

function EPGP:IncEPBy(name, reason, amount, noCallback)
  assert(CheckDB())
  assert(EPGP:CanIncEPBy(reason, amount))
  assert(type(name) == "string")

  local ep, gp, main = self:GetEPGP(name)
  GS:SetNote(main or name, EncodeNote(ep + amount, gp))
  AppendLog(GetTimestamp(), "EP", name, reason, amount)
  if not noCallback then
    callbacks:Fire("EPAward", name, reason, amount)
  end
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
  callbacks:Fire("GPAward", name, reason, amount)

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
  if UnitInRaid("player") then
    -- If we are in a raid, make sure no member of the raid is
    -- selected
    for name,_ in pairs(selected) do
      if UnitInRaid(name) then
        selected[name] = nil
        selected._count = selected._count - 1
      end
    end
  else
    -- If we are not in a raid, this means we just left so remove
    -- everyone from the selected list.
    for name,_ in pairs(selected) do
      selected[name] = nil
    end
    selected._count = 0
  end
  DestroyStandings()
end

function EPGP:OnInitialize()
  player = UnitName("player")
  db = LibStub("AceDB-3.0"):New("EPGP_DB")
end

function EPGP:OnEnable()
  -- This is for modules
  self.db = db

  GS:RegisterCallback("GuildInfoChanged", ParseGuildInfo)
  GS:RegisterCallback("GuildNoteChanged", ParseGuildNote)
  self:RegisterEvent("RAID_ROSTER_UPDATE")
end

function EPGP:GetMain(name)
  return main_data[name] or name
end

function EPGP:IncMassEPBy(reason, amount)
  local awarded = {}
  for i=1,EPGP:GetNumMembers() do
    local name = EPGP:GetMember(i)
    if EPGP:IsMemberInAwardList(name) then
      local main = EPGP:GetMain(name)
      if not awarded[main] then
        awarded[EPGP:IncEPBy(name, reason, amount, true)] = true
      end
    end
  end
  callbacks:Fire("MassEPAward", awarded, reason, amount)
end
