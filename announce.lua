local mod = EPGP:NewModule("EPGP_Announce")

local L = LibStub("AceLocale-3.0"):GetLocale("EPGP")

local function Announce(fmt, ...)
  local medium = EPGP.db.profile.announce_medium
  local channel = EPGP.db.profile.announce_channel or 0

  local msg = string.format(fmt, ...)
  local str = "EPGP:"
  for _,s in pairs({strsplit(" ", msg)}) do
    if #str + #s >= 250 then
      SendChatMessage(str, medium, nil, GetChannelName(channel))
      str = "EPGP:"
    end
    str = str .. " " .. s
  end

  SendChatMessage(str, medium, nil, GetChannelName(channel))
end

local function AnnounceEPAward(event_name, name, reason, amount, mass)
  if mass or not EPGP.db.profile.announce then return end
  Announce(L["%+d EP (%s) to %s"], amount, reason, name)
end

local function AnnounceGPAward(event_name, name, reason, amount, mass)
  if mass or not EPGP.db.profile.announce then return end
  Announce(L["%+d GP (%s) to %s"], amount, reason, name)
end

local function AnnounceMassEPAward(event_name, names, reason, amount)
  if not EPGP.db.profile.announce then return end
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

function mod:OnEnable()
  EPGP.RegisterCallback(self, "EPAward", AnnounceEPAward)
  EPGP.RegisterCallback(self, "MassEPAward", AnnounceMassEPAward)
  EPGP.RegisterCallback(self, "GPAward", AnnounceGPAward)
  EPGP.RegisterCallback(self, "Decay", AnnounceDecay)
  EPGP.RegisterCallback(self, "StartRecurringAward",
                        AnnounceStartRecurringAward)
  EPGP.RegisterCallback(self, "StopRecurringAward", AnnounceStopRecurringAward)
end
