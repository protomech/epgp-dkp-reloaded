EPGP = AceLibrary("AceAddon-2.0"):new("AceConsole-2.0", "AceDB-2.0", "AceDebug-2.0", "AceEvent-2.0", "FuBarPlugin-2.0")

EPGP:RegisterDB("EPGP_DB")

CURRENT_ZONE = nil

function EPGP:OnInitialize()
  self:SetDebugging(true)
  local guild_name, guild_rank_name, guild_rank_index = GetGuildInfo("player")
  if (not guild_name) then guild_name = "EPGP_testing_guild" end
  self:SetProfile(guild_name)  
  self:RegisterChatCommand({ "/epgp" },
    EPGP:BuildOptions()
  )
end

function EPGP:OnEnable()
  self:Print("EPGP addon is enabled")
  self:RegisterEvent("ZONE_CHANGED_NEW_AREA")
  self:RegisterEvent("CHAT_MSG_LOOT")
  self:RegisterEvent("CHAT_MSG_COMBAT_HOSTILE_DEATH")
end

function EPGP:OnDisable()

end

-- Builds an AceOptions table for the options
-- Passing true generates options suitable for a command line
function EPGP:BuildOptions()
  options = {
    type = "group",
    desc = "EPGP Options",
    args = {
    	["bosses"] = {
    	  type = "group",
    	  name = "Bosses",
    	  desc = "Effort points given for succesful boss kills.",
    	  args = { }
    	},
    	["zones"] = {
    	  type = "group",
    	  name = "Zones",
    	  desc = "Gear Point multipliers for the drops of each zone.",
    	  args = { }
    	}
  	}
  }
  -- Setup bosses options
  for k, v in pairs(self.db.profile.bosses) do
    local cmd = string.gsub(k, "%s", "_")
    local key = k
    options.args["bosses"].args[cmd] = {
      type = "range",
      name = key,
      desc = "Effort points given for succesful kill.",
      min = 0,
      max = 100,
      step = 1,
      get = function() return self:GetBossEP(key) end,
      set = function(v) self:SetBossEP(key, v) end
    }
  end
  -- Setup zones options
  for k, v in pairs(self.db.profile.zones) do
    local cmd = string.gsub(k, "%s", "_")
    local key = k
    options.args["zones"].args[cmd] = {
      type = "range",
      name = key,
      desc = "Gear Point multiplier for drops in this zone.",
      min = 0,
      max = 10,
      step = 0.1,
      get = function() return self.db.profile.zones[key] end,
      set = function(v) self.db.profile.zones[key] = v end
    }
  end
  
	return options
end

-------------------------------------------------------------------------------
-- Event Handlers for tracking interesting events
-------------------------------------------------------------------------------
function EPGP:ZONE_CHANGED_NEW_AREA()
  CURRENT_ZONE = GetRealZoneText()
  if (self.db.profile.zones[CURRENT_ZONE]) then
    self:Debug("Tracked zone: [%s]", CURRENT_ZONE)
  else
    self:Debug("Not tracked zone: [%s]", CURRENT_ZONE)
  end
end

function EPGP:CHAT_MSG_LOOT(msg)
  local receiver, count, itemlink = EPGP_ParseLootMsg(msg)
  self:Debug("Player: [%s] Count: [%d] Loot: [%s]", receiver, count, itemlink)
  self:EventLog_Add_LOOT(self:GetOrLastEventLog(), receiver, count, itemlink)
end

function EPGP:CHAT_MSG_COMBAT_HOSTILE_DEATH(msg)
  -- Message can be of two forms:
  --   1. "Greater Duskbat dies."
  --   2. "You have slain Greater Duskbat."
  -- We only care about the first since we always get it. The second one we
  -- get it in addition to the first if we did the killing blow.

  local dead_mob = EPGP_ParseHostileDeath(msg)
  if (not dead_mob) then return end
  
  local mob_value = self:GetBossEP(dead_mob)
  if (mob_value) then
    self:Debug("Boss kill: %s value: %d", dead_mob, mob_value)
    self:EventLog_Add_BOSSKILL(
      self:GetLastEventLog(), dead_mob, self:GetCurrentRoster())
  else
    self:Debug(string.format("Trash kill: %s", dead_mob))
  end
end

function EPGP:CHAT_MSG_ADDON(prefix, msg, type, sender)
  -- This is where sync should happen
  self:Debug("Prefix: [%s] Msg: [%s] Type: [%s] Sender: [%s]",
             prefix, msg, type, sender)
end
