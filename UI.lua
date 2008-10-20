--[[ EPGP User Interface ]]--

local mod = EPGP:NewModule("EPGP_UI", "AceEvent-3.0")

local CURRENT_VERSION = GetAddOnMetadata('EPGP_UI', 'Version')

EPGP_TEXT_STANDINGS = "Standings"
EPGP_TEXT_LOG = "Logs"
EPGP_TEXT_SHOWALTS = "Show Alts"
EPGP_TEXT_ADD = "Add EPs"
EPGP_TEXT_RECURRING = "Add Recurring EPs"
EPGP_TEXT_UNDO = "Undo"
EPGP_TEXT_RECURRING_EP = "Recurring EPs"
EPGP_TEXT_TITLE = "EPGP v5.0"

function mod:OnInitialize()
  LogPage:Hide()
  HideUIPanel(EPGPFrame)
end

local function initButton(button, text)
  button:SetWidth(48)
  button:SetHeight(32)
  button:SetText(text)
  button:SetWidth(button:GetTextWidth()+20)
end

-- ## Paper Doll Frame used by main EPGP frame ##

local function PaperDollFrame(name)
  local f = CreateFrame("Frame",name,UIParent)
  f:SetFrameStrata("BACKGROUND")
  f:SetWidth(384)
  f:SetHeight(512)
  f:SetPoint("TOPLEFT", nil, "TOPLEFT", 0, -104)
  f:SetHitRectInsets(0,30,0,70)
  --f:SetToplevel(true)
  f:EnableMouse(true)
  f:SetMovable(true) 
  f:SetAttribute("UIPanelLayout-defined", true)
  f:SetAttribute("UIPanelLayout-enabled", true)
  f:SetAttribute("UIPanelLayout-area", "left")
  f:SetAttribute("UIPanelLayout-pushable", 5)
  f:SetAttribute("UIPanelLayout-whileDead", true)
  
  local titlebar = CreateFrame("Button", "$parentTitleBar", f)
  titlebar:SetWidth(64)
  titlebar:SetHeight(32)
  titlebar:SetPoint("TOPLEFT", f, "TOPLEFT", 164, -8)
  local titletext = titlebar:CreateFontString("$parentTitle", "ARTWORK", "GameFontNormalSmall")
  titletext:SetAllPoints(titlebar)
  titletext:SetText(EPGP_TEXT_TITLE)
  
  t = f:CreateTexture(nil,"BACKGROUND")
  t:SetTexture("Interface\\PetitionFrame\\GuildCharter-Icon.blp")
  t:SetWidth(60)
  t:SetHeight(60)
  t:SetPoint("TOPLEFT",f,"TOPLEFT",7,-6)
  tl = f:CreateTexture(nil,"ARTWORK")
  tl:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-General-TopLeft.blp")
  tl:SetWidth(256)
  tl:SetHeight(256)
  tl:SetPoint("TOPLEFT",f,"TOPLEFT")
  tr = f:CreateTexture(nil,"ARTWORK")
  tr:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-General-TopRight.blp")
  tr:SetWidth(128)
  tr:SetHeight(256)
  tr:SetPoint("TOPRIGHT",f,"TOPRIGHT")
  bl = f:CreateTexture(nil,"ARTWORK")
  bl:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-General-BottomLeft.blp")
  bl:SetWidth(256)
  bl:SetHeight(256)
  bl:SetPoint("BOTTOMLEFT",f,"BOTTOMLEFT")
  tr = f:CreateTexture(nil,"ARTWORK")
  tr:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-General-BottomRight.blp")
  tr:SetWidth(128)
  tr:SetHeight(256)
  tr:SetPoint("BOTTOMRIGHT",f,"BOTTOMRIGHT")

  closebutton = CreateFrame("Button", "$parentXButton", f, "UIPanelCloseButton")
  closebutton:SetPoint("CENTER", f, "TOPRIGHT", -46, -24)
  closebutton:RegisterForClicks("LeftButtonUp")
  closebutton:SetScript("OnClick", function() HideUIPanel(f) end )
  closebutton:Enable()

  return f
end

-- Creates a tab page. 

local function CreateTabPage(parent, name)
  f = CreateFrame("Frame", "$parent"..name ,parent)
  f:SetAllPoints(parent)
  --f:SetPoint("TOPLEFT", parent, "TOPLEFT")
  --f:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT")
  return f
end

-- Creates a tab button.

local function CreateTabButton(parent, text, id)
  local f = CreateFrame("Button", "$parentTabButton"..id, parent, "CharacterFrameTabButtonTemplate")
  f:SetID(id)
  f:SetText(text)
  --f:RegisterForClicks("LeftButtonUp")
  f:Show()
  return f
end

-- Creates a log row.

local function CreateLogRow(parent, anchor, index)
  local b = CreateFrame("Button", "$parentRow"..index, parent)
  b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight.blp", "ADD")
  b:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT",0, 0)
  b:SetHeight(14)
  b:SetWidth(300)
  
  local date_text = b:CreateFontString("$parentDateText", "ARTWORK", "GameFontNormalSmall")
  date_text:SetWidth(64)
  date_text:SetHeight(14)
  date_text:SetPoint("TOPLEFT",b,"TOPLEFT",7,0)
  date_text:SetJustifyH("LEFT") 
  date_text:SetText("date_"..index) -- debug line
  
  local log_text = b:CreateFontString("$parentLogText", "ARTWORK", "GameFontNormalSmall")
  log_text:SetWidth(236)
  log_text:SetHeight(14)
  log_text:SetPoint("TOPLEFT",date_text,"TOPRIGHT",0,0)
  log_text:SetJustifyH("LEFT") 
  log_text:SetText("Debug awards 2500 GPs to Bug (O Rly)") -- debug line
  
  return b
end

-- Creates a listing row.

local function CreateListingRow(parent, anchor, index)
  local b = CreateFrame("Button", "$parentRow"..index, parent)
  b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight.blp", "ADD")
  b:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT",0, 0)
  b:SetHeight(14)
  b:SetWidth(298)
  
  local checkbox = CreateFrame("CheckButton", "$parentCheckBox", b, "UICheckButtonTemplate")
  checkbox:SetWidth(14)
  checkbox:SetHeight(14)
  checkbox:SetPoint("TOPLEFT", b, "TOPLEFT", 3, 0)
  --checkbox:SetScript("OnLoad", function() end)
  checkbox:SetScript("OnShow", function() this:SetChecked(true) end)
  --checkbox:SetScript("OnClick", function() end)
  
  local name_text = b:CreateFontString("$parentNameText", "ARTWORK", "GameFontNormalSmall")
  name_text:SetWidth(72)
  name_text:SetHeight(14)
  name_text:SetPoint("TOPLEFT", checkbox, "TOPRIGHT", 10, 0)
  name_text:SetJustifyH("LEFT") 
  name_text:SetText("test_"..index) -- debug line
  
  local ep_text = b:CreateFontString("$parentEPText", "ARTWORK", "GameFontNormalSmall")
  ep_text:SetWidth(64)
  ep_text:SetHeight(14)
  ep_text:SetPoint("TOPLEFT",name_text,"TOPRIGHT",0,0)
  ep_text:SetJustifyH("RIGHT") 
  ep_text:SetText(index..".0") -- debug line
  
  local gp_text = b:CreateFontString("$parentGPText", "ARTWORK", "GameFontNormalSmall")
  gp_text:SetWidth(64)
  gp_text:SetHeight(14)
  gp_text:SetPoint("TOPLEFT",ep_text,"TOPRIGHT",0,0)
  gp_text:SetJustifyH("RIGHT") 
  gp_text:SetText(index..".0") -- debug line
  
  local pr_text = b:CreateFontString("$parentPRText", "ARTWORK", "GameFontNormalSmall")
  pr_text:SetWidth(64)
  pr_text:SetHeight(14)
  pr_text:SetPoint("TOPLEFT",gp_text,"TOPRIGHT",0,0)
  pr_text:SetJustifyH("RIGHT") 
  pr_text:SetText(index..".0") -- debug line
  
  
  return b
end

-- Creates a Column Header used by tables.

local function CreateColumnHeader(parent, name)
  local b = CreateFrame("Button", "$parentColumnHeader", parent, "WhoFrameColumnHeaderTemplate")
  b:SetText(name)
  b:SetHighlightTexture("Interface\\PaperDollInfoFrame\\UI-Character-Tab-Highlight.blp", "ADD")
  
  return b
end

-- Creates a status bar for counting time.

local function CreateStatusBar(parent)
  local barborder = CreateFrame("StatusBar", "$parentStatusBarBorder", parent)
  barborder:SetMinMaxValues(0, 1)
  barborder:SetValue(0)
  barborder:SetStatusBarTexture("PaperDollInfoFrame\\UI-Character-Skills-BarBorder.blp")
  barborder:SetStatusBarColor(0.20, 0.90, 0.20, 1)
  barborder:SetPoint("TOPLEFT", parent, "BOTTOMLEFT", 10, -15)
  barborder:SetHeight(24)
  barborder:SetWidth(parent:GetWidth())
  
  local bar = CreateFrame("StatusBar", "$parentStatusBar", barborder)
  bar:SetMinMaxValues(0, 1)
  bar:SetValue(1)
  bar:SetAllPoints(barborder)
  bar:SetStatusBarTexture("Interface\\PaperDollInfoFrame\\UI-Character-Skills-Bar.blp")
  bar:SetStatusBarColor(0.20, 0.90, 0.20, 1)
  
  local rec_ep_text = bar:CreateFontString("$parentStatusText", "ARTWORK", "GameFontNormalSmall")
  rec_ep_text:SetWidth(92)
  rec_ep_text:SetHeight(20)
  rec_ep_text:SetPoint("CENTER",bar,"CENTER",0,0)
  rec_ep_text:SetText(EPGP_TEXT_RECURRING_EP)

  return barborder
end

-- ## Officer Bar in Standings Page ## --
-- Displays a status bar and two buttons, recurring and add.

local function CreateStandingsOfficerBar(parent)
  
  local statusBar = CreateStatusBar(parent)
  
  local editBox = CreateFrame("EditBox", "$parentEPEditBox", parent, "InputBoxTemplate")
  editBox:SetAutoFocus(false)
  editBox:SetHeight(24)
  editBox:SetWidth(96)
  editBox:SetFontObject("GameFontHighlightSmall")
  editBox:SetScript("OnEditFocusLost", function(self) self:HighlightText(0, 0) end)
  editBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  --editBox:SetScript("OnEnterPressed", function(self) parent.ping:GetScript("OnClick")(parent.ping) end)
  editBox:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
  editBox:SetPoint("TOPLEFT", statusBar, "BOTTOMLEFT", 10, -5)

  local addButton = CreateFrame("Button", "$parentAddEPButton", editBox, "UIPanelButtonTemplate2")
  addButton:SetPoint("TOPLEFT", editBox, "BOTTOMLEFT", -5, 0)
  initButton(addButton, EPGP_TEXT_ADD)
  --addButton:SetScript("OnClick", function() AddEP2Raid(this:GetParent():GetText()) end) 

  local recurringButton = CreateFrame("Button", "$parentRecurringEPButton", editBox, "UIPanelButtonTemplate2")
  recurringButton:SetPoint("TOPLEFT", addButton, "TOPRIGHT", 10, 0)
  initButton(recurringButton, EPGP_TEXT_RECURRING)
  --recurringButton:SetScript("OnClick", function() .... end) 
  
end

-- ## Standings Page ##
-- Displays the EPGP Standings table and a bottom panel
-- that is only visible to officers.

local function CreateStandingsPage(parent, id)
  local f = CreateTabPage(parent, "Standings")
  f:SetID(id)

  -- ## Show Alts checkbox & text ##
  local alts = CreateFrame("CheckButton", "$parentShowAltsCheckBox", f, "UICheckButtonTemplate")
  alts:SetHeight(20)
  alts:SetWidth(20)
  alts:SetPoint("TOPLEFT", f, "TOPLEFT", 85, -45)
  --alts:SetScript("OnLoad", function() end)
  alts:SetScript("OnShow", function() this:SetChecked(true) end)
  --alts:SetScript("OnClick", function() end)

  local alts_text = alts:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
  alts_text:SetPoint("LEFT", alts, "RIGHT", 0, 0)
  alts_text:SetText(EPGP_TEXT_SHOWALTS)

  local checkbox = CreateFrame("CheckButton", "$parentMasterCheckBox", f, "UICheckButtonTemplate")
  checkbox:SetHeight(20)
  checkbox:SetWidth(20)
  checkbox:SetPoint("TOPLEFT", f, "TOPLEFT", 19, -70)
  checkbox:SetScript("OnShow", function() this:SetChecked(true) end)

  -- ## Table Headers ##
  
  local NameHeader = CreateColumnHeader(f, "Name")
  NameHeader:SetPoint("TOPLEFT", checkbox, "TOPRIGHT", 1, 0)
  NameHeader:SetWidth(64)
  --NameHeader:SetScript("OnClick", function() end)
  
  local EP_Header = CreateColumnHeader(f, "EP")
  EP_Header:SetPoint("TOPLEFT", NameHeader, "TOPRIGHT",45,0)
  EP_Header:SetWidth(48)
  --EP_Header:SetScript("OnClick", function() end)
  
  local GP_Header = CreateColumnHeader(f, "GP")
  GP_Header:SetPoint("TOPLEFT", EP_Header, "TOPRIGHT",5,0)
  GP_Header:SetWidth(48)
  --GP_Header:SetScript("OnClick", function() end)
  
  local PR_Header = CreateColumnHeader(f, "PR")
  PR_Header:SetPoint("TOPLEFT", GP_Header, "TOPRIGHT",5, 0)
  PR_Header:SetWidth(48)
  --PR_Header:SetScript("OnClick", function() end)
  
  local scrollbar = CreateFrame("ScrollFrame", "$parentScrollBar", f, "FauxScrollFrameTemplate")
  scrollbar:SetWidth(296)
  scrollbar:SetHeight(210)
  scrollbar:SetPoint("TOPLEFT", NameHeader, "BOTTOMRIGHT", -85, 0)
  
  -- ## Listing Rows ## --
  
  local anchor = checkbox
  for i=1,15 do
    anchor = CreateListingRow(f, anchor, i)
  end
  
  -- ## Officer Bar ## --
  CreateStandingsOfficerBar(anchor)

  return f
end

-- ## Officer bar in log page. ## --
-- Contains an undo button.

local function CreateLogOfficerBar(parent)
  undoButton = CreateFrame("Button", "$parentUndoButton", parent, "UIPanelButtonTemplate2")
  undoButton:SetPoint("TOPLEFT", parent, "BOTTOMLEFT", 10, -5)
  initButton(undoButton, EPGP_TEXT_UNDO)
  --undoButton:SetScript("OnClick", function() .... end) 
end

-- ## Log Page ##
-- Contains a table with two columns (date, log entry)
-- and an undo button only visible to officers.

local function CreateLogPage(parent, id)
  local f = CreateTabPage(parent, "Log")
  f:SetID(id)
  
  -- ## Table Headers ## --
  
  local DateHeader = CreateColumnHeader(f, "Date")
  DateHeader:SetPoint("TOPLEFT", f, "TOPLEFT",19,-70)
  DateHeader:SetWidth(64)
  --DateHeader:SetScript("OnClick", function() end)
  
  local LogHeader = CreateColumnHeader(f, "Log")
  LogHeader:SetPoint("TOPLEFT", DateHeader, "TOPRIGHT",0,0)
  LogHeader:SetWidth(192)
  --LogHeader:SetScript("OnClick", function() end)
  
  local scrollbar = CreateFrame("ScrollFrame", "$parentScrollBar", f, "FauxScrollFrameTemplate")
  scrollbar:SetWidth(296)
  scrollbar:SetHeight(210)
  scrollbar:SetPoint("TOPLEFT", DateHeader, "BOTTOMRIGHT", -62, 0)
  
  -- ## Listing Rows ## --
  
  local anchor = DateHeader
  for i=1,15 do
    anchor = CreateLogRow(f, anchor, i)
  end
  
  -- ## Officer Bar ## --
  
  CreateLogOfficerBar(anchor)
  
  return f   
end

-- ## Main Frame Construction ##

ChatFrame1:AddMessage("*** EPGP UI initializing..")

EPGPFrame = PaperDollFrame("EPGP")

StandingsPage = CreateStandingsPage(EPGPFrame, 1)
LogPage = CreateLogPage(EPGPFrame, 2)

-- make Tab Buttons
StandingsTabButton = CreateTabButton(EPGPFrame, EPGP_TEXT_STANDINGS, 1)
StandingsTabButton:SetPoint("CENTER", EPGPFrame, "BOTTOMLEFT", 60, 61)
StandingsTabButton:SetScript("OnClick", function(self) LogPage:Hide() StandingsPage:Show() end)
LogTabButton = CreateTabButton(EPGPFrame, EPGP_TEXT_LOG, 2)
LogTabButton:SetPoint("LEFT", StandingsTabButton, "RIGHT", -10, 0)
LogTabButton:SetScript("OnClick", function(self) StandingsPage:Hide() LogPage:Show() end)

ChatFrame1:AddMessage("*** EPGP UI loaded successfully!")
