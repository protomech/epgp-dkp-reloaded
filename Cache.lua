local L = EPGPGlobalStrings

local mod = EPGP:NewModule("EPGP_Cache", "AceEvent-2.0")

function mod:OnInitialize()
  self.guild_member_count = 0
end

function mod:OnEnable()
  self:RegisterEvent("GUILD_ROSTER_UPDATE")
  self:RegisterEvent("PLAYER_GUILD_UPDATE")
  self:RegisterEvent("CHAT_MSG_ADDON")
  self:GuildRosterNow()
end

function mod:LoadConfig()
  local lines = {string.split("\n", GetGuildInfoText() or "")}
  local in_block = false

  local outsiders = {}
  local dummies = {}

  for _,line in pairs(lines) do
    if line == "-EPGP-" then
      in_block = not in_block
    elseif in_block then
      -- Get options and alts
      -- Format is:
      --   @DECAY_P:<number>    // for decay percent (defaults to 10)
      --   @MIN_EP:<number>     // for min eps until member can need items (defaults to 1000)
      --   @FC                  // for flat credentials (true if specified, false otherwise)

      -- Decay percent
      local dp = line:match("@DECAY_P:(%d+)")
      if dp then
        dp = tonumber(dp)
        if dp and dp >= 0 and dp <= 100 then EPGP.db.profile.decay_percent = dp
        else EPGP:Print(L["Decay Percent should be a number between 0 and 100"]) end
      end

      -- Min EPs
      local mep = tonumber(line:match("@MIN_EP:(%d+)"))
      if mep then
        if mep and mep >= 0 then EPGP.db.profile.min_eps = mep
        else EPGP:Print(L["Min EPs should be a positive number"]) end
      end

      -- Flat Credentials
      local fc = line:match("@FC")
      if fc then EPGP.db.profile.flat_credentials = true end

      -- Read in Outsiders
      for outsider, dummy in line:gmatch("(%a+):(%a+)") do
        outsiders[outsider] = dummy
        dummies[dummy] = outsider
      end
    end
  end
  EPGP.db.profile.outsiders = outsiders
  EPGP.db.profile.dummies = dummies
end

local function GetMemberData(obj, name)
  if obj:IsOutsider(name) then
    return EPGP.db.profile.data[EPGP.db.profile.outsiders[name]]
  elseif obj:IsAlt(name) then
    return EPGP.db.profile.data[EPGP.db.profile.alts[name]]
  else
    return EPGP.db.profile.data[name]
  end
end

function mod:IsAlt(name)
  return not not EPGP.db.profile.alts[name]
end

function mod:IsOutsider(name)
  return not not EPGP.db.profile.outsiders[name]
end

function mod:IsDummy(name)
  return not not EPGP.db.profile.dummies[name]
end

function mod:GetMemberEPGP(name)
  local t = GetMemberData(self, name)
  if not t then
    return
  elseif not t[1] then
    return 0,0,0,0
  else
    return unpack(t)
  end
end

function mod:GetMemberInfo(name)
  local guild_name = name
  if self:IsOutsider(name) then
    guild_name = EPGP.db.profile.outsiders[name]
  end
  local t = EPGP.db.profile.info[guild_name]
  if t then return unpack(t) end
end

function mod:SetMemberEPGP(name, ep, tep, gp, tgp)
  assert(type(ep) == "number" and ep >= 0 and ep <= 99999)
  assert(type(tep) == "number" and tep >= 0 and tep <= 999999999)
  assert(type(gp) == "number" and gp >= 0 and gp <= 99999)
  assert(type(tgp) == "number" and tgp >= 0 and tgp <= 999999999)
  local t = GetMemberData(self, name)
  t[1] = ep
  t[2] = tep
  t[3] = gp
  t[4] = tgp
end

local function ParseNote(note)
  if note == "" then return 0, 0, 0, 0 end
  local ep, tep, gp, tgp = string.match(note, "^(%d+)|(%d+)|(%d+)|(%d+)$")
  return tonumber(ep), tonumber(tep), tonumber(gp), tonumber(tgp)
end

function mod:LoadRoster()
  local data = {}
  local info = {}
  local alts = {}
  for i = 1, GetNumGuildMembers(true) do
    local name, rank, rankIndex, level, class, zone, note, officernote, online, status = GetGuildRosterInfo(i)
    -- This is an alt and officernote stores the main
    if string.match(officernote, "%u%l*") == officernote then
      alts[name] = officernote
      data[name] = nil
    -- This is a main and officernote stores EPGP
    else
      local ep, tep, gp, tgp = ParseNote(officernote)
      data[name] = { ep, tep, gp, tgp }
    end
    info[name] = { rank, rankIndex, level, class, zone, note, officernote, online, status }
  end
  EPGP.db.profile.data = data
  EPGP.db.profile.info = info
  EPGP.db.profile.alts = alts

  local old_count = self.guild_member_count
  self.guild_member_count = GetNumGuildMembers(true)
  EPGP:Debug("old:%d new:%d", old_count, self.guild_member_count)
  return old_count ~= self.guild_member_count
end

local function EncodeNote(ep, tep, gp, tgp)
  return string.format("%d|%d|%d|%d", ep, tep, gp, tgp)
end

function mod:SaveRoster()
  for i = 1, GetNumGuildMembers(true) do
    local name, _, _, _, _, _, _, officernote, _, _ = GetGuildRosterInfo(i)
    if not self:IsAlt(name) then
      local ep, tep, gp, tgp = self:GetMemberEPGP(name)
      if ep then
        local new_officernote = EncodeNote(ep, tep, gp, tgp)
        if new_officernote ~= officernote then
          GuildRosterSetOfficerNote(i, new_officernote)
        end
      end
    end
  end
  EPGP:Debug("Notes changed - sending update to guild")
  SendAddonMessage("EPGP", "UPDATE", "GUILD")
end

function mod:GuildRosterNow()
  if not IsInGuild() then return end

  GuildRoster()
  self.last_guild_roster_time = GetTime()
end

function mod:GuildRoster()
  if not IsInGuild() then return end

  local time = GetTime()
  if not self.last_guild_roster_time or time - self.last_guild_roster_time > 10 then
    self:GuildRosterNow()
  else
    local delay = 10 + self.last_guild_roster_time - time
    EPGP:Debug("Delaying GuildRoster() for %f secs", delay)
    self:ScheduleEvent("DELAYED_GUILD_ROSTER_UPDATE", mod.GuildRoster, delay, self)
  end
end

function mod:PLAYER_GUILD_UPDATE()
  self:GuildRoster()
end

function mod:GUILD_ROSTER_UPDATE(local_update)
  local guild_name = GetGuildInfo("player")
  if guild_name and guild_name ~= EPGP:GetProfile() then
    EPGP:SetProfile(guild_name)
  end

  if local_update then
    self:GuildRosterNow()
    return
  end
  EPGP:Debug("Reloading roster and config from game")
  self:LoadConfig()
  local member_change = self:LoadRoster()
  self:TriggerEvent("EPGP_CACHE_UPDATE", member_change)
end

function mod:CHAT_MSG_ADDON(prefix, msg, type, sender)
  if prefix == "EPGP" then
    EPGP:Debug("Processing CHAT_MSG_ADDON(%s,%s,%s,%s)", prefix, msg, type, sender)
    if sender == UnitName("player") then return end
    if msg == "UPDATE" then self:GuildRoster() end
  end
end
