local mod = EPGP:NewModule("EPGP_Cache", "AceConsole-2.0", "AceDB-2.0", "AceDebug-2.0", "AceEvent-2.0")

mod:RegisterDB("EPGP_Cache_DB")
mod:RegisterDefaults("profile", {
  alts = {},
  data = {},
  info = {},
  flat_credentials = false,
  min_eps = 1000,
  decay_percent = 10
})

function mod:OnEnable()
  --self:SetDebugging(true)
  self:RegisterEvent("GUILD_ROSTER_UPDATE")
  self:RegisterEvent("PLAYER_GUILD_UPDATE")
	self:RegisterEvent("CHAT_MSG_ADDON")
	self:GuildRosterNow()
end

function mod:LoadConfig()
  self:Debug("Loading config")
  local lines = {string.split("\n", GetGuildInfoText() or "")}
	local in_block = false
  self.db.profile.alts = {}
	for _,line in pairs(lines) do
		if line == "-EPGP-" then
			in_block = not in_block
		elseif in_block then
		  -- Get options and alts
		  -- Format is:
		  --   @DECAY_P:<number>    // for decay percent (defaults to 10)
		  --   @MIN_EP:<number>     // for min eps until member can need items (defaults to 1000)
		  --   @FC                  // for flat credentials (true if specified, false otherwise)
		  --   Main:Alt1 Alt2       // Alt1 and Alt2 are alts for Main

		  -- Decay percent
			local dp = line:match("@DECAY_P:(%d+)")
			if dp then
			  self:Debug(dp)
			  dp = tonumber(dp)
			  if dp and dp >= 0 and dp <= 100 then self.db.profile.decay_percent = dp
			  else self:Print("Decay Percent should be a number between 0 and 100") end
      end
      
		  -- Min EPs
			local mep = tonumber(line:match("@MIN_EP:(%d+)"))
      if mep then
  			self:Debug(mep)
  		  if mep and mep >= 0 then self.db.profile.min_eps = mep
  		  else self:Print("Min EPs should be a positive number") end
      end

		  -- Flat Credentials
		  local fc = line == "@FC"
		  if fc then self.db.profile.flat_credentials = fc end

			-- Read in alts
		  for main, alts_text in line:gmatch("(%a+):([%a%s]+)") do
		    for alt in alts_text:gmatch("(%a+)") do
	        self.db.profile.alts[alt] = main
		    end
		  end
		end
	end
end

local function GetMemberData(obj, name)
  local real_name = obj.db.profile.alts[name]
  return obj.db.profile.data[real_name or name]
end

function mod:IsAlt(name)
  return not not self.db.profile.alts[name]
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
  local t = self.db.profile.info[name]
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
  self:Debug("Loading roster")
  local data = {}
  local info = {}
  for i = 1, GetNumGuildMembers(true) do
    local name, rank, rankIndex, level, class, zone, note, officernote, online, status = GetGuildRosterInfo(i)
    local ep, tep, gp, tgp = ParseNote(officernote)
    data[name] = { ep, tep, gp, tgp }
    info[name] = { rank, rankIndex, level, class, zone, note, officernote, online, status }
  end
  self.db.profile.data = data
  self.db.profile.info = info
end

local function EncodeNote(ep, tep, gp, tgp)
	return string.format("%d|%d|%d|%d", ep, tep, gp, tgp)	
end

function mod:SaveRoster()
  for i = 1, GetNumGuildMembers(true) do
    local name, _, _, _, _, _, _, officernote, _, _ = GetGuildRosterInfo(i)
    local ep, tep, gp, tgp = self:GetMemberEPGP(name)
    if ep then
      local new_officernote = EncodeNote(ep, tep, gp, tgp)
      if new_officernote ~= officernote then
        GuildRosterSetOfficerNote(i, new_officernote)
      end
    end
  end
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
		self:Debug("Delaying GuildRoster() for %f secs", delay)
		self:ScheduleEvent("DELAYED_GUILD_ROSTER_UPDATE", mod.GuildRoster, delay, self)
	end
end

function mod:PLAYER_GUILD_UPDATE()
  self:GuildRoster()
end

function mod:GUILD_ROSTER_UPDATE(local_update)
	if local_update then
		self:Debug("Detected changes; sending update to guild")
		SendAddonMessage("EPGP", "UPDATE", "GUILD")
		self:GuildRosterNow()
		return
	end
	self:LoadConfig()
	self:LoadRoster()
	self:TriggerEvent("EPGP_CACHE_UPDATE")
end

function mod:CHAT_MSG_ADDON(prefix, msg, type, sender)
	self:Debug("Processing CHAT_MSG_ADDON(%s,%s,%s,%s)", prefix, msg, type, sender)
	if not prefix == "EPGP" then return end
	if sender == UnitName("player") then return end
	if msg == "UPDATE" then self:GuildRoster() end
end

-------------------------------------------------------------------------------
-- Upgrade functions
-------------------------------------------------------------------------------
local NUM2STRING = {
  [0] = "0",
  [1] = "1",
  [2] = "2",
  [3] = "3",
  [4] = "4",
  [5] = "5",
  [6] = "6",
  [7] = "7",
  [8] = "8",
  [9] = "9",
  [10] = "A",
  [11] = "B",
  [12] = "C",
  [13] = "D",
  [14] = "E",
  [15] = "F",
  [16] = "G",
  [17] = "H",
  [18] = "I",
  [19] = "J",
  [20] = "K",
  [21] = "L",
  [22] = "M",
  [23] = "N",
  [24] = "O",
  [25] = "P",
  [26] = "Q",
  [27] = "R",
  [28] = "S",
  [29] = "T",
  [30] = "U",
  [31] = "V",
  [32] = "W",
  [33] = "X",
  [34] = "Y",
  [35] = "Z",
  [36] = "a",
  [37] = "b",
  [38] = "c",
  [39] = "d",
  [40] = "e",
  [41] = "f",
  [42] = "g",
  [43] = "h",
  [44] = "i",
  [45] = "j",
  [46] = "k",
  [47] = "l",
  [48] = "m",
  [49] = "n",
  [50] = "o",
  [51] = "p",
  [52] = "q",
  [53] = "r",
  [54] = "s",
  [55] = "t",
  [56] = "u",
  [57] = "v",
  [58] = "w",
  [59] = "x",
  [60] = "y",
  [60] = "z",
  [62] = "+",
  [63] = "/",
}

local STRING2NUM = { }
for k, v in pairs(NUM2STRING) do
  STRING2NUM[v] = k
end

local function Decode(s)
  local num = 0
  for i = 1, string.len(s) do
    local ss = string.sub(s, i, i)
    num = num * 64
    num = num + (STRING2NUM[ss] or 0)
  end
  
  return num
end

local function ParseNoteVersion1(s)
  if (s == "") then
    return { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 }
  end
  local t = { }
  for i = 1, string.len(s), 2 do
    local val = Decode(string.sub(s, i, i+1))
    table.insert(t, val)
  end
  return t
end

function mod:UpgradeFromVersion1(scale)
  local factor = 1 - self.db.profile.decay_percent * 0.01
  for i = 1, GetNumGuildMembers(true) do
  	local name, _, _, _, _, _, note, officernote, _, _ = GetGuildRosterInfo(i)
  	local ept, gpt = ParseNoteVersion1(note), ParseNoteVersion1(officernote)
  	assert(#ept == #gpt, "EP and GP tables are not of the same size")
  	local tep, tgp = 0, 0
  	for i = #ept,1,-1 do
  		tep = tep + ept[i]*scale
  		tep = math.floor(tep * factor)
  		tgp = tgp + gpt[i]*scale
  		tgp = math.floor(tgp * factor)
  	end
  	self:Debug("%s EP/GP: %d/%d", name, tep, tgp)
  	self:SetMemberEPGP(name, 0, tep, 0, tgp)
  end
end
