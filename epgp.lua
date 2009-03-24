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
-- GetNumMembersInAwardList(): Returns the number of members in the
-- award list.
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
-- reasonable values for IncEPBy and the caller can change EPGP.
--
-- IncEPBy(name, reason, amount): Increases the EP of member <name> by
-- <amount>. Returns the member's main character name.
--
-- CanIncGPBy(reason, amount): Return true if reason and amount are
-- reasonable values for IncGPBy and the caller can change EPGP.
--
-- IncGPBy(name, reason, amount): Increases the GP of member <name> by
-- <amount>. Returns the member's main character name.
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
-- CanDecayEPGP(): Returns true if the caller can decay EPGP.
--
-- GetBaseGP(): Returns the base GP configured in guild info.
--
-- GetMinEP(): Returns the min EP configured in guild info.
--
-- GetEPGP(name): Returns <ep, gp, main> for <name>. <main> will be
-- nil if this is the main toon, otherwise it will be the name of the
-- main toon since this is an alt. If <name> is an invalid name it
-- returns nil.
--
-- GetClass(name): Returns the class of member <name>. It returns nil
-- if the class is unknown.
--
-- ReportErrors(outputFunc): Calls function for each error during
-- initialization, one line at a time.
--
-- The library also fires the following messages, which you can
-- register for through RegisterCallback and unregister through
-- UnregisterCallback. You can also unregister all messages through
-- UnregisterAllCallbacks.
--
-- StandingsChanged: Fired when the standings have changed.
--
-- EPAward(name, reason, amount, mass): Fired when an EP award is
-- made.  mass is set to true if this is a mass award or decay.
--
-- MassEPAward(names, reason, amount): Fired when a mass EP award is made.
--
-- GPAward(name, reason, amount, mass): Fired when a GP award is
-- made. mass is set to true if this is a mass award or decay.
--
-- StartRecurringAward(reason, amount, mins): Fired when recurring
-- awards are started.
--
-- StopRecurringAward(): Fired when recurring awards are stopped.
--
-- RecurringAwardUpdate(reason, amount, remainingSecs): Fired
-- periodically between awards with the remaining seconds to award in
-- seconds.
--
-- EPGPReset(): Fired when EPGP are reset.
--
-- Decay(percent): Fired when a decay happens.
--
-- DecayPercentChanged(v): Fired when decay percent changes. v is the
-- new value.
--
-- BaseGPChanged(v): Fired when base gp changes. v is the new value.
--
-- MinEPChanged(v): Fired when min ep changes. v is the new value.
--
-- ExtrasPercentChanged(v): Fired when extras percent changes.  v is
-- the new value.
--

EPGP = LibStub("AceAddon-3.0"):NewAddon(
  "EPGP", "AceEvent-3.0", "AceConsole-3.0", "AceTimer-3.0")
local EPGP = EPGP
EPGP:SetDefaultModuleState(false)

local version = GetAddOnMetadata('EPGP', 'Version')
if not version or #version == 0 then
  version = "(development)"
end
EPGP.version = version

local GS = LibStub("LibGuildStorage-1.0")
local CallbackHandler = LibStub("CallbackHandler-1.0")
if not EPGP.callbacks then
  EPGP.callbacks = CallbackHandler:New(EPGP)
end
local callbacks = EPGP.callbacks

local L = LibStub("AceLocale-3.0"):GetLocale("EPGP")

local global_config = {}
local ep_data = {}
local gp_data = {}
local main_data = {}
local alt_data = {}
local ignored = {}
local db
local standings = {}
local selected = {}
selected._count = 0  -- This is safe since _ is not allowed in names

local function DecodeNote(note)
  if note then
    if note == "" then
      return 0, 0
    else
      local ep, gp = string.match(note, "^(%d+),(%d+)$")
      if ep then
        return tonumber(ep), tonumber(gp)
      end
    end
  end
end

local function EncodeNote(ep, gp)
  return string.format("%d,%d",
                       math.max(ep, 0),
                       math.max(gp - global_config.base_gp, 0))
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

         local a_qualifies = a_ep >= global_config.min_ep
         local b_qualifies = b_ep >= global_config.min_ep

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
  EPGP:Debug("Resorting standings")
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
-- @EXTRAS_P:<number>
-- @MIN_EP:<number>
-- @BASE_GP:<number>
local global_config_defs = {
  decay_p = {
    pattern = "@DECAY_P:(%d+)",
    parser = tonumber,
    validator = function(v) return v >= 0 and v <= 100 end,
    error = L["Decay Percent should be a number between 0 and 100"],
    default = 0,
    change_message = "DecayPercentChanged",
  },
  extras_p = {
    pattern = "@EXTRAS_P:(%d+)",
    parser = tonumber,
    validator = function(v) return v >= 0 and v <= 100 end,
    error = L["Extras Percent should be a number between 0 and 100"],
    default = 100,
    change_message = "ExtrasPercentChanged",
  },
  min_ep = {
    pattern = "@MIN_EP:(%d+)",
    parser = tonumber,
    validator = function(v) return v >= 0 end,
    error = L["Min EP should be a positive number"],
    default = 0,
    change_message = "MinEPChanged",
  },
  base_gp = {
    pattern = "@BASE_GP:(%d+)",
    parser = tonumber,
    validator = function(v) return v >= 0 end,
    error = L["Base GP should be a positive number"],
    default = 1,
    change_message = "BaseGPChanged",
  },
}
-- Set defaults
for var, def in pairs(global_config_defs) do
  global_config[var] = def.default
end
local function ParseGuildInfo(callback, info)
  EPGP:Debug("Parsing GuildInfo")
  local lines = {string.split("\n", info)}
  local in_block = false

  local new_config = {}

  for _,line in pairs(lines) do
    if line == "-EPGP-" then
      in_block = not in_block
    elseif in_block then
      for var, def in pairs(global_config_defs) do
        local v = line:match(def.pattern)
        if v then
          EPGP:Debug("Matched [%s]", line)
          v = def.parser(v)
          if v == nil or not def.validator(v) then
            EPGP:Error(def.error)
          else
            new_config[var] = v
          end
        end
      end
    end
  end

  for var, def in pairs(global_config_defs) do
    local new_value = new_config[var]
    if new_value == nil then
      new_value = def.default
    end
    if global_config[var] ~= new_value then
      EPGP:Debug("Setting new value %s for variable %s",
                 tostring(new_value), var)
      global_config[var] = new_value
      callbacks:Fire(def.change_message, new_value)
    end
  end
end

local function DeleteState(name)
  -- If this is was an alt we need to fix the alts state
  local main = main_data[name]
  if main then
    if alt_data[main] then
      for i,alt in ipairs(alt_data[main]) do
        if alt == name then
          table.remove(alt_data[main], i)
          break
        end
      end
    end
    main_data[name] = nil
  end
  -- Delete any existing cached values
  ep_data[name] = nil
  gp_data[name] = nil
end

local function HandleDeletedGuildNote(callback, name)
  DeleteState(name)
  DestroyStandings()
end

local function ParseGuildNote(callback, name, note)
  EPGP:Debug("Parsing Guild Note for %s [%s]", name, note)
  -- Delete current state about this toon.
  DeleteState(name)

  local ep, gp = DecodeNote(note)
  if ep then
    ep_data[name] = ep
    gp_data[name] = gp
  else
    if not GS:GetNote(note) then
      -- This is a junk note, ignore it
      ignored[name] = note
    else
      -- Otherwise setup the alts state 
      main_data[name] = note
      if not alt_data[note] then
        alt_data[note] = {}
      end
      table.insert(alt_data[note], name)
      ep_data[name] = nil
      gp_data[name] = nil
    end
  end
  DestroyStandings()
end

function EPGP:ExportRoster()
  local base_gp = global_config.base_gp
  local t = {}
  for name,_ in pairs(ep_data) do
    local ep, gp, main = self:GetEPGP(name)
    if ep ~= 0 or gp ~= base_gp then
      table.insert(t, {name, self:GetClass(name), ep, gp})
    end
  end
  return t
end

function EPGP:ImportRoster(t, base_gp)
  local notes = {}
  for _, entry in pairs(t) do
    local name, ep, gp = unpack(entry)
    ep = math.max(0, ep)
    gp = math.max(base_gp, gp)
    notes[name] = EncodeNote(ep, gp - base_gp)
  end

  local zero_note = EncodeNote(0, 0)
  for name,_ in pairs(ep_data) do
    local note = notes[name] or zero_note
    GS:SetNote(name, note)
  end
end

function EPGP:StandingsSort(order)
  if not order then
    return db.profile.sort_order
  end

  assert(comparators[order], "Unknown sort order")

  db.profile.sort_order = order
  DestroyStandings()
end

function EPGP:StandingsShowEveryone(val)
  if val == nil then
    return db.profile.show_everyone
  end

  db.profile.show_everyone = not not val
  DestroyStandings()
end

function EPGP:GetNumMembers()
  if #standings == 0 then
    RefreshStandings(db.profile.sort_order, db.profile.show_everyone)
  end

  return #standings
end

function EPGP:GetMember(i)
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

function EPGP:GetNumMembersInAwardList()
  if UnitInRaid("player") then
    return GetNumRaidMembers() + selected._count
  else
    if selected._count == 0 then
      return self:GetNumMembers()
    else
      return selected._count
    end
  end
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
  for name,_ in pairs(ep_data) do
    GS:SetNote(name, zero_note)
    local ep, gp, main = self:GetEPGP(name)
    assert(main == nil, "Corrupt alt data!")
    if ep > 0 then
      callbacks:Fire("EPAward", name, "Reset", -ep, true)
    end
    if gp > 0 then
      callbacks:Fire("GPAward", name, "Reset", -gp, true)
    end
  end
  callbacks:Fire("EPGPReset")
end

function EPGP:CanDecayEPGP()
  if not CanEditOfficerNote() or global_config.decay_p == 0 or not GS:IsCurrentState() then
    return false
  end
  return true
end

function EPGP:DecayEPGP()
  local decay = global_config.decay_p  * 0.01
  local reason = string.format("Decay %d%%", global_config.decay_p)
  for name,_ in pairs(ep_data) do
    local ep, gp, main = self:GetEPGP(name)
    assert(main == nil, "Corrupt alt data!")
    local decay_ep = math.ceil(ep * decay)
    local decay_gp = math.ceil(gp * decay)
    GS:SetNote(name, EncodeNote(ep - decay_ep, gp - decay_gp))
    if decay_ep ~= 0 then
      callbacks:Fire("EPAward", name, reason, -decay_ep, true)
    end
    if decay_gp ~= 0 then
      callbacks:Fire("GPAward", name, reason, -decay_gp, true)
    end
  end
  callbacks:Fire("Decay", global_config.decay_p)
end

function EPGP:GetEPGP(name)
  local main = main_data[name]
  if main then
    name = main
  end
  if ep_data[name] then
    return ep_data[name], gp_data[name] + global_config.base_gp, main
  end
end

function EPGP:GetClass(name)
  return GS:GetClass(name)
end

function EPGP:CanIncEPBy(reason, amount)
  if not CanEditOfficerNote() or not GS:IsCurrentState() then
    return false
  end
  if type(reason) ~= "string" or type(amount) ~= "number" or #reason == 0 then
    return false
  end
  if amount < -99999 or amount > 99999 or amount == 0 then
    return false
  end
  return true
end

function EPGP:IncEPBy(name, reason, amount, mass, undo)
  -- When we do mass EP or decay we know what we are doing even though
  -- CanIncEPBy returns false
  assert(EPGP:CanIncEPBy(reason, amount) or mass)
  assert(type(name) == "string")

  local ep, gp, main = self:GetEPGP(name)
  GS:SetNote(main or name, EncodeNote(ep + amount, gp))
  callbacks:Fire("EPAward", name, reason, amount, mass, undo)
  db.profile.last_awards[reason] = amount
  return main or name
end

function EPGP:CanIncGPBy(reason, amount)
  if not CanEditOfficerNote() or not GS:IsCurrentState() then
    return false
  end
  if type(reason) ~= "string" or type(amount) ~= "number" or #reason == 0 then
    return false
  end
  if amount < -99999 or amount > 99999 or amount == 0 then
    return false
  end
  return true
end

function EPGP:IncGPBy(name, reason, amount, mass, undo)
  -- When we do mass GP or decay we know what we are doing even though
  -- CanIncGPBy returns false
  assert(EPGP:CanIncGPBy(reason, amount) or mass)
  assert(type(name) == "string")

  local ep, gp, main = self:GetEPGP(name)
  GS:SetNote(main or name, EncodeNote(ep, gp + amount))
  callbacks:Fire("GPAward", name, reason, amount, mass, undo)

  return main or name
end

local timer
local next_award

local function RecurringTicker(arg)
  local reason, amount = unpack(arg)
  local now = GetTime()
  if now > next_award then
    EPGP:IncMassEPBy(reason, amount)
    next_award = next_award + db.profile.recurring_ep_period_mins * 60
  end
  
  callbacks:Fire("RecurringAwardUpdate", reason, amount, next_award - now)
end

function EPGP:StartRecurringEP(reason, amount)
  if timer then
    return false
  end

  local arg = {reason, amount}
  timer = self:ScheduleRepeatingTimer(RecurringTicker, 1, arg)
  next_award = GetTime() + db.profile.recurring_ep_period_mins * 60

  callbacks:Fire("StartRecurringAward", reason, amount,
                 db.profile.recurring_ep_period_mins)
  RecurringTicker(arg)
  return true
end

function EPGP:StopRecurringEP()
  if not timer then
    return false
  end

  self:CancelTimer(timer)
  timer = nil

  callbacks:Fire("StopRecurringAward")
  return true
end

function EPGP:RunningRecurringEP()
  return not not timer
end

function EPGP:RecurringEPPeriodMinutes(val)
  if val == nil then
    return db.profile.recurring_ep_period_mins
  end
  db.profile.recurring_ep_period_mins = val
end

function EPGP:GetDecayPercent()
  return global_config.decay_p
end

function EPGP:GetExtrasPercent()
  return global_config.extras_p
end

function EPGP:GetBaseGP()
  return global_config.base_gp
end

function EPGP:GetMinEP()
  return global_config.min_ep
end

function EPGP:SetGlobalConfiguration(decay_p, extras_p, base_gp, min_ep)
  local guild_info = GS:GetGuildInfo()
  epgp_stanza = string.format(
    "-EPGP-\n@DECAY_P:%d\n@EXTRAS_P:%s\n@MIN_EP:%d\n@BASE_GP:%d\n-EPGP-",
    decay_p or DEFAULT_DECAY_P,
    extras_p or DEFAULT_EXTRAS_P,
    min_ep or DEFAULT_MIN_EP,
    base_gp or DEFAULT_BASE_GP)

  -- If we have a global configuration stanza we need to replace it
  EPGP:Debug("epgp_stanza:\n%s", epgp_stanza)
  if guild_info:match("%-EPGP%-.*%-EPGP%-") then
    guild_info = guild_info:gsub("%-EPGP%-.*%-EPGP%-", epgp_stanza)
  else
    guild_info = epgp_stanza.."\n"..guild_info
  end
  EPGP:Debug("guild_info:\n%s", guild_info)
  SetGuildInfoText(guild_info)
  GuildRoster()
end

function EPGP:GetMain(name)
  return main_data[name] or name
end

function EPGP:IncMassEPBy(reason, amount)
  local awarded = {}
  local extras_amount = math.floor(global_config.extras_p * 0.01 * amount)
  for i=1,EPGP:GetNumMembers() do
    local name = EPGP:GetMember(i)
    if EPGP:IsMemberInAwardList(name) then
      local main = EPGP:GetMain(name)
      if not awarded[main] then
        local award_amount = EPGP:IsMemberInExtrasList(name) and extras_amount or amount
        awarded[EPGP:IncEPBy(name, reason, award_amount, true)] = true
      end
    end
  end
  callbacks:Fire("MassEPAward", awarded, reason, amount)
end

function EPGP:ReportErrors(outputFunc)
  for name, note in pairs(ignored) do
    outputFunc(L["Invalid officer note [%s] for %s (ignored)"]:format(
                 note, name))
  end
end

function EPGP:OnInitialize()
  db = LibStub("AceDB-3.0"):New("EPGP_DB")
  
  -- TODO(alkis): Add hooks to the modules to setup their namespaces
  -- and handle their own defaults.
  db:RegisterDefaults(
    {
      profile = {
        log = {},
        redo = {},
        last_awards = {},
        show_everyone = false,
        sort_order = "PR",
        recurring_ep_period_mins = 15,
        gptooltip = true,
        loot = true,
        auto_loot_threshold = 4,  -- Epic quality items
        whisper = true,
        boss = false,
        announce = true,
        announce_medium = "GUILD",
      }
    })
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
    -- We also need to stop any recurring EP since they should stop
    -- once a raid stops.
    self:StopRecurringEP()
  end
  DestroyStandings()
end

function CheckForGuildInfo()
  local guild = GetGuildInfo("player")
  if type(guild) == "string" then
    if db:GetCurrentProfile() ~= guild then
      db:SetProfile(guild)
    end
    EPGP.db = db
    -- Upgrade database variables
    local translation_table = {
      gp_on_tooltips = 'gptooltip',
      auto_loot = 'loot',
      auto_standby_whispers = 'whisper',
      auto_boss = 'boss',
    }
    for o,n in pairs(translation_table) do
      if db.profile[o] ~= nil then
        db.profile[n] = db.profile[o]
        db.profile[o] = nil
      end
    end
    -- Enable all modules that are supposed to be enabled
    for name, module in EPGP:IterateModules() do
      if db.profile[module:GetName()] ~= false then
        module:Enable()
      end
    end
    EPGP:CancelTimer(EPGP.GetGuildInfoTimer)
    EPGP.GetGuildInfoTimer = nil
  end
end

function EPGP:GUILD_ROSTER_UPDATE()
  if not IsInGuild() then
    for name, module in EPGP:IterateModules() do
      module:Disable()
    end
  else
    local guild = GetGuildInfo("player")
    if type(guild) == "string" then
      if db:GetCurrentProfile() ~= guild then
        db:SetProfile(guild)
      end
    end
  end
end

function EPGP:OnEnable()
  GS.RegisterCallback(self, "GuildInfoChanged", ParseGuildInfo)
  GS.RegisterCallback(self, "GuildNoteChanged", ParseGuildNote)
  GS.RegisterCallback(self, "GuildNoteDeleted", HandleDeletedGuildNote)

  self:RegisterEvent("RAID_ROSTER_UPDATE")
  self:RegisterEvent("GUILD_ROSTER_UPDATE")

  if IsInGuild() then
    self.GetGuildInfoTimer = self:ScheduleRepeatingTimer(CheckForGuildInfo, 1)
  end
end

-- Console output support
local console_levels = {
  DEBUG = 1,
  INFO = 2,
  WARNING = 3,
  ERROR = 4,
}

local prefix_for_level = {
  [1] = "(dbg): ",
  [2] = "(inf): ",
  [3] = "(wrn): ",
  [4] = "(err): ",
}

local console_level = version == '(development)' and 1 or 3

local function OutputToConsoleFormatted(lvl, fmt, ...)
  if lvl < console_level then return end
  local msg = fmt:format(...)
  EPGP:Print(prefix_for_level[lvl]..msg)
end

function EPGP:Debug(fmt, ...) OutputToConsoleFormatted(1, fmt, ...) end
function EPGP:Info(fmt, ...) OutputToConsoleFormatted(2, fmt, ...) end
function EPGP:Warning(fmt, ...) OutputToConsoleFormatted(3, fmt, ...) end
function EPGP:Error(fmt, ...) OutputToConsoleFormatted(4, fmt, ...) end

function EPGP:SetConsoleLevel(level)
  console_level = console_levels[level]
end
