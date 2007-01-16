local mod = EPGP:NewModule("EPGP_Backend", "AceDB-2.0")

mod:RegisterDB("EPGP_Backend_DB")
mod:RegisterDefaults("profile", {
  report_channel = "GUILD",
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
  self:Report("Added " .. tostring(points) .. " EPs to " .. name .. ".")
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
  self:Report("Added " .. tostring(points) .. " EPs to " .. table.concat(members, ", ") .. ".")
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
  self:Report("Added " .. tostring(bonus * 100) .. "% EP bonus to " .. table.concat(members, ", ") .. ".")
end

function mod:AddGP2Member(name, points)
	assert(type(name) == "string")
	assert(type(points) == "number")
  local ep, tep, gp, tgp = self.cache:GetMemberInfo(name)
  self.cache:SetMemberInfo(name, ep, tep, gp+points, tgp)
  self.cache:SaveRoster()
  self:Report("Added " .. tostring(points) .. " GPs to " .. name .. ".")
end

function mod:UpgradeEPGP(scale)
  assert(type(scale) == "number" and scale > 0, "Scaling factor should be a positive number")
  self.cache:UpgradeFromVersion1(scale)
	self.cache:SaveRoster()
	self:Report("All EP/GP are upgraded.")
end

function mod:BuildOptions()
  local options = {
    type = "group",
    desc = "EPGP Options",
    args = { }
  }
  -- EPs to raid
  options.args["ep_raid"] = {
    type = "text",
    name = "+EPs to Raid",
    desc = "Award EPs to raid members that are zoned.",
    get = false,
    set = function(v) self:AddEP2Raid(tonumber(v)) end,
    usage = "<EP>",
    disabled = function() return not (self:CanLogRaids() and UnitInRaid("player")) end,
    validate = function(v)
      local n = tonumber(v)
      return n and n >= 0 and n < 100000
    end,
    order = 1
  }
  -- distribute EPs to raid
  options.args["ep_raid_distr"] = {
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
    order = 1
  }
  -- EP% to raid
  options.args["ep_bonus_raid"] = {
    type = "text",
    name = "+Bonus EP to Raid",
    desc = "Award % EP bonus to raid members that are zoned.",
    get = false,
    set = function(v) self:AddEPBonus2Raid(tonumber(v)*0.01) end,
    usage = "<Bonus%>",
    disabled = function() return not (self:CanLogRaids() and UnitInRaid("player")) end,
    validate = function(v)
      local n = tonumber(v)
      return n and n > 0 and n <= 100
    end,
    order = 2
  }
  -- EPs to member
  options.args["ep"] = {
    type = "group",
    name = "+EPs to Member",
    desc = "Award EPs to member.",
    disabled = function() return not self:CanChangeRules() end,
    args = { },
    order = 3,
  }
	for i = 1, GetNumGuildMembers(true) do
  	local name, _, _, _, class = GetGuildRosterInfo(i)
    if (not options.args["ep"].args[class]) then
      options.args["ep"].args[class] = {
        type = "group",
        name = class,
        desc = class .. " members",
        disabled = function() return not self:CanChangeRules() end,
        args = { }
      }
    end
    options.args["ep"].args[class].args[name] = {
      type = "text",
      name = name,
      desc = "Award EPs to " .. name .. ".",
      usage = "<EP>",
      get = false,
      set = function(v) self:AddEP2Member(name, tonumber(v)) end,
      validate = function(v)
        local n = tonumber(v)
        return n and n > 0 and n <= 10000
      end,
      order = 3
    }
  end
  -- GPs to member
  options.args["gp"] = {
    type = "group",
    name = "+GPs to Member",
    desc = "Account GPs for member.",
    disabled = function() return not self:CanLogRaids() end,
    args = { },
    order = 4
  }
	for i = 1, GetNumGuildMembers(true) do
  	local name, _, _, _, class = GetGuildRosterInfo(i)
    if (not options.args["gp"].args[class]) then
      options.args["gp"].args[class] = {
        type = "group",
        name = class,
        desc = class .. " members",
        disabled = function() return not self:CanLogRaids() end,
        args = { }
      }
    end
    options.args["gp"].args[class].args[name] = {
      type = "text",
      name = name,
      desc = "Account GPs to " .. name .. ".",
      usage = "<GP>",
      get = false,
      set = function(v) self:AddGP2Member(name, tonumber(v)) end,
      validate = function(v)
        local n = tonumber(v)
        return n and n > 0 and n <= 10000
      end,
    }
  end

  -- Start new raid
  options.args["newraid"] = {
    type = "execute",
    name = "Create New Raid",
    desc = "Create a new raid and decay all past EP/GP.",
    order = 1001,
    disabled = function() return not self:CanLogRaids() end,
    func =  function() self:NewRaid() end,
    confirm = true
  }
  -- Reporting channel
  options.args["report_channel"] = {
    type = "text",
    name = "Reporting channel",
    desc = "Channel used by reporting functions.",
    get = function() return self.db.profile.report_channel end,
    set = function(v) self.db.profile.report_channel = v end,
    validate = { "PARTY", "RAID", "GUILD", "OFFICER" },
    order = 1002
  }
  -- Reset EPGP data
  options.args["reset"] = {
    type = "execute",
    name = "Reset EPGP",
    desc = "Resets all EPGP data.",
    guiHidden = true,
    disabled = function() return not self:CanChangeRules() end,
    func = function() self:ResetEPGP() end
  }
  -- Upgrade EPGP data
  options.args["upgrade"] = {
  	type = "text",
  	name = "Upgrades EPGP",
  	desc = "Upgrades EPGP to new format and scales them by <scale>",
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
  return options
end
