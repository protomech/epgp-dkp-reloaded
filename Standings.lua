local T = AceLibrary("Tablet-2.0")
local D = AceLibrary("Dewdrop-2.0")

EPGP_Standings = EPGP:NewModule("EPGP_Standings", "AceDB-2.0")
EPGP_Standings:RegisterDB("EPGP_Standings_DB", "EPGP_Standings_DB_CHAR")
EPGP_Standings:RegisterDefaults("char", {
  data = { },
  detached_data = { }
})

function EPGP_Standings:OnEnable()
  if not T:IsRegistered("EPGP_Standings") then
    T:Register("EPGP_Standings",
      "children", function()
        T:SetTitle("EPGP Standings")
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
  if not T:IsAttached("EPGP_Standings") then
    T:Open("EPGP_Standings")
  end
end

function EPGP_Standings:OnDisable()
  T:Close("EPGP_Standings")
end

function EPGP_Standings:Refresh()
  T:Refresh("EPGP_Standings")
end

function EPGP_Standings:Toggle()
  if T:IsAttached("EPGP_Standings") then
    T:Detach("EPGP_Standings")
  else
    T:Attach("EPGP_Standings")
  end
end

function EPGP_Standings:OnTooltipUpdate()
  local cat = T:AddCategory(
      "columns", 4,
      "text", "Name", "textR", 1, "textG", 1, "textB", 1, "justify", "LEFT",
      "text2", "EP", "textR", 1, "textG", 1, "textB", 1, "justify2", "RIGHT",
      "text3", "GP", "textR", 1, "textG", 1, "textB", 1, "justify3", "RIGHT",
      "text4", "PR", "textR", 1, "textG", 1, "textB", 1, "justify4", "RIGHT"      
    )
  local t = EPGP:BuildStandingsTable()
  for i = 1, table.getn(t) do
    cat:AddLine(
      "text", t[i][1],
      "text2", string.format("%.4g", t[i][2]),
      "text3", string.format("%.4g", t[i][3]),
      "text4", string.format("%.4g", t[i][4]))
  end
end
