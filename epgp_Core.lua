EPGP = AceLibrary("AceAddon-2.0"):new("AceConsole-2.0", "AceDebug-2.0", "AceEvent-2.0")

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
  self:Debug(current_zone)
end

function EPGP:CHAT_MSG_LOOT(msg)
  self:Debug(msg)
  SendAddonMessage("EPGP", msg, "GUILD")
end

function EPGP:RAID_ROSTER_UPDATE()
  -- Need to figure out who entered/left in order to send event
  self:Debug("Raid roster changed")
  SendAddonMessage("EPGP", "Raid roster changed", "GUILD")
end

function EPGP:PARTY_MEMBERS_CHANGED()
  self:Debug("Party members changed")
end

function EPGP:CHAT_MSG_COMBAT_HOSTILE_DEATH(msg)
  -- Message can be of two forms:
  --   1. "Greater Duskbat dies."
  --   2. "You have slain Greater Duskbat."
  -- We only care about the first since we always get it. The second one we
  -- get it in addition if we did the killing blow.

  local s, e, dead_mob = string.find(msg, "(.+) dies.")
  if (dead_mob) then
    local mob_value = EPGP_Bosses[dead_mob]
    if (mob_value) then
      self:Debug(string.format("Boss kill: %s value: %d", dead_mob, mob_value))
      SendAddonMessage("EPGP", dead_mob, "RAID")
    else
      self:Debug(string.format("Trash kill: %s", dead_mob))
    end
  end
end

function EPGP:CHAT_MSG_ADDON(prefix, msg, type, sender)
  -- This is where sync should happen
  self:Debug(string.format("Prefix: [%s] Msg: [%s] Type: [%s] Sender: [%s]",
                           prefix, msg, type, sender))
end
