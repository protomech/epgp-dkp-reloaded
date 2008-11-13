local mod = EPGP:NewModule("EPGP_Report", "AceEvent-3.0")

local L = LibStub:GetLibrary("AceLocale-3.0"):GetLocale("EPGP")

local function Report(fmt, ...)
  local report_channel = "GUILD"
  local report_custom_channel = "epgp_testing"

  local msg = string.format(fmt, ...)
  local str = "EPGP:"
  for _,s in pairs({strsplit(" ", msg)}) do
    if #str + #s >= 250 then
      if report_channel == "CHANNEL" then
        SendChatMessage(str, report_channel, nil,
                        GetChannelName(report_custom_channel))
      else
        SendChatMessage(str, report_channel)
      end
      str = "EPGP:"
    end
    str = str .. " " .. s
  end

  if report_channel == "CHANNEL" then
    SendChatMessage(str, report_channel, nil,
                    GetChannelName(report_custom_channel))
  else
    SendChatMessage(str, report_channel)
  end
end

local function ReportEPAward(event_name, name, reason, amount)
  Report(L["Awarded %d EP to %s for %s"], amount, name, reason)
end

local function ReportGPAward(event_name, name, reason, amount)
  Report(L["Credited %d GP to %s for %s"], amount, name, reason)
end

local function ReportMassEPAward(event_name, names, reason, amount)
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

function mod:OnInitialize()
  -- TODO(alkis): Use db to persist enabled/disabled state.
end

function mod:OnEnable()
  EPGP:RegisterCallback("EPAward", ReportEPAward)
  EPGP:RegisterCallback("MassEPAward", ReportMassEPAward)
  EPGP:RegisterCallback("GPAward", ReportGPAward)
end
