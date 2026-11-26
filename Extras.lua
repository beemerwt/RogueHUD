local _, RH = ...
if not RH.isRogue then return end

local spellNames = {}
local function Name(id)
  if spellNames[id] == nil then
    local info = RH.SpellInfo(id)
    spellNames[id] = info and not RH.IsSecret(info) and RH.Plain(info.name) or false
  end
  return spellNames[id] or nil
end

local function CastSound(when, id)
  if not RH.db or not RH.db.sounds.enabled or RH.IsSecret(id) or type(id) ~= "number" then return end
  local name = Name(id)
  if not name then return end
  for _, rule in ipairs(RH.db.sounds.rules or {}) do
    local extension = type(rule.path) == "string" and rule.path:match("%.(%w+)$")
    if rule.enabled and rule.when == when and type(rule.spell) == "number" and Name(rule.spell) == name
      and extension and ({ogg = true, wav = true, mp3 = true})[extension:lower()] then
      RH.Safe(PlaySoundFile, rule.path:gsub("/", "\\"), rule.channel or "Master")
    end
  end
end

RH.On("UNIT_SPELLCAST_SUCCEEDED", function(_, unit, _, id) if unit == "player" then CastSound("success", id) end end)
RH.On("UNIT_SPELLCAST_START", function(_, unit, _, id) if unit == "player" then CastSound("start", id) end end)
RH.On("UNIT_SPELLCAST_CHANNEL_START", function(_, unit, _, id) if unit == "player" then CastSound("start", id) end end)
RH.On("SPELLS_CHANGED", function() spellNames = {} end)

local registered = false
local function RegisterEllesmere()
  if registered or not RH.db or not RH.db.ellesmere.enabled then return end
  local eui = rawget(_G, "EllesmereUI")
  if type(eui) ~= "table" or type(eui.MakeUnlockElement) ~= "function"
    or type(eui.RegisterUnlockElements) ~= "function" then return end
  local element = RH.Safe(eui.MakeUnlockElement, {
    key = "RogueHUD_HUD", label = "RogueHUD", group = "RogueHUD", order = 1,
    noResize = true,
    getFrame = function() return RH.hud end,
    getSize = function() return RH.hud:GetWidth(), RH.hud:GetHeight() end,
    savePos = function(_, _, _, x, y)
      local scale = RH.hud:GetScale()
      RH.db.x, RH.db.y = (x or 0) / scale, (y or 0) / scale
    end,
    loadPos = function()
      local scale = RH.hud:GetScale()
      return {point = "CENTER", relPoint = "CENTER", x = RH.db.x * scale, y = RH.db.y * scale}
    end,
    clearPos = function() RH.db.x, RH.db.y = 0, -190 RH.Refresh() end,
    applyPos = function() RH.Refresh() end,
  })
  if element then registered = pcall(eui.RegisterUnlockElements, eui, {element}, RH.name) end
end

RH.On("PLAYER_LOGIN", RegisterEllesmere)
RH.On("ADDON_LOADED", function(_, name) if name == "EllesmereUI" then RegisterEllesmere() end end)
