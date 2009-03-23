-- This library provides an interface to query if an item can be
-- use by a certain class. The API is as follows:
--
-- CanClassUse(class, itemType): class is one of **** and itemType a localized itemType (http://www.wowwiki.com/ItemType).
--

local MAJOR_VERSION = "LibItemUtils-1.0"
local MINOR_VERSION = tonumber(("$Revision: $"):match("%d+")) or 0

local lib, oldMinor = LibStub:NewLibrary(MAJOR_VERSION, MINOR_VERSION)
if not lib then return end

local function Debug(fmt, ...)
  DEFAULT_CHAT_FRAME:AddMessage(string.format(fmt, ...))
end

-- Inventory types are localized on each client. For this we need
-- LibBabble-Inventory to unlocalize the strings.
local LBIR = LibStub("LibBabble-Inventory-3.0"):GetReverseLookupTable()
-- Class restrictions are localized on each client. For this we need
-- LibBabble-Class to unlocalize the strings.
local LBCR = LibStub("LibBabble-Class-3.0"):GetReverseLookupTable()
local deformat = AceLibrary("Deformat-2.0")

if lib.frame then
  lib.frame:UnregisterAllEvents()
  lib.frame:SetScript("OnEvent", nil)
  lib.frame:SetScript("OnUpdate", nil)
else
  lib.frame = CreateFrame("GameTooltip", MAJOR_VERSION .. "_Frame", UIParent, "GameTooltipTemplate")
end
local frame = lib.frame
local bindingFrame = getglobal(frame:GetName().."TextLeft2")
local restrictedClassFrame = getglobal(frame:GetName().."TextLeft3")
frame:Show()

-- Deformat library. This should really go into its own.
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
    -- If the last pattern is a non-greedy match and it ends the
    -- pattern, make a greedy match.
    pattern = pattern:gsub("%-%)$", "+)")
    --print(string.format("Final pattern: %s", pattern))
    pattern_cache[format] = pattern
  end
  return str:match(pattern)
end

--[[

All item types we care about:

    Cloth = true,
    Leather = true,
    Mail = true,
    Plate = true,
    Shields = true,

    Bows = true,
    Crossbows = true,
    Daggers = true,
    ["Fist Weapons"] = true,
    Guns = true,
    ["One-Handed Axes"] = true,
    ["One-Handed Maces"] = true,
    ["One-Handed Swords"] = true,
    Polearms = true,
    Staves = true,
    ["Two-Handed Axes"] = true,
    ["Two-Handed Maces"] = true,
    ["Two-Handed Swords"] = true,

    Idols = true,
    Librams = true,
    Sigils = true,
    Thrown = true,
    Totems = true,
    Wands = true,
--]]

local dissallowed = {
  DEATHKNIGHT = {
    Shields = true,

    Bows = true,
    Crossbows = true,
    Daggers = true,
    ["Fist Weapons"] = true,
    Guns = true,
    Polearms = true,
    Staves = true,

    Idols = true,
    Librams = true,
    Thrown = true,
    Totems = true,
    Wands = true,
  },
  DRUID = {
    Mail = true,
    Plate = true,
    Shields = true,

    Bows = true,
    Crossbows = true,
    Guns = true,
    ["One-Handed Axes"] = true,
    ["One-Handed Swords"] = true,
    ["Two-Handed Axes"] = true,
    ["Two-Handed Swords"] = true,

    Librams = true,
    Sigils = true,
    Thrown = true,
    Totems = true,
    Wands = true,
  },
  HUNTER = {
    Plate = true,
    Shields = true,

    ["One-Handed Maces"] = true,
    ["Two-Handed Maces"] = true,

    Idols = true,
    Librams = true,
    Sigils = true,
    Totems = true,
    Wands = true,
  },
  MAGE = {
    Leather = true,
    Mail = true,
    Plate = true,
    Shields = true,

    Bows = true,
    Crossbows = true,
    ["Fist Weapons"] = true,
    Guns = true,
    ["One-Handed Axes"] = true,
    ["One-Handed Maces"] = true,
    Polearms = true,
    ["Two-Handed Axes"] = true,
    ["Two-Handed Maces"] = true,
    ["Two-Handed Swords"] = true,

    Idols = true,
    Librams = true,
    Sigils = true,
    Thrown = true,
    Totems = true,
  },
  PALADIN = {
    Bows = true,
    Crossbows = true,
    ["Fist Weapons"] = true,
    Guns = true,
    Staves = true,

    Idols = true,
    Sigils = true,
    Thrown = true,
    Totems = true,
    Wands = true,
  },
  PRIEST = {
    Leather = true,
    Mail = true,
    Plate = true,
    Shields = true,

    Bows = true,
    Crossbows = true,
    ["Fist Weapons"] = true,
    Guns = true,
    ["One-Handed Axes"] = true,
    ["One-Handed Swords"] = true,
    Polearms = true,
    ["Two-Handed Axes"] = true,
    ["Two-Handed Maces"] = true,
    ["Two-Handed Swords"] = true,

    Idols = true,
    Librams = true,
    Sigils = true,
    Thrown = true,
    Totems = true,
  },
  ROGUE = {
    Mail = true,
    Plate = true,
    Shields = true,

    Polearms = true,
    Staves = true,
    ["Two-Handed Axes"] = true,
    ["Two-Handed Maces"] = true,
    ["Two-Handed Swords"] = true,

    Idols = true,
    Librams = true,
    Sigils = true,
    Totems = true,
    Wands = true,
  },
  SHAMAN = {
    Plate = true,

    Bows = true,
    Crossbows = true,
    Guns = true,
    ["One-Handed Swords"] = true,
    Polearms = true,
    ["Two-Handed Swords"] = true,

    Idols = true,
    Librams = true,
    Sigils = true,
    Thrown = true,
    Wands = true,
  },
  WARLOCK = {
    Leather = true,
    Mail = true,
    Plate = true,
    Shields = true,

    Bows = true,
    Crossbows = true,
    ["Fist Weapons"] = true,
    Guns = true,
    ["One-Handed Axes"] = true,
    ["One-Handed Maces"] = true,
    Polearms = true,
    ["Two-Handed Axes"] = true,
    ["Two-Handed Maces"] = true,
    ["Two-Handed Swords"] = true,

    Idols = true,
    Librams = true,
    Sigils = true,
    Thrown = true,
    Totems = true,
  },
  WARRIOR = {
    Idols = true,
    Librams = true,
    Sigils = true,
    Totems = true,
    Wands = true,
  },
}

function lib:ClassCanUse(class, item)
  local subType = select(7, GetItemInfo(item))
  if not subType then
    return true
  end

  -- Check if this is a restricted class token.
  -- TODO(alkis): Possibly cache this check if performance is an issue.
  local link = select(2, GetItemInfo(item))
  frame:SetOwner(UIParent, "ANCHOR_NONE")
  frame:SetHyperlink(link)
  if frame:NumLines() > 2 then
    local text = restrictedClassFrame:GetText()
    frame:Hide()

    if text then
      local classList = deformat(text, ITEM_CLASSES_ALLOWED)
      if classList then
        for _, restrictedClass in pairs({strsplit(',', classList)}) do
          restrictedClass = strupper(LBCR[strtrim(restrictedClass)])
          if class == restrictedClass then
            return true
          end
        end
        return false
      end
    end
  end
  frame:Hide()

  -- Check if players can equip this item.
  subType = LBIR[subType]
  if dissallowed[class][subType] then
    return false
  end

  return true
end

function lib:ClassCannotUse(class, item)
  return not self:ClassCanUse(class, item)
end

local function NewTableOrClear(t)
  if not t then return {} end
  wipe(t)
  return t
end

function lib:ClassesThatCanUse(item, t)
  t = NewTableOrClear(t)
  for class, _ in pairs(RAID_CLASS_COLORS) do
    if self:ClassCanUse(class, item) then
      table.insert(t, class)
    end
  end
  return t
end

function lib:ClassesThatCannotUse(item, t)
  t = NewTableOrClear(t)
  for class, _ in pairs(RAID_CLASS_COLORS) do
    if self:ClassCannotUse(class, item) then
      table.insert(t, class)
    end
  end
  return t
end

-- binding is one of: ITEM_BIND_ON_PICKUP, ITEM_BIND_ON_EQUIP, ITEM_BIND_ON_USE, ITEM_BIND_TO_ACCOUNT
function lib:IsBinding(binding, item)
  local link = select(2, GetItemInfo(item))
  frame:SetOwner(UIParent, "ANCHOR_NONE")
  frame:SetHyperlink(link)

  if frame:NumLines() > 1 then
    local text = bindingFrame:GetText()
    if text then
      return text == binding
    end
  end
  frame:Hide()
end

function lib:IsBoP(item)
  return lib:IsBinding(ITEM_BIND_ON_PICKUP, item)
end

function lib:IsBoE(item)
  return lib:IsBinding(ITEM_BIND_ON_EQUIP, item)
end

local items = {
  40558, -- Cloth
  40539, -- Leather
  40543, -- Mail
  40592, -- Plate

  40405, -- Cloak
  40192, -- Off-Hand
  40401, -- Shield

  40387, -- Neck
  40399, -- Ring
  40532, -- Trinket

  40342, -- Idol
  40268, -- Libram
  40322, -- Totem
  40207, -- Sigil

  40386, -- Dagger
  40383, -- Fist Weapon
  40402, -- One-Handed Axe
  40395, -- One-Handed Mace
  40396, -- One-Handed Sword

  40497, -- Polearm
  40388, -- Stave
  40384, -- Two-Handed Axe
  40406, -- Two-Handed Mace
  40343, -- Two-Handed Sword

  40265, -- Bow
  40346, -- Crossbow
  40385, -- Gun
  40190, -- Thrown
  40245, -- Wand

  40626, -- Protector token
}

function lib:DebugTest()
  local t = {}
  for _, itemID in ipairs(items) do
    local link = select(2, GetItemInfo(itemID))

    t = self:ClassesThatCanUse(itemID)
    Debug("Classes that can use %s: %s", link, table.concat(t, ' '))

    t = self:ClassesThatCannotUse(itemID)
    Debug("Classes that cannot use %s: %s", link, table.concat(t, ' '))

    Debug("IsBoP: %s", tostring(self:IsBoP(itemID)))
    Debug("IsBoE: %s", tostring(self:IsBoE(itemID)))

  end
end

-- /script LibStub("LibItemUtils-1.0"):DebugTest()