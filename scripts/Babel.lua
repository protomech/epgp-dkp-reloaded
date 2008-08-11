#!/usr/bin/env lua5.1

local strings = {}

if #arg < 2 then
  print("Usage: Babel.lua varname sourcefile ...\n"..
        "  varname - the variable name of the global table holding the translations\n"..
        "  sourcefile ... - the source files to scavenge for localized strings\n")
  return
end

-- The first arg is the global variable to use for the global table
local varname = arg[1]

-- Parse all the lua files given in the command line and extract
-- strings for localization.
for i = 2,#arg do
  local file = io.open(arg[i], "r")
  assert(file, "Could not open "..arg[i])
  print("Reading "..arg[i])
  local text = file:read("*all")

  for match in string.gmatch(text, "L%[\"(.-)\"%]") do
    strings[match] = true
  end
end

do
  local t = {}
  for k,v in pairs(strings) do
    table.insert(t, k)
  end
  strings = t
end
table.sort(strings)

local languages = {
  "enUS",
  "frFR",
  "deDE",
  "zhCN",
  "zhTW",
  "koKR",
  "esES",
  "ruRU",
}

local lang_tables = {}

-- Populate tables and merge in existing Localization files
for i,lang in pairs(languages) do
  if not lang_tables[lang] then
    lang_tables[lang] = {}
  end

  local lang_table = lang_tables[lang]

  for i,str in pairs(strings) do
    lang_table[str] = str
  end

  local filename = "Localization."..lang..".lua"
  local file = io.open(filename, "r")
  if file then
    print("Merging localizations from "..filename)
    function GetLocale() return lang end
    loadfile(filename)()
    for k,v in pairs(_G[varname]) do
      lang_table[k] = v
    end
  end
end

-- Output new localization files
for i,lang in pairs(languages) do
  local filename = "Localization."..lang..".lua"
  local file = io.open(filename, "w")
  assert(file, "Could not open "..filename.." for writing!")
  print("Writing localizations to "..filename)
  file:write("if GetLocale() ~= \""..lang.."\" then return end\n")
  file:write(varname.." = {\n")

  local lang_table = lang_tables[lang]
  for i,w in pairs(strings) do
    file:write("\t[\""..w.."\"] = \""..lang_table[w].."\",\n")
  end

  file:write("}\n")
end
