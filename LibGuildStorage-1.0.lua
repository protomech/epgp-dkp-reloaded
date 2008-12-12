-- This library handles storing information in officer notes. It
-- streamlines and optimizes access to these notes. The API is as
-- follows:
--
-- GetNote(name): Returns the officer note of member 'name'
--
-- SetNote(name, note): Sets the officer note of member 'name' to
-- 'note'
--
-- GetClass(name): Returns the class of member 'name'
--
-- GetGuildInfo(): Returns the guild info text
--
-- ProtectActionButton(button): Enables and disables buttons
-- accordingly depending on the state of the library to avoid data
-- corruption.
--
-- The library also fires the following messages, which you can
-- register for through RegisterCallback and unregister through
-- UnregisterCallback. You can also unregister all messages through
-- UnregisterAllCallbacks.
--
-- GuildInfoChanged(info): Fired when guild info has changed since its
--   previous state. The info is the new guild info.
--
-- GuildNoteChanged(name, note): Fired when a guild note changes. The
--   name is the name of the member of which the note changed and the
--   note is the new note.

local MAJOR_VERSION = "LibGuildStorage-1.0"
local MINOR_VERSION = tonumber(("$Revision$"):match("%d+")) or 0

local lib, oldMinor = LibStub:NewLibrary(MAJOR_VERSION, MINOR_VERSION)
if not lib then return end

local CallbackHandler = LibStub("CallbackHandler-1.0")
if not lib.callbacks then
  lib.callbacks = CallbackHandler:New(lib)
end
local callbacks = lib.callbacks

if lib.frame then
  lib.frame:UnregisterAllEvents()
  lib.frame:SetScript("OnEvent", nil)
  lib.frame:SetScript("OnUpdate", nil)
else
  lib.frame = CreateFrame("Frame", MAJOR_VERSION .. "_Frame")
end
local frame = lib.frame
local state = "STALE"
local protected_buttons = {}

local function LockActionButtons()
  for button in pairs(protected_buttons) do
    button:Disable()
  end
end

local function RestoreActionButtons()
  for button in pairs(protected_buttons) do
    button:SetCurrentState()
  end
end
  
local timers = LibStub("AceTimer-3.0")

-- We want to not call GuildRoster continuously if we are doing a lot
-- of changes so delay it by 10 milliseconds. If another request comes
-- in to update the roster in the meantime cancel the current one and
-- schedule another after 10 milliseconds.
local guildroster_timer
local function GuildRosterDelayed()
  timers:CancelTimer(guildroster_timer, true)
  guildroster_timer = timers:ScheduleTimer(GuildRoster, 0.01)
end

frame:SetScript("OnEvent",
                function(this, event, ...)
                  lib[event](lib, ...)
                end)

-- Cache is indexed by name and a table with index, class and note
local cache = {}
local guild_info = ""

local next_index = 1
local function UpdateGuildRoster()
  if next_index == 1 then
    local new_guild_info = GetGuildInfoText() or ""
    if new_guild_info ~= guild_info then
      guild_info = new_guild_info
      callbacks:Fire("GuildInfoChanged", guild_info)
    end
  end

  -- Read up to 100 members at a time.
  local e = math.min(next_index + 99, GetNumGuildMembers(true))
  for i = next_index, e do
    local name, _, _, _, _, _, _, note, _, _, class = GetGuildRosterInfo(i)
    if name then
      local t = cache[name]
      if not t then
        t = {}
        cache[name] = t
      end
      t.index = i
      t.class = class
      if t.note ~= note then
        t.note = note
        callbacks:Fire("GuildNoteChanged", name, note)
      end
    end
  end
  next_index = e + 1
  if next_index > GetNumGuildMembers(true) then
    frame:Hide()
    if state == "STALE" then
      RestoreActionButtons()
      state = "CURRENT"
    elseif state == "LOCAL_PENDING" then
      RestoreActionButtons()
      SendAddonMessage("EPGP", "CHANGES_FLUSHED", "GUILD")
      state = "CURRENT"
    elseif state == "REMOTE_FLUSHED" then
      RestoreActionButtons()
      state = "CURRENT"
    end
  end
end

frame:SetScript("OnUpdate", UpdateGuildRoster)

frame:RegisterEvent("PLAYER_GUILD_UPDATE")
frame:RegisterEvent("GUILD_ROSTER_UPDATE")
frame:RegisterEvent("CHAT_MSG_ADDON")

function lib:CHAT_MSG_ADDON(prefix, msg, type, sender)
  if prefix == "EPGP" and sender ~= UnitName("player") then
    if msg == "CHANGES_PENDING" then
      LockActionButtons()
      state = "REMOTE_PENDING"
    elseif msg == "CHANGES_FLUSHED" then
      GuildRosterDelayed()
      state = "REMOTE_FLUSHED"
    end
  end
end

function lib:PLAYER_GUILD_UPDATE()
  -- Hide the frame to stop OnUpdate from reading guild information
  if frame:IsShown() and not IsInGuild() then
    frame:Hide()
  end
  GuildRosterDelayed()
end

function lib:GUILD_ROSTER_UPDATE(loc)
  if loc then
    GuildRosterDelayed()
    return
  end

  -- Show the frame to make the OnUpdate handler to be called
  next_index = 1
  frame:Show()
end

function lib:GetNote(name)
  local entry = cache[name]
  if not entry then
    return nil
  end
  return entry.note
end

function lib:SetNote(name, note)
  LockActionButtons()
  -- Also lock down all other clients as well
  if not changes_pending then
    SendAddonMessage("EPGP", "CHANGES_PENDING", "GUILD")
  end
  state = "LOCAL_PENDING"

  local entry = cache[name]
  if not entry then
    return
  end
  -- We do not update the note here. We are going to wait until the
  -- next GUILD_ROSTER_UPDATE and fire a GuildNoteChanged callback.

  -- TODO(alkis): Investigate performance issues in case we want to
  -- verify if this is the right index or not.
  GuildRosterSetOfficerNote(entry.index, note)
end

function lib:GetClass(name)
  local entry = cache[name]
  if not entry then
    return
  end
  return entry.class
end

function lib:GetGuildInfo()
  return guild_info
end

function lib:ProtectActionButton(button)
  assert(button:IsObjectType("Button"), "Argument must be a Button")
  protected_buttons[button] = true
end

GuildRosterDelayed()
last_guildroster_time = GetTime()
frame:Hide()
