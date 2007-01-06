-------------------------------------------------------------------------------
-- Table utils
-------------------------------------------------------------------------------

function EPGP:CloneTable(t)
  assert(type(t) == "table")
  local r = { }
  for k,v in pairs(t) do
    local key = k
    if (type(key) == "table") then key = self:CloneTable(key) end
    local value = v
    if (type(value) == "table") then value = self:CloneTable(value) end
    r[key] = value
  end
  return r
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

function EPGP:GetPreviousRoster()
  local length = table.getn(self.db.profile.rosters)
  assert(length > 1)
  return self.db.profile.rosters[length-1]
end

function EPGP:HasActionsToUndo()
  return table.getn(self.db.profile.rosters) > 1
end

function EPGP:Undo()
  assert(self:HasActionsToUndo())
  local roster = self:GetPreviousRoster()
  self:SaveRoster(roster);
  self:Report("Undone last change.")
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

function EPGP:GuildRoster(no_time_check)
	local time = GetTime()
	if no_time_check or not self.last_guild_roster_time or time - self.last_guild_roster_time > 10 then
		GuildRoster()
		self.last_guild_roster_time = time
	else
		local delay = 10 + self.last_guild_roster_time - time
		self:Debug("Delaying GuildRoster() for %f secs", delay)
		self:ScheduleEvent(function() EPGP:GuildRoster() end,  delay)
	end
end

function EPGP:GUILD_ROSTER_UPDATE(local_update)
	self:Debug("Processing GUILD_ROSTER_UPDATE")
	if local_update then
		self:Debug("Detected changes; sending update to guild")
		SendAddonMessage("EPGP", "UPDATE", "GUILD")
		self:GuildRoster(true)
		return
	end
	self:LoadConfig()
  -- Get roster from server
  local roster = self:LoadRoster()
  if next(roster) then
    self:Debug("Roster changed, pushing new roster in undo queue")
    self:PushRoster(roster)
  end
  -- Rebuild options
  self.OnMenuRequest = self:BuildOptions()
  self:RefreshTablets()
end

function EPGP:CHAT_MSG_ADDON(prefix, msg, type, sender)
	self:Debug("Processing CHAT_MSG_ADDON(%s,%s,%s,%s)", prefix, msg, type, sender)
	if not prefix == "EPGP" then return end
	if sender == UnitName("player") then return end
	if msg == "UPDATE" then self:GuildRoster() end
end

function EPGP:LoadConfig()
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
  for main, alts_text in string.gmatch(text, "(%a+):([%a%s]+)\n") do
    for alt in string.gmatch(alts_text, "(%a+)") do
      if (alts[alt] ~= main) then
        alts[alt] = main
        self:Print("Added alt for %s: %s", main, alt)
      end
    end
  end
end

-- Reads roster from server
function EPGP:LoadRoster()
  self:Debug("Loading roster from server")
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
  return roster
end

-- Writes roster to server
function EPGP:SaveRoster(roster)
  for i = 1, GetNumGuildMembers(true) do
    local name, _, _, _, _, _, _, _, _, _ = GetGuildRosterInfo(i)
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

function EPGP:GetClass(roster, name)
  assert(name and type(name) == "string")
  if (not roster[name]) then
    self:Debug("Cannot find member record for member %s!", name)
    return nil
  end
  local class, _ = unpack(roster[name])
  assert(class, "Member record corrupted!")
  return class
end

function EPGP:GetEPGP(roster, name)
  assert(roster and type(roster) == "table")
  assert(name and type(name) == "string")
  if (not roster[name]) then
    self:Debug("Cannot find member record for member %s!", name)
    return nil, nil
  end
  local _, ep, gp = unpack(roster[name])
  assert(ep and gp, "Member record corrupted!")
  return ep, gp
end

-- Sets all EP/GP to 0
function EPGP:ResetEPGP()
  for i = 1, GetNumGuildMembers(true) do
    GuildRosterSetPublicNote(i, "")
    GuildRosterSetOfficerNote(i, "")
  end
  self:Report("All EP/GP are reset.")
end

function EPGP:NewRaid()
  local roster = self:CloneTable(self:GetRoster())
  for n, t in pairs(roster) do
    local name, _, ep, gp = n, unpack(t)
    table.remove(ep)
    table.insert(ep, 1, 0)
    table.remove(gp)
    table.insert(gp, 1, 0)
  end
  self:SaveRoster(roster)
  self:Report("Created new raid.")
end

function EPGP:RemoveLastRaid()
  local roster = self:CloneTable(self:GetRoster())
  for n, t in pairs(roster) do
    local name, _, ep, gp = n, unpack(t)
    table.remove(ep, 1)
    table.insert(ep, 0)
    table.remove(gp, 1)
    table.insert(gp, 0)
  end
  self:SaveRoster(roster)
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
  local roster = self:CloneTable(self:GetRoster())
  member = self:ResolveMember(member)
  local ep, gp = self:GetEPGP(roster, member)
  ep[1] = ep[1] + tonumber(points)
  self:SaveRoster(roster)
  self:Report("Added " .. tostring(points) .. " EPs to " .. member .. ".")
end

function EPGP:AddEP2Raid(points)
  if (not UnitInRaid("player")) then
    self:Print("You are not in a raid group!")
    return
  end
  local roster = self:CloneTable(self:GetRoster())
  local members = { }
  for i = 1, GetNumRaidMembers() do
    local name, _, _, _, _, _, zone, _, _ = GetRaidRosterInfo(i)
    if (zone == self.current_zone) then
      name = self:ResolveMember(name)
      local ep, gp = self:GetEPGP(roster, name)
      if (ep and gp) then
        table.insert(members, name)
        ep[1] = ep[1] + tonumber(points)
      end
    end
  end
  self:SaveRoster(roster)
  self:Report("Added " .. tostring(points) .. " EPs to " .. table.concat(members, ", "))
end

function EPGP:AddEPBonus2Raid(bonus)
  if (not UnitInRaid("player")) then
    self:Print("You are not in a raid group!")
    return
  end
  local roster = self:CloneTable(self:GetRoster())
  local members = { }
  for i = 1, GetNumRaidMembers() do
    local name, _, _, _, _, _, zone, _, _ = GetRaidRosterInfo(i)
    if (zone == self.current_zone) then
      name = self:ResolveMember(name)
      local ep, gp = self:GetEPGP(roster, name)
      if (ep and gp) then
        table.insert(members, name)
        ep[1] = math.floor(ep[1] * (1 + tonumber(bonus)))
      end
    end
  end
  self:SaveRoster(roster)
  self:Report("Added " .. tostring(bonus * 100) .. "% EP bonus to " .. table.concat(members, ", "))
end

function EPGP:AddGP2Member(member, points)
  local roster = self:CloneTable(self:GetRoster())
  member = self:ResolveMember(member)
  local ep, gp = self:GetEPGP(roster, member)
  gp[1] = gp[1] + tonumber(points)
  self:SaveRoster(roster)
  self:Report("Added " .. tostring(points) .. " GPs to " .. member .. ".")
end
