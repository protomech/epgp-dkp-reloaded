local mod = EPGP:NewModule("EPGP_Loot", "AceEvent-3.0", "AceTimer-3.0")

local L = LibStub("AceLocale-3.0"):GetLocale("EPGP")
local deformat = LibStub("Deformat-2.0")

local CallbackHandler = LibStub("CallbackHandler-1.0")
if not mod.callbacks then
  mod.callbacks = CallbackHandler:New(mod)
end
local callbacks = mod.callbacks

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

local in_combat = false
local loot_queue = {}
local timer

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
  if item_rarity < 4 then return end
  local item_id = select(3, item_link:find("item:(%d+):"))
  if not item_id then return end
  item_id = tonumber(item_id:trim())
  if not item_id then return end

  if ignored_items[item_id] then return end
  self:SendMessage("LootReceived", player, item_link, quantity)
end

function mod:PopLootQueue()
  if in_combat then return end

  if #loot_queue == 0 then
    if timer then
      self:CancelTimer(timer, true)
      timer = nil
    end
    return
  end

  local player, itemLink = loot_queue[1][1], loot_queue[1][2]

  -- In theory this should never happen.
  if not player or not itemLink then
    tremove(loot_queue, 1)
    return
  end

  -- User is busy with other popup.
  if StaticPopup_Visible("EPGP_CONFIRM_GP_CREDIT") then
    return
  end

  tremove(loot_queue, 1)

  local itemName, itemLink, itemRarity, _, _, _, _, _, _, itemTexture = GetItemInfo(itemLink)
  local r, g, b = GetItemQualityColor(itemRarity);

  local dialog = StaticPopup_Show("EPGP_CONFIRM_GP_CREDIT", player, "", {
                                  texture = itemTexture,
                                  name = itemName,
                                  color = {r, g, b, 1},
                                  link = itemLink
                                  })
   if dialog then
     dialog.name = player
   end
end

local function Loot_Received(event_name, player, itemLink, quantity)
  tinsert(loot_queue, {player, itemLink, quantity})
  if not timer then
    timer = mod:ScheduleRepeatingTimer("PopLootQueue", 1)
  end
end

function mod:PLAYER_REGEN_DISABLED()
  in_combat = true
end

function mod:PLAYER_REGEN_ENABLED()
  in_combat = false
end

function mod:DebugLootQueue()
  local _, itemLink = GetItemInfo(34541)
  callbacks:Fire("LootReceived", "Knucklehead", itemLink, 1)
end

function mod:OnInitialize()
  -- TODO(alkis): Use db to persist enabled/disabled state.
end

function mod:OnEnable()
  self:RegisterEvent("RAID_ROSTER_UPDATE")
  self:RegisterEvent("PLAYER_REGEN_DISABLED")
  self:RegisterEvent("PLAYER_REGEN_ENABLED")
  self:RegisterCallback("LootReceived", Loot_Received)
end
