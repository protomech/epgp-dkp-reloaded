local mod = EPGP:NewModule("EPGP_Standings", "AceDB-2.0", "AceEvent-2.0")

mod:RegisterDB("EPGP_Standings_DB")
mod:RegisterDefaults("profile", {
  data = { },
  detached_data = { },
  standings = { },
  group_by_class = false,
  show_alts = false,
  raid_mode = true
})

local T = AceLibrary("Tablet-2.0")
local D = AceLibrary("Dewdrop-2.0")
local C = AceLibrary("Crayon-2.0")

local BC = AceLibrary("Babble-Class-2.2")

local function RaidIterator(obj, i)
  local name = GetRaidRosterInfo(i)
  if not name then return end
  return i+1, name
end

local function GuildIterator(obj, i)
  local name
  repeat
    name = GetGuildRosterInfo(i)
    i = i+1
  until obj.db.profile.show_alts or not obj.cache:IsAlt(name)
  if not name then return end
  return i, name
end

function mod:GetStandingsIterator()
  if (self.db.profile.raid_mode and UnitInRaid("player")) then
    return RaidIterator, self, 1
  else
    return GuildIterator, self, 1
  end
end

function mod:OnInitialize()
  self.cache = EPGP:GetModule("EPGP_Cache")
end

function mod:OnEnable()
  self:RegisterEvent("EPGP_CACHE_UPDATE")
  self:RegisterEvent("RAID_ROSTER_UPDATE")
  if not T:IsRegistered("EPGP_Standings") then
    T:Register("EPGP_Standings",
      "children", function()
        T:SetTitle("EPGP Standings")
        T:SetHint("EP: Effort Points, GP: Gear Points, PR: Priority")
        self:OnTooltipUpdate()
      end,
      "data", self.db.profile.data,
      "detachedData", self.db.profile.detached_data,
  		"showTitleWhenDetached", true,
  		"showHintWhenDetached", true,
  		"cantAttach", true,
  		"menu", function()
  		  D:AddLine(
  		    "text", "Group by class",
  		    "tooltipText", "Toggles grouping members by class.",
  		    "checked", self.db.profile.group_by_class,
  		    "func", function() self.db.profile.group_by_class = not self.db.profile.group_by_class; self:EPGP_CACHE_UPDATE() end
  		  )
  		  D:AddLine(
  		    "text", "Show Alts",
  		    "tooltipText", "Toggles listing of Alts in standings.",
  		    "checked", self.db.profile.show_alts or self.db.profile.raid_mode,
  		    "disabled", self.db.profile.raid_mode,
  		    "func", function() self.db.profile.show_alts = not self.db.profile.show_alts; self:EPGP_CACHE_UPDATE() end
  		  )
  		  D:AddLine(
  		    "text", "Raid Mode",
  		    "tooltipText", "Toggles listing only raid members (if in raid).",
  		    "checked", self.db.profile.raid_mode,
  		    "func", function() self.db.profile.raid_mode = not self.db.profile.raid_mode; self:EPGP_CACHE_UPDATE() end
  		  )
  		end
    )
  end
  if not T:IsAttached("EPGP_Standings") then
    T:Open("EPGP_Standings")
  end
end

function mod:OnDisable()
  T:Close("EPGP_Standings")
end

function mod:EPGP_CACHE_UPDATE()
  self.standings = self:BuildStandingsTable()
  T:Refresh("EPGP_Standings")
end

function mod:RAID_ROSTER_UPDATE()
  if self.db.profile.raid_mode then
    T:Refresh("EPGP_Standings")
  end
end

function mod:Toggle()
  if T:IsAttached("EPGP_Standings") then
    T:Detach("EPGP_Standings")
    if (T:IsLocked("EPGP_Standings")) then
      T:ToggleLocked("EPGP_Standings")
    end
  else
    T:Attach("EPGP_Standings")
  end
end

-- Builds a standings table with record:
-- name, class, EP, GP, PR
-- and sorted by PR with members with EP < MIN_EP at the end
function mod:BuildStandingsTable()
  local t = {}
  for i,name in self:GetStandingsIterator() do
  	local ep, tep, gp, tgp = self.cache:GetMemberEPGP(name)
    local rank, rankIndex, level, class, zone, note, officernote, online, status = self.cache:GetMemberInfo(name)
    ChatFrame1:AddMessage("name: "..tostring(name).." class: "..tostring(rankIndex))
    if ep and tep and gp and tgp then
			local EP,GP = tep + ep, tgp + gp
			local PR = GP == 0 and EP or EP/GP
      table.insert(t, { name, class, EP, GP, PR })
    end
  end
  -- Normal sorting function
	local function SortPR(a,b)
		local a_low = a[3] < self.cache.db.profile.min_eps
		local b_low = b[3] < self.cache.db.profile.min_eps
		if a_low and not b_low then return false
		elseif not a_low and b_low then return true
		else return a[5] > b[5] end
	end
  if (self.db.profile.group_by_class) then
    table.sort(t, function(a,b)
      if (a[2] ~= b[2]) then return a[2] < b[2]
      else return SortPR(a, b) end
    end)
  else
    table.sort(t, SortPR)
  end
  return t
end

function mod:OnTooltipUpdate()
  if not self.standings then
    self.standings = self:BuildStandingsTable()
  end
  local cat = T:AddCategory(
      "columns", 4,
      "text",  C:Orange("Name"),   "child_textR",    1, "child_textG",    1, "child_textB",    1, "child_justify",  "LEFT",
      "text2", C:Orange("EP"),     "child_text2R",   1, "child_text2G",   1, "child_text2B",   1, "child_justify4", "RIGHT",
      "text3", C:Orange("GP"),     "child_text3R",   1, "child_text3G",   1, "child_text3B",   1, "child_justify5", "RIGHT",
      "text4", C:Orange("PR"),     "child_text4R",   1, "child_text4G",   1, "child_text4B",   0, "child_justify6", "RIGHT"
    )
  for k,v in pairs(self.standings) do
    local name, class, ep, gp, pr = unpack(v)
		local ep_str, gp_str, pr_str = string.format("%d", ep), string.format("%d", gp), string.format("%.4g", pr)
    cat:AddLine(
      "text", C:Colorize(BC:GetHexColor(class), name),
      "text2", ep < self.cache.db.profile.min_eps and C:Colorize("7f7f7f", ep_str) or ep_str,
      "text3", ep < self.cache.db.profile.min_eps and C:Colorize("7f7f7f", gp_str) or gp_str,
      "text4", ep < self.cache.db.profile.min_eps and C:Colorize("7f7f00", pr_str) or pr_str
    )
  end

  local info = T:AddCategory("columns", 2)
  info:AddLine("text", C:Red("Min EPs"), "text2", C:Red(self.cache.db.profile.min_eps))
end
