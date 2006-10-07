-------------------------------------------------------------------------------
-- Syncing code
-------------------------------------------------------------------------------

EPGP.comm_handlers = { }

function EPGP:RegisterComms()
  self:SetCommPrefix("EPGP")
  self:RegisterComm("EPGP", "WHISPER")
  self:RegisterComm("EPGP", "GUILD")
  self:RegisterMemoizations({
    "EVENTLOG_VERSION_QUERY",
    "EVENTLOG_VERSION_REPLY",
    "EVENTLOG_REQUEST",
    "EVENTLOG_UPDATE"
  })
  self:RegisterEvent("PLAYER_LOGIN")
  -- Register event to ask versions on login
end

function EPGP:PLAYER_LOGIN()
  EPGP:EventLogVersionQuery()
end

function EPGP:EventLogVersionQuery()
  self:SendCommMessage("GUILD", "EVENTLOG_VERSION_QUERY")
end

function EPGP:OnCommReceive(prefix, sender, distribution,
                            a1, a2, a3, a4, a5, a6, a7, a8, a9, a10)
  self:Debug("Message on %s with prefix: %s type: %s from: %s",
             distribution, prefix, a1, sender)
  if (prefix ~= "EPGP") then
    self:Debug("Ignoring msg")
    return
  end
  if (type(a1) == "string" and self.comm_handlers[a1]) then
    self:Debug("Calling handler")
    self.comm_handlers[a1](self, sender, a2, a3, a4, a5, a6, a7, a8, a9, a10)
  else
    self:Debug("Did not find handler")
  end
end

function EPGP.comm_handlers:EVENTLOG_VERSION_QUERY(sender)
  local last_raidid = self:GetLastRaidId()
  local last_entry = table.getn(self:GetOrCreateEventLog(last_raidid))
  self:Debug("Sending last version stamp to %s", sender)
  self:SendCommMessage("WHISPER", sender,
                       "EVENTLOG_VERSION_REPLY", last_raidid, last_entry)
end

function EPGP.comm_handlers:EVENTLOG_VERSION_REPLY(sender, remote_last_raidid, remote_last_entry)
  local local_last_raidid = self:GetLastRaidId()
  local local_last_entry = table.getn(self:GetOrCreateEventLog(local_last_raidid))
  if (not target_raidid and
      remote_last_raidid > local_last_raidid or
      (remote_last_raidid == local_last_raidid and
       remote_last_entry > local_last_entry)) then
    self.target_raidid = remote_last_raidid
    self:Print("Requesting syncing from %s", sender)
    self:Debug("Syncing from %d to %d", local_last_raidid, self.target_raidid)
    self:SendCommMessage("WHISPER", sender,
                         "EVENTLOG_REQUEST", local_last_raidid, self.target_raidid)
  else
    self:Debug("Already synced to last version")
  end
end

function EPGP.comm_handlers:EVENTLOG_REQUEST(sender, start_raidid, end_raidid)
  self:Debug("Sending updates to %s for %d,%d", sender, start_raidid, end_raidid)
  for i = start_raidid, end_raidid do
    local event_log = self:GetOrCreateEventLog(i)
    self:SendCommMessage("WHISPER", sender,
                         "EVENTLOG_UPDATE", i, event_log)
  end
end

function EPGP.comm_handlers:EVENTLOG_UPDATE(sender, raidid, event_log)
  self:Debug("Recieved update from %s for %d", sender, raidid)
  self:SetEventLog(raidid, event_log)
  if (self.target_raidid == raidid) then
    self.target_raidid = nil
    self:EventLogVersionQuery()
  end
end
