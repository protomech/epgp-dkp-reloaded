local mod = EPGP:NewModule("EPGP_GPTooltip")

function mod:AddGP2Tooltip(frame, itemLink)
  local gp, ilvl, ivalue = GPUtils:GetGPValue(itemLink)
  if gp and gp > 0 then
    frame:AddLine(string.format("GP: %d [ItemLevel=%d ItemValue=%d]", gp, ilvl, ivalue),
      NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
    frame:Show()
  end
end

function mod.OnTooltipSetItem(tooltip)
  local _, itemlink = tooltip:GetItem()
  mod:AddGP2Tooltip(tooltip, itemlink)
end

function mod:OnEnable()
  local obj = EnumerateFrames()
  while obj do
    if obj:IsObjectType("GameTooltip") then
      if obj:HasScript("OnTooltipSetItem") then
        local old_script = obj:GetScript("OnTooltipSetItem")
        if old_script then
          obj:SetScript("OnTooltipSetItem", function(obj)
            old_script(obj)
            mod.OnTooltipSetItem(obj)
          end)
        else
          obj:SetScript("OnTooltipSetItem", mod.OnTooltipSetItem)
        end
      end
    end
    obj = EnumerateFrames(obj)
  end
end
