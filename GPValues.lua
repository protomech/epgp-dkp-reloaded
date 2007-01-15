local mod = EPGP:NewModule("EPGP_GPValues", "AceHook-2.1")

local EQUIPSLOT_VALUE = {
  ["INVTYPE_HEAD"] = 1,
  ["INVTYPE_NECK"] = 0.55,
  ["INVTYPE_SHOULDER"] = 0.777,
  ["INVTYPE_CHEST"] = 1,
  ["INVTYPE_ROBE"] = 1,
  ["INVTYPE_WAIST"] = 0.777,
  ["INVTYPE_LEGS"] = 1,
  ["INVTYPE_FEET"] = 0.777,
  ["INVTYPE_WRIST"] = 0.55,
  ["INVTYPE_HAND"] = 0.777,
  ["INVTYPE_FINGER"] = 0.55,
  ["INVTYPE_TRINKET"] = 0.7,
  ["INVTYPE_CLOAK"] = 0.55,
  ["INVTYPE_WEAPON"] = 0.42,
  ["INVTYPE_SHIELD"] = 0.55,
  ["INVTYPE_2HWEAPON"] = 1,
  ["INVTYPE_WEAPONMAINHAND"] = 0.42,
  ["INVTYPE_WEAPONOFFHAND"] = 0.42,
  ["INVTYPE_HOLDABLE"] = 0.55,
  ["INVTYPE_RANGED"] = 0.42,
  ["INVTYPE_RANGEDRIGHT"] = 0.42
}

local ILVL_TO_IVALUE = {
  [2] = function(ilvl) return (ilvl - 4) / 2 end,         -- Green
  [3] = function(ilvl) return (ilvl - 1.84) / 1.6 end,   -- Blue
  [4] = function(ilvl) return (ilvl - 1.3) / 1.3 end,     -- Purple
}

function mod:AddGP2Tooltip(frame, itemLink)
  local gp = self:GetGPValue(itemLink)
  if gp > 0 then
    frame:AddDoubleLine("GP", string.format("%d", gp),
      NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b,
      NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
    frame:Show()
  end
end

function mod:GetGPValue(itemLink)
  if not itemLink then return end
  local name, link, rarity, level, minlevel, type, subtype, count, equipLoc = GetItemInfo(itemLink)
  local islot_mod = EQUIPSLOT_VALUE[equipLoc]
  if not islot_mod then return end
  local ilvl2ivalue = ILVL_TO_IVALUE[rarity]
  if ilvl2ivalue then
    local ivalue = ilvl2ivalue(level)
    return math.floor(ivalue^2 * 0.04 * islot_mod)
  end
end

function mod:OnEnable()
  self:SecureHook(GameTooltip, "SetAuctionItem", function(this, type, index) self:AddGP2Tooltip(this, GetAuctionItemLink(type, index)) end)
  self:SecureHook(GameTooltip, "SetBagItem", function(this, bag, slot) self:AddGP2Tooltip(this, GetContainerItemLink(bag, slot)) end)
  self:SecureHook(GameTooltip, "SetHyperlink", function(this, link) self:AddGP2Tooltip(this, link) end)
  self:SecureHook(GameTooltip, "SetInventoryItem", function(this, unit, slot) self:AddGP2Tooltip(this, GetInventoryItemLink(unit, slot)) end)
  self:SecureHook(GameTooltip, "SetLootItem", function(this, slot) self:AddGP2Tooltip(this, GetLootSlotLink(slot)) end)
  self:SecureHook(GameTooltip, "SetLootRollItem", function(this, slot) self:AddGP2Tooltip(this, GetLootRollItemLink(slot)) end)
  self:SecureHook(GameTooltip, "SetMerchantItem", function(this, index) self:AddGP2Tooltip(this, GetMerchantItemLink(index)) end)
  self:SecureHook(GameTooltip, "SetQuestItem", function(this, type, index) self:AddGP2Tooltip(this, GetQuestItemLink(type, index)) end)
  self:SecureHook(GameTooltip, "SetQuestLogItem", function(this, type, index) self:AddGP2Tooltip(this, GetQuestLogItemLink(type, index)) end)
  self:SecureHook(GameTooltip, "SetSendMailItem", function(this) self:AddGP2Tooltip(this, GetSendMailItem()) end)
  self:SecureHook(GameTooltip, "SetTradePlayerItem", function(this, id) self:AddGP2Tooltip(this, GetTradePlayerItemLink(id)) end)
  self:SecureHook(GameTooltip, "SetTradeSkillItem", function(this, index) self:AddGP2Tooltip(this, GetTradeSkillItemLink(index)) end)
  self:SecureHook(GameTooltip, "SetTradeTargetItem", function(this, id) self:AddGP2Tooltip(this, GetTradeTargetItemLink(id)) end)
  self:SecureHook(ItemRefTooltip, "SetHyperlink", function(this, link) self:AddGP2Tooltip(this, link) end)
end
