local strings = {}

if #arg < 2 then
  print("Usage: Babel.lua varname sourcefile ...\n"..
        "  varname - the variable name of the global table holding the translations\n"..
        "  sourcefile ... - the source files to scavenge for localized strings\n")
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
    table.insert(strings, match)
  end
end

local languages = {
  "enUS",
  "frFR",
  "deDE",
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
      if lang_table[k] then
        lang_table[k] = v
      end
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

  for k,v in pairs(lang_tables[lang]) do
    file:write("\t[\""..k.."\"] = \""..v.."\",\n")
  end

  file:write("}\n")
end
