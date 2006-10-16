local T = AceLibrary("Tablet-2.0")
local D = AceLibrary("Dewdrop-2.0")
local C = AceLibrary("Crayon-2.0")

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
        T:SetHint("EP: Effort Points, TEP: Total Effort Points, #Raid: Number of raids, GP: Gear Points, PR: Priority")
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
      "columns", 6,
      "text",  C:Orange("Name"),   "child_textR",    1, "child_textG",    1, "child_textB",    1, "child_justify",  "LEFT",
      "text2", C:Orange("TEP"),    "child_text2R", 0.5, "child_text2G", 0.5, "child_text2B", 0.5, "child_justify2", "RIGHT",
      "text3", C:Orange("#raids"), "child_text3R",   1, "child_text3G",   1, "child_text3B",   1, "child_justify3", "RIGHT",
      "text4", C:Orange("EP"),     "child_text4R",   1, "child_text4G",   1, "child_text4B",   1, "child_justify4", "RIGHT",
      "text5", C:Orange("GP"),     "child_text5R",   1, "child_text5G",   1, "child_text5B",   1, "child_justify5", "RIGHT",
      "text6", C:Orange("PR"),     "child_text6R",   1, "child_text6G",   1, "child_text6B",   0, "child_justify6", "RIGHT"
    )
  local t = EPGP:BuildStandingsTable()
  for i = 1, table.getn(t) do
    local name, tep, nraids, ep, gp, pr = unpack(t[i])
    cat:AddLine(
      "text", name,
      "text2", string.format("%.4g", tep),
      "text3", string.format("%.2g", nraids),
      "text4", string.format("%.4g", ep),
      "text5", string.format("%.4g", gp),
      "text6", string.format("%.4g", pr)
    )
  end

  local info = T:AddCategory("columns", 2)
  info:AddLine("text", C:Red("Raid Window"), "text2", C:Red(EPGP.db.profile.raid_window_size))
  info:AddLine("text", C:Red("Min Raids"), "text2", C:Red(EPGP.db.profile.min_raids))
end
