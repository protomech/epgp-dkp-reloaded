EPGP = AceLibrary("AceAddon-2.0"):new("AceConsole-2.0", "AceDB-2.0", "AceDebug-2.0", "AceEvent-2.0")

EPGP:RegisterDB("EPGP_DB")

CURRENT_ZONE = nil

function EPGP:OnInitialize()
  self:SetDebugging(true)
  local guild_name, guild_rank_name, guild_rank_index = GetGuildInfo("player")
  if (not guild_name) then guild_name = "EPGP_testing_guild" end
  self:SetProfile(guild_name)
end

function EPGP:OnEnable()
  self:Print("EPGP addon is enabled")
  self:RegisterEvent("ZONE_CHANGED_NEW_AREA")
  self:RegisterEvent("CHAT_MSG_LOOT")
  self:RegisterEvent("CHAT_MSG_COMBAT_HOSTILE_DEATH")
end

function EPGP:OnDisable()

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
