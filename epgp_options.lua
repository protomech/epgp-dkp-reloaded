local L = LibStub("AceLocale-3.0"):GetLocale("EPGP")

function EPGP:ModuleEnabled(i)
  local m = self:GetModule(i[#i-1])
  return m:IsEnabled()
end

function EPGP:ModuleDisabled(i)
  local m = self:GetModule(i[#i-1])
  return not m:IsEnabled()
end

function EPGP:ModuleSetEnabledState(i, v)
  local m = self:GetModule(i[#i-1])
  if v ~= m:IsEnabled() then
    if v then
      self:Info("Enabling module: %s", m:GetName())
      m:Enable()
    else
      self:Info("Disabling module: %s", m:GetName())
      m:Disable()
    end
  end
  m.db.profile.enabled = v
end

function EPGP:ModuleGetDBVar(i)
  local m = self:GetModule(i[#i-1])
  return m.db.profile[i[#i]]
end

function EPGP:ModuleSetDBVar(i, v)
  local m = self:GetModule(i[#i-1])
  m.db.profile[i[#i]] = v
end

function EPGP:SetupOptions()
  local options = {
    name = "EPGP",
    type = "group",
    childGroups = "tab",
    handler = self,
    args = {
      help = {
        order = 1,
        type = "description",
        name = L["EPGP is an in game, relational loot distribution system"],
      },
      hint = {
        order = 2,
        type = "description",
        name = L["Hint: You can open these options by typing /epgp config"],
      },
      list_errors = {
        order = 1000,
        type = "execute",
        name = L["List errors"],
        desc = L["Lists errors during officer note parsing to the default chat frame. Examples are members with an invalid officer note."],
        func = function()
                 outputFunc = function(s) DEFAULT_CHAT_FRAME:AddMessage(s) end
                 EPGP:ReportErrors(outputFunc)
               end,
      },
      reset = {
        order = 1001,
        type = "execute",
        name = L["Reset EPGP"],
        desc = L["Resets EP and GP of all members of the guild. This will set all main toons' EP and GP to 0. Use with care!"],
        func = function() StaticPopup_Show("EPGP_RESET_EPGP") end,
      },
    },
  }

  -- Setup options for each module that defines them.
  for name, m in self:IterateModules() do
    if m.optionsArgs then
      -- Set all options under this module as disabled when the module
      -- is disabled.
      for n, o in pairs(m.optionsArgs) do
        if o.disabled then
          local old_disabled = o.disabled
          o.disabled = function(i)
                         return old_disabled(i) or ModuleDisabled(i)
                       end
        else
          o.disabled = ModuleDisabled
        end
      end
      -- Add the enable/disable option.
      m.optionsArgs.enabled = {
        order = 0,
        type = "toggle",
        width = "full",
        name = ENABLE,
        get = "ModuleEnabled",
        set = "ModuleSetEnabledState",
      }
    end
    if m.optionsName then
      -- Add this module's options.
      options.args[name] = {
        order = 100,
        type = "group",
        name = m.optionsName,
        desc = m.optionsDesc,
        args = m.optionsArgs,
        get = "ModuleGetDBVar",
        set = "ModuleSetDBVar",
      }
    end
  end

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
