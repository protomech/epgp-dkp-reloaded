-- A library to use for Debug information that provides a central way
-- to enable/disable debugging on a special debug frame.

local MAJOR_VERSION = "LibDebug-1.0"
local MINOR_VERSION = tonumber(("$Revision: 1023 $"):match("%d+")) or 0

local lib, oldMinor = LibStub:NewLibrary(MAJOR_VERSION, MINOR_VERSION)
if not lib then return end

lib.frame = lib.frame or CreateFrame("Frame", MAJOR_VERSION.."_Frame", UIParent)
local frame = lib.frame

-- See if we're updating the lib, if so copy the old lib's isDebugging boolean
local isDebugging = lib.isDebugging and lib:isDebugging() or false

-- The main frame.
frame:EnableMouse()

frame:SetMinResize(300, 100)
frame:SetWidth(400)
frame:SetHeight(400)

frame:SetPoint("CENTER", UIParent)
frame:SetFrameStrata("TOOLTIP")
frame:SetBackdrop(
  {
    bgFile = "Interface\\Tooltips\\ChatBubble-Background",
    edgeFile = "Interface\\Tooltips\\ChatBubble-BackDrop",
    tile = true,
    tileSize = 32,
    edgeSize = 32,
    insets = { left=32, right=32, top=32, bottom=32 }
  })
frame:SetBackdropColor(0, 0, 0, 1)

-- The titlebar/drag bar.
frame:SetMovable(true)
frame:SetClampedToScreen(true)
frame.title = CreateFrame("Button", nil, frame)
frame.title:SetNormalFontObject("GameFontNormal")
frame.title:SetText(MAJOR_VERSION)
frame.title:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -8)
frame.title:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -8, -8)
frame.title:SetHeight(8)
frame.title:SetHighlightTexture(
  "Interface\\FriendsFrame\\UI-FriendsFrame-HighlightBar")
frame.title:SetScript("OnMouseDown",
                      function (self) self:GetParent():StartMoving() end)
frame.title:SetScript("OnMouseUp",
                      function (self) self:GetParent():StopMovingOrSizing() end)

-- The sizing button.
frame:SetResizable(true)
frame.sizer = CreateFrame("Button", nil, frame)
frame.sizer:SetHeight(16)
frame.sizer:SetWidth(16)
frame.sizer:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -8, 8)
frame.sizer:SetScript("OnMouseDown",
                       function (self)
                         self:GetParent():StartSizing("BOTTOMRIGHT")
                       end)
frame.sizer:SetScript("OnMouseUp",
                       function (self) self:GetParent():StopMovingOrSizing()
                       end)

local sizerTexture = frame.sizer:CreateTexture(nil, "BACKGROUND")
sizerTexture:SetWidth(17)
sizerTexture:SetHeight(17)
sizerTexture:SetPoint("BOTTOMRIGHT", -6, 4)
sizerTexture:SetTexture("Interface\\Tooltips\\UI-Tooltip-Border")
local x = 0.1 * 10/17
sizerTexture:SetTexCoord(0.15 - x, 0.5, 0.05, 0.5 + x, 0.05, 0.5 - x, 0.5 + x, 0.5)

frame.bottom = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
frame.bottom:SetJustifyH("LEFT")
frame.bottom:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 8, 8)
frame.bottom:SetPoint("BOTTOMRIGHT", frame.sizer)
frame.bottom:SetHeight(8)
frame.bottom:SetText("Mouse wheel to scroll (with shift scroll top/bottom). Title bar drags. Bottom-right corner resizes.")

-- The scrolling message frame with all the debug info.
frame.msg = CreateFrame("ScrollingMessageFrame", nil, frame)
frame.msg:SetPoint("TOPLEFT", frame.title, "BOTTOMLEFT")
frame.msg:SetPoint("TOPRIGHT", frame.title, "BOTTOMRIGHT")
frame.msg:SetPoint("BOTTOM", frame.bottom, "TOP", 0, 8)

frame.msg:SetMaxLines(10000)
frame.msg:SetFading(false)
frame.msg:SetFontObject("GameFontHighlightLeft")
frame.msg:EnableMouseWheel(true)

-- Hook scrolling to scroll up down with mousewheel. shift mousewheel
-- scroll all the way to the top/bottom.
local function ScrollingFunction(self, arg)
  if arg > 0 then
    if IsShiftKeyDown() then self:ScrollToTop() else self:ScrollUp() end
  elseif arg < 0 then
    if IsShiftKeyDown() then self:ScrollToBottom() else self:ScrollDown() end
  end
end
frame.msg:SetScript("OnMouseWheel", ScrollingFunction)

function lib:DebugStub(fmt, ...) end

local function GetTimeShort()
  local t = GetTime()
  return t - math.floor(t / 100) * 100
end

local function GetCaller()
  local trace = debugstack(3, 1, 0)
  return trace:match("([^\\]-): in function") or trace
end

function lib:Debug(fmt, ...)
  frame.msg:AddMessage(string.format("%6.3f (%s):  "..fmt,
                                     GetTimeShort(), GetCaller(), ...))
end

local mt = getmetatable(lib) or {}
mt.__call = lib.DebugStub
setmetatable(lib, mt)

function lib:IsDebugging()
  return isDebugging
end

function lib:EnableDebugging(val)
  local mt = getmetatable(self)
  if val == false then
    mt.__call = lib.DebugStub
    frame:Hide()
  else
    mt.__call = lib.Debug
    frame:Show()
  end
  isDebugging = val ~= false
end

frame:Hide()
