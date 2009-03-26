local mod = EPGP:NewModule("announce")

local L = LibStub("AceLocale-3.0"):GetLocale("EPGP")

function mod:Announce(fmt, ...)
  local medium = self.db.profile.medium
  local channel = self.db.profile.channel or 0

  -- Override raid and party if we are not grouped
  if medium == "RAID" and not UnitInRaid("player") then
    medium = "GUILD"
  elseif medium == "PARTY" and not UnitInRaid("player") then
    medium = "GUILD"
  end

  local msg = string.format(fmt, ...)
  local str = "EPGP:"
  for _,s in pairs({strsplit(" ", msg)}) do
    if #str + #s >= 250 then
      if ChatThrottleLib then
        ChatThrottleLib:SendChatMessage(
          "NORMAL", "EPGP", str, medium, nil, GetChannelName(channel))
      else
        SendChatMessage(str, medium, nil, GetChannelName(channel))
      end
      str = "EPGP:"
    end
    str = str .. " " .. s
  end

  SendChatMessage(str, medium, nil, GetChannelName(channel))
end

local function AnnounceEPAward(event_name, name, reason, amount, mass)
  if mass then return end
  mod:Announce(L["%+d EP (%s) to %s"], amount, reason, name)
end

local function AnnounceGPAward(event_name, name, reason, amount, mass)
  if mass then return end
  mod:Announce(L["%+d GP (%s) to %s"], amount, reason, name)
end

local function AnnounceMassEPAward(event_name, names, reason, amount)
  local first = true
  local awarded

  for name in pairs(names) do
    if first then
      awarded = name
      first = false
    else
      awarded = awarded..", "..name
    end
  end

  mod:Announce(L["%+d EP (%s) to %s"], amount, reason, awarded)
end

local function AnnounceDecay(event_name, decay_p)
  mod:Announce(L["Decay of EP/GP by %d%%"], decay_p)
end

local function AnnounceStartRecurringAward(event_name, reason, amount, mins)
  local fmt, val = SecondsToTimeAbbrev(mins * 60)
  mod:Announce(L["Start recurring award (%s) %d EP/%s"], reason, amount, fmt:format(val))
end

local function AnnounceStopRecurringAward(event_name)
  mod:Announce(L["Stop recurring award"])
end

local function AnnounceEPGPReset(event_name)
  mod:Announce(L["EP/GP are reset"])
end

mod.dbDefaults = {
  profile = {
    enabled = true,
    medium = "GUILD",
  }
}

mod.optionsName = L["Announce"]
mod.optionsDesc = L["Announcement of EPGP actions"]
mod.optionsArgs = {
  help = {
    order = 1,
    type = "description",
    name = L["Announces all EPGP actions to the specified medium."],
  },
  medium = {
    order = 10,
    type = "select",
    name = L["Announce medium"],
    desc = L["Sets the announce medium EPGP will use to announce EPGP actions."],
    values = {
      ["GUILD"] = CHAT_MSG_GUILD,
      ["OFFICER"] = CHAT_MSG_OFFICER,
      ["RAID"] = CHAT_MSG_RAID,
      ["PARTY"] = CHAT_MSG_PARTY,
      ["CHANNEL"] = CUSTOM,
    },
  },
  channel = {
    order = 11,
    type = "input",
    name = L["Custom announce channel name"],
    desc = L["Sets the custom announce channel name used to announce EPGP actions."],
    disabled = function(i) return mod.db.profile.medium ~= "CHANNEL" end,
  },
}

function mod:OnEnable()
  EPGP.RegisterCallback(self, "EPAward", AnnounceEPAward)
  EPGP.RegisterCallback(self, "MassEPAward", AnnounceMassEPAward)
  EPGP.RegisterCallback(self, "GPAward", AnnounceGPAward)
  EPGP.RegisterCallback(self, "Decay", AnnounceDecay)
  EPGP.RegisterCallback(self, "StartRecurringAward",
                        AnnounceStartRecurringAward)
  EPGP.RegisterCallback(self, "StopRecurringAward", AnnounceStopRecurringAward)
  EPGP.RegisterCallback(self, "EPGPReset", AnnounceEPGPReset)
end

function mod:OnDisable()
  EPGP.UnregisterAllCallbacks(self)
end