local mod = EPGP:NewModule("EPGP_Report")

local L = LibStub:GetLibrary("AceLocale-3.0"):GetLocale("EPGP")

local function Report(fmt, ...)
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

local function ReportEPAward(event_name, name, reason, amount)
  if not EPGP.db.profile.announce then return end
  Report(L["Awarded %d EP to %s for %s"], amount, name, reason)
end

local function ReportGPAward(event_name, name, reason, amount)
  if not EPGP.db.profile.announce then return end
  Report(L["Credited %d GP to %s for %s"], amount, name, reason)
end

local function ReportMassEPAward(event_name, names, reason, amount)
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

  Report(L["Mass award of %d EP for %s to: %s."], amount, reason, awarded)
end

function mod:OnEnable()
  EPGP:RegisterCallback("EPAward", ReportEPAward)
  EPGP:RegisterCallback("MassEPAward", ReportMassEPAward)
  EPGP:RegisterCallback("GPAward", ReportGPAward)
end
