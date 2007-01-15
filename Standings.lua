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
        T:SetHint("EP: Effort Points, GP: Gear Points, PR: Priority")
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

-- Builds a standings table with record:
-- name, class, EP, GP, PR
-- and sorted by PR with members with EP < MIN_EP at the end
function EPGP_Standings:BuildStandingsTable()
  local t = { }
  local alts = EPGP:GetAlts()
  local roster = EPGP:GetRoster()
  for n in EPGP:GetStandingsIterator() do
  	local name = EPGP:ResolveMember(n)
  	local class, ep, tep, gp, tgp = unpack(roster[name])
    if (class and ep and tep and gp and tgp) then
			local EP,GP = tep + ep, tgp + gp
			local PR = GP == 0 and EP or EP/GP
      table.insert(t, { n, class, EP, GP, PR })
    end
  end
  -- Normal sorting function
	local function SortPR(a,b)
		local a_low = a[3] < EPGP:GetMinEPs()
		local b_low = b[3] < EPGP:GetMinEPs()
		if a_low and not b_low then return false
		elseif not a_low and b_low then return true
		else return a[5] > b[5] end
	end
  if (self.db.char.group_by_class) then
    table.sort(t, function(a,b)
      if (a[2] ~= b[2]) then return a[2] < b[2]
      else return SortPR(a, b) end
    end)
  else
    table.sort(t, SortPR)
  end
  return t
end

function EPGP_Standings:OnTooltipUpdate()
  local cat = T:AddCategory(
      "columns", 4,
      "text",  C:Orange("Name"),   "child_textR",    1, "child_textG",    1, "child_textB",    1, "child_justify",  "LEFT",
      "text2", C:Orange("EP"),     "child_text2R",   1, "child_text2G",   1, "child_text2B",   1, "child_justify4", "RIGHT",
      "text3", C:Orange("GP"),     "child_text3R",   1, "child_text3G",   1, "child_text3B",   1, "child_justify5", "RIGHT",
      "text4", C:Orange("PR"),     "child_text4R",   1, "child_text4G",   1, "child_text4B",   0, "child_justify6", "RIGHT"
    )
  local t = self:BuildStandingsTable()
  for k,v in pairs(t) do
    local name, class, ep, gp, pr = unpack(v)
		local ep_str, gp_str, pr_str = string.format("%d", ep), string.format("%d", gp), string.format("%.4g", pr)
    cat:AddLine(
      "text", C:Colorize(BC:GetHexColor(class), name),
      "text2", ep < EPGP:GetMinEPs() and C:Colorize("7f7f7f", ep_str) or ep_str,
      "text3", ep < EPGP:GetMinEPs() and C:Colorize("7f7f7f", gp_str) or gp_str,
      "text4", ep < EPGP:GetMinEPs() and C:Colorize("7f7f00", pr_str) or pr_str
    )
  end

  local info = T:AddCategory("columns", 2)
  info:AddLine("text", C:Red("Min EPs"), "text2", C:Red(EPGP:GetMinEPs()))
end
