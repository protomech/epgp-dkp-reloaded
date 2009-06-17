-- A library to allow registration of callbacks to receive
-- notifications on loot events.

local MAJOR_VERSION = "LibLootNotify-1.0"
local MINOR_VERSION = tonumber(("$Revision: 1023 $"):match("%d+")) or 0

local lib, oldMinor = LibStub:NewLibrary(MAJOR_VERSION, MINOR_VERSION)
if not lib then return end

local Debug = LibStub("LibDebug-1.0")

local AceTimer = LibStub("AceTimer-3.0")

local deformat = AceLibrary("Deformat-2.0")
local CallbackHandler = LibStub("CallbackHandler-1.0")

lib.callbacks = lib.callbacks or CallbackHandler:New(lib)
local callbacks = lib.callbacks

lib.frame = lib.frame or CreateFrame("Frame", MAJOR_VERSION .. "_Frame")
local frame = lib.frame

frame:UnregisterAllEvents()
frame:SetScript("OnEvent", nil)

-- Some tables we need to cache the contents of the loot slots
local slotCache = {}
local lootTimers = {}

-- Sets the timeout before emulating a loot message
local EMULATE_TIMEOUT = 5

-- Create a handle for a emulation timer
local function GetTimerName(player, itemLink, quantity)
  return format('%s:%s:%s',
                tostring(player),
                tostring(itemLink),
                tostring(quantity))
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

local function HandleLootMessage(msg)
  local player, itemLink, quantity = ParseLootMessage(msg)
  if player and itemLink and quantity then
    Debug('Firing LootReceived(%s, %s, %d)', player, itemLink, quantity)

    -- See if we can find a timer for the out of range bug
    local timerName = GetTimerName(player, itemLink, quantity)
    if lootTimers[timerName] then
      -- A timer has been found for this item, stop that timer asap
      Debug('Stopping loot message emulate timer %s', timerName)
      AceTimer:CancelTimer(lootTimers[timerName], true)
      lootTimers[timerName] = null
    end

    callbacks:Fire("LootReceived", player, itemLink, quantity)
  end
end

local function EmulateEvent(event, ...)
  for _, frame in pairs({GetFramesRegisteredForEvent(event)}) do
    local func = frame:GetScript('OnEvent')
    pcall(func, frame, event, ...)
  end
end

--[[  BLIZZARD BUGFIX: Looter out of range
  For a long time there has been a bug when people
  that receive masterloot but they're out of range
  of the Master Looter (ML), the ML doesn't receive
  the 'player X receives Item Y.' message. The code
  below tries to fix this problem by hooking the
  GiveMasterLoot() function and remembering to which
  player the ML tried to send the loot. The ML always
  receives the LOOT_SLOT_CLEARED events, so we can
  safely assume that the last player the ML tried to
  send to loot to, is the one who received the item.
  This obviously only works when using master loot, not
  group loot.
]]--

-- Triggers when MasterLoot has been handed out but
-- no loot message has been received within the timeframe
local function OnLootTimer(slotData)
  local candidate = slotData.candidate
  local itemLink = slotData.itemLink
  local quantity = slotData.quantity
  local timerName = slotData.timerName

  if not timerName then return end
  lootTimers[timerName] = null
  
  print(format('No loot message received while %s received %sx%s, player was probably out of range. Emulating loot message locally:',
               candidate,
               itemLink,
               quantity))

  -- Emulate the event so other addons can benefit from it aswell.
  if quantity==1 then
    EmulateEvent('CHAT_MSG_LOOT', LOOT_ITEM:format(candidate, itemLink), '', '', '', '')
  else
    EmulateEvent('CHAT_MSG_LOOT', LOOT_ITEM_MULTIPLE:format(candidate, itemLink, quantity), '', '', '', '')
  end
end

--- This handler gets called when a loot slot gets cleared.
--  This is where we detect who got the item
local function LOOT_SLOT_CLEARED(event, slotID, ...)
  -- Someone looted a slot, lets see if we have someone registered for it
  local slotData = slotCache[slotID]
  if slotData then
    -- Ok, we know who got the item but the server might also still send the
    -- 'player X receives Item Y' message. We'll need to wait for a little while
    -- and see if the server still sends us this message. If it doesn't, we should
    -- emulate the message ourselves. Note that this is fairly optimized because it
    -- only starts timers for loot that was handed out using GiveMasterLoot() and
    -- doesn't start timers for any normal loot.

    -- Generate a name for the timer and store it in the slotData
    local timerName = GetTimerName(slotData.candidate, slotData.itemLink, slotData.quantity)
    slotData.timerName = timerName
    Debug("LibLootNotify: (%s) creating timer %s", event, timerName)

    -- Schedule a timer for this loot
    lootTimers[timerName] = AceTimer:ScheduleTimer(OnLootTimer, EMULATE_TIMEOUT, slotData)
  end

  -- Clear our slot entry since the slot is now empty
  slotCache[slotID] = nil
end

--- This handler gets called when the native loot frame gets closed
local function LOOT_CLOSED(event, ...)
  -- Clear the cache of loot slots
  Debug('LOOT_CLOSED')
  wipe(slotCache)
end

-- PreHook the GiveMasterLoot function so we can intercept the slotID and candidate
local _GiveMasterLoot = lib.origGiveMasterLoot or GiveMasterLoot
lib.origGiveMasterLoot = _GiveMasterLoot
GiveMasterLoot = function(slotID, candidateID, ...)
  local candidate = tostring(GetMasterLootCandidate(candidateID))
  local itemLink = tostring(GetLootSlotLink(slotID))
  local slotData = {
    candidate   = candidate,
    itemLink    = itemLink,
    quantity    = select(3, GetLootSlotInfo(slotID)) or 1
  }
  slotCache[slotID] = slotData
  _GiveMasterLoot(slotID, candidateID, ...)
  Debug("LibLootNotify: GiveMasterLoot(%s, %s)", itemLink, candidate)
end

--[[###############################################--
      REGISTER EVENTS
--###############################################]]--

frame:RegisterEvent("CHAT_MSG_LOOT")
frame:RegisterEvent("LOOT_SLOT_CLEARED")
frame:RegisterEvent("LOOT_CLOSED")
frame:SetScript("OnEvent",
                function(self, event, ...)
                  if event == "CHAT_MSG_LOOT" then
                    HandleLootMessage(...)
                  elseif event == "LOOT_SLOT_CLEARED" then
                    LOOT_SLOT_CLEARED(event, ...)
                  elseif event == "LOOT_CLOSED" then
                    LOOT_CLOSED(event, ...)
                  end
                end)
frame:Show()

--[[###############################################--
      UNIT TESTS
--###############################################]]--

function lib:DebugTest()
  EmulateEvent('CHAT_MSG_LOOT',
               LOOT_ITEM:format(UnitName('player'),
                                select(2, GetItemInfo(40592))),
               '', '', '', '')
  EmulateEvent('CHAT_MSG_LOOT',
               LOOT_ITEM_SELF:format(select(2, GetItemInfo(32386))),
               '', '', '', '')
  EmulateEvent('CHAT_MSG_LOOT',
               LOOT_ITEM_SELF:format(select(2, GetItemInfo(43954))),
               '', '', '', '')
end

-- /script LibStub("LibLootNotify-1.0"):DebugTest()
