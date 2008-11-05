--[[ EPGP User Interface ]]--

local mod = EPGP:NewModule("EPGP_UI", "AceEvent-3.0")

local CURRENT_VERSION = GetAddOnMetadata('EPGP_UI', 'Version')

local BUTTON_TEXT_PADDING = 20
local BUTTON_HEIGHT = 22

EPGP_TEXT_STANDINGS = "Standings"
EPGP_TEXT_LOG = "Logs"
EPGP_TEXT_SHOWALTS = "Show Alts"
EPGP_TEXT_ADD = "Add EPs"
EPGP_TEXT_RECURRING = "Add Recurring EPs"
EPGP_TEXT_UNDO = "Undo"
EPGP_TEXT_RECURRING_EP = "Recurring EPs"
EPGP_TEXT_TITLE = "EPGP v5.0"

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
  t:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-General-TopLeft")
  t:SetWidth(256)
  t:SetHeight(256)
  t:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)

  t = f:CreateTexture(nil, "ARTWORK")
  t:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-General-TopRight")
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

local function CreateColumnHeader(parent, text, width)
  local h = CreateFrame("Button", nil, parent)
  h:SetWidth(width)
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
  tm:SetWidth(10)
  tm:SetHeight(24)
  tm:SetPoint("LEFT", tl, "RIGHT")
  tm:SetPoint("RIGHT", tr, "LEFT")
  tm:SetTexCoord(0.07815, 0.90625, 0, 0.75)

  h:SetText(text)
  h:GetFontString():SetPoint("LEFT", h, "LEFT", 8, 0)

  h:SetNormalFontObject("GameFontHighlightSmall")
  local hl = h:CreateTexture()
  h:SetHighlightTexture(hl)
  hl:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-Tab-Highlight")
  hl:SetBlendMode("ADD")
  hl:SetWidth(5)
  hl:SetHeight(33)
  hl:SetPoint("LEFT", h, "LEFT", 0, -2)
  hl:SetPoint("RIGHT", h, "RIGHT", 0, -2)

  return h
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
  record:SetText("amsdoiamsdASD")
  record:SetPoint("TOPLEFT", scrollParent, "TOPLEFT", 5, -3)
  for i=2,numLogRecordFrames do
    record = scrollParent:CreateFontString("EPGPLogRecordFrame"..i)
    record:SetFontObject(font)
    record:SetHeight(recordHeight)
    record:SetWidth(recordWidth)
    record:SetMultilineIndent(false)
    record:SetPoint("TOPLEFT", "EPGPLogRecordFrame"..(i-1), "BOTTOMLEFT")
    record:SetText("amsdoiamsdASD")
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
                      end)
end

local function CreateEPGPFrameStandings()
  -- Make the show alts checkbox
  local f = CreateFrame("Frame", nil, EPGPFrame)
  f:SetWidth(210)
  f:SetHeight(23)
  f:SetPoint("TOPRIGHT", EPGPFrame, "TOPRIGHT", -42, -38)

  local tr = f:CreateTexture(nil, "BACKGROUND")
  tr:SetTexture("Interface\\ClassTrainerFrame\\UI-ClassTrainer-FilterBorder")
  tr:SetWidth(12)
  tr:SetHeight(28)
  tr:SetPoint("TOPRIGHT")
  tr:SetTexCoord(0.90625, 1, 0, 1)

  local tm = f:CreateTexture(nil, "BACKGROUND")
  tm:SetTexture("Interface\\ClassTrainerFrame\\UI-ClassTrainer-FilterBorder")
  tm:SetWidth(96)
  tm:SetHeight(28)
  tm:SetPoint("RIGHT", tr, "LEFT")
  tm:SetTexCoord(0.09375, 0.90625, 0, 1)

  local tl = f:CreateTexture(nil, "BACKGROUND")
  tl:SetTexture("Interface\\ClassTrainerFrame\\UI-ClassTrainer-FilterBorder")
  tl:SetWidth(12)
  tl:SetHeight(28)
  tl:SetPoint("RIGHT", tm, "LEFT")
  tl:SetTexCoord(0, 0.09375, 0, 1)

  local cb = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
  cb:SetWidth(20)
  cb:SetHeight(20)
  cb:SetPoint("RIGHT", f, "RIGHT", -8, 0)

  local t = cb:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  t:SetText("Show alts")
  t:SetPoint("RIGHT", cb, "LEFT", -10, 1)

  -- Make the main frame
  local main = CreateFrame("Frame", nil, EPGPFrame)
  main:SetWidth(322)
  main:SetHeight(358)
  main:SetPoint("TOPLEFT", EPGPFrame, 19, -72)

  -- Make the headers
  local h1 = CreateColumnHeader(main, "Name", 100)
  h1:SetPoint("TOPLEFT")

  local h2 = CreateColumnHeader(main, "EP", 64)
  h2:SetPoint("TOPLEFT", h1, "TOPRIGHT")

  local h3 = CreateColumnHeader(main, "GP", 64)
  h3:SetPoint("TOPLEFT", h2, "TOPRIGHT")

  local h4 = CreateColumnHeader(main, "PR", 64)
  h4:SetPoint("TOPLEFT", h3, "TOPRIGHT")

  -- Make the log frame
  CreateEPGPLogFrame()

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
end

function mod:OnInitialize()
  CreateEPGPFrame()
  CreateEPGPFrameStandings()

  HideUIPanel(EPGPFrame)
end
