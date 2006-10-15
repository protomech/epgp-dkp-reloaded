local T = AceLibrary("Tablet-2.0")
local D = AceLibrary("Dewdrop-2.0")

EPGP_History = EPGP:NewModule("EPGP_History", "AceDB-2.0")
EPGP_History:RegisterDB("EPGP_History_DB", "EPGP_History_DB_CHAR")
EPGP_History:RegisterDefaults("char", {
  data = { },
  detached_data = { }
})

function EPGP_History:OnEnable()
  self.index_start = 1
  if not T:IsRegistered("EPGP_History") then
    T:Register("EPGP_History",
      "children", function()
        T:SetTitle("EPGP History")
        T:SetHint("EP: Effort Points, GP: Gear Points, PR: Priority")
        self:OnTooltipUpdate()
      end,
      "data", self.db.char.data,
      "detachedData", self.db.char.detached_data,
  		"showTitleWhenDetached", true,
  		"showHintWhenDetached", true,
  		"cantAttach", true
    )
  end
  if not T:IsAttached("EPGP_History") then
    T:Open("EPGP_History")
  end
end

function EPGP_History:OnDisable()
  T:Close("EPGP_History")
end

function EPGP_History:Refresh()
  T:Refresh("EPGP_History")
end

function EPGP_History:Toggle()
  if T:IsAttached("EPGP_History") then
    T:Detach("EPGP_History")
  else
    T:Attach("EPGP_History")
  end
end

function EPGP_History:NavigateNext()
  self.index_start = math.min(11, self.index_start + 5)
  self:Refresh()
end

function EPGP_History:NavigatePrevious()
  self.index_start = math.max(1, self.index_start - 5)
  self:Refresh()
end

function EPGP_History:OnTooltipUpdate()
  local prev = T:AddCategory(
      "columns", 1
    )
  prev:AddLine(
    "text", "Previous",
    "func", "NavigatePrevious",
    "arg1", self
    )
  local cat = T:AddCategory(
      "columns", 6,
      "text",  "Name",                        "textR",  1, "textG",  1, "textB",  1, "justify",  "LEFT",
      "text2", "Raid " .. self.index_start,   "text2R", 1, "text2G", 1, "text2B", 1, "justify2", "RIGHT",
      "text3", "Raid " .. self.index_start+1, "text3R", 1, "text3G", 1, "text3B", 1, "justify3", "RIGHT",
      "text4", "Raid " .. self.index_start+2, "text4R", 1, "text4G", 1, "text4B", 1, "justify4", "RIGHT",
      "text5", "Raid " .. self.index_start+3, "text5R", 1, "text5G", 1, "text5B", 1, "justify5", "RIGHT",
      "text6", "Raid " .. self.index_start+4, "text6R", 1, "text6G", 1, "text6B", 1, "justify6", "RIGHT"
    )
  local t = EPGP:BuildHistoryTable()
  for i = 1, table.getn(t) do
    assert(table.getn(t[i][2]) == table.getn(t[i][3]), "EP and GP tables are not equal!")
    cat:AddLine(
      "text",  t[i][1],
      "text2", string.format("%d/%d", t[i][2][self.index_start],   t[i][3][self.index_start]),
      "text3", string.format("%d/%d", t[i][2][self.index_start+1], t[i][3][self.index_start+1]),
      "text4", string.format("%d/%d", t[i][2][self.index_start+2], t[i][3][self.index_start+2]),
      "text5", string.format("%d/%d", t[i][2][self.index_start+3], t[i][3][self.index_start+3]),
      "text6", string.format("%d/%d", t[i][2][self.index_start+4], t[i][3][self.index_start+4])
    )
  end
  local prev = T:AddCategory(
      "columns", 1
    )
  prev:AddLine(
    "text", "Next",
    "func", "NavigateNext",
    "arg1", self
    )
end
