-------------------------------------------------------------------------------
-- Event Handlers for tracking a raid
-------------------------------------------------------------------------------

-- CHAT_MSG_LOOT parsing
-- returns receiver, count, itemlink
local EPGP_LOOT_ITEM = "^(%S+) receives loot: (.+)%.$"
local EPGP_LOOT_ITEM_MULTIPLE = "^(%S+) receives loot: (.+)x(%d+)%.$"
local EPGP_LOOT_ITEM_SELF = "^You receive loot: (.+)%.$"
local EPGP_LOOT_ITEM_SELF_MULTIPLE = "^You receive loot: (.+)x(%d+)%.$"
function EPGP:ParseLootMsg(msg)
  -- Variable names
  -- r: reciever, i: itemlink, c: count
  local _, _, r, i = string.find(msg, EPGP_LOOT_ITEM)
  if (r and i) then return r, 1, i end

  local _, _, r, i, c = string.find(msg, EPGP_LOOT_ITEM_MULTIPLE)
  if (r and i and c) then return r, c, i end

  local _, _, i = string.find(msg, EPGP_LOOT_ITEM_SELF)
  if (i) then return UnitName("player"), 1, i end

  local _, _, i, c = string.find(msg, EPGP_LOOT_ITEM_SELF_MULTIPLE)
  if (i and c) then return UnitName("player"), c, i end
  
  self:DEBUG("Ignored CHAT_MSG_LOOT message: %s", msg)
  return nil, nil, nil
end

local EPGP_ITEM_LINK = "Hitem:(%d+):"
function EPGP:ParseItemId(itemlink)
  local _, _, item_id = string.find(itemlink, EPGP_ITEM_LINK)
  return item_id
end

function EPGP:CHAT_MSG_LOOT(msg)
  local receiver, count, itemlink = self:ParseLootMsg(msg)
  if (receiver and count and itemlink) then
    local item_id = self:ParseItemId(itemlink)
    self:Debug("Player: [%s] Count: [%d] Loot: [%s]", receiver, count, itemlink)
    -- Gross hack. Better schedule an event for this to be filled it. Or have the
    -- looter send us the ItemInfo since that is for sure in the local cache.
    local item_info
    while (not item_info or not item_info[1]) do
      item_info = { GetItemInfo(item_id) }
    end
    -- Only log items of quality uncommon or better
    if (item_info[3] >= 2 or self:IsDebugging()) then
      self:EventLogAdd_LOOT(self:GetLastEventLog(), receiver, count, itemlink, item_info)
    end
  end
end

-- CHAT_MSG_COMBAT_HOSTILE_DEATH parsing
-- returns dead_mob
--
-- Message can be of two forms:
--   1. "Greater Duskbat dies."
--   2. "You have slain Greater Duskbat."
-- We only care about the first since we always get it. The second one we
-- get it in addition to the first if we did the killing blow.

local EPGP_UNIT_DIES_OTHER = "^(.+) dies%.$"
function EPGP:ParseHostileDeath(msg)
  local _, _, dead_mob = string.find(msg, EPGP_UNIT_DIES_OTHER)
  return dead_mob
end

function EPGP:CHAT_MSG_COMBAT_HOSTILE_DEATH(msg)
  local dead_mob = self:ParseHostileDeath(msg)
  if (not dead_mob) then return end
  
  local mob_value = self:GetBossEP(dead_mob)
  if (mob_value) then
    self:Debug("Boss kill: %s value: %d", dead_mob, mob_value)
    self:EventLogAdd_BOSSKILL(
      self:GetLastEventLog(), dead_mob, self:GetCurrentRoster())
  else
    self:Debug(string.format("Trash kill: %s", dead_mob))
  end
end

function EPGP:ZONE_CHANGED_NEW_AREA()
  self.current_zone = GetRealZoneText()
  if (self.db.profile.zones[self.current_zone]) then
    self:Debug("Tracked zone: [%s]", self.current_zone)
  else
    self:Debug("Not tracked zone: [%s]", self.current_zone)
  end
end
