local addonName, RH = ...
RH.name = addonName
RH.version = "0.1.0"
RH.isRogue = select(2, UnitClass("player")) == "ROGUE"
if not RH.isRogue then return end

RH.defaults = {
  styleVersion = 2,
  enabled = true,
  locked = true,
  x = 0, y = -190, width = 240, scale = 1,
  theme = "default", alpha = 1, stackGap = 2,
  style = {
    barTexture = "smooth", font = "Inter SemiBold", fontSize = 12, fontOutline = "OUTLINE",
    borderSize = 1, borderColor = {0, 0, 0, 1}, backdropColor = {0.06, 0.05, 0.05, 0.8},
    iconZoom = 0.08, iconShape = "square", iconOverlay = "none",
    ownIconBorder = false, iconBorderSize = 1, iconBorderColor = {0, 0, 0, 1},
    swipeAlpha = 0.7, shadow = false,
  },
  colors = {
    energy = {0.95, 0.72, 0.15, 1}, health = {0.23, 0.75, 0.35, 1},
    combo1 = {1, 0.83, 0.19, 1}, combo2 = {1, 0.74, 0.19, 1},
    combo3 = {1, 0.65, 0.19, 1}, combo4 = {1, 0.56, 0.19, 1},
    combo5 = {1, 0.47, 0.19, 1},
    swingMain = {0.96, 0.58, 0.16, 1}, swingOff = {0.46, 0.62, 0.91, 1},
    text = {1, 1, 1, 1}, accent = {1, 0.61, 0.12, 1},
  },
  darkColors = {
    energy = {0.55, 0.55, 0.55, 1}, health = {0.23, 0.75, 0.35, 1},
    combo1 = {1, 0.83, 0.19, 1}, combo2 = {1, 0.74, 0.19, 1},
    combo3 = {1, 0.65, 0.19, 1}, combo4 = {1, 0.56, 0.19, 1},
    combo5 = {1, 0.47, 0.19, 1},
    swingMain = {0.96, 0.58, 0.16, 1}, swingOff = {0.46, 0.62, 0.91, 1},
    text = {1, 1, 1, 1}, accent = {0.83, 0.83, 0.83, 1},
  },
  barOrder = {"essential", "combo", "health", "energy", "swing", "utility"},
  energy = {enabled = true, height = 18, text = true, fontSize = 12},
  combo = {enabled = true, height = 9, gap = 2},
  health = {enabled = false, height = 8, text = true, mode = "percent", fontSize = 12},
  swing = {enabled = true, height = 3},
  gcd = {enabled = true, color = {0.35, 0.9, 1, 1}},
  cast = {
    enabled = true, side = "BELOW", offset = 10, height = 26,
    color = {1, 0.96078431372549, 0.41176470588235, 1},
    texture = "details", fontSize = 12, textAlign = "CENTER", textOffset = 10,
    icon = true, iconSize = 26, iconZoom = 0.3, iconGap = 2, latency = true,
  },
  poison = {
    enabled = true, size = 28, gap = 2, side = "LEFT", x = 0, y = 0,
    showWeapon = true, order = {"instant", "deadly", "crippling", "wound", "mind"},
    visible = {instant = true, deadly = true, crippling = true, wound = true, mind = true},
  },
  cooldown = {
    essentialSize = 36, essentialGap = 2, utilitySize = 28, utilityGap = 2,
    essential = true, utility = true,
    showSwipe = true, showNumbers = true, desaturate = true,
    dimUnusable = true, outOfRange = true, hideReady = false,
    readyAlpha = 1, cooldownAlpha = 1,
    source = "game", hidden = {}, extraEssential = {}, extraUtility = {}, customEssential = {}, customUtility = {},
  },
  hints = {enabled = true, slice = true, rupture = true, energy = true, sliceExpiry = 5, ruptureExpiry = 5},
  sounds = {enabled = false, rules = {}},
  ellesmere = {enabled = true},
  profile = "Default",
}

local function Copy(value)
  if type(value) ~= "table" then return value end
  local result = {}
  for key, child in pairs(value) do result[key] = Copy(child) end
  return result
end
RH.Copy = Copy

local function Fill(tableValue, defaults)
  for key, value in pairs(defaults) do
    if tableValue[key] == nil then tableValue[key] = Copy(value)
    elseif type(value) == "table" and type(tableValue[key]) == "table" then Fill(tableValue[key], value) end
  end
end
RH.Fill = Fill

function RH.MigrateStyle(db)
  if type(db) ~= "table" then return end
  if type(db.hints) == "table" and db.hints.expiry ~= nil then
    if db.hints.sliceExpiry == nil then db.hints.sliceExpiry = db.hints.expiry end
    if db.hints.ruptureExpiry == nil then db.hints.ruptureExpiry = db.hints.expiry end
    db.hints.expiry = nil
  end
  local version = tonumber(db.styleVersion) or 0
  if version < 1 then
    db.width, db.alpha, db.stackGap = 240, 1, 2
    db.style = Copy(RH.defaults.style)
    db.colors = Copy(RH.defaults.colors)
    db.darkColors = Copy(RH.defaults.darkColors)
    for key, values in pairs({
      energy = {height = 18, fontSize = 12}, combo = {height = 9, gap = 2},
      health = {height = 8, fontSize = 12}, swing = {height = 3},
      poison = {size = 28, gap = 2},
    }) do
      db[key] = type(db[key]) == "table" and db[key] or {}
      for field, value in pairs(values) do db[key][field] = value end
    end
    db.cooldown = type(db.cooldown) == "table" and db.cooldown or {}
    db.cooldown.size, db.cooldown.gap = nil, nil
    db.cooldown.essentialSize, db.cooldown.essentialGap = 36, 2
    db.cooldown.utilitySize, db.cooldown.utilityGap = 28, 2
  end
  if version < 2 then
    db.style = type(db.style) == "table" and db.style or {}
    db.style.font = "Inter SemiBold"
    db.health = type(db.health) == "table" and db.health or {}
    db.health.mode = "percent"
  end
  db.styleVersion = 2
end

function RH.MigrateCast(db)
  if type(db) ~= "table" then return end
  db.cast = type(db.cast) == "table" and db.cast or {}
  if db.cast.side == nil then
    local enabled = db.cast.enabled
    db.cast = Copy(RH.defaults.cast)
    if enabled ~= nil then db.cast.enabled = enabled end
  end
  db.cast.mode = nil
end

function RH.MigrateTheme(db)
  if type(db) == "table" and db.theme == "rogue" then db.theme = "default" end
end

function RH.NormalizeBarOrder(db)
  db.stealth = nil
  local normalized, seen = {}, {}
  if type(db.barOrder) == "table" then
    for _, key in ipairs(db.barOrder) do
      for _, allowed in ipairs(RH.defaults.barOrder) do
        if key == allowed and not seen[key] then
          normalized[#normalized + 1] = key
          seen[key] = true
          break
        end
      end
    end
  end
  for _, key in ipairs(RH.defaults.barOrder) do
    if not seen[key] then normalized[#normalized + 1] = key end
  end
  db.barOrder = normalized
end

function RH.IsSecret(value)
  return issecretvalue and issecretvalue(value) or false
end

function RH.Plain(value)
  if RH.IsSecret(value) then return nil end
  return value
end

function RH.Safe(fn, ...)
  if type(fn) ~= "function" then return nil end
  local ok, a, b, c, d, e, f, g, h = pcall(fn, ...)
  if ok then return a, b, c, d, e, f, g, h end
  return nil
end

local reported = {}
local function Run(label, fn, ...)
  local ok, err = pcall(fn, ...)
  if not ok then
    RH.lastError = label .. ": " .. tostring(err)
    if not reported[label] then
      reported[label] = true
      RH.Message(RH.lastError)
    end
  end
end

local function SpellInfo(id)
  if C_Spell and C_Spell.GetSpellInfo then return RH.Safe(C_Spell.GetSpellInfo, id) end
  if GetSpellInfo then
    local name, _, icon = RH.Safe(GetSpellInfo, id)
    return name and {name = name, iconID = icon, spellID = id} or nil
  end
end
RH.SpellInfo = SpellInfo

function RH.Knows(id)
  if IsPlayerSpell and RH.Plain(RH.Safe(IsPlayerSpell, id)) == true then return true end
  if IsSpellKnown and RH.Plain(RH.Safe(IsSpellKnown, id)) == true then return true end
  if C_SpellBook and C_SpellBook.IsSpellKnown then
    local playerBank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player
    if RH.Plain(RH.Safe(C_SpellBook.IsSpellKnown, id, playerBank)) == true then return true end
  end
  return false
end

function RH.KnownRank(ids)
  if type(ids) == "number" then ids = {ids} end
  if type(ids) ~= "table" then return nil end
  for i = #ids, 1, -1 do if RH.Knows(ids[i]) then return ids[i] end end
  return nil
end

function RH.SpellIcon(id)
  local info = SpellInfo(id)
  if info and not RH.IsSecret(info) then return RH.Plain(info.iconID or info.icon) end
  if C_Spell and C_Spell.GetSpellTexture then return RH.Plain(RH.Safe(C_Spell.GetSpellTexture, id)) end
end

function RH.ItemIcon(id)
  if C_Item and C_Item.GetItemIconByID then return RH.Plain(RH.Safe(C_Item.GetItemIconByID, id)) end
  if GetItemIcon then return RH.Plain(RH.Safe(GetItemIcon, id)) end
end

function RH.ItemCount(id)
  if C_Item and C_Item.GetItemCount then
    local n = RH.Plain(RH.Safe(C_Item.GetItemCount, id, false, false))
    if type(n) == "number" then return n end
  end
  if GetItemCount then
    local n = RH.Plain(RH.Safe(GetItemCount, id, false, false))
    if type(n) == "number" then return n end
  end
  return 0
end

function RH.Message(value)
  if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cffffc040RogueHUD|r: " .. tostring(value)) end
end

local listeners = {}
function RH.On(event, fn)
  if not listeners[event] then
    listeners[event] = {}
    if not pcall(RH.events.RegisterEvent, RH.events, event) then return false end
  end
  table.insert(listeners[event], fn)
  return true
end

local refreshers = {}
function RH.AddRefresh(fn) table.insert(refreshers, fn) end
function RH.Refresh()
  if not RH.db then return end
  for index, fn in ipairs(refreshers) do Run("refresh " .. index, fn) end
end

RH.events = CreateFrame("Frame")
RH.events:SetScript("OnEvent", function(_, event, ...)
  if event == "PLAYER_LOGIN" then
    RogueHUDDB = type(RogueHUDDB) == "table" and RogueHUDDB or {}
    RogueHUDCharacterDB = type(RogueHUDCharacterDB) == "table" and RogueHUDCharacterDB or {}
    RH.characterDB = RogueHUDCharacterDB
    local build = GetBuildInfo and select(2, GetBuildInfo())
    if build and RogueHUDDB.enchantBuild ~= build then
      RogueHUDDB.enchants = {}
      RogueHUDDB.enchantBuild = build
    end
    RogueHUDDB.profiles = type(RogueHUDDB.profiles) == "table" and RogueHUDDB.profiles or {}
    for _, profile in pairs(RogueHUDDB.profiles) do
      RH.MigrateStyle(profile)
      RH.MigrateCast(profile)
      RH.MigrateTheme(profile)
    end
    local active = RogueHUDDB.active or "Default"
    RogueHUDDB.active = active
    if type(RogueHUDDB.profiles[active]) ~= "table" then RogueHUDDB.profiles[active] = Copy(RH.defaults) end
    RH.db = RogueHUDDB.profiles[active]
    Fill(RH.db, RH.defaults)
    RH.NormalizeBarOrder(RH.db)
    RH.db.profile = active
  end
  local list = listeners[event]
  if list then for index, fn in ipairs(list) do Run(event .. " " .. index, fn, event, ...) end end
  if event == "PLAYER_LOGIN" then RH.Refresh() end
end)
RH.events:RegisterEvent("PLAYER_LOGIN")
