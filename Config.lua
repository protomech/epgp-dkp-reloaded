local mod = EPGP:NewModule("EPGP_Config", "AceDB-2.0", "AceEvent-2.0")

mod:RegisterDB("EPGP_Config_DB")
mod:RegisterDefaults("profile", {
  data = { },
  detached_data = { },
})

local T = AceLibrary("Tablet-2.0")
local D = AceLibrary("Dewdrop-2.0")
local C = AceLibrary("Crayon-2.0")

local BC = AceLibrary("Babble-Class-2.2")

function mod:OnInitialize()
  self.cache = EPGP:GetModule("EPGP_Cache")
end

function mod:OnEnable()
  self:RegisterEvent("EPGP_CACHE_UPDATE")
  if not T:IsRegistered("EPGP_Config") then
    T:Register("EPGP_Config",
      "children", function()
        T:SetTitle("EPGP Config")
        self:OnTooltipUpdate()
      end,
      "data", self.db.profile.data,
      "detachedData", self.db.profile.detached_data,
      "showTitleWhenDetached", true,
      "showHintWhenDetached", true,
      "cantAttach", true
    )
  end
  if not T:IsAttached("EPGP_Config") then
    T:Open("EPGP_Config")
  end
end

function mod:OnDisable()
  T:Close("EPGP_Config")
end

function mod:EPGP_CACHE_UPDATE()
  self.alts = self:BuildAltsTable()
  self.outsiders = self:BuildOutsidersTable()
  T:Refresh("EPGP_Config")
end

function mod:BuildAltsTable()
  local t = {}
  for alt,main in pairs(self.cache.db.profile.alts) do
    if not t[main] then
      t[main] = {}
    end
    table.insert(t[main], alt)
  end
  return t
end

function mod:BuildOutsidersTable()
  local t = {}
  for outsider,dummy in pairs(self.cache.db.profile.outsiders) do
    t[outsider] = dummy
  end
  return t
end

function mod:Toggle()
  if T:IsAttached("EPGP_Config") then
    T:Detach("EPGP_Config")
    if (T:IsLocked("EPGP_Config")) then
      T:ToggleLocked("EPGP_Config")
    end
  else
    T:Attach("EPGP_Config")
  end
end

function mod:OnTooltipUpdate()
  if not self.alts then
    self.alts = self:BuildAltsTable()
  end
  if not self.outsiders then
    self.outsiders = self:BuildOutsidersTable()
  end

  local cat = T:AddCategory(
      "columns", 2,
      "text",  C:Red("Main"),   "child_textR",    1, "child_textG",    1, "child_textB",    1, "child_justify",  "LEFT",
      "text2", C:Red("Alts"),   "child_text2R",   1, "child_text2G",   1, "child_text2B",   1, "child_justify4", "RIGHT"
    )
  for main,alts in pairs(self.alts) do
    local alts_str
    for _,alt in pairs(alts) do
      local rank, rankIndex, level, class, zone, note, officernote, online, status = self.cache:GetMemberInfo(alt)
      if alts_str then
        alts_str = alts_str.." "..C:Colorize(BC:GetHexColor(class), alt)
      else
        alts_str = C:Colorize(BC:GetHexColor(class), alt)
      end
    end
    local rank, rankIndex, level, class, zone, note, officernote, online, status = self.cache:GetMemberInfo(main)
    if main and class then
      cat:AddLine(
        "text", C:Colorize(BC:GetHexColor(class), main),
        "text2", alts_str
        )
    end
  end

  local cat2 = T:AddCategory(
      "columns", 2,
      "text",  C:Red("Outsider"),   "child_textR",    1, "child_textG",    1, "child_textB",    1, "child_justify",  "LEFT",
      "text2", C:Red("Dummy"),   "child_text2R",   1, "child_text2G",   1, "child_text2B",   1, "child_justify4", "RIGHT"
    )
  for outsider,dummy in pairs(self.outsiders) do
    local rank, rankIndex, level, class, zone, note, officernote, online, status = self.cache:GetMemberInfo(dummy)
    local color = C.COLOR_HEX_SILVER
    if class then
      color = BC:GetHexColor(class)
    end
    cat2:AddLine(
      "text", C:Colorize(color, outsider),
      "text2", C:Colorize(color, dummy)
      )
  end
  local info = T:AddCategory("columns", 2)
  info:AddLine("text", C:Red("Min EPs"), "text2", C:Silver(self.cache.db.profile.min_eps))
  info:AddLine("text", C:Red("Decay"), "text2", C:Silver(self.cache.db.profile.decay_percent.."%"))
end
