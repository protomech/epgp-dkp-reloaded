local T = AceLibrary("Tablet-2.0")
local D = AceLibrary("Dewdrop-2.0")
local C = AceLibrary("Crayon-2.0")

local BC = AceLibrary("Babble-Class-2.2")

EPGP_Standings = EPGP:NewModule("EPGP_Standings", "AceDB-2.0")
EPGP_Standings:RegisterDB("EPGP_Standings_DB", "EPGP_Standings_DB_CHAR")
EPGP_Standings:RegisterDefaults("char", {
  data = { },
  detached_data = { },
  group_by_class = false
})

function EPGP_Standings:OnEnable()
  if not T:IsRegistered("EPGP_Standings") then
    T:Register("EPGP_Standings",
      "children", function()
        T:SetTitle("EPGP Standings")
        T:SetHint("EP: Effort Points, TEP: Total Effort Points, #R: Number of raids, GP: Gear Points, PR: Priority")
        self:OnTooltipUpdate()
      end,
      "data", self.db.char.data,
      "detachedData", self.db.char.detached_data,
  		"showTitleWhenDetached", true,
  		"showHintWhenDetached", true,
  		"cantAttach", true,
  		"menu", function()
  		  D:AddLine(
  		    "text", "Group by class",
  		    "tooltipText", "Group members by class.",
  		    "checked", self.db.char.group_by_class,
  		    "func", function() EPGP_Standings:ToggleGroupByClass() end
  		    )
  		end
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
    if (T:IsLocked("EPGP_Standings")) then
      T:ToggleLocked("EPGP_Standings")
    end
  else
    T:Attach("EPGP_Standings")
  end
end

function EPGP_Standings:ToggleGroupByClass()
  self.db.char.group_by_class = not self.db.char.group_by_class
  self:Refresh()
end

function EPGP_Standings:ComputeEP(t)
  local ep = 0
  local tep = 0
  local nraids = 0
  local rw = EPGP:GetRaidWindow()
  local mr = EPGP:GetMinRaids()
  
  for k,v in pairs(t) do
    if (k > rw) then break end
    tep = tep + v
    if (v > 0) then
      nraids = nraids + 1
    end
  end
  ep = (nraids < mr) and 0 or tep
  return tep, nraids, ep
end

function EPGP_Standings:ComputeGP(t)
  local gp = 0
  local rw = EPGP:GetRaidWindow()
  for k,v in pairs(t) do
    if (k > rw) then break end
    gp = gp + v
  end
  return (gp == 0) and 1 or gp
end
  
-- Builds a standings table with record:
-- name, class, EP, NR, EEP, GP, PR
-- and sorted by PR
function EPGP_Standings:BuildStandingsTable()
  local t = { }
  local alts = EPGP:GetAlts()
  local roster = EPGP:GetRoster()
  for n in EPGP:GetStandingsIterator() do
    local name = n
    local main_name = EPGP:ResolveMember(name)
    local class, ept, gpt = EPGP:GetClass(roster, name), EPGP:GetEPGP(roster, main_name)
    if (class and ept and gpt) then
      local tep, nraids, ep = self:ComputeEP(ept)
      local gp = self:ComputeGP(gpt)
      table.insert(t, { name, class, tep, nraids, ep, gp, ep/gp })
    end
  end
  -- Sort by priority and group by class if necessary
  if (self.db.char.group_by_class) then
    table.sort(t, function(a,b)
      if (a[2] ~= b[2]) then return a[2] > b[2]
      else return a[7] > b[7] end
    end)
  else
    table.sort(t, function(a,b)
      return a[7] > b[7]
    end)
  end
  return t
end

function EPGP_Standings:OnTooltipUpdate()
  local cat = T:AddCategory(
      "columns", 6,
      "text",  C:Orange("Name"),   "child_textR",    1, "child_textG",    1, "child_textB",    1, "child_justify",  "LEFT",
      "text2", C:Orange("TEP"),    "child_text2R", 0.5, "child_text2G", 0.5, "child_text2B", 0.5, "child_justify2", "RIGHT",
      "text3", C:Orange("#R"),     "child_text3R",   1, "child_text3G",   1, "child_text3B",   1, "child_justify3", "RIGHT",
      "text4", C:Orange("EP"),     "child_text4R",   1, "child_text4G",   1, "child_text4B",   1, "child_justify4", "RIGHT",
      "text5", C:Orange("GP"),     "child_text5R",   1, "child_text5G",   1, "child_text5B",   1, "child_justify5", "RIGHT",
      "text6", C:Orange("PR"),     "child_text6R",   1, "child_text6G",   1, "child_text6B",   0, "child_justify6", "RIGHT"
    )
  local t = self:BuildStandingsTable()
  for k,v in pairs(t) do
    local name, class, tep, nraids, ep, gp, pr = unpack(v)
    cat:AddLine(
      "text", C:Colorize(BC:GetHexColor(class), name),
      "text2", string.format("%.4g", tep),
      "text3", string.format("%.2g", nraids),
      "text4", string.format("%.4g", ep),
      "text5", string.format("%.4g", gp),
      "text6", string.format("%.4g", pr)
    )
  end

  local info = T:AddCategory("columns", 2)
  info:AddLine("text", C:Red("Raid Window"), "text2", C:Red(EPGP:GetRaidWindow()))
  info:AddLine("text", C:Red("Min Raids"), "text2", C:Red(EPGP:GetMinRaids()))
end
