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

local function CreateEPGPFrameStandings()
  local f = CreateFrame("Frame", "$parentStandings", EPGPFrame)
  f:SetWidth(210)
  f:SetHeight(23)
  f:SetPoint("TOPRIGHT", EPGPFrame, "TOPRIGHT", -42, -38)

  -- Make the show alts checkbox
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

  -- Make the table
  f = CreateFrame("Frame", nil, EPGPFrame)
  f:SetWidth(300)
  f:SetHeight(200)
  f:SetPoint("TOPLEFT")

  local h1 = CreateColumnHeader(f, "Name", 100)
  h1:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -70)

  local h2 = CreateColumnHeader(f, "EP", 64)
  h2:SetPoint("TOPLEFT", h1, "TOPRIGHT")

  local h3 = CreateColumnHeader(f, "GP", 64)
  h3:SetPoint("TOPLEFT", h2, "TOPRIGHT")

  local h4 = CreateColumnHeader(f, "PR", 64)
  h4:SetPoint("TOPLEFT", h3, "TOPRIGHT")

end

local function CreateEPGPFrameLog()
  local f = CreateFrame("Frame", "$parentLog", EPGPFrame)
  f:SetWidth(395)
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
  undo:SetWidth(139)
  undo:SetHeight(22)
  undo:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -9, 13)
  undo:GetNormalFontObject():SetFontObject("GameFontNormalSmall")
  undo:GetHighlightFontObject():SetFontObject("GameFontHighlightSmall")
  undo:GetDisabledFontObject():SetFontObject("GameFontDisableSmall")
  undo:SetText("Undo")

  local events = CreateFrame("Frame", "$parentEvents", f)
  events:SetWidth(375)
  events:SetHeight(370)
  events:SetPoint("TOPLEFT", f, "TOPLEFT", 11, -32)
  events:SetBackdrop(
    {
      bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
      edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      tile = true,
      tileSize = 16,
      edgeSize = 16,
      insets = { left=5, right=5, top=5, bottom=5 }
    })
  events:SetBackdropBorderColor(TOOLTIP_DEFAULT_COLOR.r,
                                TOOLTIP_DEFAULT_COLOR.g,
                                TOOLTIP_DEFAULT_COLOR.b)
  events:SetBackdropColor(TOOLTIP_DEFAULT_BACKGROUND_COLOR.r,
                          TOOLTIP_DEFAULT_BACKGROUND_COLOR.g,
                          TOOLTIP_DEFAULT_BACKGROUND_COLOR.b)

  local records = CreateFrame("ScrollingMessageFrame", nil, events)
  records:SetWidth(345)
  records:SetHeight(350)
  records:SetPoint("TOPLEFT", events, "TOPLEFT", 8, -8)

  local scrollFrame = CreateFrame("ScrollFrame", nil, records,
                                  "FauxScrollFrameTemplate")
  scrollFrame:SetWidth(340)
  scrollFrame:SetHeight(359)
  scrollFrame:SetPoint("TOPRIGHT", events, "TOPRIGHT", -28, -6)
  scrollFrame:SetScript("OnVerticalScroll",
                        function(self)
                          -- FauxScrollFrame_OnVerticalScroll(...)
                        end)
end

function mod:OnInitialize()
  CreateEPGPFrame()
  CreateEPGPFrameStandings()
  CreateEPGPFrameLog()

  HideUIPanel(EPGPFrame)
end
