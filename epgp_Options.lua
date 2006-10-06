-------------------------------------------------------------------------------
-- Constants for EP and GP
-------------------------------------------------------------------------------
EPGP:RegisterDefaults("profile", {
  -- The Zones we keep track of along with the respective GP multipliers
  zones = {
    ["Zul'Gurub"]=1,
    ["Ruins of Ahn'Qiraj"]=1,
    ["Onyxia's Lair"]=1.5,
    ["Molten Core"]=1,
    ["Blackwing Lair"]=1.5,
    ["Temple of Ahn'Qiraj"]=2,
    ["Naxxramas"]=2
  },
  -- The bossses we keep track of in a map with EP values assigned
  bosses = {
  	-- ZG:
  	["High Priestess Jeklik"]=20,
  	["High Priest Venoxis"]=20,
  	["High Priestess Mar'li"]=20,
  	["High Priest Thekal"]=50,
  	["High Priestess Arlokk"]=50,
  	["Hakkar the Soulflayer"]=100,
  	["Bloodlord Mandokir"]=50,
  	["Jin'do the Hexxer"]=80,
  	["Gahz'ranka"]=50,
  	["Gri'lek"]=30,
  	["Renataki"]=30,
  	["Hazza'rah"]=30,
  	["Wushoolay"]=30,
  	-- Onyxia:
  	["Onyxia"]=10,
  	-- AQ 20:
  	["Kurinnaxx"]=2,
  	["General Rajaxx"]=2,
  	["Moam"]=2,
  	["Buru the Gorger"]=2,
  	["Ayamiss the Hunter"]=2,
  	["Ossirian the Unscarred"]=2,
  	-- MC:
  	["Lucifron"]=2,
  	["Magmadar"]=2,
  	["Gehennas"]=2,
  	["Garr"]=2,
  	["Baron Geddon"]=2,
  	["Shazzrah"]=2,
  	["Golemagg The Incinerator"]=5,
  	["Sulfuron Harbinger"]=5,
  	["Majordomo Executus"]=10,
  	["Ragnaros"]=20,
  	-- BWL:
  	["Razorgore the Untamed"]=5,
  	["Vaelastrasz the Corrupt"]=5,
  	["Broodlord Lashlayer"]=5,
  	["Firemaw"]=5,
  	["Ebonroc"]=5,
  	["Flamegor"]=5,
  	["Chromaggus"]=10,
  	["Nefarian"]=30,
  	-- AQ40:
  	["The Prophet Skeram"]=10,
  	["Vem"]=10,
  	["Yauj"]=10,
  	["Kri"]=10,
  	["Battleguard Sartura"]=10,
  	["Fankriss the Unyielding"]=10,
  	["Viscidus"]=10,
  	["Princess Huhuran"]=10,
  	["Emperor Vek'lor"]=10,
  	["Emperor Vek'nilash"]=10,
  	["Ouro the Sandworm"]=10,
  	["C'Thun"]=30,
  	-- Naxx:
  	["Anub'Rekhan"]=10,
  	["Grand Widow Faerlina"]=10,
  	["Maexxna"]=10,
  	["Patchwerk"]=10,
  	["Grobbulus"]=10,
  	["Gluth"]=10,
  	["Thaddius"]=10,
  	["Feugen"]=10,
  	["Stalagg"]=10,
  	["Noth The Plaguebringer"]=10,
  	["Heigan the Unclean"]=10,
  	["Loatheb"]=10,
  	["Instructor Razuvious"]=10,
  	["Gothik the Harvester"]=10,
  	["Highlord Mograine"]=10,
  	["Thane Korthazz"]=10,
  	["Lady Blaumeux"]=10,
  	["Sir Zeliek"]=10,
  	["Sapphiron"]=10,
  	["Kel'Thuzad"]=10
  },
  -- The table of equip slots with the GP multiplier
  equip_slot = {
    ["INVTYPE_HEAD"] = 1.0,
    ["INVTYPE_CHEST"] = 1.0,
    ["INVTYPE_ROBE"] = 1.0,
    ["INVTYPE_LEGS"] = 1.0,
    ["INVTYPE_2HWEAPON"] = 1.0,
    ["INVTYPE_SHOULDER"] = 0.8,
    ["INVTYPE_HANDS"] = 0.8,
    ["INVTYPE_FEET"] = 0.8,
    ["INVTYPE_FINGER"] = 0.6,
    ["INVTYPE_TRINKET"] = 0.6,
    ["INVTYPE_CLOAK"] = 0.6,
    ["INVTYPE_WEAPON"] = 0.6,
    ["INVTYPE_SHIELD"] = 0.6,
    ["INVTYPE_WEAPONMAINHAND"] = 0.6,
    ["INVTYPE_WEAPONOFFHAND"] = 0.6,
    ["INVTYPE_HOLDABLE"] = 0.6,
    ["INVTYPE_RANGED"] = 0.6,
    ["INVTYPE_RANGEDRIGHT"] = 0.6
  },
  base_item_value = 100,
  -- The table of item qualities along with the GP multipliers
  -- Poor, Common, Uncommon, Rare, Epic, Legendary, Artifact
  quality = {
    [0] = 0.0,
    [1] = 0.0,
    [2] = 0.25,
    [3] = 0.5,
    [4] = 1.0,
    [5] = 2.0,
    [6] = 3.0
  },
  -- The raid_window size on which we count EPs and GPs.
  -- Anything out of the window will not be taken into account.
  raid_window_size = 10,
  -- The event log, indexed by raid_id
  event_log = { ['*'] = nil }
})

EPGP_quality_names = {
  [0] = "Poor",
  [1] = "Common",
  [2] = "Uncommon",
  [3] = "Rare",
  [4] = "Epic",
  [5] = "Legendary",
  [6] = "Artifact"
}

local Tablet = AceLibrary("Tablet-2.0")
local Dewdrop = AceLibrary("Dewdrop-2.0")

function EPGP:GetItemGP(item_info, zone)
  local name, _, quality, _, _, _, _, equip_slot = unpack(item_info)
  local quality_mult = self.db.profile.quality[quality]
  local equip_slot_mult = self.db.profile.equip_slot[equip_slot] or 0.0
  local value = self.db.profile.base_item_value * quality_mult * equip_slot_mult
  self:Debug("%s accounted for %d GP", name, value)
  return value
end

function EPGP:GetBossEP(boss)
  local value = self.db.profile.bosses[boss]
  if (not value and self:IsDebugging()) then
    value = 1
  end
  self:Debug("%s accounted for %d EP", boss, value)
  return value
end

function EPGP:SetBossEP(boss, ep)
  local value = self.db.profile.bosses[boss]
  if (value) then
    self.db.profile.bosses[boss] = ep
  end
end

function EPGP:OnTooltipUpdate()
  -- A refresh button
  Tablet:AddCategory():AddLine(
    "text", "Refresh",
    "func", function() EPGP:UpdateData() end
  )
  -- The standings
  local cat = Tablet:AddCategory(
      'text', "Standings",
      'columns', 4,
      'child_textR' , 1, 'child_textG' , 1, 'child_textB' , 0,
      'child_textR2', 1, 'child_textG2', 1, 'child_textB2', 1,
      'child_textR3', 1, 'child_textG3', 1, 'child_textB3', 1,
      'child_textR4', 0, 'child_textG4', 1, 'child_textB4', 0
  )
  cat:AddLine(
    "text", "Name",
    "text2", "EP",
    "text3", "GP",
    "text4", "PR"
  )
  
  table.foreach(self.standings, function(_, stats)
      cat:AddLine(
        "text", stats[1],
        "text2", string.format("%.1f", stats[2]),
        "text3", string.format("%.1f", stats[3]),
        "text4", string.format("%.1f", stats[4])    
      )
    end
  )
end

function EPGP:OnDataUpdate()
  self.standings = self:ComputeStandings()
end
