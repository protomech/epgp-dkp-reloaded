local L = EPGPGlobalStrings

EPGP_TEXT_BACKUP = L["Backup"]
EPGP_TEXT_RESTORE = L["Restore"]
EPGP_TEXT_STANDINGS = L["Standings"]
EPGP_TEXT_ADD = L["Add"]
EPGP_TEXT_DISTRIBUTE = L["Distribute"]
EPGP_TEXT_RECURRING = L["Recurring"]
EPGP_TEXT_BONUS = L["Bonus"]
EPGP_TEXT_EXPORT_HTML = L["Export to HTML"]
EPGP_TEXT_EXPORT_TEXT = L["Export to text"]
EPGP_TEXT_DECAY = L["Decay"]

EPGP_UI = EPGP:NewModule("EPGP_UI", "AceEvent-2.0")

function EPGP_UI:OnInitialize()
  UIPanelWindows["EPGPFrame"] = { area = "left", pushable = 1, whileDead = 1, }
  self:RegisterEvent("EPGP_CACHE_UPDATE")
  StaticPopupDialogs["EPGP_TEXT_EXPORT"] = {
    text = "%s",
    hasEditBox = 1,
    OnShow = function()
      local editBox = getglobal(this:GetName().."EditBox")
      editBox:SetText(EPGP_UI.text)
      EPGP_UI.text = nil
      editBox:HighlightText()
      editBox:SetFocus()
    end,
    EditBoxOnEnterPressed = function()
      this:GetParent():Hide()
      end,
    EditBoxOnEscapePressed = function()
      this:GetParent():Hide();
    end,
    timeout = 0,
    whileDead = 1,
    hideOnEscape = 1,
  }
  StaticPopupDialogs["EPGP_HTML_EXPORT"] = {
    text = "%s",
    hasEditBox = 1,
    OnShow = function()
      local editBox = getglobal(this:GetName().."EditBox")
      editBox:SetText(EPGP_UI.text)
      EPGP_UI.text = nil
      editBox:HighlightText()
      editBox:SetFocus()
    end,
    EditBoxOnEnterPressed = function()
      this:GetParent():Hide()
      end,
    EditBoxOnEscapePressed = function()
      this:GetParent():Hide();
    end,
    timeout = 0,
    whileDead = 1,
    hideOnEscape = 1,
  }
  StaticPopupDialogs["EPGP_SET_RECURRING_PERIOD"] = {
    text = L["Enter new recurring EP period in seconds"],
    button1 = ACCEPT,
    button2 = CANCEL,
    timeout = 0,
    OnShow = function()
      local editBox = getglobal(this:GetName().."EditBox")
      editBox:SetNumeric(true)
      editBox:SetFocus()
    end,
    OnAccept = function()
      local editBox = getglobal(this:GetParent():GetName().."EditBox")
      local number = editBox:GetNumber()
      if number > 0 then
        EPGP.db.profile.recurring_ep_period = number
      end
    end,
    EditBoxOnEnterPressed = function()
      local editBox = getglobal(this:GetParent():GetName().."EditBox")
      local number = editBox:GetNumber()
      if number > 0 then
        EPGP.db.profile.recurring_ep_period = number
        this:GetParent():Hide()
      end
    end,
    EditBoxOnTextChanged = function()
      local editBox = getglobal(this:GetParent():GetName().."EditBox")
      local button1 = getglobal(this:GetParent():GetName().."Button1")
      local number = editBox:GetNumber()
      if number > 0 then
        button1:Enable()
      else
        button1:Disable()
      end
    end,
    EditBoxOnEscapePressed = function()
      this:GetParent():Hide()
    end,
    hideOnEscape = 1,
    hasEditBox = 1,
  }
end

function EPGP_UI:SetRestoreButtonStatus(button)
  if EPGP:GetModule("EPGP_Backend"):CanLogRaids() then
    button:Enable()
  else
    button:Disable()
  end
end

function EPGP_UI:SetEPButtonStatus(button)
  button:Enable()
  if not EPGP:GetModule("EPGP_Backend"):CanLogRaids() then
    button:Disable()
    return
  end

  if button:GetParent():GetNumber() == 0 then
    button:Disable()
    return
  end

  if EPGP.db.profile.current_listing == "RAID" and not UnitInRaid("player") then
    button:Disable()
    return
  end
end

function EPGP_UI:EPGP_CACHE_UPDATE()
  if EPGPListingFrame:IsShown() then
    self:UpdateListing()
  end
end

function EPGP_UI:UpdateListing()
  local backend = EPGP:GetModule("EPGP_Backend")
  local frame = getglobal("EPGPListingFrame")
  local t = self:GetListingForListingFrame()

  local last_idx = 0
  local frame_height = 0
  for i,rowdata in pairs(t) do
    local name, class, EP, GP, PR = unpack(rowdata)
    row = getglobal(frame:GetName().."Row"..i)
    if not row then
      row = CreateFrame("Button", frame:GetName().."Row"..i, frame, "EPGPListingRowTemplate")
      if i == 1 then
        row:SetPoint("TOPLEFT")
      else
        row:SetPoint("TOPLEFT", getglobal(frame:GetName().."Row"..last_idx), "BOTTOMLEFT")
      end
    end
    row.member_name = name

    getglobal(row:GetName().."Name"):SetText(name)
    local color = RAID_CLASS_COLORS[strupper(class)]
    getglobal(row:GetName().."Name"):SetTextColor(color.r, color.g, color.b)
    getglobal(row:GetName().."EP"):SetText(tostring(EP))
    getglobal(row:GetName().."EP"):SetAlpha(backend:IsBelowThreshold(EP) and 0.5 or 1.0)
    getglobal(row:GetName().."GP"):SetText(tostring(GP))
    getglobal(row:GetName().."GP"):SetAlpha(backend:IsBelowThreshold(EP) and 0.5 or 1.0)
    getglobal(row:GetName().."PR"):SetText(string.format("%.4g", PR))
    getglobal(row:GetName().."PR"):SetAlpha(backend:IsBelowThreshold(EP) and 0.5 or 1.0)
    last_idx = i
    frame_height = frame_height + row:GetHeight()
    row:Show()
  end

  -- Hide remaining rows
  while true do
    last_idx = last_idx + 1
    local row = getglobal(frame:GetName().."Row"..last_idx)
    if not row then break end
    row:Hide()
  end

  frame:SetHeight(frame_height)
  frame:GetParent():UpdateScrollChildRect()
end

function EPGP_UI:UpdateCheckButtons()
  local show_alts_button = getglobal("EPGPFrameShowAltsCheckButton")
  show_alts_button:SetChecked(EPGP.db.profile[EPGP.db.profile.current_listing].show_alts)
  local current_raid_button = getglobal("EPGPFrameShowCurrentRaidCheckButton")
  current_raid_button:SetChecked(EPGP.db.profile[EPGP.db.profile.current_listing].current_raid_only)
end

function EPGP_UI:GetListingForListingFrame()
  local backend = EPGP:GetModule("EPGP_Backend")
  local t = backend:GetListing(EPGP.db.profile.current_listing,
                               EPGP.db.profile.comparator_name,
                               EPGP.db.profile[EPGP.db.profile.current_listing].show_alts,
                               EPGP.db.profile[EPGP.db.profile.current_listing].current_raid_only,
                               getglobal("EPGPListingSearchBox"):GetText())
  return t
end

function EPGP_UI:Export2HTML()
  local t = self:GetListingForListingFrame()

  local text = "<table id=\"epgp-standings\">"..
  "<caption>EPGP Standings</caption>"..
  "<tr><th>Name</th><th>Class</th><th>EP</th><th>GP</th><th>PR</th></tr>"
  for i,rowdata in pairs(t) do
    local name, class, EP, GP, PR = unpack(rowdata)
    text = text..string.format(
      "<tr class=\"%s\">"..
      "<td>%s</td><td>%s</td><td>%d</td><td>%d</td><td>%.4g</td>"..
      "</tr>",
      class, name, class, EP, GP, PR)
  end
  text = text.."</table>"
  return text
end

function EPGP_UI:Export2Text()
  local t = self:GetListingForListingFrame()

  local text =
  "+----------------+-------EPGP Standings----+----------+----------+\n"..
  "|      Name      |     Class    |    EP    |    GP    |    PR    |\n"..
  "+----------------+--------------+----------+----------+----------+\n"
  local fmt_str_row = "| %-15s| %-13s|%9d |%9d |%9.2f |\n"
  for i,rowdata in pairs(t) do
    local name, class, EP, GP, PR = unpack(rowdata)
    text = text..string.format(fmt_str_row, name, class, EP, GP, PR);
  end
  text = text..
  "+----------------+--------------+----------+----------+----------+\n"
  return text
end

function EPGP_UI:AddEP2List(points)
  assert(type(points) == "number")
  EPGP:GetModule("EPGP_Backend"):AddEP2List(EPGP.db.profile.current_listing, points)
end

function EPGP_UI:DistributeEP2List(points)
  assert(type(points) == "number")
  EPGP:GetModule("EPGP_Backend"):DistributeEP2List(EPGP.db.profile.current_listing, points)
end

function EPGP_UI:RecurringEP2List(points)
  assert(type(points) == "number")
  EPGP:GetModule("EPGP_Backend"):RecurringEP2List(EPGP.db.profile.current_listing, points)
end

function EPGP_UI:BonusEP2List(percent)
  assert(type(percent) == "number")
  EPGP:GetModule("EPGP_Backend"):BonusEP2List(EPGP.db.profile.current_listing, percent)
end

function EPGP_UI.ReportChannelList_Initialize()
  local info = UIDropDownMenu_CreateInfo()
  info.func = function()
    EPGP.db.profile.report_channel = this.value
    UIDropDownMenu_SetSelectedValue(getglobal(UIDROPDOWNMENU_OPEN_MENU), EPGP.db.profile.report_channel)
  end

  local options = { L["None"], L["Guild"], L["Officer"], L["Raid"], L["Party"] }
  for i,v in pairs(options) do
    info.text = v
    info.value = strupper(v)
    info.checked = nil
    UIDropDownMenu_AddButton(info)
  end
end

function EPGP_UI.ListingList_Initialize()
  local info = UIDropDownMenu_CreateInfo()
  info.func = function()
    EPGP.db.profile.current_listing = this.value
    UIDropDownMenu_SetSelectedValue(getglobal(UIDROPDOWNMENU_OPEN_MENU), EPGP.db.profile.current_listing)
    EPGP_UI:UpdateListing()
    EPGP_UI:UpdateCheckButtons()
  end

  local options = EPGP:GetModule("EPGP_Backend"):GetListingIDs()
  for i,v in pairs(options) do
    info.text = getglobal(v)
    info.value = strupper(v)
    info.checked = nil
    UIDropDownMenu_AddButton(info)
  end
end

function EPGP_UI.ListingDropDown_Initialize()
  local info = UIDropDownMenu_CreateInfo()

  info.text = ListingDropDown.member_name
  info.isTitle = 1
  UIDropDownMenu_AddButton(info)

  info = UIDropDownMenu_CreateInfo()
  info.func = function()
    EPGP:GetModule("EPGP_Backend"):AddEP2Member(ListingDropDown.member_name)
  end
  info.text = L["Award EP"]
  info.checked = nil
  UIDropDownMenu_AddButton(info)

  info = UIDropDownMenu_CreateInfo()
  info.func = function()
    EPGP:GetModule("EPGP_Backend"):AddGP2Member(ListingDropDown.member_name)
  end
  info.text = L["Credit GP"]
  info.checked = nil
  UIDropDownMenu_AddButton(info)
end

function EPGP_UI.ListingDropDown(name)
  HideDropDownMenu(1)
  UIDropDownMenu_Initialize(ListingDropDown, EPGP_UI.ListingDropDown_Initialize, "MENU")
  ListingDropDown.member_name = name
  ToggleDropDownMenu(1, nil, ListingDropDown, "cursor");
end
