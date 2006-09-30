EPGP = AceLibrary("AceAddon-2.0"):new("AceConsole-2.0", "AceDB-2.0", "AceDebug-2.0", "AceEvent-2.0")

EPGP:RegisterDB("EPGP_DB", "EPGP_DB_CHAR")

function EPGP:OnInitialize()
  self:SetDebugging(true)
end

function EPGP:OnEnable()
  self:Print("EPGP addon is enabled")
  self:RegisterEvent("ZONE_CHANGED_NEW_AREA")
  self:RegisterEvent("CHAT_MSG_LOOT")
  self:RegisterEvent("RAID_ROSTER_UPDATE")
  self:RegisterEvent("PARTY_MEMBERS_CHANGED")
  self:RegisterEvent("CHAT_MSG_COMBAT_HOSTILE_DEATH")
end

function EPGP:OnDisable()

end

-------------------------------------------------------------------------------
-- Event Handlers for tracking interesting events
-------------------------------------------------------------------------------
function EPGP:ZONE_CHANGED_NEW_AREA()
  local current_zone = GetRealZoneText()
  if (self.db.char.zones[current_zone]) then
    self:Debug(string.format("Tracked zone: [%s]", current_zone))
  else
    self:Debug(string.format("Not tracked zone: [%s]", current_zone))
  end
end

function EPGP:CHAT_MSG_LOOT(msg)
  local receiver, count, itemlink = EPGP_ParseLootMsg(msg)
  self:Debug(string.format("Player: [%s] Count: [%d] Loot: [%s]",
             receiver, count, itemlink))
end

function EPGP:RAID_ROSTER_UPDATE()
  -- Need to figure out who entered/left in order to send event
  self:Debug("Raid roster changed")
end

function EPGP:PARTY_MEMBERS_CHANGED()
  self:Debug("Party members changed")
end

function EPGP:CHAT_MSG_COMBAT_HOSTILE_DEATH(msg)
  -- Message can be of two forms:
  --   1. "Greater Duskbat dies."
  --   2. "You have slain Greater Duskbat."
  -- We only care about the first since we always get it. The second one we
  -- get it in addition to the first if we did the killing blow.

  local dead_mob = EPGP_ParseHostileDeath(msg)
  local mob_value = self.db.char.bosses[dead_mob]
  if (mob_value) then
    self:Debug(string.format("Boss kill: %s value: %d", dead_mob, mob_value))
  else
    self:Debug(string.format("Trash kill: %s", dead_mob))
  end
end

function EPGP:CHAT_MSG_ADDON(prefix, msg, type, sender)
  -- This is where sync should happen
  self:Debug(string.format("Prefix: [%s] Msg: [%s] Type: [%s] Sender: [%s]",
                           prefix, msg, type, sender))
end
