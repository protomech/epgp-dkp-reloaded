-------------------------------------------------------------------------------
-- CHAT_MSG_LOOT parsing
--
-- returns receiver, count, itemlink
-------------------------------------------------------------------------------
local EPGP_LOOT_ITEM = "^(%S+) receives loot: (.+)%.$"
local EPGP_LOOT_ITEM_MULTIPLE = "^(%S+) receives loot: (.+)x(%d+)%.$"
local EPGP_LOOT_ITEM_SELF = "^You receive loot: (.+)%.$"
local EPGP_LOOT_ITEM_SELF_MULTIPLE = "^You receive loot: (.+)x(%d+)%.$"
function EPGP_ParseLootMsg(msg)
  -- Variable names
  -- s: start, e: end, r: reciever, i: itemlink, c: count
  local s, e, r, i = string.find(msg, EPGP_LOOT_ITEM)
  if (r and i) then return r, 1, i end

  local s, e, r, i, c = string.find(msg, EPGP_LOOT_ITEM_MULTIPLE)
  if (r and i and c) then return r, c, i end

  local s, e, i = string.find(msg, EPGP_LOOT_ITEM_SELF)
  if (i) then return UnitName("player"), 1, i end

  local i, c = string.find(msg, EPGP_LOOT_ITEM_SELF_MULTIPLE)
  if (i and c) then return UnitName("player"), c, i end
  
  assert(false, "Unable to parse CHAT_MSG_LOOT message!")
end

-------------------------------------------------------------------------------
-- CHAT_MSG_COMBAT_HOSTILE_DEATH parsing
--
-- returns dead_mob
-------------------------------------------------------------------------------
local EPGP_UNIT_DIES_OTHER = "^(.+) dies%.$"
function EPGP_ParseHostileDeath(msg)
  local s, e, dead_mob = string.find(msg, EPGP_UNIT_DIES_OTHER)
  return dead_mob
end
