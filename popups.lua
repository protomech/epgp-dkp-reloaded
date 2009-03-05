local mod = EPGP:NewModule("popups")

local L = LibStub("AceLocale-3.0"):GetLocale("EPGP")
local gptooltip = EPGP:GetModule("gptooltip")

local function EPGP_CONFIRM_GP_CREDIT_UpdateButtons(self)
  local link = self.itemFrame.link
  local gp = tonumber(self.editBox:GetText())
  if EPGP:CanIncGPBy(link, gp) then
    self.button1:Enable()
  else
    self.button1:Disable()
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

  OnShow = function(self, data)
             if not blizzardPopupAnchors[self] then
               blizzardPopupAnchors[self] = {}
               SaveAnchors(blizzardPopupAnchors[self],
                           self.itemFrame, self.editBox, self.button1)
             end

             self.itemFrame:SetPoint("TOPLEFT", 35, -35)
             self.editBox:SetPoint(
               "TOPLEFT", self.itemFrame, "TOPRIGHT", 150, -10)
             self.editBox:SetPoint("RIGHT", -35, 0)
             self.button1:SetPoint(
               "TOPRIGHT", self.itemFrame, "BOTTOMRIGHT", 85, -6)

             local text = gptooltip:GetGPValueText(self.itemFrame.link)
             self.editBox:SetText(text)
             self.editBox:HighlightText()
             EPGP_CONFIRM_GP_CREDIT_UpdateButtons(self)
           end,

  OnHide = function(self)
             -- Clear anchor points of frames that we modified, and revert them.
             self.itemFrame:ClearAllPoints()
             self.editBox:ClearAllPoints()
             self.button1:ClearAllPoints()

             RestoreAnchors(blizzardPopupAnchors[self])

             if ChatFrameEditBox:IsShown() then
               ChatFrameEditBox:SetFocus()
             end
             self.editBox:SetText("")
           end,

  EditBoxOnEnterPressed = function(self)
                            self:GetParent().button1:Click()
                          end,

  EditBoxOnTextChanged = function(self)
                           local parent = self:GetParent()
                           EPGP_CONFIRM_GP_CREDIT_UpdateButtons(parent)
                         end,

  EditBoxOnEscapePressed = function(self)
                             self:GetParent():Hide()
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
               EPGP:GetModule("log"):Rollback()
             end
}

StaticPopupDialogs["EPGP_BOSS_DEAD"] = {
  text = L["%s is dead. Award EP?"],
  button1 = ACCEPT,
  button2 = CANCEL,
  timeout = 0,
  whileDead = 1,
  hasEditBox = 1,
  OnAccept = function(self)
               local ep = tonumber(self.editBox:GetText())
               EPGP:IncMassEPBy(self.reason, ep)
             end,

  OnHide = function(self)
             if ChatFrameEditBox:IsShown() then
               ChatFrameEditBox:SetFocus()
             end
             self.editBox:SetText("")
             self.reason = nil
           end,

  EditBoxOnEnterPressed = function(self)
                            self:GetParent().button1:Click()
                          end,

  EditBoxOnTextChanged = function(self)
                           local parent = self:GetParent()
                           local ep = tonumber(parent.editBox:GetText())
                           if EPGP:CanIncEPBy(parent.reason, ep) then
                             parent.button1:Enable()
                           else
                             parent.button1:Disable()
                           end
                         end,
  EditBoxOnEscapePressed = function(self)
                             self:GetParent():Hide()
                           end,
}
