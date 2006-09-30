-------------------------------------------------------------------------------
-- Constants for EP and GP
-------------------------------------------------------------------------------

EPGP:RegisterDefaults("char", {
  -- The Zones we keep track of in a map for easy lookup
  zones = {
    ["Zul'Gurub"]=true,
    ["Ruins of Ahn'Qiraj"]=true,
    ["Onyxia's Lair"]=true,
    ["Molten Core"]=true,
    ["Blackwing Lair"]=true,
    ["Temple of Ahn'Qiraj"]=true,
    ["Naxxramas"]=true
  },
  -- The bossses we keep track of in a map with EP values assigned
  bosses = {
  	-- ZG:
  	["High Priestess Jeklik"]=2,
  	["High Priest Venoxis"]=2,
  	["High Priestess Mar'li"]=2,
  	["High Priest Thekal"]=2,
  	["High Priestess Arlokk"]=2,
  	["Hakkar the Soulflayer"]=2,
  	["Bloodlord Mandokir"]=2,
  	["Jin'do the Hexxer"]=2,
  	["Gahz'ranka"]=2,
  	["Gri'lek"]=2,
  	["Renataki"]=2,
  	["Hazza'rah"]=2,
  	["Wushoolay"]=2,
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
  -- The event log, indexed by raid_id
  event_log = { ['*'] = nil },
  -- The raid info, indexed by raid_id
  raid_info = { ['*'] = nil }
})
