local L = LibStub("AceLocale-3.0"):GetLocale("EPGP")
local GS = LibStub("LibGuildStorage-1.0")
local gptooltip = EPGP:GetModule("gptooltip")

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

  OnUpdate = function(self, elapsed)
               local link = self.itemFrame.link
               local gp = tonumber(self.editBox:GetText())
               if EPGP:CanIncGPBy(link, gp) then
                 self.button1:Enable()
               else
                 self.button1:Disable()
               end
             end,

  EditBoxOnEnterPressed = function(self)
                            self:GetParent().button1:Click()
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
             end,

  OnUpdate = function(self, elapsed)
               if GS:IsCurrentState() then
                 self.button1:Enable()
               else
                 self.button1:Disable()
               end
             end,
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
             end,

  OnUpdate = function(self, elapsed)
               if GS:IsCurrentState() then
                 self.button1:Enable()
               else
                 self.button1:Disable()
               end
             end,
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

  OnUpdate = function(self, elapsed)
               local ep = tonumber(self.editBox:GetText())
               if EPGP:CanIncEPBy("", ep) then
                 self.button1:Enable()
               else
                 self.button1:Disable()
               end
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

StaticPopupDialogs["EPGP_EXPORT"] = {
  text = L["To export the current standings, copy the text below and post it to the webapp: http://epgpweb.appspot.com"],
  timeout = 0,
  whileDead = 1,
  hasEditBox = 1,
  OnShow = function(self)
             self.editBox:SetText(EPGP:GetModule("log"):Export())
             self.editBox:HighlightText()
           end,
  OnHide = function(self)
             self.editBox:SetText("")
           end,
  EditBoxOnEscapePressed = function(self)
                             self:GetParent():Hide()
                           end,
}

StaticPopupDialogs["EPGP_IMPORT"] = {
  text = L["To restore to an earlier version of the standings, copy and paste the text from the webapp: http://epgpweb.appspot.com here"],
  button1 = ACCEPT,
  button2 = CANCEL,
  timeout = 0,
  hideOnEscape = 1,
  whileDead = 1,
  hasEditBox = 1,
  OnAccept = function(self)
               EPGP:GetModule("log"):Import(self.editBox:GetText())
             end,
  OnHide = function(self)
             self.editBox:SetText("")
           end,
  EditBoxOnEnterPressed = function(self)
                            self:GetParent().button1:Click()
                          end,
  EditBoxOnEscapePressed = function(self)
                             self:GetParent():Hide()
                           end,
}

StaticPopupDialogs["EPGP_LOOTMASTER_ASK_TRACKING"] = {
  text = L["You are the Loot Master, would you like to use %s to distribute loot?\r\n\r\n(You will be asked again next time. Use the configuration panel to change this behaviour)"]:format('EPGP Lootmaster'),
  button1 = YES,
  button2 = NO,
  OnAccept = function()
    EPGP:GetModule("lootmaster"):EnableTracking()
    EPGP:Print(L['You have enabled loot tracking for this raid'])
  end,
  OnCancel = function()
    EPGP:GetModule("lootmaster"):DisableTracking()
    EPGP:Print(L['You have disabled loot tracking for this raid'])
  end,
  OnShow = function()
  end,
  OnHide = function()
  end,
  timeout = 0,
  hideOnEscape = 0,
  whileDead = 1,
  showAlert = 1
}

StaticPopupDialogs["EPGP_RECURRING_RESUME"] = {
  text = "%s",
  button1 = YES,
  button2 = NO,
  timeout = 0,
  whileDead = 1,
  OnAccept = function()
               EPGP:ResumeRecurringEP()
             end,
  OnCancel = function()
               EPGP:StopRecurringEP()
             end,
}
