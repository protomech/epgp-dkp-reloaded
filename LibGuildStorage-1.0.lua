-- This library handles storing information in officer notes. It
-- streamlines and optimizes access to these notes. It should be noted
-- that the library does not have correct information until
-- PLAYER_ENTERING_WORLD is fired (for Ace authors this is after OnInitialize
-- is called). The API is as follows:
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
-- IsCurrentState(): Return true if the state of the library is current.
--
-- Snapshot(table): Write out snapshot in the table
-- provided. table.guild_info will contain the epgp clause in guild
-- info and table.notes a table of {name, class, note}.
--
-- Rollback(table): Given the table filled in by Snapshot, rollback
-- the state of the officer notes and guild info to that.
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
--
-- StateChanged(): Fired when the state of the guild storage cache has
-- changed.
--
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
frame:Hide()
-- Possible states: STALE, LOCAL_PENDING, REMOTE_PENDING,
-- REMOTE_FLUSHED, CURRENT
local state = "STALE"
local initialized = false

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
  -- Sometimes GetNumGuildMembers returns 0. In this case return so
  -- that we call it again and get a proper value.
  if GetNumGuildMembers(true) == 0 then return end

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
      -- Mark the entry so that we know we should keep it.
      t.marked = true
      t.index = i
      t.class = class
      if t.note ~= note then
        t.note = note
        -- We want to delay all GuildNoteChanged calls until we have a
        -- complete view of the guild, otherwise alts might not be
        -- rejected (we read alts note before we even know about the
        -- main).
        if initialized then
          callbacks:Fire("GuildNoteChanged", name, note)
        end
      end
    end
  end
  next_index = e + 1
  if next_index > GetNumGuildMembers(true) then
    -- We are done, we need to clear the marks and delete the unmarked
    -- entries. We also fire events for removed members now.
    for name, t in pairs(cache) do
      if t.marked then
        t.marked = nil
      else
        cache[name] = nil
        callbacks:Fire("GuildNoteDeleted", name)
      end
    end

    frame:Hide()
    if not initialized then
      initialized = true
      -- Now make all GuildNoteChanged calls because we have a full
      -- state.
      for name, t in pairs(cache) do
        callbacks:Fire("GuildNoteChanged", name, t.note)
      end
    end
    if state == "STALE" then
      state = "CURRENT"
      callbacks:Fire("StateChanged")
    elseif state == "LOCAL_PENDING" then
      state = "CURRENT"
      callbacks:Fire("StateChanged")
      SendAddonMessage("EPGP", "CHANGES_FLUSHED", "GUILD")
    elseif state == "REMOTE_FLUSHED" then
      state = "CURRENT"
      callbacks:Fire("StateChanged")
    end      
  end
end

frame:SetScript("OnUpdate", UpdateGuildRoster)

frame:RegisterEvent("PLAYER_GUILD_UPDATE")
frame:RegisterEvent("GUILD_ROSTER_UPDATE")
frame:RegisterEvent("CHAT_MSG_ADDON")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")

function lib:CHAT_MSG_ADDON(prefix, msg, type, sender)
  if prefix == "EPGP" and sender ~= UnitName("player") then
    if msg == "CHANGES_PENDING" then
      state = "REMOTE_PENDING"
      callbacks:Fire("StateChanged")
    elseif msg == "CHANGES_FLUSHED" then
      state = "REMOTE_FLUSHED"
      callbacks:Fire("StateChanged")
      guildroster_timer = timers:ScheduleTimer(GuildRoster, 10)
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
  local entry = cache[name]
  if not entry then
    return
  end

  -- Also lock down all other clients as well
  if state == "CURRENT" then
    state = "LOCAL_PENDING"
    callbacks:Fire("StateChanged")
    SendAddonMessage("EPGP", "CHANGES_PENDING", "GUILD")
  end

  -- We do not update the note here. We are going to wait until the
  -- next GUILD_ROSTER_UPDATE and fire a GuildNoteChanged callback.

  if select(1, GetGuildRosterInfo(entry.index)) ~= name then
    DEFAULT_CHAT_FRAME:AddMessage(
      string.format("Failed to change %s's note to %s. Please report "..
                    "this at http://epgp.googlecode.com", name, note))
  else
    GuildRosterSetOfficerNote(entry.index, note)
  end
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

function lib:IsCurrentState()
  return state == "CURRENT"
end

function lib:Snapshot(t)
  assert(type(t) == "table")
  t.guild_info = guild_info:match("%-EPGP%-\n(.*)\n\%-EPGP%-")
  t.roster_info = {}
  for name,info in pairs(cache) do
    table.insert(t.roster_info, {name, info.class, info.note})
  end
end

function lib:Rollback(t)
  assert(type(t) == "table")
  SetGuildInfoText(guild_info:gsub("%-EPGP%-\n.*\n\%-EPGP%-",
                                   "-EPGP-\n"..t.guild_info.."\n-EPGP-"))
  for _,i in pairs(t.roster_info) do
    lib:SetNote(i[1], i[3])
  end
  GuildRosterDelayed()
end

function lib:PLAYER_ENTERING_WORLD()
  frame:Hide()
  GuildRosterDelayed()
  last_guildroster_time = GetTime()
end
