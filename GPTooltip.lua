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

local function HookScript(obj, name, func)
  local old_script = obj:GetScript(name)
  if old_script then
    obj:SetScript(name, function(...)
      old_script(...)
      func(...)
    end)
  else
    obj:SetScript(name, func)
  end
end

function mod:OnEnable()
  local obj = EnumerateFrames()
  while obj do
    if obj:IsObjectType("GameTooltip") then
      assert(obj:HasScript("OnTooltipSetItem"))
      HookScript(obj, "OnTooltipSetItem", mod.OnTooltipSetItem)
    end
    obj = EnumerateFrames(obj)
  end
end
