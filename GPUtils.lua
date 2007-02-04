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

GPUtils = {}
function GPUtils:GetGPValue(itemLink)
  if not itemLink then return end
  local name, link, rarity, level, minlevel, type, subtype, count, equipLoc = GetItemInfo(itemLink)
  local islot_mod = EQUIPSLOT_VALUE[equipLoc]
  if not islot_mod then return end
  local ilvl2ivalue = ILVL_TO_IVALUE[rarity]
  if ilvl2ivalue then
    local ivalue = ilvl2ivalue(level)
    return math.floor(ivalue^2 * 0.04 * islot_mod), level, ivalue
  end
end
