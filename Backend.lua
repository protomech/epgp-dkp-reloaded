local C = AceLibrary("Crayon-2.0")
local BC = AceLibrary("Babble-Class-2.2")

local mod = EPGP:NewModule("EPGP_Backend", "AceDB-2.0", "AceConsole-2.0")

mod:RegisterDB("EPGP_Backend_DB")
mod:RegisterDefaults("profile", {
  report_channel = "GUILD",
  backup_notes = {},
})

function mod:OnInitialize()
  self.cache = EPGP:GetModule("EPGP_Cache")
end

function mod:CanLogRaids()
  return CanEditOfficerNote() and CanEditPublicNote()
end

function mod:CanChangeRules()
  return IsGuildLeader() or (self:CanLogRaids() and self.cache.db.profile.flat_credentials)
end

function mod:Report(fmt, ...)
  -- FIXME: Chop-off message to 255 character chunks as necessary
  local msg = string.format(fmt, ...)
  SendChatMessage("EPGP: " .. msg, self.db.profile.report_channel)
end

function mod:ResetEPGP()
  for i = 1, GetNumGuildMembers(true) do
    local name = GetGuildRosterInfo(i)
    self.cache:SetMemberInfo(name, 0, 0, 0, 0)
  end
  self.cache:SaveRoster()
  self:Report("All EP/GP are reset.")
end

function mod:NewRaid()
  local factor = 1 - self.cache.db.profile.decay_percent*0.01
  for i = 1, GetNumGuildMembers(true) do
    local name = GetGuildRosterInfo(i)
    if not self.cache:IsAlt(name) then
      local ep, tep, gp, tgp = self.cache:GetMemberInfo(name)
      tep = math.floor((ep+tep) * factor)
      ep = 0
      gep = math.floor((gp+tgp) * factor)
      gp = 0
      self.cache:SetMemberInfo(name, ep, tep, gp, tgp)
    end
  end
  self.cache:SaveRoster()
  self:Report("Created new raid.")
end

function mod:AddEP2Member(name, points)
	assert(type(name) == "string")
	assert(type(points) == "number")
  local ep, tep, gp, tgp = self.cache:GetMemberInfo(name)
  self.cache:SetMemberInfo(name, ep+points, tep, gp, tgp)
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
      local ep, tep, gp, tgp = self.cache:GetMemberInfo(name)
      self.cache:SetMemberInfo(name, ep+points, tep, gp, tgp)
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
      local ep, tep, gp, tgp = self.cache:GetMemberInfo(name)
      self.cache:SetMemberInfo(name, ep*(1+bonus), tep, gp, tgp)
    end
  end
  self.cache:SaveRoster()
  self:Report("Added %d%% EP bonus to %s.", bonus * 100, table.concat(members, ", "))
end

function mod:AddGP2Member(name, points)
	assert(type(name) == "string")
	assert(type(points) == "number")
  local ep, tep, gp, tgp = self.cache:GetMemberInfo(name)
  self.cache:SetMemberInfo(name, ep, tep, gp+points, tgp)
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

function mod:BuildOptions()
  local options = {
    type = "group",
    desc = "EPGP Options",
    args = {}
  }
  
  -- Raid options
  options.args["raid"] = {
    type = "group",
    name = "+EP Raid",
    desc = "Award EPs to raid members that are zoned.",
    args = {},
    order = 1
  }

  -- Start new raid
  options.args["newraid"] = {
    type = "execute",
    name = "New Raid",
    desc = "Create a new raid and decay all past EP and GP.",
    disabled = function() return not self:CanLogRaids() end,
    func =  function() self:NewRaid() end,
    order = 2,
    confirm = true
  }

  local raid = options.args["raid"]
  -- Add EPs to Raid
  raid.args["add"] = {
    type = "text",
    name = "Add EPs to Raid",
    desc = "Add EPs to raid members that are zoned.",
    get = false,
    set = function(v) self:AddEP2Raid(tonumber(v)) end,
    usage = "<EP>",
    disabled = function() return not (self:CanLogRaids() and UnitInRaid("player")) end,
    validate = function(v)
      local n = tonumber(v)
      return n and n >= 0 and n < 100000
    end,
  }
  -- Distribute EPs to raid
  raid.args["distribute"] = {
    type = "text",
    name = "Distribute EPs to Raid",
    desc = "Distribute EPs to raid members that are zoned.",
    get = false,
    set = function(v) self:DistributeEP2Raid(tonumber(v)) end,
    usage = "<EP>",
    disabled = function() return not (self:CanLogRaids() and UnitInRaid("player")) end,
    validate = function(v)
      local n = tonumber(v)
      return n and n >= 0 and n < 1000000
    end,
  }
  -- EP% to raid
  raid.args["bonus"] = {
    type = "text",
    name = "Add bonus EP to Raid",
    desc = "Add % EP bonus to raid members that are zoned.",
    get = false,
    set = function(v) self:AddEPBonus2Raid(tonumber(v)*0.01) end,
    usage = "<Bonus%>",
    disabled = function() return not (self:CanLogRaids() and UnitInRaid("player")) end,
    validate = function(v)
      local n = tonumber(v)
      return n and n > 0 and n <= 100
    end,
  }
  -- EPs to member
  options.args["ep"] = {
    type = "group",
    name = "+EP",
    desc = "Award EPs.",
    args = {}
  }
  local ep = options.args["ep"]
	for i = 1, GetNumGuildMembers(true) do
  	local name, _, _, _, class = GetGuildRosterInfo(i)
    if (not ep.args[class]) then
      ep.args[class] = {
        type = "group",
        name = C:Colorize(BC:GetHexColor(class), class),
        desc = class .. " members",
        disabled = function() return not self:CanChangeRules() end,
        args = { }
      }
    end
    options.args["ep"].args[class].args[name] = {
      type = "text",
      name = C:Colorize(BC:GetHexColor(class), name),
      desc = "Add EPs to " .. name .. ".",
      usage = "<EP>",
      get = false,
      set = function(v) self:AddEP2Member(name, tonumber(v)) end,
      validate = function(v)
        local n = tonumber(v)
        return n and n > 0 and n <= 10000
      end,
    }
  end
  -- GPs to member
  options.args["gp"] = {
    type = "group",
    name = "+GP",
    desc = "Add GPs to member.",
    disabled = function() return not self:CanLogRaids() end,
    args = { },
  }
	for i = 1, GetNumGuildMembers(true) do
  	local name, _, _, _, class = GetGuildRosterInfo(i)
    if (not options.args["gp"].args[class]) then
      options.args["gp"].args[class] = {
        type = "group",
        name = C:Colorize(BC:GetHexColor(class), class),
        desc = class .. " members",
        disabled = function() return not self:CanLogRaids() end,
        args = { }
      }
    end
    options.args["gp"].args[class].args[name] = {
      type = "text",
      name = C:Colorize(BC:GetHexColor(class), name),
      desc = "Add GPs to " .. name .. ".",
      usage = "<GP>",
      get = false,
      set = function(v) self:AddGP2Member(name, tonumber(v)) end,
      validate = function(v)
        local n = tonumber(v)
        return n and n > 0 and n <= 10000
      end,
    }
  end

  -- Reporting channel
  options.args["channel"] = {
    type = "text",
    name = "Channel",
    desc = "Channel used by reporting functions.",
    get = function() return self.db.profile.report_channel end,
    set = function(v) self.db.profile.report_channel = v end,
    validate = { "PARTY", "RAID", "GUILD", "OFFICER" },
    order = 1000,
  }
  -- Reset EPGP data
  options.args["reset"] = {
    type = "execute",
    name = "Reset EPGP",
    desc = "Reset all EPGP data.",
    guiHidden = true,
    disabled = function() return not self:CanChangeRules() end,
    func = function() self:ResetEPGP() end
  }
  -- Upgrade EPGP data
  options.args["upgrade"] = {
  	type = "text",
  	name = "Upgrade EPGP",
  	desc = "Upgrade EPGP to new format and scale them by <scale>.",
  	usage = "<scale>",
  	get = false,
  	set = function(v) self:UpgradeEPGP(tonumber(v)) end,
    validate = function(v)
      local n = tonumber(v)
      return n and n > 0 and n <= 1000
    end,
  	guiHidden = true,
  	disabled = function() return not self:CanChangeRules() end
  }
  -- Backup notes
  options.args["backup"] = {
    type = "execute",
    name = "Backup",
    desc = "Backup public and officer notes and replace last backup.",
    func = function() self:BackupNotes() end,
  }
  -- Restore notes
  options.args["restore"] = {
    type = "execute",
    name = "Restore",
    desc = "Restores public and officer notes from last backup.",
    disabled = function() return not self:CanLogRaids() end,
    func = function() self:RestoreNotes() end,
    confirm = true
  }
  return options
end
