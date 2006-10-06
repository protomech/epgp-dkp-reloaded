EPGP = AceLibrary("AceAddon-2.0"):new("AceConsole-2.0", "AceDB-2.0", "AceDebug-2.0", "AceEvent-2.0", "FuBarPlugin-2.0")

EPGP:RegisterDB("EPGP_DB")

function EPGP:OnInitialize()
  self:SetDebugging(true)
  self.defaultMinimapPosition = 250
  self.clickableTooltyp = true
  local guild_name, guild_rank_name, guild_rank_index = GetGuildInfo("player")
  if (not guild_name or self:IsDebugging()) then
    guild_name = "EPGP_testing_guild"
  end
  self:SetProfile(guild_name)
  self.defaultMinimapPosition = 250
  self.clickableTooltip = true
  self.OnMenuRequest = self:BuildOptions()
  self:RegisterChatCommand({ "/epgp" }, self.OnMenuRequest)
end

function EPGP:OnEnable()
  -- Keep track of current zone
  self.current_zone = GetRealZoneText()
  self:RegisterEvent("ZONE_CHANGED_NEW_AREA")

  -- Keep track of raid ranks
  self:RegisterEvent("RAID_ROSTER_UPDATE", "Reconfigure", 1)
  self:RegisterEvent("PARTY_MEMBERS_CHANGED", "Reconfigure", 1)

  self:Print("EPGP addon is enabled")
  self:Reconfigure()
end

function EPGP:OnDisable()

end

function EPGP:CanTrackRaid()
  return self.track_raid
end

function EPGP:CanChangeRules()
  return IsGuildLeader() or self:IsDebugging()
end

-- Builds an AceOptions table for the options
-- Passing true generates options suitable for a command line
function EPGP:BuildOptions()
  -- Set up raid tracking options
  local options = {
    type = "group",
    desc = "EPGP Options",
    args = { }
  }
  options.args["startraid"] = {
    type = "execute",
    name = "Start Tracking Raid",
    desc = "Starts tracking this raid and marks the current zone.",
    order = 1,
    disabled = function() return not self:CanTrackRaid() end,
    func =  function() EPGP:StartTracking() end 
  }
  options.args["endraid"] = {
    type = "execute",
    name = "Stop Traking Raid",
    desc = "Stops tracking this raid.",
    order = 2,
    disabled = function() return not self:CanTrackRaid() end,
    func =  function() EPGP:StopTracking() end 
  }
  options.args["newraid"] = {
    type = "execute",
    name = "Create New Raid",
    desc = "Create a new raid and start tracking it.",
    order = 3,
    disabled = function() return not self:CanTrackRaid() end,
    func =  function() EPGP:NewRaid() end 
  }
  -- Setup window size
  options.args["window_size"] = {
    type = "range",
    name = "EP/GP Raid Window Size",
    desc = "The number of raids back to be accounted for EP/GP calculations.",
    min = 10,
    max = 100,
    step = 1,
    disabled = function() return not self:CanChangeRules() end,
    get = function() return self.db.profile.raid_window_size end,
    set = function(v) self.db.profile.raid_window_size = v end
  }
  -- Setup bosses options
	options.args["bosses"] = {
	  type = "group",
	  name = "Bosses",
	  desc = "Effort points given for succesful boss kills.",
	  args = { }
	}
  for k, v in pairs(self.db.profile.bosses) do
    local key = k
    local cmd = string.gsub(k, "%s", "_")
    options.args["bosses"].args[cmd] = {
      type = "range",
      name = key,
      desc = "Effort points given for succesful kill.",
      min = 0,
      max = 100,
      step = 1,
      disabled = function() return not self:CanChangeRules() end,
      get = function() return self:GetBossEP(key) end,
      set = function(v) self:SetBossEP(key, v) end
    }
  end
  -- Setup zones options
	options.args["zones"] = {
	  type = "group",
	  name = "Zones",
	  desc = "Gear Point multipliers for the drops of each zone.",
	  args = { }
	}
  for k, v in pairs(self.db.profile.zones) do
    local key = k
    local cmd = string.gsub(k, "%s", "_")
    options.args["zones"].args[cmd] = {
      type = "range",
      name = key,
      desc = "Gear Point multiplier for drops in this zone.",
      min = 0,
      max = 10,
      step = 0.1,
      disabled = function() return not self:CanChangeRules() end,
      get = function() return self.db.profile.zones[key] end,
      set = function(v) self.db.profile.zones[key] = v end
    }
  end
  -- Setup item slot options
	options.args["equip_slots"] = {
	  type = "group",
	  name = "Equipment Slots",
	  desc = "Gear Point multipliers for each equipment slot.",
	  args = { }
	}
  for k, v in pairs(self.db.profile.equip_slot) do
    local key = k
    local cmd = string.gsub(key, "%s", "_")
    options.args["equip_slots"].args[cmd] = {
      type = "range",
      name = string.gsub(key, ".*_(.*)", "%1"),
      desc = "Gear Point multiplier for items that are equipemed in this slot.",
      min = 0,
      max = 1,
      step = 0.05,
      disabled = function() return not self:CanChangeRules() end,
      get = function() return self.db.profile.equip_slot[key] end,
      set = function(v) self.db.profile.equip_slot[key] = v end
    }
  end
  -- Setup quality options
	options.args["quality"] = {
	  type = "group",
	  name = "Quality",
	  desc = "Gear Point multipliers for item quality.",
	  args = { }
	}
  for k, v in pairs(self.db.profile.quality) do
    local key = k
    local cmd = string.gsub(key, "%s", "_")
    options.args["quality"].args[cmd] = {
      type = "range",
      name = EPGP_quality_names[k],
      desc = "Gear Point multiplier for drops of this quality.",
      order = k + 1,
      min = 0,
      max = 10,
      step = 0.25,
      disabled = function() return not self:CanChangeRules() end,
      get = function() return self.db.profile.quality[key] end,
      set = function(v) self.db.profile.quality[key] = v end
    }
  end
  -- Setup base item value
  options.args["base_item_value"] = {
    type = "range",
    name = "Base item GP value",
    desc = "The base GP value of a item. The effective value is base_item_value*zone*quality*item_slot.",
    min = 10,
    max = 500,
    step = 10,
    disabled = function() return not self:CanChangeRules() end,
    get = function() return self.db.profile.base_item_value end,
    set = function(v) self.db.profile.base_item_value = v end
  }
  return options
end
