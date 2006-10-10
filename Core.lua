EPGP = AceLibrary("AceAddon-2.0"):new("AceConsole-2.0", "AceDB-2.0", "AceDebug-2.0", "AceEvent-2.0", "FuBarPlugin-2.0")

-------------------------------------------------------------------------------
-- DB defaults
-------------------------------------------------------------------------------
EPGP:RegisterDB("EPGP_DB")
EPGP:RegisterDefaults("profile", {
  -- The raid_window size on which we count EPs and GPs.
  -- Anything out of the window will not be taken into account.
  raid_window_size = 10
})

-------------------------------------------------------------------------------
-- Init code
-------------------------------------------------------------------------------
function EPGP:OnInitialize()
  self:SetDebugging(true)
  self.defaultMinimapPosition = 180
  self.OnMenuRequest = self:BuildOptions()
  self:RegisterChatCommand({ "/epgp" }, self.OnMenuRequest)
end

function EPGP:OnEnable()
  self:Print("EPGP addon is enabled")
  GuildRoster() -- Fetch the most up to date Guild Roster
  self:RegisterEvent("GUILD_ROSTER_UPDATE")
  self.current_zone = GetRealZoneText()
  self:RegisterEvent("ZONE_CHANGED_NEW_AREA")
end

function EPGP:GUILD_ROSTER_UPDATE()
  -- Fetch the most up to date Guild Roster
  GuildRoster() 
  -- Rebuild options
  self.OnMenuRequest = self:BuildOptions()
end

function EPGP:ZONE_CHANGED_NEW_AREA()
  self.current_zone = GetRealZoneText()
end

function EPGP:OnDisable()

end

function EPGP:CanLogRaids()
  return CanEditOfficerNote() and CanEditPublicNote()
end

function EPGP:CanChangeRules()
  return IsGuildLeader()
end

-- Builds an AceOptions table for the options
function EPGP:BuildOptions()
  -- Set up raid tracking options
  local options = {
    type = "group",
    desc = "EPGP Options",
    args = { }
  }
  options.args["standings"] = {
    type = "execute",
    name = "Report standings",
    desc = "Report standings in guild chat channel.",
    order = 1,
    func = function() self:ReportStandings() end
  }
  options.args["history"] = {
    type = "execute",
    name = "Report raid history",
    desc = "Report raid history in guild chat channel.",
    order = 1,
    func = function() self:ReportHistory() end
  }
  options.args["ep_raid"] = {
    type = "text",
    name = "+EPs to Raid",
    desc = "Award EPs to raid members that are zoned.",
    get = false,
    set = function(v) self:AddEP2Raid(tonumber(v)) end,
    usage = "<EP>",
    order = 2,
    disabled = function() return not self:CanLogRaids() end,
    validate = function(v) return (type(v) == "number" or tonumber(v)) and tonumber(v) < 4096 end
  }
  options.args["ep"] = {
    type = "group",
    name = "+EPs to Member",
    desc = "Award EPs to member.",
    order = 1,
    disabled = function() return not self:CanChangeRules() end,
    args = { }
  }
  for i = 1, GetNumGuildMembers() do
    local member_name, _, _, _, _, _, _, _, _, _ = GetGuildRosterInfo(i)
    options.args["ep"].args[member_name] = {
      type = "text",
      name = member_name,
      desc = "Award EPs to " .. member_name .. ".",
      usage = "<EP>",
      get = false,
      set = function(v) self:AddEP2Member(member_name, tonumber(v)) end,
      validate = function(v) return (type(v) == "number" or tonumber(v)) and tonumber(v) < 4096 end
    }
  end
  options.args["gp"] = {
    type = "group",
    name = "+GPs to Member",
    desc = "Account GPs for member.",
    order = 3,
    disabled = function() return not self:CanLogRaids() end,
    args = { }
  }
  for i = 1, GetNumGuildMembers() do
    local member_name, _, _, _, _, _, _, _, _, _ = GetGuildRosterInfo(i)
    options.args["gp"].args[member_name] = {
      type = "text",
      name = member_name,
      desc = "Account GPs to " .. member_name .. ".",
      usage = "<GP>",
      get = false,
      set = function(v) self:AddGP2Member(member_name, tonumber(v)) end,
      validate = function(v) return (type(v) == "number" or tonumber(v)) and tonumber(v) < 4096 end
    }
  end

  -----------------------------------------------------------------------------
  -- Administrative options
  options.args["newraid"] = {
    type = "execute",
    name = "Create New Raid",
    desc = "Create a new raid slot.",
    order = 1001,
    disabled = function() return not self:CanLogRaids() end,
    func =  function() self:NewRaid() end 
  }
  options.args["window_size"] = {
    type = "range",
    name = "EP/GP Raid Window Size",
    desc = "The number of raids back to be accounted for EP/GP calculations.",
    min = 5,
    max = 15,
    step = 1,
    order = 1002,
    disabled = function() return not self:CanChangeRules() end,
    get = function() return self.db.profile.raid_window_size end,
    set = function(v) self.db.profile.raid_window_size = v end
  }
  options.args["reset"] = {
    type = "execute",
    name = "Reset EPGP",
    desc = "Resets all EPGP data.",
    order = 9999,
    guiHidden = true,
    disabled = function() return not self:CanChangeRules() end,
    func = function() EPGP:ResetEPGP() end
  }
  return options
end


-------------------------------------------------------------------------------
-- EP/GP manipulation
--
-- We use public/officers notes to keep track of EP/GP. Each note has storage
-- for a string of max length of 31. So with two bytes for each score, we can
-- have up to 15 numbers in it, which gives a max raid window of 15.
--
-- NOTE: Each number is in hex which means that we can have max 256 GP/EP for
-- each raid. This needs to be improved to raise the limit.
--
-- EPs are stored in the public note. The first byte is the EPs gathered for
-- the current raid. The second is the EPs gathered in the previous raid (of
-- the guild not the membeer). Ditto for the rest.
--
-- GPs are stored in the officers note, in a similar manner as the EPs.
--
-- Bonus EPs are added to the last/current raid.

local EMPTY_POINTS = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 }

function EPGP:PointString2Table(s)
  local t = { }
  for i = 1, string.len(s), 2 do
    local val = self:Decode(string.sub(s, i, i+1))
    table.insert(t, val)
  end
  return t
end

function EPGP:PointTable2String(t)
  local s = ""
  for k, v in pairs(t) do
  self:Print(v)
    local ss = string.format("%02s", self:Encode(v))
    assert(string.len(ss) == 2)
    s = s .. ss
  end
  return s
end

function EPGP:SumPoints(t, n)
  local sum = 0
  for k,v in pairs(t) do
    if (k <= n) then
      sum = sum + v
    end
  end
  return sum
end

function EPGP:GetEPGP(i)
  local name, _, _, _, _, _, note, officernote, _, _ = GetGuildRosterInfo(i)
  if (string.len(note) == 0 and string.len(officernote) == 0) then
    self:SetEPGP(i, EMPTY_POINTS, EMPTY_POINTS)
    name, _, _, _, _, _, note, officernote, _, _ = GetGuildRosterInfo(i)
  end
  return name, self:PointString2Table(note), self:PointString2Table(officernote)
end

function EPGP:SetEPGP(i, ep, gp)
  GuildRosterSetPublicNote(i, self:PointTable2String(ep))
  GuildRosterSetOfficerNote(i, self:PointTable2String(gp))
end

-- Sets all EP/GP to 0
function EPGP:ResetEPGP()
  for i = 1, GetNumGuildMembers(true) do
    self:SetEPGP(i, EMPTY_POINTS, EMPTY_POINTS)
  end
  self:Report("All EP/GP are reset.")
end

function EPGP:AddEP2Member(member, points)
  for i = 1, GetNumGuildMembers(true) do
    local name, ep, gp = self:GetEPGP(i)
    if (name == member) then
      ep[1] = ep[1] + tonumber(points)
      self:SetEPGP(i, ep, gp)
      self:Report("Added " .. tostring(points) .. " EPs to " .. member .. ".")
    end
  end
end

function EPGP:AddEP2Raid(points)
  local raid = { }
  for i = 1, GetNumRaidMembers() do
    local name, _, _, _, _, _, zone, _, _ = GetRaidRosterInfo(i)
    if (zone == self.current_zone) then
      raid[name] = true
    end
  end
  
  for i = 1, GetNumGuildMembers(true) do
    local name, ep, gp = self:GetEPGP(i)
    if (raid[name]) then
        ep[1] = ep[1] + tonumber(points)
        self:SetEPGP(i, ep, gp)
        self:Report("Added " .. tostring(points) .. " EPs to " .. member .. ".")
    end
  end
end

function EPGP:AddGP2Member(member, points)
  for i = 1, GetNumGuildMembers(true) do
    local name, ep, gp = self:GetEPGP(i)
    if (name == member) then
      gp[1] = gp[1] + tonumber(points)
      self:SetEPGP(i, ep, gp)
      self:Report("Added " .. tostring(points) .. " GPs to " .. member .. ".")
    end
  end
end

function EPGP:Report(msg)
  SendChatMessage("EPGP: " .. msg, "GUILD")
end

function EPGP:NewRaid()
  for i = 1, GetNumGuildMembers(true) do
    local _, ep, gp = self:GetEPGP(i)
    table.remove(ep)
    table.insert(ep, 1, 0)
    table.remove(gp)
    table.insert(gp, 1, 0)
    self:SetEPGP(i, ep, gp)
  end
  self:Report("Created new raid.")
end

-- Builds a standings table with record:
-- name, EP, GP, PR
-- and sorted by PR
function EPGP:BuildStandingsTable()
  local t = { }
  for i = 1, GetNumGuildMembers(true) do
    local name, ep, gp = self:GetEPGP(i)
    local total_ep = self:SumPoints(ep, self.db.profile.raid_window_size)
    local total_gp = self:SumPoints(gp, self.db.profile.raid_window_size)
    if (total_gp == 0) then total_gp = 1 end
    table.insert(t, { name, total_ep, total_gp, total_ep/total_gp })
  end
  table.sort(t, function(a, b) return a[4] > b[4] end)
  return t
end

-- Builds a history table with record:
-- name, { ep1, ... }, { gp1, ... }
function EPGP:BuildHistoryTable()
  local t = { }
  for i = 1, GetNumGuildMembers(true) do
    table.insert(t, { self:GetEPGP(i) })
  end
  table.sort(t, function(a, b) return a[1] < b[1] end)
  return t
end

function EPGP:ReportStandings()
  local t = self:BuildStandingsTable()
  self:Report("Standings (Name: EP/GP=PR)")
  for i = 1, table.getn(t) do
    self:Report(string.format("%s: %d/%d=%.4g", unpack(t[i])))
  end
end

function EPGP:ReportHistory()
  local t = self:BuildHistoryTable()
  self:Report("History (Name: EP/GP ...)")
  for i = 1, table.getn(t) do
    local record = t[i]
    local history = record[1] .. ": "
    for j = 1, table.getn(record[2]) do
      history = history .. record[2][j] .. "/" .. record[3][j] .. " "
    end
    self:Report(history)
  end
end

-------------------------------------------------------------------------------
-- UI code
-------------------------------------------------------------------------------
local Tablet = AceLibrary("Tablet-2.0")
local Dewdrop = AceLibrary("Dewdrop-2.0")

function EPGP:OnTooltipUpdate()
end
