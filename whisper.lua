local mod = EPGP:NewModule("EPGP_Whisper", "AceEvent-3.0")

local L = LibStub("AceLocale-3.0"):GetLocale("EPGP")

local senderMap = {}

function mod:CHAT_MSG_WHISPER(event_name, msg, sender)
  if not UnitInRaid("player") then return end
  if not EPGP.db.profile.auto_standby_whispers then return end
  if not msg:match("epgp standby") then return end

  local member = msg:match("epgp standby ([^ ]+)")
  if member then
    member = member:sub(1,1):upper()..member:sub(2):lower()
  else
    member = sender
  end

  senderMap[member] = sender

  if not EPGP:GetEPGP(member) then
    SendChatMessage(L["%s is not eligible for EP awards"]:format(member),
                    "WHISPER", nil, sender)
  elseif EPGP:IsMemberInAwardList(member) then
    SendChatMessage(L["%s is already in the award list"]:format(member),
                    "WHISPER", nil, sender)
  else
    EPGP:SelectMember(member)
    SendChatMessage(L["%s is added to the award list"]:format(member),
                    "WHISPER", nil, sender)
  end
end

local function SendNotifiesAndClearExtras(event_name, names, reason, amount)
  for member, sender in pairs(senderMap) do
    if EPGP:IsMemberInExtrasList(member) then
      SendChatMessage(L["%+d EP (%s) to %s"]:format(amount, reason, member),
                      "WHISPER", nil, sender)
      -- If whispers are enabled clear the standby list so that people
      -- can re-add themselves.
      if EPGP.db.profile.auto_standby_whispers then
        SendChatMessage(
          L["%s is now removed from the award list"]:format(member),
          "WHISPER", nil, sender)
        EPGP:DeSelectMember(member)
      end
    end
    senderMap[member] = nil
  end
end

function mod:OnEnable()
  self:RegisterEvent("CHAT_MSG_WHISPER")
  EPGP.RegisterCallback(self, "MassEPAward", SendNotifiesAndClearExtras)
end
