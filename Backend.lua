local mod = EPGP:NewModule("EPGP_Backend", "AceDB-2.0", "AceEvent-2.0", "AceConsole-2.0")

mod:RegisterDB("EPGP_Backend_DB")
mod:RegisterDefaults("profile", {
  report_channel = "GUILD",
  backup_notes = {},
})

function mod:OnInitialize()
  self.cache = EPGP:GetModule("EPGP_Cache")
end

function mod:OnEnable()
  self:RegisterEvent("EPGP_CACHE_UPDATE")
end

function mod:EPGP_CACHE_UPDATE()
  local guild_name = GetGuildInfo("player")
  if guild_name ~= self:GetProfile() then self:SetProfile(guild_name) end
end

function mod:CanLogRaids()
  return CanEditOfficerNote() and CanEditPublicNote()
end

function mod:CanChangeRules()
  return IsGuildLeader() or (self:CanLogRaids() and self.cache.db.profile.flat_credentials)
end

function mod:Report(fmt, ...)
  if self.db.profile.report_channel ~= "NONE" then
    -- FIXME: Chop-off message to 255 character chunks as necessary
    local msg = string.format(fmt, ...)
    SendChatMessage("EPGP: " .. msg, self.db.profile.report_channel)
  end
end

function mod:ResetEPGP()
  for i = 1, GetNumGuildMembers(true) do
    local name = GetGuildRosterInfo(i)
    self.cache:SetMemberEPGP(name, 0, 0, 0, 0)
  end
  self.cache:SaveRoster()
  self:Report("All EP/GP are reset.")
end

function mod:NewRaid()
  local factor = 1 - self.cache.db.profile.decay_percent*0.01
  for i = 1, GetNumGuildMembers(true) do
    local name = GetGuildRosterInfo(i)
    if not self.cache:IsAlt(name) then
      local ep, tep, gp, tgp = self.cache:GetMemberEPGP(name)
      tep = math.floor((ep+tep) * factor)
      ep = 0
      tgp = math.floor((gp+tgp) * factor)
      gp = 0
      self.cache:SetMemberEPGP(name, ep, tep, gp, tgp)
    end
  end
  self.cache:SaveRoster()
  self:Report("Created new raid.")
end

function mod:AddEP2Member(name, points)
	assert(type(name) == "string")
	assert(type(points) == "number")
  local ep, tep, gp, tgp = self.cache:GetMemberEPGP(name)
  self.cache:SetMemberEPGP(name, ep+points, tep, gp, tgp)
  self.cache:SaveRoster()
  self:Report("Added %d EPs to %s.", points, name)
end

function mod:AddEP2Raid(points)
	assert(type(points) == "number")
	assert(UnitInRaid("player"))
	local members = {}
	local leader_zone = GetRealZoneText()
	for i = 1, GetNumRaidMembers() do
    local name, _, _, _, _, _, zone, _, _ = GetRaidRosterInfo(i)
    if zone == leader_zone then
      table.insert(members, name)
      local ep, tep, gp, tgp = self.cache:GetMemberEPGP(name)
      if ep then -- If the member is not in the guild we get nil
        self.cache:SetMemberEPGP(name, ep+points, tep, gp, tgp)
      end
    end
  end
  self.cache:SaveRoster()
  self:Report("Added %d EPs to %s.", points, table.concat(members, ", "))
end

function mod:DistributeEP2Raid(total_points)
	assert(type(total_points) == "number")
	assert(UnitInRaid("player"))
  local count = 0
	local leader_zone = GetRealZoneText()
	for i = 1, GetNumRaidMembers() do
    local name, _, _, _, _, _, zone, _, _ = GetRaidRosterInfo(i)
    if zone == leader_zone then
      count = count + 1
    end
  end
  local points = math.floor(total_points / count)
  self:AddEP2Raid(points)
end

function mod:AddEPBonus2Raid(bonus)
	assert(type(bonus) == "number" and bonus >= 0 and bonus <= 1)
	assert(UnitInRaid("player"))
	local members = {}
	local leader_zone = GetRealZoneText()
	for i = 1, GetNumRaidMembers() do
    local name, _, _, _, _, _, zone, _, _ = GetRaidRosterInfo(i)
    if zone == leader_zone then
      table.insert(members, name)
      local ep, tep, gp, tgp = self.cache:GetMemberEPGP(name)
      self.cache:SetMemberEPGP(name, ep*(1+bonus), tep, gp, tgp)
    end
  end
  self.cache:SaveRoster()
  self:Report("Added %d%% EP bonus to %s.", bonus * 100, table.concat(members, ", "))
end

function mod:AddGP2Member(name, points)
	assert(type(name) == "string")
	assert(type(points) == "number")
  local ep, tep, gp, tgp = self.cache:GetMemberEPGP(name)
  self.cache:SetMemberEPGP(name, ep, tep, gp+points, tgp)
  self.cache:SaveRoster()
  self:Report("Added %d GPs to %s.", points, name)
end

function mod:UpgradeEPGP(scale)
  assert(type(scale) == "number" and scale > 0, "Scaling factor should be a positive number")
  self.cache:UpgradeFromVersion1(scale)
	self.cache:SaveRoster()
	self:Report("All EP/GP are upgraded.")
end

function mod:BackupNotes()
  for i = 1, GetNumGuildMembers(true) do
    local name, _, _, _, _, _, note, officernote, _, _ = GetGuildRosterInfo(i)
    self.db.profile.backup_notes[name] = { note, officernote }
  end
  self:Print("Backed up Officer and Public notes.")
end

function mod:RestoreNotes()
  if not self.db.profile.backup_notes then return end
  for i = 1, GetNumGuildMembers(true) do
    local name = GetGuildRosterInfo(i)
    local t = self.db.profile.backup_notes[name]
    if t then
      GuildRosterSetPublicNote(i, t[1])
      GuildRosterSetOfficerNote(i, t[2])
    end
  end
  self:Print("Restored Officer and Public notes.")
end
