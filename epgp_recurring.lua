local L = LibStub("AceLocale-3.0"):GetLocale("EPGP")
local GS = LibStub("LibGuildStorage-1.0")
local Debug = LibStub("LibDebug-1.0")

local callbacks = EPGP.callbacks

local frame = CreateFrame("Frame", "EPGP_RecurringAwardFrame")
local timeout = 0
local function RecurringTicker(self, elapsed)
  local vars = EPGP.db.profile
  local now = GetTime()
  if now > vars.next_award and GS:IsCurrentState() then
    EPGP:IncMassEPBy(vars.next_award_reason, vars.next_award_amount)
    vars.next_award =
      vars.next_award + vars.recurring_ep_period_mins * 60
  end
  timeout = timeout + elapsed
  if timeout > 0.5 then
    callbacks:Fire("RecurringAwardUpdate",
                   vars.next_award_reason,
                   vars.next_award_amount,
                   vars.next_award - now)
    timeout = 0
  end
end
frame:SetScript("OnUpdate", RecurringTicker)
frame:Hide()

function EPGP:StartRecurringEP(reason, amount)
  local vars = EPGP.db.profile
  if vars.next_award then
    return false
  end

  vars.next_award_reason = reason
  vars.next_award_amount = amount
  vars.next_award = GetTime() + vars.recurring_ep_period_mins * 60
  frame:Show()

  callbacks:Fire("StartRecurringAward",
                 vars.next_award_reason,
                 vars.next_award_amount,
                 vars.recurring_ep_period_mins)
  return true
end

function EPGP:ResumeRecurringEP()
  local vars = EPGP.db.profile
  assert(vars.next_award_reason)
  assert(vars.next_award_amount)
  assert(vars.next_award)
  callbacks:Fire("ResumeRecurringAward",
                 vars.next_award_reason,
                 vars.next_award_amount,
                 vars.recurring_ep_period_mins)
  frame:Show()
end

function EPGP:CanResumeRecurringEP()
  local vars = EPGP.db.profile
  local now = GetTime()
  if not vars.next_award then return false end

  -- Now check if we only missed at most one award period.
  local period_secs = vars.recurring_ep_period_mins * 60
  if vars.next_award + period_secs < GetTime() then
    return false
  end
  return true
end

function EPGP:CancelRecurringEP()
  local vars = EPGP.db.profile
  vars.next_award_reason = nil
  vars.next_award_amount = nil
  vars.next_award = nil
  frame:Hide()
end

function EPGP:StopRecurringEP()
  self:CancelRecurringEP()

  callbacks:Fire("StopRecurringAward")
  return true
end

function EPGP:RunningRecurringEP()
  local vars = EPGP.db.profile
  return not not vars.next_award
end

function EPGP:RecurringEPPeriodMinutes(val)
  local vars = EPGP.db.profile
  if val == nil then
    return vars.recurring_ep_period_mins
  end
  vars.recurring_ep_period_mins = val
end

function EPGP:RecurringEPPeriodString()
  local vars = EPGP.db.profile
  local fmt, val = SecondsToTimeAbbrev(vars.recurring_ep_period_mins * 60)
  return fmt:format(val)
end
