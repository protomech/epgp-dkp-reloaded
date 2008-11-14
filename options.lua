local mod = EPGP:NewModule("EPGP_Options")

local L = LibStub("AceLocale-3.0"):GetLocale("EPGP")

function mod:OnEnable()
  local options = {
    name = "EPGP",
    type = "group",
    get = function(i) return EPGP.db.profile[i[#i]] end,
    set = function(i, v) EPGP.db.profile[i[#i]] = v end,
    args = {
      help = {
        order = 0,
        type = "description",
        name = L["EPGP is an in game, relational loot distribution system"],
      },
      gp_on_tooltips = {
        order = 1,
        type = "toggle",
        name = L["Enable GP on tooltips"],
        desc = L["Enable a proposed GP value of epic quality armor on tooltips. Quest items or tokens that can be traded with armor will also have a proposed GP value."],
        width = "double",
      },
      auto_loot = {
        order = 2,
        type = "toggle",
        name = L["Enable automatic loot tracking"],
        desc = L["Enable automatic loot tracking by means of a popup to assign GP to the toon that received loot. This option only has effect if you are in a raid and you are either the Raid Leader or the Master Looter."],
        width = "double",
      },
      announce = {
        order = 3,
        type = "toggle",
        name = L["Enable announce of actions"],
        desc = L["Enable announcement of all EPGP actions to the specified medium."],
        width = "double",
      },
      announce_medium = {
        order = 4,
        type = "select",
        name = L["Set the announce medium"],
        desc = L["Sets the announce medium EPGP will use to announce EPGP actions."],
        values = {
          ["GUILD"] = GUILD,
          ["RAID"] = RAID,
          ["PARTY"] = PARTY,
          ["CHANNEL"] = CHANNEL,
        },
      },
      announce_channel = {
        order = 5,
        type = "input",
        name = L["Custom announce channel name"],
        desc = L["Sets the custom announce channel name used to announce EPGP actions."],
      },
      reset = {
        order = 100,
        type = "execute",
        name = L["Reset EPGP"],
        desc = L["Resets EP and GP of all members of the guild. This will set all main toons' EP and GP to 0. Use with care!"],
        func = function() StaticPopup_Show("EPGP_RESET_EPGP") end,
      },
    },
  }

  local config = LibStub("AceConfig-3.0")
  local dialog = LibStub("AceConfigDialog-3.0")

  config:RegisterOptionsTable("EPGP-Bliz", options)
  dialog:AddToBlizOptions("EPGP-Bliz", "EPGP")

  SLASH_EPGP1 = "/epgp"
  SlashCmdList["EPGP"] = function(msg)
                           InterfaceOptionsFrame_OpenToCategory("EPGP")
                         end
end
