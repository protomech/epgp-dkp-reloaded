EPGP = AceLibrary("AceAddon-2.0"):new("AceConsole-2.0", "AceDB-2.0", "AceDebug-2.0", "AceEvent-2.0", "AceModuleCore-2.0", "FuBarPlugin-2.0")
EPGP:SetModuleMixins("AceDebug-2.0")

-------------------------------------------------------------------------------
-- DB defaults
-------------------------------------------------------------------------------
EPGP:RegisterDB("EPGP_DB")
EPGP:RegisterDefaults("profile", {
  -- The raid_window size on which we count EPs and GPs.
  -- Anything out of the window will not be taken into account.
  raid_window_size = 10,
  -- The min number of raids to attend in the window in order to get
  -- EPs counted
  min_raids = 2,
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
  self.roster = { }
  self.alts = { }
  -- Keep Guild Roster up to date by calling GuildRoster() every 15 secs
  self:ScheduleRepeatingEvent(GuildRoster, 15); GuildRoster()
  self:RegisterEvent("GUILD_ROSTER_UPDATE", 1)
  self:RegisterEvent("ZONE_CHANGED_NEW_AREA")
  self:ZONE_CHANGED_NEW_AREA()
  if (self:CanChangeRules()) then
    self:ScheduleRepeatingEvent(self.SyncRules, 60, self)
  else
    self:RegisterEvent("CHAT_MSG_ADDON")
  end
end

function EPGP:GetRaidWindow()
  return self.db.profile.raid_window_size
end

function EPGP:SetRaidWindow(rw)
  assert(rw and tonumber(rw), "Attempt to set raid window to something that is not a number!")
  self.db.profile.raid_window_size = tonumber(rw)
end

function EPGP:GetMinRaids()
  return self.db.profile.min_raids
end

function EPGP:SetMinRaids(mr)
  assert(mr and tonumber(mr), "Attempt to set min raids to something that is not a number!")
  self.db.profile.min_raids = tonumber(mr)
end

function EPGP:GUILD_ROSTER_UPDATE()
  self:Debug("Processing GUILD_ROSTER_UPDATE")
  -- Change profile
  local guild_name, _, _ = GetGuildInfo("player")
  self:SetProfile(guild_name)
  -- Cache roster
  self:PullRoster()
  -- Rebuild options
  self.OnMenuRequest = self:BuildOptions()
  EPGP_Standings:Refresh()
  EPGP_History:Refresh()
end

function EPGP:ZONE_CHANGED_NEW_AREA()
  self.current_zone = GetRealZoneText()
end

function EPGP:SyncRules()
  local s = string.format("V:%s RW:%d MR:%d",
                          self.version,
                          self:GetRaidWindow(),
                          self:GetMinRaids())
  SendAddonMessage(self.title, s, "GUILD")
  self:Debug("Syncing rules.")
end

function EPGP:CHAT_MSG_ADDON(prefix, msg, distr, sender)
  if (prefix ~= self.title or distr ~= "GUILD") then
    return
  end
  local _, _, remote_ver, new_raid_window_size, new_min_raids =
    string.find(msg, "V:(.+) RW:(%d+) MR:(%d+)")
  if (remote_ver ~= self.version) then
    self:Print("Version mismatch. Please use the same clients across the guild!")
    return
  end
  self:SetRaidWindow(new_raid_window_size)
  self:SetMinRaids(new_min_raids)
  self:Debug("Synced raid window size to %d", self:GetRaidWindow())
  self:Debug("Synced min raids to %d", self:GetMinRaids())
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
    validate = function(v) return (type(v) == "number" or tonumber(v)) and tonumber(v) < 4096 end,
    order = 1
  }
  -- EPs to member
  options.args["ep"] = {
    type = "group",
    name = "+EPs to Member",
    desc = "Award EPs to member.",
    disabled = function() return not self:CanChangeRules() end,
    args = { },
    order = 2,
  }
  for n, t in pairs(self.db.profile.roster) do
    local member_name = n
    options.args["ep"].args[member_name] = {
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
  for n, t in pairs(self.db.profile.roster) do
    local member_name = n
    options.args["gp"].args[member_name] = {
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
  -- Report history
  options.args["history"] = {
    type = "execute",
    name = "History browser",
    desc = "Toggle the history browser.",
    order = 1004,
    func = function() EPGP_History:Toggle() end
  }
  -- Window size
  options.args["window_size"] = {
    type = "range",
    name = "EP/GP Raid Window Size",
    desc = "The number of raids back to be accounted for EP/GP calculations.",
    min = 5,
    max = 15,
    step = 1,
    order = 1005,
    disabled = function() return not self:CanChangeRules() end,
    get = function() return self:GetRaidWindow() end,
    set = function(v) self:SetRaidWindow(v) end
  }
  -- Min raids
  options.args["min_raids"] = {
    type = "range",
    name = "EP/GP Min Raids",
    desc = "The minimum number of raids in the window, for EPs to be accounted.",
    min = 0,
    max = 7,
    step = 1,
    order = 1006,
    disabled = function() return not self:CanChangeRules() end,
    get = function() return self:GetMinRaids() end,
    set = function(v) self:SetMinRaids(v) end
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
  T:SetHint("Click to show/hide EPGP standings.")
end

function EPGP:OnClick()
  EPGP_Standings:Toggle()
end
