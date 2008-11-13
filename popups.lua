local mod = EPGP:NewModule("EPGP_Popups")

local L = LibStub("AceLocale-3.0"):GetLocale("EPGP")
local GPTooltip = EPGP:GetModule("EPGP_GPTooltip")

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
               EPGP:IncGPBy(self.name, self.itemFrame.link,
                            self.editBox:GetNumber())
             end,

  OnCancel = function(self)
               self:Hide()
               ClearCursor()
             end,

  OnShow = function(self)
             local itemFrame = getglobal(self:GetName().."ItemFrame")
             local editBox = getglobal(self:GetName().."EditBox")
             local button1 = getglobal(self:GetName().."Button1")

             itemFrame:SetPoint("TOPLEFT", 35, -35)
             editBox:SetPoint("TOPLEFT", itemFrame, "TOPRIGHT", 150, -10)
             editBox:SetPoint("RIGHT", -35, 0)
             button1:SetPoint("TOPRIGHT", itemFrame, "BOTTOMRIGHT", 85, -6)

             editBox:SetText(GPTooltip:GetGPValue(itemFrame.link))
             editBox:HighlightText()
           end,

  OnHide = function()
             if ChatFrameEditBox:IsShown() then
               ChatFrameEditBox:SetFocus()
             end
           end,

  EditBoxOnEnterPressed = function(self)
                            local parent = self:GetParent()
                            if EPGP:CanIncGPBy(parent.itemFrame.link, parent.editBox:GetNumber()) then
                              EPGP:IncGPBy(parent.name, parent.itemFrame.link, parent.editBox:GetNumber())
                              parent:Hide()
                            end
                          end,

  EditBoxOnTextChanged = function(self)
                           local parent = self:GetParent()
                           if EPGP:CanIncGPBy(parent.itemFrame.link, parent.editBox:GetNumber()) then
                             parent.button1:Enable()
                             parent.button3:Enable()
                           else
                             parent.button1:Disable()
                             parent.button3:Disable()
                           end
                         end,

  EditBoxOnEscapePressed = function(self)
                             self:GetParent():Hide()
                             ClearCursor()
                           end
}

StaticPopupDialogs["EPGP_DECAY_EPGP"] = {
  text = "",
  button1 = ACCEPT,
  button2 = CANCEL,
  timeout = 0,
  hideOnEscape = 1,
  whileDead = 1,
  OnShow = function()
             local text = getglobal(this:GetName().."Text")
             text:SetFormattedText(L["Decay EP and GP by %d%%?"],
                                   EPGP:GetDecayPercent())
           end,
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

local function Debug(fmt, ...)
  DEFAULT_CHAT_FRAME:AddMessage(string.format(fmt, ...))
end

function mod:OnInitialize()
--   local playername = UnitName("player")
--   local itemName, itemLink, itemRarity, _, _, _, _, _, _, itemTexture = GetItemInfo(34541)
--   local r, g, b = GetItemQualityColor(itemRarity);

--   Debug("ItemName: %s ItemLink: %s ItemRarity: %d ItemTexture: %s",
--         itemName, itemLink, itemRarity, itemTexture)
--   local dialog = StaticPopup_Show("EPGP_CONFIRM_GP_CREDIT", playername, "", {
--                                     texture = itemTexture,
--                                     name = itemName,
--                                     color = {r, g, b, 1},
--                                     link = itemLink
--                                   })
--   if dialog then
--     dialog.name = playername
--   end
end
