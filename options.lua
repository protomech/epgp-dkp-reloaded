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
      hint = {
        order = 1,
        type = "description",
        name = L["Hint: You can open these options by typing /epgp config"],
      },
      gp_on_tooltips = {
        order = 11,
        type = "toggle",
        name = L["Enable GP on tooltips"],
        desc = L["Enable a proposed GP value of armor on tooltips. Quest items or tokens that can be traded with armor will also have a proposed GP value."],
        width = "double",
      },
      auto_loot = {
        order = 12,
        type = "toggle",
        name = L["Enable automatic loot tracking"],
        desc = L["Enable automatic loot tracking by means of a popup to assign GP to the toon that received loot. This option only has effect if you are in a raid and you are either the Raid Leader or the Master Looter."],
        width = "double",
      },
      auto_loot_threshold = {
        order = 13,
        type = "select",
        name = L["Automatic loot tracking threshold"],
        desc = L["Sets automatic loot tracking threshold, to disable the popup on loot below this threshold quality."],
        values = {
          [2] = ITEM_QUALITY2_DESC,
          [3] = ITEM_QUALITY3_DESC,
          [4] = ITEM_QUALITY4_DESC,
          [5] = ITEM_QUALITY5_DESC,
        },
      },
      auto_standby_whispers = {
        order = 14,
        type = "toggle",
        name = L["Enable standby whispers in raid"],
        desc = L["Enable automatic handling of the standby list through whispers when in raid. When this option is selected the standby list is cleared after each reward"],
        width = "double",
      },
      announce = {
        order = 15,
        type = "toggle",
        name = L["Enable announce of actions"],
        desc = L["Enable announcement of all EPGP actions to the specified medium."],
        width = "double",
      },
      announce_medium = {
        order = 16,
        type = "select",
        name = L["Set the announce medium"],
        desc = L["Sets the announce medium EPGP will use to announce EPGP actions."],
        values = {
          ["GUILD"] = CHAT_MSG_GUILD,
          ["OFFICER"] = CHAT_MSG_OFFICER,
          ["RAID"] = CHAT_MSG_RAID,
          ["PARTY"] = CHAT_MSG_PARTY,
          ["CHANNEL"] = CUSTOM,
        },
      },
      announce_channel = {
        order = 17,
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
                           if msg == "config" then
                             InterfaceOptionsFrame_OpenToCategory("EPGP")
                           else
                             if EPGPFrame then
                               if EPGPFrame:IsShown() then
                                 HideUIPanel(EPGPFrame)
                               else
                                 ShowUIPanel(EPGPFrame)
                               end
                             end
                           end
                         end
end
