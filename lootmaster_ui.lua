--[[
  EPGP Lootmaster module - UI Stuff
]]--

local mod = EPGP:NewModule("lootmaster_ui")
local lootmaster = EPGP:GetModule("lootmaster")
local L = LibStub("AceLocale-3.0"):GetLocale("EPGP")
local GS = LibStub("LibGuildStorage-1.0")
local gptooltip = EPGP:GetModule("gptooltip")
local lootmaster = EPGP:GetModule("lootmaster")
local callbacks = EPGP.callbacks

function mod:OnEnable()
  self:BuildUI()
end

local columns = {
  {text="C",          width=20},
  {text="Candidate",  width=80},
  {text="Rank",       width=70},
  {text="Status",     width=90},
  {text="EP",         width=55},
  {text="GP",         width=55},
  {text="PR",         width=55},
  {text="Roll",       width=25},
  {text="N",          width=20},
  {text="Equipment",  width=120}
}

--- TODO(mackatack) make a proper builder
--  Really just a testing function, once everything looks as
--  it should i will make separate functions for all the visual components.
function mod:BuildUI()
  local f = self:CreateEPGPFrame()
  local sp = f.scrollPanel
  
  -- Make column headers
  local lastH = sp
  for i, colData in ipairs(columns) do
    local t = self:CreateTableHeader(sp)
    t:SetText(colData.text)
    t:SetWidth(colData.width)
    if lastH == sp then
      t:SetPoint("BOTTOMLEFT", lastH, "TOPLEFT", 0, -2)
    else
      t:SetPoint("TOPLEFT", lastH, "TOPRIGHT", 0, 0)
    end
    lastH = t
  end
  
  -- Candidate selection panel:
  local lmf = CreateFrame("Frame", nil, f)
  lmf:SetPoint("TOPLEFT", f, "TOPLEFT", 80, -50)
  lmf:SetPoint("RIGHT", f, "RIGHT", 0, 0)
  
  -- Create icon
  local icon = CreateFrame("Button", "EPGPLM_CURRENTITEMICON", lmf, "AutoCastShineTemplate")
  icon:EnableMouse()
  icon:SetNormalTexture("Interface/ICONS/INV_Misc_QuestionMark")
  icon:SetPoint("TOPLEFT", lmf, "TOPLEFT", 0, 0)
  icon:SetHeight(48)
  icon:SetWidth(48)
  
  local lblItem = lmf:CreateFontString(nil,"OVERLAY","GameFontNormalLarge")
  lblItem:SetPoint("TOPLEFT",icon,"TOPRIGHT", 10, 0)
  lblItem:SetVertexColor(1, 1, 1)
  lblItem:SetText("[Uber leet item]")
  
  local btn = CreateFrame("Button", nil, lmf, "UIPanelButtonTemplate")
  btn:SetPoint("BOTTOMLEFT",icon,"BOTTOMRIGHT",10,0)
  btn:SetHeight(25)
  btn:SetWidth(90)
  btn:SetText("Mainspec")
  local btnMainspec = btn
  
  btn = CreateFrame("Button", nil, lmf, "UIPanelButtonTemplate")
  btn:SetPoint("BOTTOMLEFT",btnMainspec,"BOTTOMRIGHT",5,0)
  btn:SetHeight(25)
  btn:SetWidth(120)
  btn:SetText("Minor upgrade")
  local btnUpgrade = btn
  
  btn = CreateFrame("Button", nil, lmf, "UIPanelButtonTemplate")
  btn:SetPoint("BOTTOMLEFT",btnUpgrade,"BOTTOMRIGHT",5,0)
  btn:SetHeight(25)
  btn:SetWidth(75)
  btn:SetText("Offspec")
  local btnOffspec = btn
  
  btn = CreateFrame("Button", nil, lmf, "UIPanelButtonTemplate")
  btn:SetPoint("BOTTOMLEFT",btnOffspec,"BOTTOMRIGHT",5,0)
  btn:SetHeight(25)
  btn:SetWidth(100)
  btn:SetText("Greed / Alt")
  local btnGreed = btn
  
  btn = CreateFrame("Button", nil, lmf, "UIPanelButtonTemplate")
  btn:SetPoint("BOTTOMLEFT",btnGreed,"BOTTOMRIGHT",5,0)
  btn:SetHeight(25)
  btn:SetWidth(60)
  btn:SetText("Pass")
  local btnPass = btn
  
  local timer = self:CreateTimeoutBar(lmf)
  timer:SetPoint("TOPLEFT", btnMainspec, "BOTTOMLEFT", 0, -5)
  
end

function mod:CreateEPGPFrame()
  -- EPGPLootmasterFrame
  if self.frame then return self.frame end;

  local f = CreateFrame("Frame", "EPGPLootmasterFrame", UIParent)
  self.frame = f
  f:Show() -- TODO(mackatack) Obviously for testing purposes, final version will be hidden at first.
  f:SetToplevel(true)
  f:EnableMouse(true)
  f:SetMovable(true)
  f:SetAttribute("UIPanelLayout-defined", true)
  f:SetAttribute("UIPanelLayout-enabled", true)
  f:SetAttribute("UIPanelLayout-area", "left")
  f:SetAttribute("UIPanelLayout-pushable", 5)
  f:SetAttribute("UIPanelLayout-whileDead", true)

  f:SetWidth(715)
  f:SetHeight(512)
  f:SetPoint("TOPLEFT", nil, "TOPLEFT", 0, -104)
  f:SetHitRectInsets(0, 30, 0, 45)

  f:SetBackdrop({
    bgFile = "Interface\\Addons\\epgp\\images\\frame_bg",
    tile = true, tileSize = 128,
    insets = { left = 13, right = 22, top = 15, bottom = 10 }
  })

  local icon = f:CreateTexture(nil, "BORDER")
  icon:SetTexture("Interface\\PetitionFrame\\GuildCharter-Icon")
  icon:SetWidth(60)
  icon:SetHeight(60)
  icon:SetPoint("TOPLEFT", f, "TOPLEFT", 7, -6)

  local tl = f:CreateTexture(nil, "ARTWORK")
  tl:SetTexture("Interface\\AddOns\\epgp\\images\\frame")
  tl:SetWidth(102.4)
  tl:SetHeight(102.4)--76.8)
  tl:SetTexCoordModifiesRect(false)
  tl:SetTexCoord(0, 0.4, 0, 0.4)
  tl:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)

  local tr = f:CreateTexture(nil, "OVERLAY")
  tr:SetTexture("Interface\\AddOns\\epgp\\images\\frame")
  tr:SetWidth(102.4)
  tr:SetHeight(102.4)
  tr:SetTexCoordModifiesRect(false)
  tr:SetTexCoord(0.6, 1, 0, 0.4)
  tr:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)

  local top = f:CreateTexture(nil, "OVERLAY")
  top:SetTexture("Interface\\AddOns\\epgp\\images\\frame", true)
  top:SetHeight(102.4)
  top:SetTexCoordModifiesRect(false)
  top:SetTexCoord(0.4, 0.6, 0, 0.4)
  top:SetPoint("TOPLEFT", tl, "TOPRIGHT", 0, 0)
  top:SetPoint("TOPRIGHT", tr, "TOPLEFT", 0, 0)

  local bl = f:CreateTexture(nil, "OVERLAY")
  bl:SetTexture("Interface\\AddOns\\epgp\\images\\frame")
  bl:SetWidth(102.4)
  bl:SetHeight(102.4)
  bl:SetTexCoord(0, 0.4, 0.6, 1)
  bl:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0)

  local br = f:CreateTexture(nil, "OVERLAY")
  br:SetTexture("Interface\\AddOns\\epgp\\images\\frame")
  br:SetWidth(102.4)
  br:SetHeight(102.4)
  br:SetTexCoordModifiesRect(false)
  br:SetTexCoord(0.6, 1, 0.6, 1)
  br:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)

  local bottom = f:CreateTexture(nil, "OVERLAY")
  bottom:SetTexture("Interface\\AddOns\\epgp\\images\\frame", true)
  bottom:SetHeight(102.4)
  bottom:SetTexCoordModifiesRect(false)
  bottom:SetTexCoord(0.4, 0.6, 0.6, 1)
  bottom:SetPoint("BOTTOMLEFT", bl, "BOTTOMRIGHT", 0, 0)
  bottom:SetPoint("BOTTOMRIGHT", br, "BOTTOMLEFT", 0, 0)

  local left = f:CreateTexture(nil, "OVERLAY")
  left:SetTexture("Interface\\AddOns\\epgp\\images\\frame", true)
  left:SetWidth(102.4)
  left:SetTexCoordModifiesRect(false)
  left:SetTexCoord(0, 0.4, 0.4, 0.6)
  left:SetPoint("TOPLEFT", tl, "BOTTOMLEFT", 0, 0)
  left:SetPoint("BOTTOMLEFT", bl, "TOPLEFT", 0, 0)

  local right = f:CreateTexture(nil, "ARTWORK")
  right:SetTexture("Interface\\AddOns\\epgp\\images\\frame", true)
  right:SetWidth(102.4)
  right:SetTexCoordModifiesRect(false)
  right:SetTexCoord(0.6, 1, 0.4, 0.6)
  right:SetPoint("TOPRIGHT", tr, "BOTTOMRIGHT", 0, 0)
  right:SetPoint("BOTTOMRIGHT", br, "TOPRIGHT", 0, 0)

  local caption = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  caption:SetWidth(250)
  caption:SetHeight(16)
  caption:SetPoint("TOP", f, "TOP", 3, -16)
  caption:SetText("EPGP Lootmaster (wip) "..EPGP.version)
  f.caption = caption
  
  local scrollPanel = CreateFrame("ScrollFrame", "EPGPLMScroll", f)
  scrollPanel:SetBackdrop({
    bgFile = "Interface\\RAIDFRAME\\UI-RaidFrame-GroupBg",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 512, edgeSize = 12,
    insets = { left = 2, right = 1, top = 1, bottom = 2 }
  })
  scrollPanel:SetPoint("TOPLEFT", f, "TOPLEFT", 80, -150)
  scrollPanel:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -25, 13)
  f.scrollPanel = scrollPanel
  
  local scrollBar = CreateFrame("Slider", "EPGPLMScrollbar", scrollPanel, "UIPanelScrollBarTemplateLightBorder")
  scrollBar:SetPoint("TOPRIGHT", scrollPanel, "TOPRIGHT", -5, -21)
  scrollBar:SetPoint("BOTTOMRIGHT", scrollPanel, "BOTTOMRIGHT", -5, 20)
  
  local btnClose = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  btnClose:SetPoint("TOPRIGHT", f, "TOPRIGHT", -15, -8)

  f:SetScript("OnHide", ToggleOnlySideFrame)
  
  return f
end

function mod:CreateTimeoutBar(parent)
  local timerFrame = CreateFrame("Frame", nil, parent)
  timerFrame:SetHeight(20)  
  timerFrame:SetWidth(135);
  timerFrame:SetBackdrop({
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    tile = true, tileSize = 64, edgeSize = 12,
    insets = { left = 2, right = 1, top = 2, bottom = 2 }
  })
  timerFrame:SetBackdropColor(1, 0, 0, 0.4)
  timerFrame:SetBackdropBorderColor(1, 0.6980392, 0, 0)
  --timerFrame:SetPoint("LEFT",btnPass,"RIGHT", 10, 0)

  local lblTimeout
  local b=CreateFrame("STATUSBAR",nil,timerFrame,"TextStatusBar");
  local bCount = 0;
  local bElapse = 0;
  b:SetPoint("TOPLEFT",timerFrame,"TOPLEFT", 3, -3);
  b:SetPoint("BOTTOMRIGHT",timerFrame,"BOTTOMRIGHT", -2, 3);
  b:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar");
  b:SetStatusBarColor(0.4, 0.8, 0.4, 0.8);
  b:SetMinMaxValues(0, 100)
  b:SetScript("OnUpdate", function(o, elapsed)
      if not lblTimeout then return end
      bElapse = bElapse + elapsed
      if bElapse%1~=0 then return end
      lblTimeout:SetText(elapsed)
      b:SetValue(bCount)
      bCount = bCount - 1
      if bCount<0 then bCount=100 end
  end)
  timerFrame.progressBar = b;

  local timerBorderFrame = CreateFrame("Frame", nil, timerFrame)    
  timerBorderFrame:SetToplevel(true)
  timerBorderFrame:SetBackdrop({
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 64, edgeSize = 12,
    insets = {left = 2, right = 1, top = 2, bottom = 2}
  })
  timerBorderFrame:SetBackdropColor(1, 0, 0, 0.0)
  timerBorderFrame:SetBackdropBorderColor(1, 0.6980392, 0, 1)
  timerBorderFrame:SetPoint("TOPLEFT", timerFrame, "TOPLEFT", 0, 0);
  timerBorderFrame:SetPoint("BOTTOMRIGHT", timerFrame, "BOTTOMRIGHT", 0, 0);

  lblTimeout = timerBorderFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  lblTimeout:SetPoint("CENTER", timerBorderFrame, "CENTER", 0, 0)
  lblTimeout:SetVertexColor(1, 1, 1)
  lblTimeout:SetText("timeout")
  
  timerFrame:Show()
  
  return timerFrame
end

function mod:CreateTableHeader(parent)
  local h = CreateFrame("Button", nil, parent)
  h:SetHeight(20)
  
  h:SetNormalFontObject("GameFontHighlightSmall")
  h:SetText("test")

  local tl = h:CreateTexture(nil, "BACKGROUND")
  tl:SetTexture("Interface\\FriendsFrame\\WhoFrame-ColumnTabs")
  tl:SetWidth(5)
  tl:SetHeight(20)
  tl:SetPoint("TOPLEFT")
  tl:SetTexCoord(0, 0.07815, 0, 0.75)

  local tr = h:CreateTexture(nil, "BACKGROUND")
  tr:SetTexture("Interface\\FriendsFrame\\WhoFrame-ColumnTabs")
  tr:SetWidth(5)
  tr:SetHeight(20)
  tr:SetPoint("TOPRIGHT")
  tr:SetTexCoord(0.90625, 0.96875, 0, 0.75)

  local tm = h:CreateTexture(nil, "BACKGROUND")
  tm:SetTexture("Interface\\FriendsFrame\\WhoFrame-ColumnTabs")
  tm:SetHeight(20)
  tm:SetPoint("LEFT", tl, "RIGHT")
  tm:SetPoint("RIGHT", tr, "LEFT")
  tm:SetTexCoord(0.07815, 0.90625, 0, 0.75)

  local hl = h:CreateTexture()
  h:SetHighlightTexture(
    "Interface\\PaperDollInfoFrame\\UI-Character-Tab-Highlight", "ADD")
  hl:SetPoint("TOPLEFT", tl, "TOPLEFT", -2, 5)
  hl:SetPoint("BOTTOMRIGHT", tr, "BOTTOMRIGHT", 2, -7)

  return h
end
