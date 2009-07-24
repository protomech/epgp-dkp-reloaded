local mod = EPGP:NewModule("whisper", "AceEvent-3.0")

local L = LibStub("AceLocale-3.0"):GetLocale("EPGP")

local senderMap = {}

function mod:CHAT_MSG_WHISPER(event_name, msg, sender)
  if not UnitInRaid("player") then return end

  -- We're going to capitalize the name of the player if it's needed anyway.
  msg = msg:lower()
  if msg:sub(1, 12) ~= 'epgp standby' then return end

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
  EPGP:GetModule("announce"):AnnounceTo(
    "GUILD",
    L["If you want to be on the award list but you are not in the raid, you need to whisper me: 'epgp standby' or 'epgp standby <name>' where <name> is the toon that should receive awards"])
  for member, sender in pairs(senderMap) do
    if EPGP:IsMemberInExtrasList(member) then
      SendChatMessage(L["%+d EP (%s) to %s"]:format(amount, reason, member),
                      "WHISPER", nil, sender)
      SendChatMessage(
        L["%s is now removed from the award list"]:format(member),
        "WHISPER", nil, sender)
      EPGP:DeSelectMember(member)
    end
    senderMap[member] = nil
  end
end

mod.dbDefaults = {
  profile = {
    enable = false,
  }
}

mod.optionsName = L["Whisper"]
mod.optionsDesc = L["Standby whispers in raid"]
mod.optionsArgs = {
  help = {
    order = 1,
    type = "description",
    name = L["Automatic handling of the standby list through whispers when in raid. When this is enabled, the standby list is cleared after each reward."],
  },
}

function mod:OnEnable()
  self:RegisterEvent("CHAT_MSG_WHISPER")
  EPGP.RegisterCallback(self, "MassEPAward", SendNotifiesAndClearExtras)
  EPGP.RegisterCallback(self, "StartRecurringAward", SendNotifiesAndClearExtras)
end

function mod:OnDisable()
  EPGP.UnregisterAllCallbacks(self)
end
