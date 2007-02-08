EPGP = AceLibrary("AceAddon-2.0"):new("AceConsole-2.0", "AceDB-2.0", "AceDebug-2.0", "AceEvent-2.0", "AceHook-2.1", "AceModuleCore-2.0", "FuBarPlugin-2.0")

-------------------------------------------------------------------------------
-- DB defaults
-------------------------------------------------------------------------------
EPGP:RegisterDB("EPGP_DB")
EPGP:RegisterDefaults("profile", {
  -- Default report channel
  report_channel = "GUILD",
})

-------------------------------------------------------------------------------
-- Init code
-------------------------------------------------------------------------------
function EPGP:OnInitialize()
	self:RegisterEvent("EPGP_CACHE_UPDATE")
end

function EPGP:EPGP_CACHE_UPDATE()
  self.OnMenuRequest = self:GetModule("EPGP_Backend"):BuildOptions()
  self:RegisterChatCommand({ "/epgp" }, self.OnMenuRequest, "EPGP")
end

-------------------------------------------------------------------------------
-- UI code
-------------------------------------------------------------------------------
local T = AceLibrary("Tablet-2.0")

EPGP.defaultMinimapPosition = 180
EPGP.cannotDetachTooltip = true
EPGP.tooltipHidderWhenEmpty = false
EPGP.hasIcon = "Interface\\Icons\\INV_Misc_Orb_04"

function EPGP:OnTooltipUpdate()
  T:SetHint("Click to toggle EPGP standings.")
end

function EPGP:OnClick()
  self:GetModule("EPGP_Standings"):Toggle()
end
