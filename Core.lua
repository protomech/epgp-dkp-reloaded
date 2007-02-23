local C = AceLibrary("Crayon-2.0")
local BC = AceLibrary("Babble-Class-2.2")

EPGP = AceLibrary("AceAddon-2.0"):new("AceConsole-2.0", "AceDB-2.0", "AceDebug-2.0", "AceEvent-2.0", "AceHook-2.1", "AceModuleCore-2.0", "FuBarPlugin-2.0")
Dewdrop = AceLibrary("Dewdrop-2.0")

-------------------------------------------------------------------------------
-- DB defaults
-------------------------------------------------------------------------------
EPGP:RegisterDB("EPGP_Core_DB", "EPGP_Core_PerCharDB")
EPGP:RegisterDefaults("profile", {
  -- Default report channel
  report_channel = "GUILD",
})

-------------------------------------------------------------------------------
-- Init code
-------------------------------------------------------------------------------
function EPGP:OnInitialize()
  self:RegisterEvent("ZONE_CHANGED_NEW_AREA", "UpdateZoneOptions")
  self:RegisterEvent("EPGP_CACHE_UPDATE", "UpdateMemberOptions")
  self:BuildOptions()
end

function EPGP:OnEnable()
  self:UpdateZoneOptions()
end

-------------------------------------------------------------------------------
-- UI code
-------------------------------------------------------------------------------
local T = AceLibrary("Tablet-2.0")

EPGP.defaultMinimapPosition = 180
EPGP.cannotDetachTooltip = true
EPGP.tooltipHidderWhenEmpty = false
EPGP.hasIcon = "Interface\\Icons\\INV_Misc_Orb_04"
EPGP.overrideMenu = true

function EPGP:OnTooltipUpdate()
  T:SetHint("Click to toggle EPGP standings.")
end

function EPGP:OnClick()
  self:GetModule("EPGP_Standings"):Toggle()
end

function EPGP:OnMenuRequest(level, value, inTooltip, valueN_1, valueN_2, valueN_3, valueN_4)
  Dewdrop:FeedAceOptionsTable(self.options)
  if level == 1 then
    Dewdrop:AddLine()
  end
  self:AddImpliedMenuOptions()
end

function EPGP:BuildOptions()
  local backend = self:GetModule("EPGP_Backend")
  local cache = self:GetModule("EPGP_Cache")
  self.options = {
    type = "group",
    desc = "EPGP Options",
    args = {
      -- Now build dynamic options
      ["raid"] = {
        type = "group",
        name = "+EP Raid",
        -- desc = "Award EPs to raid members that are in "..GetRealZoneText()..".",
        args = {
          ["add"] = {
            type = "text",
            name = "Add EPs to Raid",
            -- desc = "Add EPs to raid members that are in "..GetRealZoneText()..".",
            get = false,
            set = function(v) backend:AddEP2Raid(tonumber(v)) end,
            usage = "<EP>",
            disabled = function() return not (backend:CanLogRaids() and UnitInRaid("player")) end,
            validate = function(v)
              local n = tonumber(v)
              return n and n >= 0 and n < 100000
            end,
          },
          ["distribute"] = {
            type = "text",
            name = "Distribute EPs to Raid",
            -- desc = "Distribute EPs to raid members that are in "..GetRealZoneText()..".",
            get = false,
            set = function(v) backend:DistributeEP2Raid(tonumber(v)) end,
            usage = "<EP>",
            disabled = function() return not (backend:CanLogRaids() and UnitInRaid("player")) end,
            validate = function(v)
              local n = tonumber(v)
              return n and n >= 0 and n < 1000000
            end,
          },
          ["bonus"] = {
            type = "text",
            name = "Add bonus EP to Raid",
            -- desc = "Add % EP bonus to raid members that are in "..GetRealZoneText()..".",
            get = false,
            set = function(v) backend:AddEPBonus2Raid(tonumber(v)*0.01) end,
            usage = "<Bonus%>",
            disabled = function() return not (backend:CanLogRaids() and UnitInRaid("player")) end,
            validate = function(v)
              local n = tonumber(v)
              return n and n > 0 and n <= 100
            end,
          },
        },
        order = 1
      },
      ["ep"] = {
        type = "group",
        name = "+EP",
        desc = "Award EPs to member.",
        disabled = function() return not backend:CanChangeRules() end,
        args = {},
        order = 2
      },
      ["gp"] = {
        type = "group",
        name = "+GP",
        desc = "Add GPs to member.",
        disabled = function() return not backend:CanLogRaids() end,
        args = {},
        order = 3
      },
      ["newraid"] = {
        type = "execute",
        name = "New Raid",
        desc = "Create a new raid and decay all past EP and GP by"..
               tostring(cache.db.profile.decay_percent).."%.",
        disabled = function() return not backend:CanLogRaids() end,
        func =  function() backend:NewRaid() end,
        order = 4,
        confirm = "Create a new raid and decay all past EP and GP by "..
                  tostring(cache.db.profile.decay_percent).."%%?",
      },
      -- Static options
      ["channel"] = {
        type = "text",
        name = "Channel",
        desc = "Channel used by reporting functions.",
        get = function() return backend.db.profile.report_channel end,
        set = function(v) backend.db.profile.report_channel = v end,
        validate = { "PARTY", "RAID", "GUILD", "OFFICER" },
        order = 1000,
      },
      ["reset"] = {
        type = "execute",
        name = "Reset EPGP",
        desc = "Reset all EPGP data.",
        guiHidden = true,
        disabled = function() return not backend:CanChangeRules() end,
        func = function() backend:ResetEPGP() end,
        confirm = "Reset all EP and GP to 0?",
        order = 1001,
      },
      ["upgrade"] = {
      	type = "text",
      	name = "Upgrade EPGP",
      	desc = "Upgrade EPGP to new format and scale them by <scale>.",
      	usage = "<scale>",
      	get = false,
      	set = function(v) backend:UpgradeEPGP(tonumber(v)) end,
        validate = function(v)
          local n = tonumber(v)
          return n and n > 0 and n <= 1000
        end,
      	guiHidden = true,
      	disabled = function() return not backend:CanChangeRules() end,
      },
      ["backup"] = {
        type = "execute",
        name = "Backup",
        desc = "Backup public and officer notes and replace last backup.",
        func = function() backend:BackupNotes() end,
        order = 1002,
      },
      ["restore"] = {
        type = "execute",
        name = "Restore",
        desc = "Restores public and officer notes from last backup.",
        disabled = function() return not backend:CanLogRaids() end,
        func = function() backend:RestoreNotes() end,
        confirm = "Restore public and officer notes from the last backup?",
        order = 1003
      },
    },
  }
end

function EPGP:UpdateOptionDisplay()
  self:RegisterChatCommand({ "/epgp" }, self.options, "EPGP")
  if Dewdrop:IsOpen() then
    Dewdrop:Refresh(1)
    Dewdrop:Refresh(2)
    Dewdrop:Refresh(3)
    Dewdrop:Refresh(4)
  end
end

function EPGP:UpdateZoneOptions()
  self.options.args.raid.desc = "Award EPs to raid members that are in "..GetRealZoneText().."."
  self.options.args.raid.args.add.desc = "Add EPs to raid members that are in "..GetRealZoneText().."."
  self.options.args.raid.args.distribute.desc = "Distribute EPs to raid members that are in "..GetRealZoneText().."."
  self.options.args.raid.args.bonus.desc = "Add %EP bonus to raid members that are in "..GetRealZoneText().."."
  self:UpdateOptionDisplay()
end

function EPGP:UpdateMemberOptions(member_change)
  local backend = self:GetModule("EPGP_Backend")
  local cache = self:GetModule("EPGP_Cache")
  if not member_change then return end
	for i = 1, GetNumGuildMembers(true) do
  	local name, _, _, _, class = GetGuildRosterInfo(i)
  	local ep_group = self.options.args.ep
  	local gp_group = self.options.args.gp
  	if not ep_group.args[class] then
  	  ep_group.args[class] = {
        type = "group",
        name = C:Colorize(BC:GetHexColor(class), class),
        desc = class .. " members",
        disabled = function() return not backend:CanChangeRules() end,
        args = {},
  	  }
  	end
  	if not gp_group.args[class] then
  	  gp_group.args[class] = {
        type = "group",
        name = C:Colorize(BC:GetHexColor(class), class),
        desc = class .. " members",
        disabled = function() return not backend:CanLogRaids() end,
        args = {},
  	  }
  	end
	  ep_group.args[class].args[name] = {
      type = "text",
      name = C:Colorize(BC:GetHexColor(class), name),
      desc = "Add EPs to " .. name .. ".",
      usage = "<EP>",
      get = false,
      set = function(v) backend:AddEP2Member(name, tonumber(v)) end,
      validate = function(v)
        local n = tonumber(v)
        return n and n > 0 and n <= 10000
      end,
	  }
	  gp_group.args[class].args[name] = {
      type = "text",
      name = C:Colorize(BC:GetHexColor(class), name),
      desc = "Add GPs to " .. name .. ".",
      usage = "<GP>",
      get = false,
      set = function(v) backend:AddGP2Member(name, tonumber(v)) end,
      validate = function(v)
        local n = tonumber(v)
        return n and n > 0 and n <= 10000
      end,
	  }
	end
  self:UpdateOptionDisplay()
end
