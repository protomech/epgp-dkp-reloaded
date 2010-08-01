-- A library to make usage of coroutines in wow easier.

local MAJOR_VERSION = "LibCoroutine-1.0"
local MINOR_VERSION = tonumber(("$Revision: 1023 $"):match("%d+")) or 0

local lib, oldMinor = LibStub:NewLibrary(MAJOR_VERSION, MINOR_VERSION)
if not lib then return end

local AT = LibStub("AceTimer-3.0")

local function running_co_checked()
  local co = coroutine.running()
  assert(co, "Sleep should be called inside a coroutine not the main thread")
  return co
end

function lib:Create(fn)
  return coroutine.create(fn)
end

function lib:Yield(...)
  return self:Sleep(0, ...)
end

local function runner(args)
  local ok, err = coroutine.resume(args[1], unpack(args, 2))
  if not ok then
    error(err)
  end
end

function lib:Sleep(t, ...)
  local co = running_co_checked()
  AT:ScheduleTimer(runner, t, {co, ...})
  return coroutine.yield(co)
end

function lib:RunAsync(fn, ...)
  local co = self:Create(fn)
  AT:ScheduleTimer(runner, 0, {co, ...})
end
