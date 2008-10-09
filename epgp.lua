-- This is the core addon. It implements all functions dealing with
-- administering and configuring EPGP. It implements the following
-- functions:
--
-- GetIter():
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

EPGP = LibStub:GetLibrary("AceAddon-3.0"):NewAddon(
  "EPGP", "AceEvent-3.0", "AceConsole-3.0")
local EPGP = EPGP
local GS = LibStub:GetLibrary("LibGuildStorage-1.0")
local AceDB = LibStub:GetLibrary("AceDB-3.0")
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
          min_ep = mep
        else
          EPGP:Print(L["Min EP should be a positive number"])
        end
      end

      -- Base GP
      local bgp = tonumber(line:match("BASE_GP:(%d+)"))
      if bgp then
        if bgp >= 0 then
          base_gp = bgp
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

-- REMOVE THIS AFTER 3.0 PATCH
local function CalendarGetDate()
  local t = date("!*t")
  return t.wday, t.day, t.month, t.year
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
end

local function LogRecordToString(record)
  local timestamp, kind, src, dst, reason, amount = unpack(record)

  if kind == "EP" then
    return string.format("%s: %s awards %d EP to %s for %s",
                         date("%c", timestamp), src, amount, dst, reason)
  elseif kind == "GP" then
    return string.format("%s: %s credits %d GP to %s for %s",
                         date("%c", timestamp), src, amount, dst, reason)
  else
    assert(false, "Unknown record in the log")
  end
end

local comparators = {
  NAME = function(a, b)
           return a < b
         end,
  EP = function(a, b)
         local a_ep, b_ep = ep_data[a] or 0, ep_data[b] or 0
         return a_ep > b_ep
       end,
  GP = function(a, b)
         local a_gp, b_gp = gp_data[a] or 0, gp_data[b] or 0
         return a_gp > b_gp
       end,
  PR = function(a, b)
         -- TODO(alkis): Fix MIN_EP computation
         local a_ep, b_ep = ep_data[a] or 0
         local b_ep = ep_data[b] or 0
         local a_gp = gp_data[a] + base_gp or base_gp
         local b_gp = gp_data[b] + base_gp or base_gp
         return a_ep/a_gp > b_ep/b_gp
       end,
}

local function Iter(t)
  local n = t.n + 1
  t.n = n
  return t[n]
end

function EPGP:GetIter(sortName)
  local comparator = comparators[sortName]
  local t = {}
  -- Main toons.
  for n in pairs(ep_data) do
    table.insert(t, n)
  end
  -- Alt toons.
  for n in pairs(main_data) do
    table.insert(t, n)
  end

  if comparator then
    table.sort(t, comparator)
  end
  t.n = 0

  return Iter, t, nil
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

  return true
end

function EPGP:OnInitialize()
  player = UnitName("player")
  db = AceDB:New("EPGP_DB", {
                   ["profile"] = {
                     ["log"] = {}
                   }
                 })
  GS:RegisterCallback("GuildInfoChanged", ParseGuildInfo)
  GS:RegisterCallback("GuildNoteChanged", ParseGuildNote)
end
