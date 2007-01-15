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
  assert(type(self.db.profile.roster) == "table")
  return self.db.profile.roster
end

function EPGP:SetRoster(roster)
	assert(type(roster) == "table")
	self.db.profile.roster = roster
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
end

function EPGP:GuildRoster(no_time_check)
	local time = GetTime()
	if no_time_check or not self.last_guild_roster_time or time - self.last_guild_roster_time > 10 then
		GuildRoster()
		self.last_guild_roster_time = time
	else
		local delay = 10 + self.last_guild_roster_time - time
		self:Debug("Delaying GuildRoster() for %f secs", delay)
		self:ScheduleEvent("DELAYED_GUILD_ROSTER_UPDATE", EPGP.GuildRoster, delay, self)
	end
end

function EPGP:GUILD_ROSTER_UPDATE(local_update)
	self:Debug("Processing GUILD_ROSTER_UPDATE"..tostring(local_update))
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
    self:Debug("Caching new roster information")
    self:SetRoster(roster)
	  -- Rebuild options
	  self.OnMenuRequest = self:BuildOptions()
	  self:RefreshTablets()
  end
end

function EPGP:CHAT_MSG_ADDON(prefix, msg, type, sender)
	self:Debug("Processing CHAT_MSG_ADDON(%s,%s,%s,%s)", prefix, msg, type, sender)
	if not prefix == "EPGP" then return end
	if sender == UnitName("player") then return end
	if msg == "UPDATE" then self:GuildRoster() end
end

function EPGP:LoadConfig()
  local lines = {string.split("\n", GetGuildInfoText() or "")}
	local in_block = false
  local alts = self:GetAlts()
	for _,line in pairs(lines) do
		if line == "-EPGP-" then
			in_block = not in_block
		elseif in_block then
		  -- Get options and alts
		  -- Format is:
		  --   @DECAY_P:<number>    // for decay percent (defaults to 10)
		  --   @MIN_EP:<number>     // for min eps until member can need items (defaults to 1000)
		  --   @FC                  // for flat credentials (true if specified, false otherwise)
		  --   Main:Alt1 Alt2       // Alt1 and Alt2 are alts for Main

		  -- Decay percent
			local dp = tonumber(line:match("@DECAY_P:(%d+)")) or self.DEFAULT_DECAY_PERCENT
			if dp ~= self:GetDecayPercent() then self:SetDecayPercent(dp) end
			
		  -- Min EPs
			local mep = tonumber(line:match("@MIN_EP:(%d+)")) or self.DEFAULT_MIN_EPS
		  if mep ~= self:GetMinEPs() then self:SetMinEPs(mep) end

		  -- Flat Credentials
		  local fc = line == "@FC"
		  if fc then self:SetFlatCredentials(fc) end

			-- Read in alts
		  for main, alts_text in line:gmatch("(%a+):([%a%s]+)") do
		    for alt in alts_text:gmatch("(%a+)") do
		      if (alts[alt] ~= main) then
		        alts[alt] = main
		        self:Print("Added alt for %s: %s", main, alt)
		      end
		    end
		  end
		end
	end
end

-- Reads roster from server
function EPGP:LoadRoster()
  -- Update roster
  local roster = { }
  for i = 1, GetNumGuildMembers(true) do
    local name, _, _, _, class, _, note, officernote, _, _ = GetGuildRosterInfo(i)
    if (name) then
      roster[name] = {
        class, self:ParseNote(officernote)
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
      local _, ep, tep, gp, tgp = unpack(roster[name])
      local officernote = self:EncodeNote(ep, tep, gp, tgp)
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
  if (s == "") then
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

-- Sets all EP/GP to 0
function EPGP:ResetEPGP()
  for i = 1, GetNumGuildMembers(true) do
    GuildRosterSetOfficerNote(i, self:EncodeNote(self:ParseNote("")))
  end
  self:Report("All EP/GP are reset.")
end

function EPGP:UpgradeEPGP(scale)
	assert(type(scale) == "number" and scale > 0, "Scaling factor should be a positive number")
	for i = 1, GetNumGuildMembers(true) do
  	local name, _, _, _, _, _, note, officernote, _, _ = GetGuildRosterInfo(i)
		local ept, gpt = self:PointString2Table(note), self:PointString2Table(officernote)
		assert(#ept == #gpt, "EP and GP tables are not of the same size")
		local tep = 0
		for i = #ept,1,-1 do
			tep = tep + ept[i]*scale
			tep = math.floor(tep * (1 - self:GetDecayFactor()))
		end
		local tgp = 0
		for i = #gpt,1,-1 do
			tgp = tgp + gpt[i]*scale
			tgp = math.floor(tgp * (1 - self:GetDecayFactor()))
		end
		tep, tgp = math.floor(tep), math.floor(tgp)
		self:Print("%s EP/GP: %d/%d", name, tep, tgp)
	end
	self:Report("All EP/GP are upgraded.")
end

function EPGP:NewRaid()
  local roster = self:CloneTable(self:GetRoster())
  for n, t in pairs(roster) do
		self:Debug("%s EP: %d,%d GP: %d,%d", n, t[2], t[3], t[4], t[5])
		t[3] = t[3] + t[2]
		t[2] = 0
    t[3] = math.floor(t[3] * (1 - self:GetDecayFactor()))
		t[5] = t[5] + t[4]
    t[4] = 0
		t[5] = math.floor(t[5] * (1 - self:GetDecayFactor()))
		self:Debug("%s EP: %d,%d GP: %d,%d", n, t[2], t[3], t[4], t[5])
  end
  self:SaveRoster(roster)
  self:Report("Created new raid.")
end

function EPGP:ResolveMember(member)
  local alts = self:GetAlts()
  while (alts[member]) do
    member = alts[member]
  end
  return member
end

function EPGP:AddEP2Member(name, points)
	assert(type(name) == "string")
	assert(type(points) == "number")
  local roster = self:CloneTable(self:GetRoster())
  name = self:ResolveMember(name)
  roster[name][2] = roster[name][2] + tonumber(points)
  self:SaveRoster(roster)
  self:Report("Added " .. tostring(points) .. " EPs to " .. name .. ".")
end

function EPGP:AddEP2Raid(total_points)
	assert(type(total_points) == "number")
  if (not UnitInRaid("player")) then
    self:Print("You are not in a raid group!")
    return
  end
  local roster = self:CloneTable(self:GetRoster())
  local members = { }
	local num_members = 0
  for i = 1, GetNumRaidMembers() do
    local name, _, _, _, _, _, zone, _, _ = GetRaidRosterInfo(i)
    if (zone == self.current_zone) then
			num_members = num_members + 1
		end
	end

	local points = math.floor(total_points / num_members)
  for i = 1, GetNumRaidMembers() do
    local name, _, _, _, _, _, zone, _, _ = GetRaidRosterInfo(i)
    if (zone == self.current_zone) then
      name = self:ResolveMember(name)
      if (roster[name]) then
        roster[name][2] = roster[name][2] + points
				table.insert(members, name)
      end
    end
  end
  self:SaveRoster(roster)
  self:Report("Added " .. tostring(points) .. " EPs to " .. table.concat(members, ", "))
end

function EPGP:AddEPBonus2Raid(bonus)
	assert(type(bonus) == "number" and bonus >= 0 and bonus <= 1)
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
      if (roster[name]) then
        roster[name][2] = math.floor(roster[name][2] * (1 + bonus))
				table.insert(members, name)
      end
    end
  end
  self:SaveRoster(roster)
  self:Report("Added " .. tostring(bonus * 100) .. "% EP bonus to " .. table.concat(members, ", "))
end

function EPGP:AddGP2Member(name, points)
	assert(type(name) == "string")
	assert(type(points) == "number")
  local roster = self:CloneTable(self:GetRoster())
  name = self:ResolveMember(name)
	roster[name][4] = roster[name][4] + points
  self:SaveRoster(roster)
  self:Report("Added " .. tostring(points) .. " GPs to " .. name .. ".")
end
