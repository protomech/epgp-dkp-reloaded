EPGP = AceLibrary("AceAddon-2.0"):new("AceConsole-2.0", "AceDB-2.0", "AceDebug-2.0", "AceEvent-2.0", "AceModuleCore-2.0", "FuBarPlugin-2.0")
EPGP:SetModuleMixins("AceDebug-2.0")

-------------------------------------------------------------------------------
-- DB defaults
-------------------------------------------------------------------------------
EPGP:RegisterDB("EPGP_DB")
EPGP:RegisterDefaults("profile", {
  -- Default report channel
  report_channel = "GUILD"
})

-------------------------------------------------------------------------------
-- Init code
-------------------------------------------------------------------------------
function EPGP:OnInitialize()
  self.OnMenuRequest = self:BuildOptions()
  self:RegisterChatCommand({ "/epgp" }, self.OnMenuRequest)
end

function EPGP:OnEnable()
  self:Print("EPGP addon is enabled")
  self:RegisterEvent("GUILD_ROSTER_UPDATE")
  self:RegisterEvent("PLAYER_GUILD_UPDATE")
  self:RegisterEvent("ZONE_CHANGED_NEW_AREA")
  self:RegisterEvent("EPGP_PULL_ROSTER", 1)
  self:ZONE_CHANGED_NEW_AREA()
  self:PLAYER_GUILD_UPDATE()
end

function EPGP:GetRaidWindow()
  return self.raid_window or 10
end

function EPGP:SetRaidWindow(rw)
  assert(rw and tonumber(rw), "Attempt to set raid window to something that is not a number!")
  rw = tonumber(rw)
  if (self.raid_window ~= rw) then
    self.raid_window = rw
    self:Print("Raid Window set to " .. tostring(rw))
  end
end

function EPGP:GetMinRaids()
  return self.min_raids or 2
end

function EPGP:SetMinRaids(mr)
  assert(mr and tonumber(mr), "Attempt to set min raids to something that is not a number!")
  mr = tonumber(mr)
  if (self.min_raids ~= mr) then
    self.min_raids = mr
    self:Print("Min raids set to " .. tostring(mr))
  end
end

function EPGP:PLAYER_GUILD_UPDATE()
  -- Keep Guild Roster up to date by calling GuildRoster() every 15 secs
  if (IsInGuild()) then
    GuildRoster()
    self:ScheduleRepeatingEvent(GuildRoster, 15)
  else
    self:CancelAllScheduledEvents()
  end
end

function EPGP:GUILD_ROSTER_UPDATE()
  self:Debug("Processing GUILD_ROSTER_UPDATE")
  self:ScheduleEvent("EPGP_PULL_ROSTER", 1)
end

function EPGP:ZONE_CHANGED_NEW_AREA()
  self.current_zone = GetRealZoneText()
end

function EPGP:OnDisable()

end

function EPGP:CanLogRaids()
  return CanEditOfficerNote() and CanEditPublicNote()
end

function EPGP:CanChangeRules()
  return IsGuildLeader()
end

-- Builds an AceOptions table for the options
function EPGP:BuildOptions()
  -- Set up raid tracking options
  local options = {
    type = "group",
    desc = "EPGP Options",
    args = { }
  }
  -- EPs to raid
  options.args["ep_raid"] = {
    type = "text",
    name = "+EPs to Raid",
    desc = "Award EPs to raid members that are zoned.",
    get = false,
    set = function(v) self:AddEP2Raid(tonumber(v)) end,
    usage = "<EP>",
    disabled = function() return not self:CanLogRaids() end,
    validate = function(v)
      local n = tonumber(v)
      return n and n >= 0 and n < 4096
    end,
    order = 1
  }
  -- EP% to raid
  options.args["ep_bonus_raid"] = {
    type = "text",
    name = "+EP bonus % to Raid",
    desc = "Award EP % bonus to raid members that are zoned.",
    get = false,
    set = function(v) self:AddEPBonus2Raid(tonumber(v)/100) end,
    usage = "<EP>",
    disabled = function() return not self:CanLogRaids() end,
    validate = function(v)
      local n = tonumber(v)
      return n and n > 0 and n <= 100
    end,
    order = 2
  }
  -- EPs to member
  options.args["ep"] = {
    type = "group",
    name = "+EPs to Member",
    desc = "Award EPs to member.",
    disabled = function() return not self:CanChangeRules() end,
    args = { },
    order = 3,
  }
  for n, t in pairs(self:GetRoster()) do
    local member_name, class, _, _ = n, unpack(t)
    if (not options.args["ep"].args[class]) then
      options.args["ep"].args[class] = {
        type = "group",
        name = class,
        desc = class .. " members",
        disabled = function() return not self:CanChangeRules() end,
        args = { }
      }
    end
    options.args["ep"].args[class].args[member_name] = {
      type = "text",
      name = member_name,
      desc = "Award EPs to " .. member_name .. ".",
      usage = "<EP>",
      get = false,
      set = function(v) self:AddEP2Member(member_name, tonumber(v)) end,
      validate = function(v) return (type(v) == "number" or tonumber(v)) and tonumber(v) < 4096 end,
      order = 3
    }
  end
  -- GPs to member
  options.args["gp"] = {
    type = "group",
    name = "+GPs to Member",
    desc = "Account GPs for member.",
    disabled = function() return not self:CanLogRaids() end,
    args = { },
    order = 4
  }
  for n, t in pairs(self:GetRoster()) do
    local member_name, class, _, _ = n, unpack(t)
    if (not options.args["gp"].args[class]) then
      options.args["gp"].args[class] = {
        type = "group",
        name = class,
        desc = class .. " members",
        disabled = function() return not self:CanChangeRules() end,
        args = { }
      }
    end
    options.args["gp"].args[class].args[member_name] = {
      type = "text",
      name = member_name,
      desc = "Account GPs to " .. member_name .. ".",
      usage = "<GP>",
      get = false,
      set = function(v) self:AddGP2Member(member_name, tonumber(v)) end,
      validate = function(v) return (type(v) == "number" or tonumber(v)) and tonumber(v) < 4096 end
    }
  end

  -----------------------------------------------------------------------------
  -- Administrative options

  -- Start new raid
  options.args["newraid"] = {
    type = "execute",
    name = "Create New Raid",
    desc = "Create a new raid slot.",
    order = 1001,
    disabled = function() return not self:CanLogRaids() end,
    func =  function() self:NewRaid() end 
  }
  -- Reporting channel
  options.args["report_channel"] = {
    type = "text",
    name = "Reporting channel",
    desc = "Channel used by reporting functions.",
    get = function() return self.db.profile.report_channel end,
    set = function(v) self.db.profile.report_channel = v end,
    validate = { "PARTY", "RAID", "GUILD", "OFFICER" },
    order = 1002
  }
  -- Reset EPGP data
  options.args["reset"] = {
    type = "execute",
    name = "Reset EPGP",
    desc = "Resets all EPGP data.",
    guiHidden = true,
    disabled = function() return not self:CanChangeRules() end,
    func = function() EPGP:ResetEPGP() end
  }
  return options
end


function EPGP:Report(msg)
  SendChatMessage("EPGP: " .. msg, self.db.profile.report_channel)
  self:Debug("EPGP: " .. msg)
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
  T:SetHint("Click to toggle EPGP standings.\nShift-Click to toggle EPGP history.")
end

function EPGP:OnClick()
  if (IsShiftKeyDown()) then
    EPGP_History:Toggle()
  else
    EPGP_Standings:Toggle()
  end
end
