local L = EPGPGlobalStrings

local mod = EPGP:NewModule("EPGP_Backend", "AceEvent-2.0", "AceHook-2.1")

local function OnStaticPopupHide()
  if ChatFrameEditBox:IsShown() then
    ChatFrameEditBox:SetFocus()
  end
  getglobal(this:GetName().."EditBox"):SetText("")
end

local function GuildIterator(obj, i)
  local name = GetGuildRosterInfo(i)
  -- Handle dummies
  if obj:IsDummy(name) then
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

local function IsValidEPValue(value)
  assert(type(value) == "number")
  return value > -100000 and value < 100000 and value ~= 0
end

local function IsValidGPValue(value)
  assert(type(value) == "number")
  return value > -10000 and value < 10000 and value ~= 0
end


function mod:GetListingIDs()
  return LISTING_IDS
end

local cache = nil
local popup_data = nil
function mod:OnInitialize()
  cache = EPGP:GetModule("EPGP_Cache")

  StaticPopupDialogs["EPGP_RESET_EPGP"] = {
    text = L["Reset all EP and GP to 0 and make officer notes readable by all?"],
    button1 = ACCEPT,
    button2 = CANCEL,
    timeout = 0,
    OnAccept =
      function()
        mod:ResetEPGP()
      end,
    hideOnEscape = 1,
    whileDead = 1,
  }
  StaticPopupDialogs["EPGP_DECAY_EPGP"] = {
    text = L["Decay EP and GP by %d%%?"],
    button1 = ACCEPT,
    button2 = CANCEL,
    timeout = 0,
    OnAccept =
      function()
        mod:DecayEPGP()
      end,
    hideOnEscape = 1,
    whileDead = 1,
  }
  StaticPopupDialogs["EPGP_RESTORE_NOTES"] = {
    text = L["Restore public and officer notes from the last backup?"],
    button1 = ACCEPT,
    button2 = CANCEL,
    timeout = 0,
    OnAccept =
      function()
        mod:RestoreNotes()
      end,
    hideOnEscape = 1,
    whileDead = 1,
  }
  local gptooltip = EPGP:GetModule("EPGP_GPTooltip")
  popup_data = {}
  StaticPopupDialogs["EPGP_MODIFY_EPGP"] = {
    text = "%s",
    button1 = ACCEPT,
    button2 = CANCEL,
    timeout = 0,
    OnShow =
      function()
        local data = popup_data
        local editBox = getglobal(this:GetName().."EditBox")
        if gptooltip:GetGPValue(data.reason) then
          editBox:SetText(gptooltip:GetGPValue(data.reason))
        elseif EPGP.db.profile.reason_award_cache[data.reason] then
          editBox:SetText(EPGP.db.profile.reason_award_cache[data.reason])
        end
        editBox:HighlightText()
        editBox:SetFocus()
      end,
    OnHide = OnStaticPopupHide,
    OnAccept =
      function()
        local data = popup_data
        local editBox = getglobal(this:GetParent():GetName().."EditBox")
        local number = editBox:GetNumber()
        if not data.valid_func or data.valid_func(number) then
          EPGP.db.profile.reason_award_cache[data.reason] = number
          if data.member then
            data.func(mod, data.member, data.reason, number)
          else
            data.func(mod, data.reason, number)
          end
        end
      end,
    EditBoxOnEnterPressed =
      function()
        local data = popup_data
        local editBox = getglobal(this:GetParent():GetName().."EditBox")
        local number = editBox:GetNumber()
        if not data.valid_func or data.valid_func(number) then
          EPGP.db.profile.reason_award_cache[data.reason] = number
          if data.member then
            data.func(mod, data.member, data.reason, number)
          else
            data.func(mod, data.reason, number)
          end
          this:GetParent():Hide()
        end
      end,
    EditBoxOnTextChanged =
      function()
        local data = popup_data
        local editBox = getglobal(this:GetParent():GetName().."EditBox")
        local button1 = getglobal(this:GetParent():GetName().."Button1")
        local number = editBox:GetNumber()
        if not data.valid_func or data.valid_func(number) then
          button1:Enable()
        else
          button1:Disable()
        end
      end,
    EditBoxOnEscapePressed =
      function()
        this:GetParent():Hide()
      end,
    hideOnEscape = 1,
    hasEditBox = 1,
    whileDead = 1,
  }
end

function mod:OnEnable()
  self:RegisterEvent("RAID_ROSTER_UPDATE")
  self:RegisterEvent("EPGP_CACHE_UPDATE")
  self:RegisterEvent("EPGP_STOP_RECURRING_EP_AWARDS")
  self:RegisterEvent("EPGP_BOSS_KILLED")
  self:RegisterEvent("EPGP_LOOT_RECEIVED")
end

function mod:RAID_ROSTER_UPDATE()
  if not UnitInRaid("player") then
    self:TriggerEvent("EPGP_STOP_RECURRING_EP_AWARDS")
  end
end

function mod:EPGP_CACHE_UPDATE()
  local guild_name = GetGuildInfo("player")
  if guild_name and guild_name ~= EPGP:GetProfile() then EPGP:SetProfile(guild_name) end
end

function mod:EPGP_BOSS_KILLED(boss)
  if not self:CanLogRaids() then return end
  self:AddEP2Raid(boss)
end

function mod:EPGP_LOOT_RECEIVED(player, itemLink, quantity)
  if not self:CanLogRaids() then return end
  mod:AddGP2Member(player, itemLink)
end

function mod:CanLogRaids()
  return CanEditOfficerNote()
end

function mod:CanChangeRules()
  return IsGuildLeader() or (self:CanLogRaids() and EPGP.db.profile.flat_credentials)
end

function mod:Report(fmt, ...)
  if EPGP.db.profile.report_channel ~= "NONE" then
    local msg = string.format(fmt, ...)
    local str = "EPGP:"
    for _,s in pairs({strsplit(" ", msg)}) do
      if #str + #s >= 250 then
        SendChatMessage(str, EPGP.db.profile.report_channel)
        str = "EPGP:"
      end
      str = str .. " " .. s
    end
    SendChatMessage(str, EPGP.db.profile.report_channel)
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
    cache:SetMemberEPGP(name, 0, 0)
  end
  cache:SaveRoster()
  -- Make officer notes readable by all ranks
  for i = 1,GuildControlGetNumRanks() do
    GuildControlSetRank(i)
    GuildControlSetRankFlag(11, true)
    GuildControlSaveRank(GuildControlGetRankName(i))
  end
  self:Report(L["All EP/GP are reset and officer notes are made readable by all."])
end

function mod:DecayEPGP()
  local factor = 1 - EPGP.db.profile.decay_percent*0.01
  for i = 1, GetNumGuildMembers(true) do
    local name = GetGuildRosterInfo(i)
    if not cache:IsAlt(name) then
      local ep, gp = cache:GetMemberEPGP(name)
      if ep then
        ep = math.floor(ep * factor)
        gp = math.floor(gp * factor)
        cache:SetMemberEPGP(name, ep, gp)
      end
    end
  end
  cache:SaveRoster()
  self:Report(L["Applied a decay of %d%% to EP and GP."], EPGP.db.profile.decay_percent)
end

function mod:AddEP2Member(name, reason, points, silent)
  assert(type(name) == "string")
  assert(type(reason) == "string")
  if type(points) == "number" then
    local ep, gp = cache:GetMemberEPGP(name)
    if ep then
      cache:SetMemberEPGP(name, ep+points, gp)
      cache:SaveRoster()
      if not silent then
        self:Report(L["Awarded %d EP to %s (%s)."], points, name, reason)
      end
    end
  else
    popup_data.func = mod.AddEP2Member
    popup_data.member = name
    popup_data.reason = reason
    popup_data.valid_func = IsValidEPValue
    StaticPopup_Show("EPGP_MODIFY_EPGP", L["Award EP to %s (%s)"]:format(name, reason), popup_modify_epgp_data)
  end
end

function mod:SetEPMember(name, reason, points)
  assert(type(name) == "string")
  if type(points) == "number" then
    local ep, gp = cache:GetMemberEPGP(name)
    cache:SetMemberEPGP(name, points, gp)
    cache:SaveRoster()
    self:Report(L["Set EP for %s to %d (%s)."], name, points, reason)
  else
    popup_data.func = mod.SetEPMember
    popup_data.member = name
    popup_data.reason = reason
    popup_data.valid_func = IsValidEPValue
    StaticPopup_Show("EPGP_MODIFY_EPGP", L["Set EP for %s (%s)"]:format(name, reason), popup_modify_epgp_data)
  end
end

local award_ep
local award_reason
local awarded_members
function mod:AcceptEPWhisperHandler(event, ...)
  if not award_ep then return end
  if event == "CHAT_MSG_WHISPER" and
    type(arg1) == "string" and type(arg2) == "string" then
    local sender = arg2
    local text = arg1
    local player
    if not text:find("%s") then
      if text == "ep" then
        player = sender
      else
        player = text:sub(1,1):upper()..text:sub(2):lower()
      end
      local ep, gp = cache:GetMemberEPGP(player)
      if not ep then
        SendChatMessage(L["%s is not eligible for EP award (%s)"]:format(player, award_reason),
                        "WHISPER", nil, sender)
      else
        local awarded = cache:GetInGuildName(player)
        if not awarded_members[awarded] then
          awarded_members[awarded] = true
          cache:SetMemberEPGP(player, ep+award_ep, gp)
          cache:SaveRoster()
          SendChatMessage(L["Awarded %d EP to %s (%s)"]:format(award_ep, player, award_reason),
                          "WHISPER", nil, sender)
        else
          SendChatMessage(L["%s was already awarded EP (%s)"]:format(player, award_reason),
                          "WHISPER", nil, sender)
        end
      end
    end
  end
end

function mod:AcceptWhisperHandlerTimeout(reason, points)
  if self:IsHooked("ChatFrame_MessageEventHandler") then
    self:Unhook("ChatFrame_MessageEventHandler")
  end
  self:Report(L["No longer accepting whispers for %s"], reason)
  local award_list = {}
  for name,_ in pairs(awarded_members) do
    table.insert(award_list, name)
  end
  self:Report(L["Awarded %d EP to %s (%s)"],
              points, table.concat(award_list, ", "), reason)
  award_ep = nil
  award_reason = nil
  awarded_members = nil
end

function mod:AddEP2Raid(reason, points)
  assert(type(reason) == "string")

  if self:IsHooked("ChatFrame_MessageEventHandler") then
    EPGP:Print("Please wait for current standby EP to be awarded before the next award")
    return
  end

  if type(points) ~= "number" then
    popup_data.func = mod.AddEP2Raid
    popup_data.member = nil
    popup_data.reason = reason
    popup_data.valid_func = IsValidEPValue
    StaticPopup_Show("EPGP_MODIFY_EPGP", L["Award EP to Raid (%s)"]:format(reason), popup_modify_epgp_data)
  else
    award_ep = points
    award_reason = reason
    awarded_members = {}
    for i = 1, GetNumRaidMembers() do
      local player = select(1, GetRaidRosterInfo(i))
      local ep, gp = cache:GetMemberEPGP(player)
      if ep and gp then
        local awarded = cache:GetInGuildName(player)
        if not awarded_members[awarded] then
          awarded_members[awarded] = true
          cache:SetMemberEPGP(player, ep+points, gp)
        end
      end
    end
    self:Report(L["Awarded %d EP to raid (%s)."], points, reason)
    cache:SaveRoster()
    self:Report(L["Whisper 'ep' or your main toon's name to receive standby EP for %s"],
                reason)

    self:SecureHook("ChatFrame_MessageEventHandler", "AcceptEPWhisperHandler")
    self:ScheduleEvent("EPGP_ACCEPT_WHISPER_TIMEOUT",
                       self.AcceptWhisperHandlerTimeout, 60, self, reason, points)
  end
end

function mod:RecurringEP2Raid(reason, points)
  assert(type(reason) == "string")

  if type(points) ~= "number" then
    popup_data.func = mod.RecurringEP2Raid
    popup_data.member = nil
    popup_data.reason = reason
    popup_data.valid_func = IsValidEPValue
    StaticPopup_Show("EPGP_MODIFY_EPGP", L["Recurring EP to Raid (%s)"]:format(reason), popup_modify_epgp_data)
  else
    if points == 0 then
      self:TriggerEvent("EPGP_STOP_RECURRING_EP_AWARDS")
    else
      self:ScheduleRepeatingEvent("RECURRING_EP", mod.AddEP2Raid, EPGP.db.profile.recurring_ep_period, self, reason, points)
      self:Report(L["Awarding %d EP/%s (%s)."], points, SecondsToTime(EPGP.db.profile.recurring_ep_period), reason)
    end
  end
end

function mod:EPGP_STOP_RECURRING_EP_AWARDS()
  if self:IsEventScheduled("RECURRING_EP") then
    self:CancelScheduledEvent("RECURRING_EP")
    self:Report(L["Recurring EP awards stopped."])
  end
end

function mod:AddGP2Member(name, reason, points)
  assert(type(name) == "string")
  assert(type(reason) == "string" or type(reason) == "number")

  if GetItemInfo(reason) then
    reason = select(2, GetItemInfo(reason))
  end

  if type(points) == "number" then
    local ep, gp = cache:GetMemberEPGP(name)
    cache:SetMemberEPGP(name, ep, math.max(gp+points, 0))
    cache:SaveRoster()
    self:Report(L["Credited %d GPs to %s (%s)."], points, name, reason)
  else
    popup_data.func = mod.AddGP2Member
    popup_data.member = name
    popup_data.reason = reason
    popup_data.valid_func = IsValidGPValue
    StaticPopup_Show("EPGP_MODIFY_EPGP", L["Credit GP to %s (%s)"]:format(name, reason))
  end
end

function mod:SetGPMember(name, reason, points)
  assert(type(name) == "string")
  if type(points) == "number" then
    local ep, gp = cache:GetMemberEPGP(name)
    cache:SetMemberEPGP(name, ep, points)
    cache:SaveRoster()
    self:Report(L["Set GPs for %s to %d (%s)."], name, points, reason)
  else
    popup_data.func = mod.SetGPMember
    popup_data.member = name
    popup_data.reason = reason
    popup_data.valid_func = IsValueGPValue
    StaticPopup_Show("EPGP_MODIFY_EPGP", L["Set GP for %s (%s)"]:format(name, reason), popup_modify_epgp_data)
  end
end

function mod:BackupNotes()
  for i = 1, GetNumGuildMembers(true) do
    local name, _, _, _, _, _, note, officernote, _, _ = GetGuildRosterInfo(i)
    EPGP.db.profile.backup_notes[name] = { note, officernote }
  end
  EPGP:Print(L["Backed up Officer and Public notes."])
end

function mod:RestoreNotes()
  if not EPGP.db.profile.backup_notes then return end
  for i = 1, GetNumGuildMembers(true) do
    local name = GetGuildRosterInfo(i)
    local t = EPGP.db.profile.backup_notes[name]
    if t then
      GuildRosterSetPublicNote(i, t[1])
      upgraded_note = t[2]:gsub('|', ',')
      GuildRosterSetOfficerNote(i, upgraded_note)
    end
  end
  EPGP:Print(L["Restored Officer and Public notes."])
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

-- list_names: GUILD, RAID
-- sort_on: NAME, EP, GP, PR
-- show_alts: boolean
-- search_str: string
--
-- returns table of listings with each row: { name:string, class:string, ep:number, gp:number, pr:number }
function mod:GetListing(list_name, sort_on, show_alts, search_str)
  local t = {}
  local iterator = ITERATORS[list_name]
  search_str = strlower(search_str)
  if not iterator then return t end
  if not cache then return t end
  for i,name in iterator,cache,1 do
    if show_alts or not cache:IsAlt(name) then
      local rank, rankIndex, level, class, zone, note, officernote, online, status = cache:GetMemberInfo(name)
      if not search_str or
         search_str == "search" or
         (class and search_str == strlower(class)) or
         string.find(strlower(name), search_str, 1, true) then
        local ep, gp = cache:GetMemberEPGP(name)
        local class = select(4, cache:GetMemberInfo(name))
        if ep and gp then
          local pr = gp == 0 and ep or ep/gp
          table.insert(t, { name, class, ep, gp, pr })
        end
      end
    end
  end
  local comparator = COMPARATORS[sort_on]
  if not comparator then comparator = COMPARATORS.PR end
  table.sort(t, comparator)
  return t
end
