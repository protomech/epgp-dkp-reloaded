EPGP = AceLibrary("AceAddon-2.0"):new("AceConsole-2.0", "AceDB-2.0", "AceDebug-2.0", "AceEvent-2.0", "AceModuleCore-2.0")

-------------------------------------------------------------------------------
-- DB defaults
-------------------------------------------------------------------------------
EPGP:RegisterDB("EPGP_Core_DB", "EPGP_Core_PerCharDB")
EPGP:RegisterDefaults("profile", {
  report_channel = "GUILD",
  current_listing = "GUILD",
  current_raid_only = false,
  show_alts = false,
  gp_in_tooltips = true,
  master_loot_popup = true,
  alts = {},
  outsiders = {},
  dummies = {},
  data = {},
  info = {},
  flat_credentials = false,
  min_eps = 1000,
  decay_percent = 10,
  group_by_class = false,
  show_alts = false,
  raid_mode = true,
  standings_data = {},
  standings_detached_data = {},
  config_data = {},
  config_detached_data = {},
  backup_notes = {},
  recurring_ep_period = 15,
})

function EPGP:OnEnable()
  BINDING_HEADER_EPGP = "EPGP Options"
  BINDING_NAME_EPGP = "Toggle EPGP UI"

  self:RegisterChatCommand({ "/epgp" }, {
    type = "group",
    desc = "EPGP Options",
    args = {
      ["show"] = {
        type = "execute",
        name = "Show UI",
        desc = "Shows the EPGP UI",
        disabled = function() return EPGPFrame:IsShown() end,
        func =  function() ShowUIPanel(EPGPFrame) end,
        order = 1,
      },
      ["newraid"] = {
        type = "execute",
        name = "New Raid",
        desc = "Create a new raid and decay all past EP and GP by"..
               tostring(EPGP.db.profile.decay_percent).."%.",
        disabled = function() return not self:GetModule("EPGP_Backend"):CanLogRaids() end,
        func =  function() self:GetModule("EPGP_Backend"):NewRaid() end,
        order = 4,
        confirm = "Create a new raid and decay all past EP and GP by "..
                  tostring(EPGP.db.profile.decay_percent).."%%?",
      },
      ["reset"] = {
        type = "execute",
        name = "Reset EPGP",
        desc = "Reset all EPGP data.",
        guiHidden = true,
        disabled = function() return not self:GetModule("EPGP_Backend"):CanChangeRules() end,
        func = function() self:GetModule("EPGP_Backend"):ResetEPGP() end,
        confirm = "Reset all EP and GP to 0 and make officer notes readable by all?",
        order = 11,
      },
    },
  },
  "EPGP")
end
