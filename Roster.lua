-- Lua 5.1 compatibility fix
local string_gmatch = string.gmatch or string.gfind

-------------------------------------------------------------------------------
-- Table utils
-------------------------------------------------------------------------------

-- This will not terminate if o1 or o2 are recursive datastructures
function EPGP:Equal(o1, o2)
  if (o1 == o2) then return true end
  if (type(o1) ~= "table" or type(o2) ~= "table") then return false end
  return self:TableContains(o1, o2) and self:TableContains(o2, o1)
end

-- This will not terminate if o1 or o2 are recursive datastructures
function EPGP:TableContains(t1, t2)
  if (type(t1) ~= "table" or type(t2) ~= "table") then return false end
  for k,v in pairs(t1) do
    if (not self:Equal(v, t2[k])) then return false end
  end
  return true
end

function EPGP:TableEmpty(t1)
  assert(type(t1) == "table")
  local f, s, v = pairs(t1)
  return not f(s, v)
end

-------------------------------------------------------------------------------
-- Roster handling code
-------------------------------------------------------------------------------
function EPGP:GetRoster()
  if (not self.db.profile.rosters or
      not type(self.db.profile.rosters) == "table") then
    self.db.profile.rosters = { }
  end
  local length = table.getn(self.db.profile.rosters)
  if (length == 0) then
    length = 1
    self.db.profile.rosters[length] = { }
  end
  return self.db.profile.rosters[length]
end

function EPGP:PushRoster(roster)
  assert(type(roster) == "table")
  table.insert(self.db.profile.rosters, roster)
  local MAX_UNDO_QUEUE = 10
  while (table.getn(self.db.profile.rosters) > MAX_UNDO_QUEUE) do
    table.remove(self.db.profile.rosters, 1)
  end
end

function EPGP:GetAlts()
  if (not self.alts) then
    self.alts = { }
  end
  return self.alts
end

function EPGP:GetStandingsIterator()
  local i = 1
  if (self.db.profile.raid_mode and UnitInRaid("player")) then
    local e = GetNumRaidMembers()
    return function()
      local name, _ = GetRaidRosterInfo(i)
      i = i + 1
      return name
    end
  else
    local alts = self:GetAlts()
    return function()
      local name, _
      repeat
        name, _ = GetGuildRosterInfo(i)
        i = i + 1
      until (self.db.profile.show_alts or not alts[name])
      return name
    end
  end
end

function EPGP:RefreshTablets()
  EPGP_Standings:Refresh()
  EPGP_History:Refresh()
end

function EPGP:EPGP_LOAD_ROSTER()
  -- Cache roster
  self:LoadRoster()
  -- Rebuild options
  self.OnMenuRequest = self:BuildOptions()
  self:RefreshTablets()
end

-- Reads roster from server
function EPGP:LoadRoster()
  local text = GetGuildInfoText() or ""
  -- Get options and alts
  -- Format is:
  --   @RW:<number>    // for raid window (defaults to 10)
  --   @NR:<number>    // for min raids (defaults to 2)
  --   @FC             // for flat credentials (true if specified, false otherwise)
  --   Main:Alt1 Alt2  // Alt1 and Alt2 are alts for Main

  -- Raid Window
  local _, _, rw = string.find(text, "@RW:(%d+)\n")
  if (not rw) then rw = self.DEFAULT_RAID_WINDOW end
  if (rw ~= self:GetRaidWindow()) then self:SetRaidWindow(rw) end

  -- Min Raids
  local _, _, mr = string.find(text, "@MR:(%d)\n")
  if (not mr) then mr = self.DEFAULT_MIN_RAIDS end
  if (mr ~= self:GetMinRaids()) then self:SetMinRaids(mr) end
  
  -- Flat Credentials
  local fc = (string.find(text, "@FC\n") and true or false)
  if (fc ~= self:IsFlatCredentials()) then self:SetFlatCredentials(fc) end
  
  local alts = self:GetAlts()
  for main, alts_text in string_gmatch(text, "(%a+):([%a%s]+)\n") do
    for alt in string_gmatch(alts_text, "(%a+)") do
      if (alts[alt] ~= main) then
        alts[alt] = main
        self:Print("Added alt for %s: %s", main, alt)
      end
    end
  end
  -- Update roster
  local roster = { }
  for i = 1, GetNumGuildMembers(true) do
    local name, _, _, _, class, _, note, officernote, _, _ = GetGuildRosterInfo(i)
    if (name) then
      roster[name] = {
        class, self:PointString2Table(note), self:PointString2Table(officernote)
      }
    end
  end
  self:Debug("roster empty: %s equal: %s",
             self:TableEmpty(roster), self:Equal(roster, self:GetRoster()))
  if (not self:TableEmpty(roster) and
      not self:Equal(roster, self:GetRoster())) then
    self:PushRoster(roster)
  end
  GuildRoster()
end

-- Writes roster to server
function EPGP:SaveRoster()
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

function EPGP:GetClass(name)
  assert(name and type(name) == "string")
  local roster = self:GetRoster()
  if (not roster[name]) then
    self:Debug("Cannot find member record for member %s!", name)
    return nil
  end
  local class, _ = unpack(roster[name])
  assert(class, "Member record corrupted!")
  return class
end

function EPGP:GetEPGP(name)
  assert(name and type(name) == "string")
  local roster = self:GetRoster()
  if (not roster[name]) then
    self:Debug("Cannot find member record for member %s!", name)
    return nil, nil
  end
  local _, ep, gp = unpack(roster[name])
  assert(ep and gp, "Member record corrupted!")
  return ep, gp
end

function EPGP:SetEPGP(name, ep, gp)
  assert(name and type(name) == "string")
  assert(ep and type(ep) == "table")
  assert(gp and type(gp) == "table")
  local roster = self:GetRoster()
  if (not roster[name]) then
    self:Print("Cannot find member record to update for member %s!", name)
    return
  end
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
  self:SaveRoster()
  self:Report("Created new raid.")
end

function EPGP:RemoveLastRaid()
  local roster = self:GetRoster()
  for n, t in pairs(roster) do
    local name, _, ep, gp = n, unpack(t)
    table.remove(ep, 1)
    table.insert(ep, 0)
    table.remove(gp, 1)
    table.insert(gp, 0)
    self:SetEPGP(name, ep, gp)
  end
  self:SaveRoster()
  self:Report("Removed last raid.")
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
  self:SaveRoster()
  self:Report("Added " .. tostring(points) .. " EPs to " .. member .. ".")
end

function EPGP:AddEP2Raid(points)
  if (not UnitInRaid("player")) then
    self:Print("You are not in a raid group!")
    return
  end
  local members = { }
  for i = 1, GetNumRaidMembers() do
    local name, _, _, _, _, _, zone, _, _ = GetRaidRosterInfo(i)
    if (zone == self.current_zone) then
      name = self:ResolveMember(name)
      local ep, gp = self:GetEPGP(name)
      if (ep and gp) then
        table.insert(members, name)
        ep[1] = ep[1] + tonumber(points)
        self:SetEPGP(name, ep, gp)
      end
    end
  end
  self:SaveRoster()
  self:Report("Added " .. tostring(points) .. " EPs to " .. table.concat(members, ", "))
end

function EPGP:AddEPBonus2Raid(bonus)
  if (not UnitInRaid("player")) then
    self:Print("You are not in a raid group!")
    return
  end
  local members = { }
  for i = 1, GetNumRaidMembers() do
    local name, _, _, _, _, _, zone, _, _ = GetRaidRosterInfo(i)
    if (zone == self.current_zone) then
      name = self:ResolveMember(name)
      local ep, gp = self:GetEPGP(name)
      if (ep and gp) then
        table.insert(members, name)
        ep[1] = math.floor(ep[1] * (1 + tonumber(bonus)))
        self:SetEPGP(name, ep, gp)
      end
    end
  end
  self:SaveRoster()
  self:Report("Added " .. tostring(bonus * 100) .. "% EP bonus to " .. table.concat(members, ", "))
end

function EPGP:AddGP2Member(member, points)
  member = self:ResolveMember(member)
  local ep, gp = self:GetEPGP(member)
  gp[1] = gp[1] + tonumber(points)
  self:SetEPGP(member, ep, gp)
  self:SaveRoster()
  self:Report("Added " .. tostring(points) .. " GPs to " .. member .. ".")
end
