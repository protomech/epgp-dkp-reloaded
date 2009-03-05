local mod = EPGP:NewModule("announce")

local L = LibStub("AceLocale-3.0"):GetLocale("EPGP")

local function Announce(fmt, ...)
  local medium = EPGP.db.profile.announce_medium
  local channel = EPGP.db.profile.announce_channel or 0

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
  Announce(L["%+d EP (%s) to %s"], amount, reason, name)
end

local function AnnounceGPAward(event_name, name, reason, amount, mass)
  if mass then return end
  Announce(L["%+d GP (%s) to %s"], amount, reason, name)
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

  Announce(L["%+d EP (%s) to %s"], amount, reason, awarded)
  if EPGP.db.profile.auto_standby_whispers and UnitInRaid("player") then
    Announce(L["If you want to be on the award list but you are not in the raid, you need to whisper me: 'epgp standby' or 'epgp standby <name>' where <name> is the toon that should receive awards"])
  end
end

local function AnnounceDecay(event_name, decay_p)
  Announce(L["Decay of EP/GP by %d%%"], decay_p)
end

local function AnnounceStartRecurringAward(event_name, reason, amount, mins)
  local fmt, val = SecondsToTimeAbbrev(mins * 60)
  Announce(L["Start recurring award (%s) %d EP/%s"], reason, amount, fmt:format(val))
end

local function AnnounceStopRecurringAward(event_name)
  Announce(L["Stop recurring award"])
end

local function AnnounceEPGPReset(event_name)
  Announce(L["EP/GP are reset"])
end

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