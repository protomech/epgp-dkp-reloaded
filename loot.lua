local mod = EPGP:NewModule("loot", "AceEvent-3.0", "AceTimer-3.0")

local L = LibStub("AceLocale-3.0"):GetLocale("EPGP")
local LLN = LibStub("LibLootNotify-1.0")

local ignored_items = {
  [20725] = true, -- Nexus Crystal
  [22450] = true, -- Void Crystal
  [34057] = true, -- Abyss Crystal
  [29434] = true, -- Badge of Justice
  [40752] = true, -- Emblem of Heroism
  [40753] = true, -- Emblem of Valor
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

function mod:PopLootQueue()
  if in_combat then return end

  if #loot_queue == 0 then
    if timer then
      self:CancelTimer(timer, true)
      timer = nil
    end
    return
  end

  local player, itemLink = unpack(loot_queue[1])

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
  local r, g, b = GetItemQualityColor(itemRarity)

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

local function LootReceived(event_name, player, itemLink, quantity)
  if IsRLorML() and CanEditOfficerNote() then
    local item_name, item_link, item_rarity = GetItemInfo(itemLink)
    if item_rarity < EPGP.db.profile.auto_loot_threshold then return end

    local item_id = tonumber(select(3, item_link:find("item:(%d+)")) or 0)
    if not item_id then return end

    if ignored_items[item_id] then return end

    tinsert(loot_queue, {player, itemLink, quantity})
    if not timer then
      timer = mod:ScheduleRepeatingTimer("PopLootQueue", 1)
    end
  end
end

function mod:PLAYER_REGEN_DISABLED()
  in_combat = true
end

function mod:PLAYER_REGEN_ENABLED()
  in_combat = false
end

function mod:Debug()
  LootReceived("LootReceived", UnitName("player"), "\124cffa335ee|Hitem:39235:0:0:0:0:0:0:531162426:8\124h[Bone-Framed Bracers]\124h\124r")
end

function mod:OnEnable()
  self:RegisterEvent("PLAYER_REGEN_DISABLED")
  self:RegisterEvent("PLAYER_REGEN_ENABLED")
  LLN.RegisterCallback(self, "LootReceived", LootReceived)
end

function mod:OnDisable()
  LLN.UnregisterAllCallbacks(self)
end
