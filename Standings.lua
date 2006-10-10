local T = AceLibrary("Tablet-2.0")
local D = AceLibrary("Dewdrop-2.0")

EPGP_Standings = EPGP:NewModule("EPGP_Standings", "AceDB-2.0")

function EPGP_Standings:ShowStandings()
  if not T:IsRegistered("EPGP_Standings") then
    T:Register("EPGP_Standings",
      "children", function() T:SetTitle("EPGP Standings"); self:OnTooltipUpdate() end,
			"showTitleWhenDetached", true,
			"showHintWhenDetached", true,
			"cantAttach", true,
			"menu", function()
			  D:AddLine(
			    "text", "Close window",
			    "tooltipTitle", "Close window",
			    "tooltipText", "Closes the standings window.",
			    "func", function() T:Attach("EPGP_Standings") end)
			end
    )
  end
  if T:IsAttached("EPGP_Standings") then
    T:Detach("EPGP_Standings")
  else
    T:Refresh("EPGP_Standings")
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
      "text", t[i][1], "text2", t[i][2], "text3", t[i][3], "text4", t[i][4])
  end
end
