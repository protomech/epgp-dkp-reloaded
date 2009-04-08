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
local gptooltip = EPGP:GetModule("gptooltip")
local callbacks = EPGP.callbacks
local Debug = LibStub("LibDebug-1.0", true)

-- Initialise the main loot table
local lootTable = {}

local db = nil;

-- Cache some math function for faster access and preventing
-- other addons from screwing em up.
local mathRandomseed        = math.randomseed
local mathRandom            = math.random
local mathFloor             = math.floor
local mathCachedRandomSeed  = math.random()*1000

--- Initialize the lootmaster module
function mod:OnInitialize()
  -- Set current lootmaster to -1 so the LootMasterChanged event always gets called
  self.current_ml = -1

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
  --self:SetRPCKey("EPGPLMRPC")         -- set a prefix/channel for the communications
  
  -- Setup the public RPC methods
  --self:RegisterRPC("RPC")
  
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

--- Add loot to masterloot cache. This is where candidate responses are stored
--  @param itemlink of the loot to be added
--  @param boolean whether this is an item the user is allowed to distribute
--  @param item count
--  @return the itemID of the item
function mod:AddLoot(link, mayDistribute, quantity)
  if not link then return end
  if not lootTable then return end
    
  -- Cache a new randomseed for later use.
  -- math.random always has same values for seeds > 2^31, so lets modulate.
  mathCachedRandomSeed = floor((mathRandom()+1)*(GetTime()*1000)) % 2^31
    
  if lootTable[link] then return link end

  local itemName, itemLink, _, _, itemMinLevel, itemType, itemSubType, itemStackCount, _, itemTexture = GetItemInfo(link)
    
  local itemID = strmatch(itemLink, 'Hitem:(%d+)')
  if not itemID or not itemName then return end

  if lootTable[itemID] then return itemID end

  -- Calc the EPGP values for this item, use gptooltip's implementation to also use the additional
  -- info from the set tokens.
  local gpvalue, gpvalue2, ilevel, itemRarity, itemEquipLoc = gptooltip:GetGPValue(itemLink)

  -- See if the item is BoP, BoE or BoU
  -- TODO(mackatack): implement this elsewhere
  -- local itemBind = LootMaster:GetItemBinding( itemLink )
  local itemBind = 'equip'
    
  -- Find what classes are eligible for the loot
  -- TODO(mackatack): implement the following functions elsewhere
  -- local autoPassClasses = LootMaster:GetItemAutoPassClasses( itemLink )
  -- local autoPassClassesEncoded = LootMaster:EncodeUnlocalizedClasses(autoPassClasses) or 0
  local autoPassClasses = nil
  local autoPassClassesEncoded = 0

  local itemCache = {
    link            = itemLink,
    name            = itemName,

    announced       = true,
    mayDistribute   = mayDistribute,

    itemID          = itemID,

    gpvalue         = gpvalue or 0,
    gpvalue2        = gpvalue2,
    gpvalue_manual  = gpvalue or 0,
    ilevel          = ilevel or 0,
    binding         = itemBind,
    quality         = itemRarity or 0,
    quantity        = quantity or 1,
    classes         = autoPassClasses,
    classesEncoded  = autoPassClassesEncoded,

    texture         = itemTexture or '',
    equipLoc        = itemEquipLoc or '',
    
    candidates      = {},
    numResponses    = 0
  }
  lootTable[itemID] = itemCache
  
  -- See if this item should be autolooted
  if db.auto_loot_threshold~=0 and db.auto_loot_candidate and db.auto_loot_candidate~='' then
      if (not itemBind or itemBind=='use' or itemBind=='equip') and itemRarity<=db.auto_loot_threshold then
          itemCache.autoLootable = true
      end
  end
  
  --[[ TODO(mackatack): implement the monitor system again
  -- Are we lootmaster for this loot? Lets send out a monitor message about the added loot
  if lootTable[itemID].mayDistribute and self:MonitorMessageRequired(itemID) then
      self:SendMonitorMessage('PRIORITY_HIGH', 'ADDLOOT', itemLink, itemName, itemID, gpvalue or 0, ilevel or 0, itemBind, itemRarity or 0, itemTexture or '', itemEquipLoc or '', gpvalue2 or '', quantity or 1, autoPassClassesEncoded)
  end
  ]]

  return itemID
end

--- Retrieve the itemcache for loot with itemLink, itemID or itemName "itemID"
--  @param itemID of the item to retrieve
--  @return table with all loot information.
function mod:GetLoot(itemID)
  -- TODO(mackatack): Needs implementation
end

--- Retrieve the itemID for loot with itemLink, itemID or itemName "itemID",
--  used to quickly test if an item is already in the cache table
--  @param itemID of the item to retrieve
--  @return table with all loot information.
function mod:GetLootID(itemID)
  -- TODO(mackatack): Needs implementation
end

--- Remove the itemcache for loot with itemLink, itemID or itemName "itemID"
--  @param itemID of the item to remove
--  @return true if remove succeeded
function mod:RemoveLoot(itemID)
  -- TODO(mackatack): Needs implementation
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

--- Sends the list of all candidates to the monitors instead of sending a monitor message per candidate add.
--  @param itemID of the item
function mod:SendCandidateListToMonitors(itemID)
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
function mod:OPEN_MASTER_LOOT_LIST()
  -- TODO(mackatack): needs implementation.
end

--- This handler gets called when someone in the raid receives an item.
--  TODO(mackatack): all this function does is detect who received an item and
--      fire a callback (PlayerReceivesLoot). This probably needs to be moved elsewhere, or not
--      and other modules should use the callback instead of listening for CHAT_MSG_LOOT events themselves
function mod:CHAT_MSG_LOOT(event, message)
  -- TODO(mackatack): needs implementation.
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
  
  if self.current_ml ~= newLootMaster then
    -- Only trigger the event when there is a new lootmaster.
    self.current_ml = newLootMaster
    callbacks:Fire("LootMasterChanged", newLootMaster)
  end
end
