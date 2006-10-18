-------------------------------------------------------------------------------
-- Roster handling code
-------------------------------------------------------------------------------

function EPGP:GetRoster()
  if (not self.roster) then
    self.roster = { }
  end
  return self.roster
end

function EPGP:GetAlts()
  if (not self.alts) then
    self.alts = { }
  end
  return self.alts
end

function EPGP:SetRoster(r)
  assert(r and type(r) == "table", "Roster is not a table!")
  self.roster = r
end

-- Reads roster from server
function EPGP:PullRoster()
  -- Figure out alts
  local alts = GetGuildInfoText() or ""
  local alts_table = self:GetAlts()
  for from, to in string.gfind(alts, "(%a+):(%a+)\n") do
    self:Debug("Adding %s as an alt for %s", to, from)
    alts_table[to] = from
  end
  -- Update roster
  for i = 1, GetNumGuildMembers(true) do
    local name, _, _, _, class, _, note, officernote, _, _ = GetGuildRosterInfo(i)
    local roster = self:GetRoster()
    if (name) then
      roster[name] = {
        class, self:PointString2Table(note), self:PointString2Table(officernote)
      }
    end
  end
end

-- Writes roster to server
function EPGP:PushRoster()
  for i = 1, GetNumGuildMembers(true) do
    local name, _, _, _, _, _, _, _, _, _ = GetGuildRosterInfo(i)
    local roster = self:GetRoster()
    if (name and roster[name]) then
      local _, ep, gp = unpack(roster[name])
      local note = self:PointTable2String(ep)
      local officernote = self:PointTable2String(gp)
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

function EPGP:GetEPGP(name)
  assert(name and type(name) == "string")
  local roster = self:GetRoster()
  assert(roster[name], "Cannot find member record to update!")
  local _, ep, gp = unpack(roster[name])
  assert(ep and gp, "Member record corrupted!")
  return ep, gp
end

function EPGP:SetEPGP(name, ep, gp)
  assert(name and type(name) == "string")
  assert(ep and type(ep) == "table")
  assert(gp and type(gp) == "table")
  local roster = self:GetRoster()
  assert(roster[name], "Cannot find member record to update!")
  local class, _, _ = unpack(roster[name])
  roster[name] = { class, ep, gp }
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
  local roster = self:GetRoster()
  for n, t in pairs(roster) do
    local name, _, ep, gp = n, unpack(t)
    table.remove(ep)
    table.insert(ep, 1, 0)
    table.remove(gp)
    table.insert(gp, 1, 0)
    self:SetEPGP(name, ep, gp)
  end
  self:PushRoster()
  self:Report("Created new raid.")
end

function EPGP:ResolveMember(member)
  local alts = self:GetAlts()
  while (alts[member]) do
    member = alts[member]
  end
  return member
end

function EPGP:AddEP2Member(member, points)
  member = self:ResolveMember(member)
  local ep, gp = self:GetEPGP(member)
  ep[1] = ep[1] + tonumber(points)
  self:SetEPGP(member, ep, gp)
  self:PushRoster()
  self:Report("Added " .. tostring(points) .. " EPs to " .. member .. ".")
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
  self:PushRoster()
  self:Report("Added " .. tostring(points) .. " GPs to " .. member .. ".")
end
