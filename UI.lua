--[[ EPGP User Interface ]]--

local mod = EPGP:NewModule("EPGP_UI", "AceEvent-3.0")
local L = LibStub:GetLibrary("AceLocale-3.0"):GetLocale("EPGP")
local GPTooltip = EPGP:GetModule("EPGP_GPTooltip")

local CURRENT_VERSION = GetAddOnMetadata('EPGP_UI', 'Version')

local BUTTON_TEXT_PADDING = 20
local BUTTON_HEIGHT = 22
local ROW_TEXT_PADDING = 5

EPGP_TEXT_STANDINGS = "Standings"
EPGP_TEXT_LOG = "Logs"
EPGP_TEXT_SHOWALTS = "Show Alts"
EPGP_TEXT_ADD = "Add EPs"
EPGP_TEXT_RECURRING = "Add Recurring EPs"
EPGP_TEXT_UNDO = "Undo"
EPGP_TEXT_RECURRING_EP = "Recurring EPs"
EPGP_TEXT_TITLE = "EPGP v5.0"

local function Debug(fmt, ...)
  DEFAULT_CHAT_FRAME:AddMessage(string.format(fmt, ...))
end

local function DebugFrame(frame, r, g, b)
  local t = frame:CreateTexture()
  t:SetAllPoints(frame)
  t:SetTexture(r or 0, g or 1, b or 0, 0.05)
end

local function CreateEPGPFrame()
  -- EPGPFrame
  local f = CreateFrame("Frame", "EPGPFrame", UIParent)
  f:Hide()
  f:SetToplevel(true)
  f:EnableMouse(true)
  f:SetMovable(true) 
  f:SetAttribute("UIPanelLayout-defined", true)
  f:SetAttribute("UIPanelLayout-enabled", true)
  f:SetAttribute("UIPanelLayout-area", "left")
  f:SetAttribute("UIPanelLayout-pushable", 5)
  f:SetAttribute("UIPanelLayout-whileDead", true)

  f:SetWidth(384)
  f:SetHeight(512)
  f:SetPoint("TOPLEFT", nil, "TOPLEFT", 0, -104)
  f:SetHitRectInsets(0, 30, 0, 45)

  local t = f:CreateTexture(nil, "BACKGROUND")
  t:SetTexture("Interface\\PetitionFrame\\GuildCharter-Icon")
  t:SetWidth(60)
  t:SetHeight(60)
  t:SetPoint("TOPLEFT", f, "TOPLEFT", 7, -6)

  t = f:CreateTexture(nil, "ARTWORK")
  t:SetTexture("Interface\\ClassTrainerFrame\\UI-ClassTrainer-TopLeft")
  t:SetWidth(256)
  t:SetHeight(256)
  t:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)

  t = f:CreateTexture(nil, "ARTWORK")
  t:SetTexture("Interface\\ClassTrainerFrame\\UI-ClassTrainer-TopRight")
  t:SetWidth(128)
  t:SetHeight(256)
  t:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)

  t = f:CreateTexture(nil, "ARTWORK")
  t:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-General-BottomLeft")
  t:SetWidth(256)
  t:SetHeight(256)
  t:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0)

  t = f:CreateTexture(nil, "ARTWORK")
  t:SetTexture(
    "Interface\\PaperDollInfoFrame\\UI-Character-General-BottomRight")
  t:SetWidth(128)
  t:SetHeight(256)
  t:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)

  t = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  t:SetWidth(250)
  t:SetHeight(16)
  t:SetPoint("TOP", f, "TOP", 3, -16)
  t:SetText(EPGP_TEXT_TITLE)

  local cb = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  cb:SetPoint("TOPRIGHT", f, "TOPRIGHT", -30, -8)
end

local function CreateTableHeader(parent)
  local h = CreateFrame("Button", nil, parent)
  h:SetHeight(24)

  local tl = h:CreateTexture(nil, "BACKGROUND")
  tl:SetTexture("Interface\\FriendsFrame\\WhoFrame-ColumnTabs")
  tl:SetWidth(5)
  tl:SetHeight(24)
  tl:SetPoint("TOPLEFT")
  tl:SetTexCoord(0, 0.07815, 0, 0.75)

  local tr = h:CreateTexture(nil, "BACKGROUND")
  tr:SetTexture("Interface\\FriendsFrame\\WhoFrame-ColumnTabs")
  tr:SetWidth(5)
  tr:SetHeight(24)
  tr:SetPoint("TOPRIGHT")
  tr:SetTexCoord(0.90625, 0.96875, 0, 0.75)

  local tm = h:CreateTexture(nil, "BACKGROUND")
  tm:SetTexture("Interface\\FriendsFrame\\WhoFrame-ColumnTabs")
  tm:SetHeight(24)
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

local function CreateTableRow(parent, rowHeight, widths, justifiesH)
  local row = CreateFrame("Button", nil, parent)
  row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
  row:SetHeight(rowHeight)
  row:SetPoint("LEFT")
  row:SetPoint("RIGHT")

  row.cells = {}
  for i,w in ipairs(widths) do
    local c =
      row:CreateFontString("$parentName", "ARTWORK", "GameFontHighlightSmall")
    c:SetHeight(rowHeight)
    c:SetWidth(w - (2 * ROW_TEXT_PADDING))
    c:SetJustifyH(justifiesH[i])
    if #row.cells == 0 then
      c:SetPoint("LEFT", row, "LEFT", ROW_TEXT_PADDING, 0)
    else
      c:SetPoint("LEFT", row.cells[#row.cells], "RIGHT", 2 * ROW_TEXT_PADDING, 0)
    end
    table.insert(row.cells, c)
    c:SetText(w)
  end

  return row
end

local function CreateTable(parent, texts, widths, justfiesH)
  assert(#texts == #widths and #texts == #justfiesH,
         "All specification tables must be the same size")
  -- Compute widths
  local totalFixedWidths = 0
  local numDynamicWidths = 0
  for i,w in ipairs(widths) do
    if w > 0 then
      totalFixedWidths = totalFixedWidths + w
    else
      numDynamicWidths = numDynamicWidths + 1
    end
  end
  local remainingWidthSpace = parent:GetWidth() - totalFixedWidths
  assert(remainingWidthSpace >= 0, "Widths specified exceed parent width")

  local dynamicWidth = math.floor(remainingWidthSpace / numDynamicWidths)
  local leftoverWidth = remainingWidthSpace % numDynamicWidths
  for i,w in ipairs(widths) do
    if w <= 0 then
      numDynamicWidths = numDynamicWidths - 1
      if numDynamicWidths then
        widths[i] = dynamicWidth
      else
        widths[i] = dynamicWidth + leftoverWidth
      end
    end
  end

  -- Make headers
  parent.headers = {}
  for i=1,#texts do
    local text, width, justifyH = texts[i], widths[i], justfiesH[i]
    local h = CreateTableHeader(parent, text, width)
    h:SetNormalFontObject("GameFontHighlightSmall")
    h:SetText(text)
    h:GetFontString():SetJustifyH(justifyH)
    h:SetWidth(width)
    if #parent.headers == 0 then
      h:SetPoint("TOPLEFT")
    else
      h:SetPoint("TOPLEFT", parent.headers[#parent.headers], "TOPRIGHT")
    end
    table.insert(parent.headers, h)
  end

  -- Compute number of rows
  local leftoverHeight =
    parent:GetHeight() - parent.headers[#parent.headers]:GetHeight()
  local fontHeight = select(2, GameFontNormalSmall:GetFont())
  local rowHeight = fontHeight + 4

  local numRows = math.floor(leftoverHeight / rowHeight)

  -- Make rows
  parent.rows = {}
  for i=1,numRows do
    local r = CreateTableRow(parent, rowHeight, widths, justfiesH)
    if #parent.rows == 0 then
      r:SetPoint("TOP", parent.headers[#parent.headers], "BOTTOM")
    else
      r:SetPoint("TOP", parent.rows[#parent.rows], "BOTTOM")
    end
    table.insert(parent.rows, r)
  end
end

local function CreateEPGPLogFrame()
  local f = CreateFrame("Frame", "EPGPLogFrame", EPGPFrame)
  f:Hide()
  f:SetWidth(450)
  f:SetHeight(435)
  f:SetPoint("TOPLEFT", EPGPFrame, "TOPRIGHT", -37, -6)

  local t = f:CreateTexture(nil, "OVERLAY")
  t:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Corner")
  t:SetWidth(32)
  t:SetHeight(32)
  t:SetPoint("TOPRIGHT", f, "TOPRIGHT", -6, -7)

  t = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  t:SetPoint("TOPLEFT", f, "TOPLEFT", 17, -17)
  t:SetText(GUILD_EVENT_LOG)

  f:SetBackdrop(
    {
      bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
      edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
      tile = true,
      tileSize = 32,
      edgeSize = 32,
      insets = { left=11, right=12, top=12, bottom=11 }
    })

  local cb = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  cb:SetPoint("TOPRIGHT", f, "TOPRIGHT", -2, -3) 

  local undo = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  undo:SetHeight(BUTTON_HEIGHT)
  undo:SetText("Undo")
  undo:SetWidth(undo:GetTextWidth() + BUTTON_TEXT_PADDING)
  undo:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -9, 13)
  undo:GetNormalFontObject():SetFontObject("GameFontNormalSmall")
  undo:GetHighlightFontObject():SetFontObject("GameFontHighlightSmall")
  undo:GetDisabledFontObject():SetFontObject("GameFontDisableSmall")
  undo:SetScript("OnClick",
                 function (self, value)
                   EPGP:UndoLastAction()
                 end)                   

  local scrollParent = CreateFrame("Frame", nil, f)
  scrollParent:SetWidth(f:GetWidth() - 20)
  scrollParent:SetHeight(f:GetHeight() - 65)
  scrollParent:SetPoint("TOPLEFT", f, "TOPLEFT", 11, -32)
  scrollParent:SetBackdrop(
    {
      bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
      edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      tile = true,
      tileSize = 16,
      edgeSize = 16,
      insets = { left=5, right=5, top=5, bottom=5 }
    })
  scrollParent:SetBackdropBorderColor(TOOLTIP_DEFAULT_COLOR.r,
                                      TOOLTIP_DEFAULT_COLOR.g,
                                      TOOLTIP_DEFAULT_COLOR.b)
  scrollParent:SetBackdropColor(TOOLTIP_DEFAULT_BACKGROUND_COLOR.r,
                                TOOLTIP_DEFAULT_BACKGROUND_COLOR.g,
                                TOOLTIP_DEFAULT_BACKGROUND_COLOR.b)

  local font = ChatFontSmall
  local fontHeight = select(2, font:GetFont())
  local recordHeight = fontHeight + 2
  local recordWidth = scrollParent:GetWidth() - 35
  local numLogRecordFrames = math.floor(
    (scrollParent:GetHeight() - 3) / recordHeight)
  local record = scrollParent:CreateFontString("EPGPLogRecordFrame1")
  record:SetFontObject(font)
  record:SetHeight(recordHeight)
  record:SetWidth(recordWidth)
  record:SetMultilineIndent(false)
  record:SetPoint("TOPLEFT", scrollParent, "TOPLEFT", 5, -3)
  for i=2,numLogRecordFrames do
    record = scrollParent:CreateFontString("EPGPLogRecordFrame"..i)
    record:SetFontObject(font)
    record:SetHeight(recordHeight)
    record:SetWidth(recordWidth)
    record:SetMultilineIndent(false)
    record:SetPoint("TOPLEFT", "EPGPLogRecordFrame"..(i-1), "BOTTOMLEFT")
  end

  local scrollBar = CreateFrame("ScrollFrame", "EPGPLogRecordScrollFrame",
                                scrollParent, "FauxScrollFrameTemplate")
  scrollBar:SetWidth(scrollParent:GetWidth() - 35)
  scrollBar:SetHeight(scrollParent:GetHeight() - 10)
  scrollBar:SetPoint("TOPRIGHT", scrollParent, "TOPRIGHT", -28, -6)

  local function UpdateLog()
    if false then
      return
    end
    local offset = FauxScrollFrame_GetOffset(EPGPLogRecordScrollFrame)
    local numRecords = EPGP:GetNumRecords()
    local numDisplayedRecords = math.min(numLogRecordFrames, numRecords - offset)
    for i=1,numLogRecordFrames do
      local record = getglobal("EPGPLogRecordFrame"..i)
      local logIndex = i + offset - 1
      if logIndex < numRecords then
        record:SetText(EPGP:GetLogRecord(logIndex))
        record:GetFontObject():SetJustifyH("LEFT")
        record:Show()
      else
        record:Hide()
      end
    end
    if numRecords > 0 then
      undo:Enable()
    else
      undo:Disable()
    end
    FauxScrollFrame_Update(EPGPLogRecordScrollFrame,
                           numRecords, numDisplayedRecords, recordHeight)
  end

  scrollBar:SetScript("OnShow", UpdateLog)
  scrollBar:SetScript("OnVerticalScroll",
                      function(self, value)
                        FauxScrollFrame_OnVerticalScroll(
                          self, value, recordHeight, UpdateLog)
                      end)
  EPGP:RegisterCallback("LogChanged", UpdateLog)

  -- Make sure when the parent shows we are hidden
  EPGPFrame:SetScript("OnShow",
                      function(self)
                        EPGPLogFrame:Hide()
                        EPGPSideFrame:Hide()
                      end)
end

local function SideFrameDropDown_Initialize()
  local info = UIDropDownMenu_CreateInfo()
  for i=1,GPTooltip:GetNumRecentItems() do
    local _, itemLink = GetItemInfo(GPTooltip:GetRecentItemID(i))
    info.text = itemLink
    info.func = function(self)
                  UIDropDownMenu_SetSelectedID(SideFrameDropDown, self:GetID())
                end
    info.checked = false
    UIDropDownMenu_AddButton(info)
  end
end

local function CreateEPGPSideFrame(self)
  local f = CreateFrame("Frame", "EPGPSideFrame", EPGPFrame)
  f:Hide()
  f:SetWidth(212)
  f:SetHeight(210)
  f:SetPoint("TOPLEFT", EPGPFrame, "TOPRIGHT", -33, -28)
  
  local t = f:CreateTexture(nil, "OVERLAY")
  t:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Corner")
  t:SetWidth(32)
  t:SetHeight(32)
  t:SetPoint("TOPRIGHT", f, "TOPRIGHT", -6, -7)
  
  f:SetBackdrop(
    {
      bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
      edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
      tile = true,
      tileSize = 32,
      edgeSize = 32,
      insets = { left=11, right=12, top=12, bottom=11 }
    })
  
  local cb = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  cb:SetPoint("TOPRIGHT", f, "TOPRIGHT", -2, -3) 
  
  local name = f:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  name:SetPoint("TOPLEFT", 17, -18)
  
  local reasonLabel = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  reasonLabel:SetText(L["Reason"])
  reasonLabel:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -20)

  dropdown = CreateFrame("Frame", "SideFrameDropDown", f, "UIDropDownMenuTemplate")
  dropdown:EnableMouse(true)
  dropdown:SetPoint("TOPLEFT", reasonLabel, "BOTTOMLEFT", -5, -10)
  UIDropDownMenu_Initialize(dropdown, SideFrameDropDown_Initialize)
  UIDropDownMenu_SetSelectedValue(dropdown, 1)
  UIDropDownMenu_SetWidth(dropdown, 140)
  UIDropDownMenu_JustifyText(dropdown, "LEFT")
  SideFrameDropDownLeft:SetHeight(50)
  SideFrameDropDownMiddle:SetHeight(50)
  SideFrameDropDownRight:SetHeight(50)
  SideFrameDropDownButton:SetPoint("TOPRIGHT", SideFrameDropDownRight, "TOPRIGHT", -16, -12)

  local valueLabel = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  valueLabel:SetText(L["Value"])
  valueLabel:SetPoint("TOPLEFT", reasonLabel, "BOTTOMLEFT", 0, -50)

  local valueBox = CreateFrame("EditBox", "SideFrameValueBox", f, "InputBoxTemplate")
  valueBox:SetWidth(120);
  valueBox:SetHeight(24);
  valueBox:SetAutoFocus(false);
  valueBox:SetFontObject("GameFontHighlightSmall")
  valueBox:SetPoint("TOPLEFT", valueLabel, "BOTTOMLEFT", 15, -7);

  local cgp = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  cgp:SetHeight(BUTTON_HEIGHT)
  cgp:SetPoint("TOPLEFT", valueLabel, "BOTTOMLEFT", 0, -50)
  cgp:SetText(L["Credit GPs"])
  cgp:SetWidth(cgp:GetTextWidth() + BUTTON_TEXT_PADDING)
  
  f:SetScript("OnShow", function(self) name:SetText(self.name) end)
end


local function CreateEPGPFrameStandings()
  -- Make the show everyone checkbox
  local f = CreateFrame("Frame", nil, EPGPFrame)
  f:SetHeight(28)
  f:SetPoint("TOPRIGHT", EPGPFrame, "TOPRIGHT", -42, -38)

  local tr = f:CreateTexture(nil, "BACKGROUND")
  tr:SetTexture("Interface\\ClassTrainerFrame\\UI-ClassTrainer-FilterBorder")
  tr:SetWidth(12)
  tr:SetHeight(28)
  tr:SetPoint("TOPRIGHT")
  tr:SetTexCoord(0.90625, 1, 0, 1)

  local tl = f:CreateTexture(nil, "BACKGROUND")
  tl:SetTexture("Interface\\ClassTrainerFrame\\UI-ClassTrainer-FilterBorder")
  tl:SetWidth(12)
  tl:SetHeight(28)
  tl:SetPoint("TOPLEFT")
  tl:SetTexCoord(0, 0.09375, 0, 1)

  local tm = f:CreateTexture(nil, "BACKGROUND")
  tm:SetTexture("Interface\\ClassTrainerFrame\\UI-ClassTrainer-FilterBorder")
  tm:SetHeight(28)
  tm:SetPoint("RIGHT", tr, "LEFT")
  tm:SetPoint("LEFT", tl, "RIGHT")
  tm:SetTexCoord(0.09375, 0.90625, 0, 1)

  local cb = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
  cb:SetWidth(20)
  cb:SetHeight(20)
  cb:SetPoint("RIGHT", f, "RIGHT", -8, 0)
  cb:SetScript("OnShow",
               function(self)
                 self:SetChecked(EPGP:StandingsShowEveryone())
               end)
  cb:SetScript("OnClick",
               function(self)
                 EPGP:StandingsShowEveryone(not not self:GetChecked())
               end)
  local t = cb:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  t:SetText("Show everyone")
  t:SetPoint("RIGHT", cb, "LEFT", 0, 2)
  f:SetWidth(t:GetStringWidth() + 4 * tl:GetWidth() + cb:GetWidth())

  -- Make the log frame
  CreateEPGPLogFrame()
  
  -- Make the side frame
  CreateEPGPSideFrame()
  
  -- Make the main frame
  local main = CreateFrame("Frame", nil, EPGPFrame)
  main:SetWidth(322)
  main:SetHeight(358)
  main:SetPoint("TOPLEFT", EPGPFrame, 19, -72)

  -- Make the buttons
  local function DisableWhileNotInRaid(self)
    if UnitInRaid("player") then
      self:Enable()
    else
      self:Disable()
    end
  end

  local once = CreateFrame("Button", nil, main, "UIPanelButtonTemplate")
  once:SetHeight(BUTTON_HEIGHT)
  once:SetPoint("BOTTOMLEFT")
  once:SetText("Once")
  once:SetWidth(once:GetTextWidth() + BUTTON_TEXT_PADDING)
  once:SetScript("OnEvent", DisableWhileNotInRaid)
  once:SetScript("OnShow", DisableWhileNotInRaid)
  once:RegisterEvent("RAID_ROSTER_UPDATE")

  local recur = CreateFrame("Button", nil, main, "UIPanelButtonTemplate")
  recur:SetHeight(BUTTON_HEIGHT)
  recur:SetPoint("LEFT", once, "RIGHT", 0, 0)
  recur:SetText("Recurring")
  recur:SetWidth(recur:GetTextWidth() + BUTTON_TEXT_PADDING)
  recur:SetScript("OnShow", DisableWhileNotInRaid)
  recur:SetScript("OnEvent", DisableWhileNotInRaid)
  recur:RegisterEvent("RAID_ROSTER_UPDATE")

  local log = CreateFrame("Button", nil, main, "UIPanelButtonTemplate")
  log:SetHeight(BUTTON_HEIGHT)
  log:SetPoint("BOTTOMRIGHT")
  log:SetText("Log")
  log:SetWidth(log:GetTextWidth() + BUTTON_TEXT_PADDING)
  log:SetScript("OnClick",
                function(self, button, down)
                  EPGPLogFrame:Show()
                end)
  local decay = CreateFrame("Button", nil, main, "UIPanelButtonTemplate")
  decay:SetHeight(BUTTON_HEIGHT)
  decay:SetPoint("RIGHT", log, "LEFT")
  decay:SetText("Decay")
  decay:SetWidth(decay:GetTextWidth() + BUTTON_TEXT_PADDING)
  decay:SetScript("OnClick",
                  function(self, button, down)
                    StaticPopup_Show("EPGP_DECAY_EPGP")
                  end)

  -- Make the table frame
  local tabl = CreateFrame("Frame", nil, main)
  tabl:SetPoint("TOPLEFT")
  tabl:SetPoint("TOPRIGHT")
  tabl:SetPoint("BOTTOM", once, "TOP")

  -- Populate the table
  CreateTable(tabl,
              {"Name", "EP", "GP", "PR"},
              {0, 64, 64, 64},
              {"LEFT", "RIGHT", "RIGHT", "RIGHT"})

  -- Make all our rows have a check on them and setup the OnClick
  -- handler for each row.
  for i,r in ipairs(tabl.rows) do
    r.check = r:CreateTexture(nil, "BACKGROUND")
    r.check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
    r.check:SetWidth(r:GetHeight())
    r.check:SetHeight(r:GetHeight())
    r.check:SetPoint("RIGHT", r.cells[1])

    r:RegisterForClicks("LeftButtonDown")
    r:SetScript("OnClick",
                function(self, value)
                  if IsModifiedClick("QUESTWATCHTOGGLE") then
                    if self.check:IsShown() then
                      EPGP:StandingsRemoveExtra(self.name)
                    else
                      EPGP:StandingsAddExtra(self.name)
                    end
                  else
                    EPGPSideFrame.name = self.name 
                    EPGPSideFrame:Show()
                  end
                end)
  end

  -- Hook up the headers
  tabl.headers[1]:SetScript("OnClick",
                            function(self)
                              EPGP:StandingsSort("NAME")
                            end)
  tabl.headers[2]:SetScript("OnClick",
                            function(self)
                              EPGP:StandingsSort("EP")
                            end)
  tabl.headers[3]:SetScript("OnClick",
                            function(self)
                              EPGP:StandingsSort("GP")
                            end)
  tabl.headers[4]:SetScript("OnClick",
                            function(self)
                              EPGP:StandingsSort("PR")
                            end)

  -- Install the update function
  local function UpdateStandings()
    if not tabl:IsVisible() then
      return
    end
    Debug("Updating standings")
    local numMembers = EPGP:GetNumMembers()
    for i=1,#tabl.rows do
      local row = tabl.rows[i]
      if i <= numMembers then
        row.name = EPGP:GetMember(i)
        row.cells[1]:SetText(row.name)
        local c = RAID_CLASS_COLORS[EPGP:GetClass(row.name)]
        row.cells[1]:SetTextColor(c.r, c.g, c.b)
        local ep, gp = EPGP:GetEPGP(row.name)
        row.cells[2]:SetText(ep)
        row.cells[3]:SetText(gp)
        if gp > 0 then
          row.cells[4]:SetFormattedText("%.4g", ep / gp)
        else
          row.cells[4]:SetText(0)
        end
        row.check:Hide()
        if UnitInRaid("player") and EPGP:StandingsShowEveryone() and EPGP:IsMemberInStandings(row.name) then
          row.check:Show()
        end
        row:SetAlpha(EPGP:IsMemberInStandingsExtra(row.name) and 0.6 or 1)
        row:Show()
      else
        row:Hide()
      end
    end
  end

  EPGP:RegisterCallback("StandingsChanged", UpdateStandings)
  tabl:SetScript("OnShow", UpdateStandings)
end

function mod:OnInitialize()
  CreateEPGPFrame()
  CreateEPGPFrameStandings()

  HideUIPanel(EPGPFrame)
end
