local L = EPGPGlobalStrings
local deformat = AceLibrary("Deformat-2.0")

local mod = EPGP:NewModule("EPGP_Loot", "AceEvent-2.0")

local ignored_items = {
  [20725] = true, -- Nexus Crystal
  [22450] = true, -- Void Crystal
  [29434] = true, -- Badge of Justice
  [30311] = true, -- Warp Slicer
  [30312] = true, -- Infinity Blade
  [30313] = true, -- Staff of Disintegration
  [30314] = true, -- Phaseshift Bulwark
  [30316] = true, -- Devastation
  [30317] = true, -- Cosmic Infuser
  [30318] = true, -- Netherstrand Longbow
  [30319] = true, -- Nether Spikes
  [30320] = true, -- Bundle of Nether Spikes
}

function mod:OnInitialize()
  self:RegisterEvent("RAID_ROSTER_UPDATE")
end

local monitoring = false
function mod:RAID_ROSTER_UPDATE()
  if UnitInRaid("player") and IsRaidLeader() and EPGP.db.profile.loot_tracking then
    if not monitoring then
      monitoring = true
      self:RegisterEvent("CHAT_MSG_LOOT")
    end
  else
    if monitoring then
      monitoring = false
      self:UnregisterEvent("CHAT_MSG_LOOT")
    end
  end
end

local function ParseLootMessage(msg)
  local player = UnitName("player")
  local item, quantity = deformat(msg, LOOT_ITEM_SELF_MULTIPLE)
  if item and quantity then
    return player, item, tonumber(quantity)
  end
  quantity = 1
  item = deformat(msg, LOOT_ITEM_SELF)
  if item then
    return player, item, tonumber(quantity)
  end
  
  player, item, quantity = deformat(msg, LOOT_ITEM_MULTIPLE)
  if player and item and quantity then
    return player, item, tonumber(quantity)
  end

  quantity = 1
  player, item = deformat(msg, LOOT_ITEM)
  return player, item, tonumber(quantity)
end

function mod:CHAT_MSG_LOOT(msg)
  local player, item, quantity = ParseLootMessage(msg)
  if not player or not item then return end

  local item_name, item_link, item_rarity = GetItemInfo(item)
  local item_id = select(3, item_link:find("item:(%d+):"))
  if not item_id then return end
  item_id = tonumber(item_id:trim())
  if not item_id then return end

  if ignored_items[item_id] then return end
  if item_rarity < EPGP.db.profile.loot_tracking_quality_threshold then return end
  self:TriggerEvent("EPGP_LOOT_RECEIVED", player, item_link, quantity)
end
