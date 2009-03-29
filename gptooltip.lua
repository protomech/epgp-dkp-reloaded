local mod = EPGP:NewModule("gptooltip", "AceHook-3.0")

local GP = LibStub("LibGearPoints-1.0")
local L = LibStub("AceLocale-3.0"):GetLocale("EPGP")

function OnTooltipSetItem(tooltip, ...)
  local _, itemlink = tooltip:GetItem()
  local gp1, gp2, ilvl = GP:GetValue(itemlink)

  if gp1 then
    if gp2 then
      tooltip:AddLine(
        L["GP: %d or %d [ItemLevel=%d]"]:format(gp1, gp2, ilvl),
        NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
    else
      tooltip:AddLine(
        L["GP: %d [ItemLevel=%d]"]:format(gp1, ilvl),
        NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
    end
  end
end

mod.optionsName = L["Tooltip"]
mod.optionsDesc = L["GP on tooltips"]
mod.optionsArgs = {
  help = {
    order = 1,
    type = "description",
    name = L["Provide a proposed GP value of armor on tooltips. Quest items or tokens that can be traded for armor will also have a proposed GP value."],
  },
}

function mod:OnEnable()
  local obj = EnumerateFrames()
  while obj do
    if obj:IsObjectType("GameTooltip") then
      assert(obj:HasScript("OnTooltipSetItem"))
      self:HookScript(obj, "OnTooltipSetItem", OnTooltipSetItem)
    end
    obj = EnumerateFrames(obj)
  end
end
