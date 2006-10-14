local EP_IDX = 1
local GP_IDX = 2

-------------------------------------------------------------------------------
-- Roster handling code
-------------------------------------------------------------------------------

-- Reads roster from server
function EPGP:PullRoster()
  -- Figure out alts
  local alts = GetGuildInfoText() or ""
  for from, to in string.gfind(alts, "(%a+):(%a+)\n") do
    self:Debug("Adding %s as an alt for %s", to, from)
    self.db.profile.alts[to] = from
  end
  -- Update roster
  for i = 1, GetNumGuildMembers(true) do
    local name, _, _, _, _, _, note, officernote, _, _ = GetGuildRosterInfo(i)
    if (name) then
      self.db.profile.roster[name] = {
        self:PointString2Table(note), self:PointString2Table(officernote)
      }
    end
  end
end

-- Writes roster to server
function EPGP:PushRoster()
  for i = 1, GetNumGuildMembers(true) do
    local name, _, _, _, _, _, _, _, _, _ = GetGuildRosterInfo(i)
    if (name and self.db.profile.roster[name]) then
      local note = self:PointTable2String(self.db.profile.roster[name][EP_IDX])
      local officernote = self:PointTable2String(self.db.profile.roster[name][GP_IDX])
      GuildRosterSetPublicNote(i, note)
      GuildRosterSetOfficerNote(i, officernote)
    end
  end
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

function EPGP:PointString2Table(s)
  if (string.len(s) == 0) then
    local EMPTY_POINTS = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 }
    return EMPTY_POINTS
  end
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
    local ss = string.format("%02s", self:Encode(v))
    assert(string.len(ss) == 2)
    s = s .. ss
  end
  return s
end

function EPGP:SumPoints(t, n, m)
  local sum = 0
  local num_raids = 0
  for k,v in pairs(t) do
    if (k > n) then break end
    sum = sum + v
    if (v > 0) then num_raids = num_raids + 1 end
  end
  if (not m) then return sum
  elseif (num_raids >= m) then return sum
  else return 0 end
end

function EPGP:GetEPGP(name)
  assert(name and type(name) == "string")
  local member = self.db.profile.roster[name]
  assert(member, "Cannot find member record to update!")
  assert(member[EP_IDX] and member[GP_IDX], "Member record corrupted!")
  return unpack(member)
end

function EPGP:SetEPGP(name, ep, gp)
  assert(name and type(name) == "string")
  assert(ep and type(ep) == "table")
  assert(gp and type(gp) == "table")
  local member = self.db.profile.roster[name]
  assert(member, "Cannot find member record to update!")
  member[EP_IDX] = ep
  member[GP_IDX] = gp
end

-- Sets all EP/GP to 0
function EPGP:ResetEPGP()
  for i = 1, GetNumGuildMembers(true) do
    GuildRosterSetPublicNote(i, "")
    GuildRosterSetOfficerNote(i, "")
  end
  GuildRoster()
  self:Report("All EP/GP are reset.")
end

function EPGP:NewRaid()
  for n, t in pairs(self.db.profile.roster) do
    local member_name, ep, gp = n, unpack(t)
    table.remove(ep)
    table.insert(ep, 1, 0)
    table.remove(gp)
    table.insert(gp, 1, 0)
    self:SetEPGP(member_name, ep, gp)
  end
  self:Report("Created new raid.")
  self:PushRoster()
end

function EPGP:ResolveMember(member)
  while (self.db.profile.alts[member]) do
    member = self.db.profile.alts[member]
  end
  return member
end

function EPGP:AddEP2Member(member, points)
  member = self:ResolveMember(member)
  local ep, gp = self:GetEPGP(member)
  ep[1] = ep[1] + tonumber(points)
  self:SetEPGP(member, ep, gp)
  self:Report("Added " .. tostring(points) .. " EPs to " .. member .. ".")
  self:PushRoster()
end

function EPGP:AddEP2Raid(points)
  local raid = { }
  for i = 1, GetNumRaidMembers() do
    local name, _, _, _, _, _, zone, _, _ = GetRaidRosterInfo(i)
    if (zone == self.current_zone) then
      self:AddEP2Member(name, points)
    end
  end
  self:PushRoster()
end

function EPGP:AddGP2Member(member, points)
  member = self:ResolveMember(member)
  local ep, gp = self:GetEPGP(member)
  gp[1] = gp[1] + tonumber(points)
  self:SetEPGP(member, ep, gp)
  self:Report("Added " .. tostring(points) .. " GPs to " .. member .. ".")
  self:PushRoster()
end

-- Builds a standings table with record:
-- name, EP, GP, PR
-- and sorted by PR
function EPGP:BuildStandingsTable()
  local t = { }
  for n, d in pairs(self.db.profile.roster) do
    local member_name, ep, gp = n, unpack(d)
    if (not self.db.profile.alts or not self.db.profile.alts[member_name]) then
      local total_ep = self:SumPoints(ep, self.db.profile.raid_window_size, self.db.profile.min_raids)
      local total_gp = self:SumPoints(gp, self.db.profile.raid_window_size)
      if (total_gp == 0) then total_gp = 1 end
      table.insert(t, { member_name, total_ep, total_gp, total_ep/total_gp })
    end
  end
  table.sort(t, function(a, b) return a[4] > b[4] end)
  return t
end

-- Builds a history table with record:
-- name, { ep1, ... }, { gp1, ... }
function EPGP:BuildHistoryTable()
  local t = { }
  for n, d in pairs(self.db.profile.roster) do
    local member_name, ep, gp = n, unpack(d)
    if (not self.db.profile.alts or not self.db.profile.alts[member_name]) then
      table.insert(t, { member_name, ep, gp })
    end
  end
  table.sort(t, function(a, b) return a[1] < b[1] end)
  return t
end
