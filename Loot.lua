local mod = EPGP:NewModule("EPGP_Loot", "AceEvent-3.0")

local L = LibStub:GetLibrary("AceLocale-3.0"):GetLocale("EPGP")
local deformat = LibStub:GetLibrary("Deformat-2.0")

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

local function IsRLorML()
  if UnitInRaid("player") then
    local loot_method, ml_party_id, ml_raid_id = GetLootMethod()
    if loot_method == "master" and ml_party_id == 0 then return true end
    if loot_method ~= "master" and IsRaidLeader() then return true end
  end
  return false
end

function mod:RAID_ROSTER_UPDATE()
  if IsRLorML() then
    self:RegisterEvent("CHAT_MSG_LOOT")
  else
    self:UnregisterEvent("CHAT_MSG_LOOT")
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
  -- TODO(alkis): Add quality threshold variable
  self:SendMessage("LootReceived", player, item_link, quantity)
end


function mod:OnInitialize()
  -- TODO(alkis): Use db to persist enabled/disabled state.
end

function mod:OnEnable()
  self:RegisterEvent("RAID_ROSTER_UPDATE")
end
