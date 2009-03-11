local mod = EPGP:NewModule("loot", "AceEvent-3.0", "AceTimer-3.0")

local L = LibStub("AceLocale-3.0"):GetLocale("EPGP")

local pattern_cache = {}
local function deformat(str, format)
  local pattern = pattern_cache[format]
  if not pattern then
    -- print(string.format("Format: %s", format))

    -- Escape special characters
    pattern = format:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]",
                          function(c) return "%"..c end)
    -- print(string.format("Escaped pattern: %s", pattern))

    -- Substitute formatting elements with captures (only s and d
    -- supported now). Obviously now a formatting element will look
    -- like %%s because we escaped the %.
    pattern = pattern:gsub("%%%%([sd])", {
                             ["s"] = "(.-)",
                             ["d"] = "(%d+)",
                           })
    --print(string.format("Final pattern: %s", pattern))

    pattern_cache[format] = pattern
  end
  return str:match(pattern)
end

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

function mod:CHAT_MSG_LOOT(event_type, msg)
  if not IsRLorML() then return end

  local player, item, quantity = ParseLootMessage(msg)
  if not player or not item then return end

  local item_name, item_link, item_rarity = GetItemInfo(item)
  if item_rarity < EPGP.db.profile.auto_loot_threshold then return end

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
  if CanEditOfficerNote() then
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
  self:RegisterEvent("CHAT_MSG_LOOT")
  self:RegisterEvent("PLAYER_REGEN_DISABLED")
  self:RegisterEvent("PLAYER_REGEN_ENABLED")
  self:RegisterMessage("LootReceived", LootReceived)
end
