local mod = EPGP:NewModule("EPGP_Popups")

local L = LibStub("AceLocale-3.0"):GetLocale("EPGP")
local GPTooltip = EPGP:GetModule("EPGP_GPTooltip")

local function EPGP_CONFIRM_GP_CREDIT_UpdateButtons(self)
  local link = self.itemFrame.link
  local gp = tonumber(self.editBox:GetText())
  if EPGP:CanIncGPBy(link, gp) then
    self.button1:Enable()
    self.button3:Enable()
  else
    self.button1:Disable()
    self.button3:Disable()
  end
end

local function SaveAnchors(t, ...)
  for n=1,select('#', ...) do
    local frame = select(n, ...)
    for i=1,frame:GetNumPoints() do
      local point, relativeTo, relativePoint, x, y = frame:GetPoint(i)
      if point then
        table.insert(t, {frame, point, relativeTo, relativePoint, x, y })
      end
    end
  end
end

local function RestoreAnchors(t)
  for i=1,#t do
    local frame, point, relativeTo, relativePoint, x, y = unpack(t[i])
    frame:SetPoint(point, relativeTo, relativePoint, x, y)
  end
end

local blizzardPopupAnchors = {}

StaticPopupDialogs["EPGP_CONFIRM_GP_CREDIT"] = {
  text = L["Credit GP to %s"],
  button1 = ACCEPT,
  button2 = CANCEL,
  timeout = 0,
  whileDead = 1,
  maxLetters = 16,
  hideOnEscape = 1,
  hasEditBox = 1,
  hasItemFrame = 1,                    

  OnAccept = function(self)
               local link = self.itemFrame.link
               local gp = tonumber(self.editBox:GetText())
               EPGP:IncGPBy(self.name, link, gp)
             end,

  OnCancel = function(self)
               self:Hide()
               ClearCursor()
             end,

  OnShow = function(self)
             local itemFrame = getglobal(self:GetName().."ItemFrame")
             local editBox = getglobal(self:GetName().."EditBox")
             local button1 = getglobal(self:GetName().."Button1")

             if not blizzardPopupAnchors[self] then
               blizzardPopupAnchors[self] = {}
               SaveAnchors(blizzardPopupAnchors[self],
                           itemFrame, editBox, button1)
             end

             itemFrame:SetPoint("TOPLEFT", 35, -35)
             editBox:SetPoint("TOPLEFT", itemFrame, "TOPRIGHT", 150, -10)
             editBox:SetPoint("RIGHT", -35, 0)
             button1:SetPoint("TOPRIGHT", itemFrame, "BOTTOMRIGHT", 85, -6)

             local gp1, gp2 = GPTooltip:GetGPValue(itemFrame.link)
             if gp1 then
               if gp2 then
                 editBox:SetText(L["%d or %d"]:format(gp1, gp2))
               else
                 editBox:SetText(gp1)
               end
             end
             editBox:HighlightText()
             EPGP_CONFIRM_GP_CREDIT_UpdateButtons(self)
           end,

  OnHide = function(self)
             local itemFrame = getglobal(self:GetName().."ItemFrame")
             local editBox = getglobal(self:GetName().."EditBox")
             local button1 = getglobal(self:GetName().."Button1")
             
             -- Clear anchor points of frames that we modified, and revert them.
             itemFrame:ClearAllPoints()
             editBox:ClearAllPoints()
             button1:ClearAllPoints()

             RestoreAnchors(blizzardPopupAnchors[self])
           
             if ChatFrameEditBox:IsShown() then
               ChatFrameEditBox:SetFocus()
             end
           end,

  EditBoxOnEnterPressed = function(self)
                            local parent = self:GetParent()
                            local link = parent.itemFrame.link
                            local gp = tonumber(parent.editBox:GetText())
                            if EPGP:CanIncGPBy(link, gp) then
                              EPGP:IncGPBy(parent.name, link, gp)
                              parent:Hide()
                            end
                          end,

  EditBoxOnTextChanged = function(self)
                           local parent = self:GetParent()
                           EPGP_CONFIRM_GP_CREDIT_UpdateButtons(parent)
                         end,

  EditBoxOnEscapePressed = function(self)
                             self:GetParent():Hide()
                             ClearCursor()
                           end
}

StaticPopupDialogs["EPGP_DECAY_EPGP"] = {
  text = L["Decay EP and GP by %d%%?"],
  button1 = ACCEPT,
  button2 = CANCEL,
  timeout = 0,
  hideOnEscape = 1,
  whileDead = 1,
  OnAccept = function()
               EPGP:DecayEPGP()
             end
}

StaticPopupDialogs["EPGP_RESET_EPGP"] = {
  text = L["Reset all main toons' EP and GP to 0?"],
  button1 = ACCEPT,
  button2 = CANCEL,
  timeout = 0,
  hideOnEscape = 1,
  whileDead = 1,
  OnAccept = function()
               EPGP:ResetEPGP()
             end
}

StaticPopupDialogs["EPGP_ROLLBACK_EPGP"] = {
  text = L["Rollback to snapshot taken on %s?"],
  button1 = ACCEPT,
  button2 = CANCEL,
  timeout = 0,
  hideOnEscape = 1,
  whileDead = 1,
  OnAccept = function()
               EPGP:GetModule("EPGP_Log"):Rollback()
             end
}
