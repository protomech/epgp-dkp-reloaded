local mod = EPGP:NewModule("EPGP_GPTooltip", "AceHook-2.1")

function mod:AddGP2Tooltip(frame, itemLink)
  local gp, ilvl, ivalue = GPUtils:GetGPValue(itemLink)
  if gp and gp > 0 then
    frame:AddLine(string.format("GP: %d [ItemLevel=%d ItemValue=%d]", gp, ilvl, ivalue),
      NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
    frame:Show()
  end
end

function mod:OnTooltipSetItem(tooltip)
  local _, itemlink = tooltip:GetItem()
  self.hooks[tooltip]["OnTooltipSetItem"]()
  self:AddGP2Tooltip(tooltip, itemlink)
end

function mod:OnEnable()
  local obj = EnumerateFrames()
  while obj do
    if obj:IsObjectType("GameTooltip") then
      assert(obj:HasScript("OnTooltipSetItem"))
      self:HookScript(obj, "OnTooltipSetItem")
    end
    obj = EnumerateFrames(obj)
  end
end
