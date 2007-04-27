local mod = EPGP:NewModule("EPGP_Backend", "AceHook-2.1", "AceEvent-2.0")

local function GuildIterator(obj, i)
  local name = GetGuildRosterInfo(i)
  -- Handle dummies
  if obj.cache:IsDummy(name) then
    name = EPGP.db.profile.dummies[name]
  end
  if not name then return end
  return i+1, name
end

local function RaidIterator(obj, i)
  if not UnitInRaid("player") then return end
  local name = GetRaidRosterInfo(i)
  if not name then return end
  return i+1, name
end

local ITERATORS = {
  ["GUILD"] = GuildIterator,
  ["RAID"] = RaidIterator,
}

local LISTING_IDS = {
  "GUILD",
  "RAID",
}
function mod:GetListingIDs()
  return LISTING_IDS
end

function mod:OnInitialize()
  self.cache = EPGP:GetModule("EPGP_Cache")
  StaticPopupDialogs["EPGP_GP_ASSIGN_FOR_LOOT"] = {
    text = "Credit GP to %s for %s",
    button1 = ACCEPT,
    button2 = CANCEL,
    timeout = 0,
    OnShow = function()
      local gp = EPGP:GetModule("EPGP_GPTooltip"):GetGPValue(mod.itemLink) or ""
      local editBox = getglobal(this:GetName().."EditBox")
      editBox:SetNumeric(true)
      editBox:SetText(gp)
      editBox:HighlightText()
      editBox:SetFocus()
    end,
    OnAccept = function()
      local editBox = getglobal(this:GetParent():GetName().."EditBox")
      local gp = editBox:GetNumber()
      if gp > 0 and gp < 10000 then
        mod:AddGP2Member(mod.member, gp)
      end
    end,
    EditBoxOnEnterPressed = function()
      local editBox = getglobal(this:GetParent():GetName().."EditBox")
      local gp = editBox:GetNumber()
      if gp > 0 and gp < 10000 then
        mod:AddGP2Member(member, gp)
        this:GetParent():Hide()
      end
    end,
    EditBoxOnTextChanged = function()
      local editBox = getglobal(this:GetParent():GetName().."EditBox")
      local button1 = getglobal(this:GetParent():GetName().."Button1")
      local gp = editBox:GetNumber()
      if gp > 0 and gp < 10000 then
        button1:Enable()
      else
        button1:Disable()
      end
    end,
    EditBoxOnEscapePressed = function()
      this:GetParent():Hide()
    end,
    hideOnEscape = 1,
    hasEditBox = 1,
  }
  StaticPopupDialogs["EPGP_RESET_EPGP"] = {
    text = "Reset all EP and GP to 0 and make officer notes readable by all?",
    button1 = ACCEPT,
    button2 = CANCEL,
    timeout = 0,
    OnAccept = function()
      mod:ResetEPGP()
    end,
    hideOnEscape = 1,
  }
  StaticPopupDialogs["EPGP_DECAY_EPGP"] = {
    text = "Decay EP and GP by %d%%?",
    button1 = ACCEPT,
    button2 = CANCEL,
    timeout = 0,
    OnAccept = function()
      mod:DecayEPGP()
    end,
    hideOnEscape = 1,
  }
  StaticPopupDialogs["EPGP_RESTORE_NOTES"] = {
    text = "Restore public and officer notes from the last backup?",
    button1 = ACCEPT,
    button2 = CANCEL,
    timeout = 0,
    OnAccept = function()
      mod:RestoreNotes()
    end,
    hideOnEscape = 1,
  }
  self.popup_add_epgp_data = {}
  StaticPopupDialogs["EPGP_ADD_EPGP"] = {
    text = "%s to %s",
    button1 = ACCEPT,
    button2 = CANCEL,
    timeout = 0,
    OnShow = function()
      local editBox = getglobal(this:GetName().."EditBox")
      editBox:SetFocus()
    end,
    OnAccept = function()
      local data = self.popup_add_epgp_data
      local editBox = getglobal(this:GetParent():GetName().."EditBox")
      local number = editBox:GetNumber()
      if number > -10000 and number < 10000 and number ~= 0 then
        data.func(mod, data.member, number)
      end
    end,
    EditBoxOnEnterPressed = function()
      local data = self.popup_add_epgp_data
      local editBox = getglobal(this:GetParent():GetName().."EditBox")
      local number = editBox:GetNumber()
      if number > -10000 and number < 10000 and number ~= 0 then
        data.func(mod, data.member, number)
        this:GetParent():Hide()
      end
    end,
    EditBoxOnTextChanged = function()
      local editBox = getglobal(this:GetParent():GetName().."EditBox")
      local button1 = getglobal(this:GetParent():GetName().."Button1")
      local number = editBox:GetNumber()
      if number > -10000 and number < 10000 and number ~= 0 then
        button1:Enable()
      else
        button1:Disable()
      end
    end,
    EditBoxOnEscapePressed = function()
      this:GetParent():Hide()
    end,
    hideOnEscape = 1,
    hasEditBox = 1,
  }
  self.popup_unzoned_members_data = {}
  StaticPopupDialogs["EPGP_UNZONED_MEMBERS_POPUP"] = {
    text = "Do you want to include members not in %s in the award? (%s)",
    button1 = YES,
    button2 = NO,
    timeout = 0,
    OnAccept = function()
      local data = self.popup_unzoned_members_data
      data.func(mod, data.list_name, data.points, {})
    end,
    OnCancel = function()
      local data = self.popup_unzoned_members_data
      data.func(mod, data.list_name, data.points, data.exclude_map)
    end,
  }
end

function mod:OnEnable()
  self:RegisterEvent("RAID_ROSTER_UPDATE")
  self:RegisterEvent("EPGP_CACHE_UPDATE")
  self:RegisterEvent("EPGP_STOP_RECURRING_EP_AWARDS")
  self:SecureHook("GiveMasterLoot")
end

function mod:GiveMasterLoot(slot, index)
  if EPGP.db.profile.master_loot_popup then
    mod.member = GetMasterLootCandidate(index)
    mod.itemLink = GetLootSlotLink(slot)
    StaticPopup_Show("EPGP_GP_ASSIGN_FOR_LOOT", mod.member, mod.itemLink)
  end
end

function mod:RAID_ROSTER_UPDATE()
  if not UnitInRaid("player") then
    self:TriggerEvent("EPGP_STOP_RECURRING_EP_AWARDS")
  end
end

function mod:EPGP_CACHE_UPDATE()
  local guild_name = GetGuildInfo("player")
  if guild_name ~= EPGP:GetProfile() then EPGP:SetProfile(guild_name) end
end

function mod:CanLogRaids()
  return CanEditOfficerNote()
end

function mod:CanChangeRules()
  return IsGuildLeader() or (self:CanLogRaids() and EPGP.db.profile.flat_credentials)
end

function mod:Report(fmt, ...)
  if EPGP.db.profile.report_channel ~= "NONE" then
    -- FIXME: Chop-off message to 255 character chunks as necessary
    local msg = string.format(fmt, ...)
    SendChatMessage("EPGP: " .. msg, EPGP.db.profile.report_channel)
  end
end

function mod:ResetEPGP()
  -- First delete all officer notes
  for i = 1, GetNumGuildMembers(true) do
    GuildRosterSetOfficerNote(i, "")
  end
  -- Now set zero values
  for i = 1, GetNumGuildMembers(true) do
    local name = GetGuildRosterInfo(i)
    self.cache:SetMemberEPGP(name, 0, 0, 0, 0)
  end
  self.cache:SaveRoster()
  -- Make officer notes readable by all ranks
  for i = 1,GuildControlGetNumRanks() do
    GuildControlSetRank(i)
    GuildControlSetRankFlag(11, true)
    GuildControlSaveRank(GuildControlGetRankName(i))
  end
  self:Report("All EP/GP are reset and officer notes are made readable by all.")
end

function mod:DecayEPGP()
  local factor = 1 - EPGP.db.profile.decay_percent*0.01
  for i = 1, GetNumGuildMembers(true) do
    local name = GetGuildRosterInfo(i)
    if not self.cache:IsAlt(name) then
      local ep, tep, gp, tgp = self.cache:GetMemberEPGP(name)
      tep = math.floor((ep+tep) * factor)
      ep = 0
      tgp = math.floor((gp+tgp) * factor)
      gp = 0
      self.cache:SetMemberEPGP(name, ep, tep, gp, tgp)
    end
  end
  self.cache:SaveRoster()
  self:Report("Applied a decay of %d%% to EP and GP.", EPGP.db.profile.decay_percent)
end

function mod:AddEP2Member(name, points)
  assert(type(name) == "string")
  if type(points) == "number" then
    local ep, tep, gp, tgp = self.cache:GetMemberEPGP(name)
    self.cache:SetMemberEPGP(name, ep+points, tep, gp, tgp)
    self.cache:SaveRoster()
    self:Report("Awarded %d EPs to %s.", points, name)
  else
    self.popup_add_epgp_data.func = mod.AddEP2Member
    self.popup_add_epgp_data.member = name
    StaticPopup_Show("EPGP_ADD_EPGP", "Award EPs", name, popup_add_epgp_data)
  end
end

function mod:CheckUnzonedInRaid(func, list_name, points)
  assert(UnitInRaid("Player"))
  local t = {}
  for i = 1, GetNumRaidMembers() do
    local name, rank, subgroup, level, class, fileName, zone, online, isDead, role, isML = GetRaidRosterInfo(i)
    if zone ~= GetRealZoneText() then
      table.insert(t, name)
    end
  end

  if #t > 0 then
    -- initialize the exclude map
    local exclude_map = {}
    for i,name in pairs(t) do
      exclude_map[name] = true
    end

    self.popup_unzoned_members_data.func = func
    self.popup_unzoned_members_data.points = points
    self.popup_unzoned_members_data.list_name = list_name
    self.popup_unzoned_members_data.exclude_map = exclude_map
    
    StaticPopup_Show("EPGP_UNZONED_MEMBERS_POPUP", GetRealZoneText(), table.concat(t, ", "))
  else
    func(mod, list_name, points, t) -- t is empty here
  end
end

function mod:AddEP2List(list_name, points, exclude_map)
  assert(type(list_name) == "string" and ITERATORS[list_name])
  assert(type(points) == "number")

  if list_name == "RAID" and not exclude_map then
    mod:CheckUnzonedInRaid(mod.AddEP2List, list_name, points)
    return
  end
  
  local members = {}
  for i,name in ITERATORS[list_name],self,1 do
    if not exclude_map or not exclude_map[name] then
      table.insert(members, name)
      local ep, tep, gp, tgp = self.cache:GetMemberEPGP(name)
      if ep and tep and gp and tgp then -- If the member is not in the guild we get nil
        if not self.cache:IsAlt(name) then -- Don't add EP to alts, otherwise mains will get it multiple times
          self.cache:SetMemberEPGP(name, ep+points, tep, gp, tgp)
        end
      end
    end
  end
  self.cache:SaveRoster()
  self:Report("Awarded %d EPs to %s.", points, table.concat(members, ", "))
end

function mod:RecurringEP2List(list_name, points)
  -- TODO: Need different event for each list
  assert(type(points) == "number")
  if points == 0 then
    self:TriggerEvent("EPGP_STOP_RECURRING_EP_AWARDS")
  else
    self:ScheduleRepeatingEvent("RECURRING_EP", mod.AddEP2List, EPGP.db.profile.recurring_ep_period, self, list_name, points, {})
    self:Report("Awarding %d EPs to raid every %s.", points, SecondsToTime(EPGP.db.profile.recurring_ep_period))
  end
end

function mod:DistributeEP2List(list_name, total_points, exclude_map)
  assert(type(total_points) == "number")

  if list_name == "RAID" and not exclude_map then
    mod:CheckUnzonedInRaid(mod.DistributeEP2List, list_name, total_points)
    return
  end
  
  local count = 0
  for i,name in ITERATORS[list_name],self,1 do
    if not exclude_map or not exclude_map[name] then
      count = count + 1
    end
  end
  local points = math.floor(total_points / count)
  self:AddEP2List(list_name, points, exclude_table)
end

function mod:EPGP_STOP_RECURRING_EP_AWARDS()
  if self:IsEventScheduled("RECURRING_EP") then
    self:CancelScheduledEvent("RECURRING_EP")
    self:Report("Recurring EP awards stopped.")
  end
end

function mod:BonusEP2List(list_name, bonus, exclude_map)
  assert(type(bonus) == "number" and bonus >= 0 and bonus <= 100)

  if list_name == "RAID" and not exclude_map then
    mod:CheckUnzonedInRaid(mod.BonusEP2List, list_name, bonus)
    return
  end
  
  local members = {}
  for i,name in ITERATORS[list_name],self,1 do
    if not exclude_map or not exclude_map[name] then
      table.insert(members, name)
      local ep, tep, gp, tgp = self.cache:GetMemberEPGP(name)
      if ep and tep and gp and tgp then -- If the member is not in the guild we get nil
        if not self.cache:IsAlt(name) then -- Don't add EP to alts, otherwise mains will get it multiple times
          self.cache:SetMemberEPGP(name, ep*(1+bonus/100), tep, gp, tgp)
        end
      end
    end
  end
  self.cache:SaveRoster()
  self:Report("Awarded %d%% EP bonus to %s.", bonus, table.concat(members, ", "))
end

function mod:AddGP2Member(name, points)
  if type(points) == "number" then
    assert(type(name) == "string")
    local ep, tep, gp, tgp = self.cache:GetMemberEPGP(name)
    self.cache:SetMemberEPGP(name, ep, tep, gp+points, tgp)
    self.cache:SaveRoster()
    self:Report("Credited %d GPs to %s.", points, name)
  else
    self.popup_add_epgp_data.func = mod.AddGP2Member
    self.popup_add_epgp_data.member = name
    StaticPopup_Show("EPGP_ADD_EPGP", "Credit GPs", name)
  end
end

function mod:BackupNotes()
  for i = 1, GetNumGuildMembers(true) do
    local name, _, _, _, _, _, note, officernote, _, _ = GetGuildRosterInfo(i)
    EPGP.db.profile.backup_notes[name] = { note, officernote }
  end
  EPGP:Print("Backed up Officer and Public notes.")
end

function mod:RestoreNotes()
  if not EPGP.db.profile.backup_notes then return end
  for i = 1, GetNumGuildMembers(true) do
    local name = GetGuildRosterInfo(i)
    local t = EPGP.db.profile.backup_notes[name]
    if t then
      GuildRosterSetPublicNote(i, t[1])
      GuildRosterSetOfficerNote(i, t[2])
    end
  end
  EPGP:Print("Restored Officer and Public notes.")
end

-------------------------------------------------------------------------------
-- Listings
-------------------------------------------------------------------------------
function mod:IsBelowThreshold(ep)
  return EPGP.db.profile.min_eps > ep
end

local function AreSameTier(n1, n2)
  return (mod:IsBelowThreshold(n1) and mod:IsBelowThreshold(n2)) or
         (not mod:IsBelowThreshold(n1) and not mod:IsBelowThreshold(n2))
end

local COMPARATORS = {
  ["NAME"] = function(a,b) return a[1] < b[1] end,
  ["EP"] = function(a,b) return a[3] > b[3] end,
  ["GP"] = function(a,b) return a[4] > b[4] end,
  ["PR"] = function(a,b) if AreSameTier(a[3], b[3]) then return a[5] > b[5] else return mod:IsBelowThreshold(b[3]) end end,
}

-- list_names: GUILD, RAID, ZONE
-- sort_on: NAME, EP, GP, PR
-- show_alts: boolean
-- current_raid_only: boolean
--
-- returns table of listings with each row: { name:string, ep:number, gp:number, pr:number }
function mod:GetListing(list_name, sort_on, show_alts, current_raid_only, name_search)
  local t = {}
  local iterator = ITERATORS[list_name]
  if not iterator then return t end
  if not self.cache then return t end
  for i,name in iterator,self,1 do
    if (show_alts or not self.cache:IsAlt(name)) and
       (not name_search or name_search == "Search" or string.find(strlower(name), strlower(name_search), 1, true)) then
      local ep, tep, gp, tgp = self.cache:GetMemberEPGP(name)
      local rank, rankIndex, level, class, zone, note, officernote, online, status = self.cache:GetMemberInfo(name)
      if ep and tep and gp and tgp then
        local EP,GP = tep + ep, tgp + gp
        local PR = GP == 0 and EP or EP/GP
        if current_raid_only then
          EP,GP = ep, gp
        end
        table.insert(t, { name, class, EP, GP, PR })
      end
    end
  end
  local comparator = COMPARATORS[sort_on]
  if not comparator then comparator = COMPARATORS.PR end
  table.sort(t, comparator)
  return t
end
