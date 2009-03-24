--[[
  EPGP Lootmaster module - UI Stuff
]]--

local mod = EPGP:NewModule("lootmaster_ui", "AceEvent-3.0", "AceComm-3.0", "AceTimer-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("EPGP")
local GS = LibStub("LibGuildStorage-1.0")
local gptooltip = EPGP:GetModule("gptooltip")
local lootmaster = EPGP:GetModule("lootmaster")
local callbacks = EPGP.callbacks

local CURRENT_VERSION = GetAddOnMetadata('EPGP', 'Version')
if not CURRENT_VERSION or #CURRENT_VERSION == 0 then
  CURRENT_VERSION = "(dev)"
end

