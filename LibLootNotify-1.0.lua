-- A library to allow registration of callbacks to receive
-- notifications on loot events.

local MAJOR_VERSION = "LibLootNotify-1.0"
local MINOR_VERSION = tonumber(("$Revision: 1023 $"):match("%d+")) or 0

local lib, oldMinor = LibStub:NewLibrary(MAJOR_VERSION, MINOR_VERSION)
if not lib then return end

local function Debug(fmt, ...)
  DEFAULT_CHAT_FRAME:AddMessage(string.format(fmt, ...))
end

-- Comment out this line to enable debug info
-- function Debug(...) end

local deformat = AceLibrary("Deformat-2.0")
local CallbackHandler = LibStub("CallbackHandler-1.0")

lib.callbacks = lib.callbacks or CallbackHandler:New(lib)
local callbacks = lib.callbacks

lib.frame = lib.frame or CreateFrame("Frame", MAJOR_VERSION .. "_Frame")
local frame = lib.frame

frame:UnregisterAllEvents()
frame:SetScript("OnEvent", nil)

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

local function HandleLootMessage(msg)
  local player, itemLink, quantity = ParseLootMessage(msg)
  if player and itemLink and quantity then
    Debug('Firing LootReceived(%s, %s, %d)', player, itemLink, quantity)
    callbacks:Fire("LootReceived", player, itemLink, quantity)
  end
end

frame:RegisterEvent("CHAT_MSG_LOOT")
frame:SetScript("OnEvent",
                function(self, event, ...)
                  if event == "CHAT_MSG_LOOT" then
                    HandleLootMessage(...)
                  end
                end)
frame:Show()

--[[###############################################--
          UNIT TESTS
--###############################################]]--

local function EmulateEvent(event, ...)
  for _, frame in pairs({GetFramesRegisteredForEvent(event)}) do
    local func = frame:GetScript('OnEvent')
    pcall(func, frame, event, ...)
  end
end

function lib:DebugTest()
  EmulateEvent('CHAT_MSG_LOOT',
               LOOT_ITEM:format(UnitName('player'),
                                select(2, GetItemInfo(40592))),
               '', '', '', '')
end

-- /script LibStub("LibLootNotify-1.0"):DebugTest()
