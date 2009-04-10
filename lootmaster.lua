--[[ EPGP Lootmaster module

Implementation copied from the EPGPLootmaster addon by mackatack@gmail.com

-- Events fired:

LootMasterChanged(newLootMaster): Triggers when someone in your group has been promoted to
    loot master. newLootMaster is nil when you leave your group or when loot master is disabled.

PlayerReceivesLoot(event, player, itemlink, quantity): Triggers when someone (player) in the raid receives
    an item (itemlink) and itemcount (quantity).

]]--

local mod = EPGP:NewModule("lootmaster", "AceEvent-3.0", "AceComm-3.0", "AceTimer-3.0", "LibRPC-1.0")
local L = LibStub("AceLocale-3.0"):GetLocale("EPGP")
local LibGearPoints = LibStub("LibGearPoints-1.0")
local callbacks = EPGP.callbacks
local Debug = LibStub("LibDebug-1.0", true)
local ItemUtils = LibStub("LibItemUtils-1.0")

-- Initialise the main loot table
local masterlootTable = {}

-- A table used to cache the contents of the native loot frame.
local lootSlots = {}

local db = nil;

-- Set current lootmaster to -1 so the LootMasterChanged event always gets called
local current_masterlooter = -1
local player_is_masterlooter = false

-- Cache some math function for faster access and preventing
-- other addons from screwing em up.
local mathRandomseed        = math.randomseed
local mathRandom            = math.random
local mathFloor             = math.floor
local mathCachedRandomSeed  = math.random()*1000

local bit_bor               = bit.bor
local bit_band              = bit.band

--- Some functions to reuse tables we create further down
local _tableCache = {}
local function popTable()
  return tremove(_tableCache, 1) or {}
end

local function pushTable(t)
  if type(t)~='table' then return end
  wipe(t) 
  tinsert(_tableCache, t)
end

--- Initialize the lootmaster module
function mod:OnInitialize()
  -- Change the onClick script of the lootbuttons a little so we can trap alt+clicks
  -- NOTE: Only tested with normal wow lootframes, not using XLoot etc.
  -- TODO(mackatack): Use AceHook to hook the scripts.
  for slot=1, LOOTFRAME_NUMBUTTONS do
    local btn = getglobal("LootButton"..slot)
    if btn and not btn.oldClickEventEPGPLM then
      btn.oldClickEventEPGPLM = btn:GetScript("OnClick")
      btn:SetScript("OnClick", function(btnObj, ...)
        if not IsAltKeyDown() then
          return btnObj.oldClickEventEPGPLM(btnObj, ...)
        end
        return LootButton_OnClick(btnObj, ...)
      end)
    end
  end
end

--- Event triggered when the lootmaster module gets enabled
function mod:OnEnable()
  -- Make a local pointer to the EPGP configuration table.
  db = self.db

  -- Register callback handlers
  EPGP.RegisterCallback(self, "LootMasterChanged", "OnLootMasterChange")      -- Triggered when loot master is changed
  EPGP.RegisterCallback(self, "PlayerReceivesLoot", "OnPlayerReceivesLoot")   -- Triggered when someone receives loot

  -- Register events
  self:RegisterEvent("OPEN_MASTER_LOOT_LIST")   -- Trap event when ML rightclicks master loot
  self:RegisterEvent("CHAT_MSG_LOOT")           -- Trap event when items get looted
  self:RegisterEvent("LOOT_OPENED")             -- Trap event when the native loot frame gets opened
  self:RegisterEvent("LOOT_CLOSED")             -- Trap event when the native loot frame gets closed
  self:RegisterEvent("LOOT_SLOT_CLEARED")       -- Trap event when a loot slot gets looted

  -- Trap some system messages here, we need these to detect any changes in loot master
  self:RegisterEvent("RAID_ROSTER_UPDATE",            "GROUP_UPDATE");
  self:RegisterEvent("PARTY_LOOT_METHOD_CHANGED",     "GROUP_UPDATE");
  self:RegisterEvent("PARTY_MEMBERS_CHANGED",         "GROUP_UPDATE");
  self:RegisterEvent("PLAYER_ENTERING_WORLD",         "GROUP_UPDATE");
  self:GROUP_UPDATE() -- update the group info immediately

  -- Trap events when entering and leaving combat
  -- TODO(mackatack): implement these again
  -- self:RegisterEvent("PLAYER_REGEN_DISABLED", "EnterCombat")
  -- self:RegisterEvent("PLAYER_REGEN_ENABLED", "LeaveCombat")

  -- Setup RPC
  self:SetRPCKey("EPGPLMRPC")         -- set a prefix/channel for the communications

  -- Setup the public RPC methods
  self:RegisterRPC("RemoveLoot")
  self:RegisterRPC("DecreaseLoot")

  -- Enable the tracking by default
  self:EnableTracking()
end

--- Event triggered when the lootmaster module gets disabled
function mod:OnDisable()
  -- Unregister all events again
  EPGP.UnregisterAllMessages(self)
  self:UnregisterAllRPC()
end

--- Enable master loot tracking by just setting our boolean,
--  we could also register the OPEN_MASTER_LOOT_LIST event here.
function mod:EnableTracking()
  self.trackingEnabled = true
end

--- Disable master loot tracking by just setting our boolean,
--  we could also unregister the OPEN_MASTER_LOOT_LIST event here.
function mod:DisableTracking()
  self.trackingEnabled = false
end

--- Returns whether the module is tracking loot.
function mod:TrackingEnabled()
  return self.trackingEnabled
end

--- Create a safe randomizer function that returns a float between 1 and 99
--  TODO(mackatack): make a more simpler implementation of this and debug it properly.
local randomtable
local randomFloat = function()
  -- I know it's best to only seed the randomizer only so now and then, but some other addon
  -- might have twisted the randomseed so reset it to our cached seed again.
  mathRandomseed(mathCachedRandomSeed)
  mathRandom()
  -- Init the randomizerCache if needed
  if randomtable == nil then
    randomtable = {}
    for i = 1, 97 do
      randomtable[i] = mathRandom()
    end
  end
  local x = mathRandom()
  local i = 1 + mathFloor(97*x)
  x, randomtable[i] = randomtable[i] or x, x
  return mathFloor((x*99+1)*100000)/100000
end

-- Make a table for bitwise encoding and decoding of class table
local classDecoderTable = {
  'MAGE','WARRIOR','DEATHKNIGHT','WARLOCK','DRUID','SHAMAN','ROGUE','PRIEST','PALADIN','HUNTER'
}
local classEncoderTable = {}
for i, class in ipairs(classDecoderTable) do
  classEncoderTable[class] = i
end

--- Returns a table with classname as key for classes that should autopass item also
--  also returns a bitencoded version of this list, used for comms.
function mod:GetAutoPassClasses(itemLink)
  local classesList = ItemUtils:ClassesThatCannotUse(itemLink)
  if not classesList or #classesList==0 then return {}, 0 end

  local autoPassList = {}
  local bits = 0
  for _, class in ipairs(classesList) do
    if not classEncoderTable[class] then
      EPGP:Print(format('Serious error in class bitencoder, class %s not found. Please make sure you have the latest version installed and report if problem persists.', class or 'nil'))
      return {}, 0
    end
    bits = bit_bor(bits, 2^(classEncoderTable[class]-1))
    autoPassList[class] = true
  end
  return autoPassList, format('%x',bits)
end

--- Decodes a bitencoded list of Autopass classes
function mod:DecodeAutoPassClasses(encoded)
  encoded = tonumber(format('0x%s',encoded or 0)) or 0
  if encoded==0 then return {} end
  local classes = {}
  for id, class in pairs(classDecoderTable) do
    local bits = 2^(id-1)
    if bit_band(encoded, bits) == bits then
      classes[class] = true
      encoded = encoded - bits
    end
  end

  if encoded~=0 then
    EPGP:Print(format('Serious error in class bitdecoder, bits %s not found. Please make sure you have the latest version installed and report if problem persists.', tostring(encoded)));
    return {}
  end

  return classes
end

--- Add loot to masterloot cache. This is where candidate responses are stored
--  @param itemlink of the loot to be added
--  @param boolean whether this is an item the user is allowed to distribute
--  @param item count
--  @return the itemID of the item
function mod:AddLoot(link, mayDistribute, quantity)
  if not link then return end
  if not masterlootTable then return end

  -- Cache a new randomseed for later use.
  -- math.random always has same values for seeds > 2^31, so lets modulate.
  mathCachedRandomSeed = floor((mathRandom()+1)*(GetTime()*1000)) % 2^31

  if masterlootTable[link] then return masterlootTable[link] end

  local itemName, itemLink, _, _, itemMinLevel, itemType, itemSubType, itemStackCount, _, itemTexture = GetItemInfo(link)

  local itemID = ItemUtils:ItemlinkToID(itemLink)
  if not itemID or not itemName then return end

  if masterlootTable[itemID] then return masterlootTable[itemID] end

  -- Calc the EPGP values for this item, use LibGearPoints implementation to also use the additional
  -- info from the set tokens.
  local gpvalue, gpvalue2, ilevel, itemRarity, itemEquipLoc = LibGearPoints:GetValue(itemLink)

  -- Find what classes are eligible for the loot
  local autoPassClasses, autoPassClassesEncoded = self:GetAutoPassClasses(itemLink)

  local itemCache = {
    link            = itemLink,

    announced       = true,
    mayDistribute   = mayDistribute,

    itemID          = itemID,
    id              = itemID,

    gpvalue         = gpvalue or 0,
    gpvalue2        = gpvalue2,
    gpvalue_manual  = gpvalue or 0,
    ilevel          = ilevel or 0,
    isBoP           = ItemUtils:IsBoP(itemLink),
    isBoE           = ItemUtils:IsBoE(itemLink),
    quality         = itemRarity or 0,
    quantity        = quantity or 1,
    classes         = autoPassClasses,
    classesEncoded  = autoPassClassesEncoded,

    texture         = itemTexture or '',
    equipLoc        = itemEquipLoc or '',

    candidates      = {},
    numResponses    = 0
  }
  masterlootTable[itemID] = itemCache

  -- See if this item should be autolooted
  if db.auto_loot_threshold~=0 and db.auto_loot_candidate and db.auto_loot_candidate~='' then
    if (not itemBind or itemBind=='use' or itemBind=='equip') and itemRarity<=db.auto_loot_threshold then
      itemCache.autoLootable = true
    end
  end

  -- Are we lootmaster for this loot? Lets send out a monitor message about the added loot
  if self:MonitorMessageRequired(itemID) then
    self:CallPrioritizedRPC('ALERT', 'RAID', 'AddMonitorLoot', itemLink, itemCache.gpvalue, itemCache.gpvalue2, itemCache.quantity, autoPassClassesEncoded)
  end

  return itemCache
end

--- RPC ENABLED - Lootmaster asked us to add the given loot to our cache, for monitoring.
function mod:AddMonitorLoot(itemLink, gpvalue, gpvalue2, quantity, autoPassClassesEncoded)
  -- TODO(mackatack): Needs implementation
  -- Only trust the gpvalues, quantity and autopassclasses from the master looter.
  -- Use the ItemCacher in LibItemUtils to retrieve the rest of the information.
end

--- Retrieve the itemID for loot with itemLink, itemID or itemName "itemID",
--  used to quickly test if an item is already in the cache table
--  @param itemID of the item to retrieve
--  @return table with all loot information.
function mod:GetLootID(itemLink)
  if not itemLink then return end

  if masterlootTable[itemLink] then return itemLink end

  local itemID = ItemUtils:ItemlinkToID(itemID)
  if not itemID then return end
  if not masterlootTable[itemID] then return end

  return itemID
end

--- Retrieve the itemcache for loot with itemLink, itemID or itemName "itemID"
--  @param itemID of the item to retrieve
--  @return table with all loot information.
function mod:GetLoot(itemLink)
  local itemID = self:GetLootID(itemLink)
  if not itemID then return end
  return masterlootTable[itemID]
end

--- RPC ENABLED - Remove the itemcache for loot with itemLink, itemID or itemName "itemID"
--  @param itemID of the item to remove
--  @return true if remove succeeded
function mod:RemoveLoot(itemLink)
  if not itemLink then return end

  local loot = self:GetLoot(itemLink)

  if not loot then
    Debug('RemoveLoot: not found %s', itemLink)
    return false
  end

  -- Checks if this function has been called remotely or not
  if self:IsRPC() then
    if not self:IsSafeRPC(loot) then return end

    masterlootTable[loot.id] = nil
    -- TODO(mackatack): Some UI update callbacks here
    return true
  end

  local itemID = loot.id;

  -- we have more than one of this item, decrease counter and return.
  if loot.quantity>1 then
    loot.quantity = loot.quantity - 1
    -- TODO(mackatack): Some UI update callbacks here

    -- Are we lootmaster for this loot? Lets send out a monitor message about the quantity decrease
    if self:MonitorMessageRequired(itemID) then
      self:CallRPC('RAID', 'DecreaseLoot', itemID)
    end
    return true
  end

  -- Lets send out a monitor message about the removed loot
  if self:MonitorMessageRequired(itemID) then
    self:CallPrioritizedRPC('ALERT', 'RAID', 'RemoveLoot', itemID)
  end

  masterlootTable[itemID] = nil
  -- TODO(mackatack): Some UI update callbacks here

  return true
end

--- RPC ENABLED - This decreases the item quantity for a given item
function mod:DecreaseLoot(itemLink)
  local loot = self:GetLoot(itemLink)
  if not loot then return end

  -- Checks if this function has been called remotely or not
  if self:IsRPC() and not self:IsSafeRPC(loot) then
    -- This function is called remotely, but safetycheck failed
    return
  end

  loot.quantity = loot.quantity - 1
  -- TODO(mackatack): Some UI update callbacks here
end

--- Announce the item to the raid if it hasn't already been announced
--  @param itemID of the item
--  @return true if announced successfully or already announced
function mod:AnnounceLoot(itemID)
  -- TODO(mackatack): Needs implementation
end

--- Add a candidate to the itemCache for the given loot. If the loot is not already in the itemCache, add it.
--  @param itemID of the item
--  @param name of the candidate to be added
--  @return the itemID of the loot when the candidate has successfully been added.
function mod:AddCandidate(itemID, candidate)
  -- TODO(mackatack): Needs implementation
end

--- Returns true when the candidate has been found on the itemCache for the given item.
--  @param itemID of the item
--  @param name of the candidate to be checked
--  @return true if candidate is on the list
function mod:IsCandidate(itemID, candidate)
  -- TODO(mackatack): Needs implementation
end

--- Sets a variable for the given candidate
--  @param itemID of the item
--  @param name of the candidate
--  @param name of the variable to set
--  @param value of the variable to set
--  @return the value that has just been set
function mod:SetCandidateData(itemID, candidate, name, value)
  -- TODO(mackatack): Needs implementation
end

--- Gets a variable for the given candidate
--  @param itemID of the item
--  @param name of the candidate
--  @param name of the variable to get
--  @return the value of the variable you requested
function mod:GetCandidateData(itemID, candidate, name)
  -- TODO(mackatack): Needs implementation
end

--- Sets the response for a given candidate
--  @param itemID of the item
--  @param name of the candidate
--  @param new response of the candidate
function mod:SetCandidateResponse(itemID, candidate, response)
  -- TODO(mackatack): Needs implementation
end

--- Sets the response for a given candidate manually (through the interface popups)
--  @param itemID of the item
--  @param name of the candidate
--  @param new response of the candidate
function mod:SetCandidateManualResponse(itemID, candidate, response)
  -- TODO(mackatack): Needs implementation, send the candidate a confirmation whisper
end

--- Tries to give the loot to the given candidate
--  @param itemID of the item
--  @param name of the candidate
--  @param lootingType, for example "BANK", "DISENCHANT", "GP", etc... see the lootingTypes table for more info.
function mod:GiveLootToCandidate(itemID, candidate, lootingType, gp)
  -- TODO(mackatack): Needs implementation
end

--- This function checks whether a monitor message should be sent out for the given item
function mod:MonitorMessageRequired(itemLink)
  if self:IsRPC() then return false end

  local loot = self:GetLoot(itemLink)
  if not loot then return end
  if not loot.mayDistribute then return end

  return true
end

--- Checks whether the RPC is safe for the specific item
function mod:IsSafeRPC(item)
  if not self.rpcSender or not self.rpcDistribution then return false end

  -- Ignore messages from self
  if self.rpcSender == UnitName('player') then return false end

  if type(item)~='table' then
    item = self:GetLoot(item)
  end
  if not item then return false end

  -- Only messages from the original master looter are safe.
  return item.lootmaster == self.rpcSender
end

--- This function checks whether the function has been called over RPC
function mod:IsRPC()
  return self.rpcDistribution ~= nil
end

--- Sends the list of all candidates to the monitors instead of sending a monitor message per candidate add.
--  @param itemID of the item
function mod:SendCandidateListToMonitors(itemLink)
  -- TODO(mackatack): Needs implementation
end

--- Handler for the LootMasterChange callback.
--  Someone is lootmaster, see if it's the player, start loot tracking if so.
function mod:OnLootMasterChange(event, newLootMaster)
  -- TODO(mackatack): this is really ui stuff because this will only show the popup, move to lootmaster_ui
  -- if master looter is nil, return
  if not newLootMaster then return end

  -- if player is not the current master looter, then just return.
  if newLootMaster~=UnitName('player') then return end

  -- TODO(mackatack): For debugging purposes tracking is enabled, no questions asked.
  if true then return self:EnableTracking() end

  -- Show a message here, based on the current settings
  if db.use_lootmaster == 'enabled' then
    -- Always enable without asking
    EPGP:Print('You are the Loot Master, loot tracking enabled.')
    self:EnableTracking()
  elseif db.use_lootmaster == 'disabled' then
    -- Disabled from the config panel
    EPGP:Print('You are the Loot Master, tracking disabled manually (open configuration panel to change).')
    self:DisableTracking()
  else
    StaticPopup_Show("EPGP_LOOTMASTER_ASK_TRACKING")
  end
end

--- This handler gets called when the lootmaster clicks master loot from the native wow popup.
function mod:OPEN_MASTER_LOOT_LIST(event)
  Debug(event)

  -- Check if EPGPLM needs to track the loot.
  if not self:TrackingEnabled() then return end

  -- Close the default confirm window
  StaticPopup_Hide("CONFIRM_LOOT_DISTRIBUTION")

  -- Get itemlink and itemID for the selected slot
  -- local _, lootName, lootQuantity, rarity = GetLootSlotInfo(LootFrame.selectedSlot);
  local itemLink = GetLootSlotLink(LootFrame.selectedSlot)
  local itemID = ItemUtils:ItemlinkToID(itemLink)
  
  Debug("master loot: %s", itemLink)

  -- Check itemID
  if not itemID or itemID==0 then
    EPGP:Print(format('Could not get itemid for %s', tostring(itemLink)))
    return
  end

  -- Traverse all lootslots and see how many of this item we have in total.
  local totalQuantity = 0
  for slotNum, slotData in pairs(lootSlots) do
    local slotItemID = ItemUtils:ItemlinkToID(slotData.link)

    if slotItemID and slotItemID==itemID then
      slotData.masterLoot = true
      
      -- A little sanity check; lets see if slotQuantity == 1
      if slotData.quantity~=1 then
        EPGP:Print(format("Could not redistribute %s because quantity != 1 (%s). Please handle it manually. Create a ticket on googlecode if this happens often.", itemLink, slotData.quantity))
        return
      end

      totalQuantity = totalQuantity + 1
    end
  end
  
  Debug("total quantity: %s", totalQuantity)

  -- Sanity check... Check total quantity > 0
  if totalQuantity<1 then
    EPGP:Print( format("Could not redistribute %s because total quantity < 1 (%s). Please handle it manually. Create a ticket on googlecode if this happens often.", itemLink, totalQuantity))
    return
  end

  -- Lootmaster module is handling the loot, so lets close the default popup, unless alt is pressed
  if not IsAltKeyDown() then
    CloseDropDownMenus()
  end

  -- Check to see if we already have the loot registered
  if self:GetLootID(itemLink) then
    -- loot is already registered, just update the ui and do nothing.
    local loot = self:GetLoot(itemLink);
    loot.quantity = totalQuantity or 1
    Debug( 'Updated %s quantity to %s', itemLink, totalQuantity )
    
    -- TODO(mackatack): UI Update callback here
    return
  end
  
  -- Register the loot in the loottable
  local loot = self:AddLoot(itemLink, true, totalQuantity)
  if not loot then return end
  local lootID = loot.id
  
  -- Ok Lets see. Who are the candidates for this slot?
  for candidateID = 1, 40 do repeat
    local candidate = GetMasterLootCandidate(candidateID)
    
    -- Candidate not found, break the repeat so continue the for loop
    if not candidate then break end

    -- Only add the candidate if not already on the list
    if not self:IsCandidate(lootID, candidate) then
      -- Create the candidate for link
      Debug("add candidate: %s", candidate)
      self:AddCandidate(lootID, candidate)
    end
  until true end  
  
  -- Auto announce?
  local autoAnnounce = loot.quality >= (db.auto_announce_threshold or 4)
  if db.auto_announce_threshold == 0 then
    -- Auto Announce Threshold is set to 0 (off), don't autoannounce
    autoAnnounce=false
  end
  
  -- Set the loot status to not announced.
  loot.announced = false;

  -- Lets see if we have to autoloot
  local isAutoLooted = false
  if db.auto_loot_threshold~=0 and db.auto_loot_candidate~='' and loot.autoLootable then
    -- loot is below or equal to auto_loot_threshold and matches the autoLooter requirements
    -- try to give the loot.
    
    -- Don't auto announce the loot
    autoAnnounce = false
    
    if IsAltKeyDown() then
      EPGP:Print('Not auto looting (alt+click detected)')
    else
      isAutoLooted = true
      if self:IsCandidate(lootID, db.auto_loot_candidate) then
        EPGP:Print(format('Auto looting %s to %s', tostring(link), tostring(db.auto_loot_candidate)))
        -- Not sure this will ever happen, but send all matching items to the autolooter
        for i=1, totalQuantity do
          self:GiveLootToCandidate(lootID, db.auto_loot_candidate, LootMaster.LOOTTYPE.BANK )
        end
      else
        EPGP:Print(format('Auto looting of %s failed. Default looter %s is not a candidate for this item.', tostring(link), tostring(db.auto_loot_candidate)))
      end
    end
  end
  
  -- See if we have to auto announce
  if autoAnnounce then
    if IsAltKeyDown() then
      EPGP:Print('Not auto announcing (alt+click detected)')
    else
      Debug("auto announce")
      self:AnnounceLoot(lootID)
    end
  end
  
  -- TODO(mackatack): Update the UI
  
  -- Send candidate list to monitors
  if self:MonitorMessageRequired(lootID) then
    Debug("SendCandidateListToMonitors")
    self:SendCandidateListToMonitors(lootID)
  end
end

--- This handler gets called when the native wow popup opens
function mod:LOOT_OPENED(event, autoLoot, ...)
  Debug("%s: autoloot: %s", event, autoLoot)

  -- Just save time, do nothing if the player is not the master looter.
  -- TODO(mackatack): It's probably better to just not register these
  -- unless the player is lootmaster, but i left it as is so i can always
  -- trap the events for debugging.
  if not player_is_masterlooter then return end

  -- Cache the contents of the lootslots
  local numLootSlots = GetNumLootItems()
  for slot=1, numLootSlots do
    -- Retrieve a reusable table
    local t = popTable()
    t.link = GetLootSlotLink(slot)
    _, t.name, t.quantity, t.rarity = GetLootSlotInfo(slot)    
    lootSlots[slot] = t

    -- player is masterlooter, check whether autoloot == 1, autoloot if so.
    -- This will trigger the OPEN_MASTER_LOOT_LIST event for masterloot and will
    -- just loot any available loot from the list.
    if autoLoot == 1 then
      LootFrame.selectedSlot = slot
      LootSlot(slot)
    end
  end
  
  Debug("END %s: autoloot: %s", event, autoLoot)
end

--- This handler gets called when a loot slot gets cleared.
--  We probably need this event to fix the Naxx portal bug.
function mod:LOOT_SLOT_CLEARED(event, slotID, ...)
  Debug("%s: slot %d: %s", event, slotID, tostring(lootSlots[slotID].link))

  -- Just save time, do nothing if the player is not the master looter
  if not player_is_masterlooter then return end

  -- Someone looted a slot, update our local cache
  pushTable(lootSlots[slotID])
  lootSlots[slotID] = nil
end

--- This handler gets called when the native loot frame gets closed
function mod:LOOT_CLOSED(event, ...)
  Debug(event)

  -- Just save time, do nothing if the player is not the master looter
  if not player_is_masterlooter then return end

  -- Clear the cache of lootslots
  for i, tbl in pairs(lootSlots) do
    pushTable(tbl)
    lootSlots[i] = nil
  end
  wipe(lootSlots)
end

--- This handler gets called when someone in the raid receives an item.
--  TODO(mackatack): all this function does is detect who received an item and
--      fire a callback (PlayerReceivesLoot). This probably needs to be moved elsewhere, or not
--      and other modules should use the callback instead of listening for CHAT_MSG_LOOT events themselves
function mod:CHAT_MSG_LOOT(event, message, ...)
  -- TODO(mackatack): needs implementation.
  print(event, message, ...)
end

--- This callback handler gets called when a player receives an item
function mod:OnPlayerReceivesLoot(event, player, itemlink, quantity)
  -- TODO(mackatack): needs implementation.
end

--- This handler gets called when various events are fired.
--  Find out if we're using master looting and find out who it is
function mod:GROUP_UPDATE()
  local lootmethod, mlPartyID, mlRaidID = GetLootMethod()
  local newLootMaster = nil

  if lootmethod == 'master' then
    if mlRaidID then
      -- we're in raid
      newLootMaster = GetRaidRosterInfo(mlRaidID)
    elseif mlPartyID==0 then
      -- player is ml
      newLootMaster = UnitName('player')
    elseif mlPartyID then
      -- someone else in party is ml
      newLootMaster = UnitName('party'..mlPartyID)
    end
  end

  if current_masterlooter ~= newLootMaster then
    -- Only trigger the event when there is a new lootmaster.
    current_masterlooter = newLootMaster

    -- Set the boolean whether the player is masterlooter or not.
    player_is_masterlooter = (newLootMaster == UnitName("player"))

    -- Callback
    callbacks:Fire("LootMasterChanged", newLootMaster)
  end
end
