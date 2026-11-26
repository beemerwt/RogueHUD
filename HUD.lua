local _, RH = ...
if not RH.isRogue then return end

local function Color(kind)
  if kind == "accent" and RH.db and RH.db.ellesmere.enabled then
    local eui = rawget(_G, "EllesmereUI")
    if type(eui) == "table" and type(eui.GetAccentColor) == "function" then
      local r, g, b = RH.Safe(eui.GetAccentColor)
      if type(r) == "number" and type(g) == "number" and type(b) == "number" then return r, g, b end
    end
  end
  local palette = RH.db and (RH.db.theme == "dark" and RH.db.darkColors or RH.db.colors)
  local c = palette and palette[kind]
  if c then return c[1], c[2], c[3], c[4] end
  return 0.16, 0.16, 0.19
end
RH.Color = Color

local WHITE = "Interface\\Buttons\\WHITE8X8"
function RH.NewText(parent, size, layer)
  local fs = parent:CreateFontString(nil, layer or "OVERLAY", "GameFontNormal")
  fs:SetFont(STANDARD_TEXT_FONT, size or 12, "OUTLINE")
  fs:SetTextColor(1, 1, 1)
  return fs
end

function RH.NewIcon(parent, size)
  local frame = CreateFrame("Frame", nil, parent)
  frame:SetSize(size, size)
  RH.Style.CreateIcon(frame)
  RH.Style.ApplyIcon(frame)
  return frame
end

local function Bar(parent, colorKind)
  local frame = CreateFrame("StatusBar", nil, parent)
  RH.Style.CreatePanel(frame)
  RH.Style.ApplyBar(frame)
  frame:SetStatusBarColor(Color(colorKind))
  frame:SetMinMaxValues(0, 100)
  return frame
end

local hud, energy, health, combo, swingMain, swingOff, gcd
local energyText, healthText, healthPercentText
local energyMarks = {}
local gcdEdges = {}
local gcdSpark
local swingStart = {main = 0, off = 0}
local swingDuration = {main = nil, off = nil}
local gcdStart, gcdDuration, gcdEnd, gcdNamedAt, gcdEstimated = nil, nil, 0, 0, false

local function StopGCD()
  gcd:SetScript("OnUpdate", nil)
  gcd:Hide()
  for _, edge in ipairs(gcdEdges) do edge:Hide() end
  gcdSpark:Hide()
  gcdStart, gcdDuration, gcdEnd, gcdEstimated = nil, nil, 0, false
end

local function DrawGCD(progress)
  local width, height = energy:GetWidth(), energy:GetHeight()
  local pixel = RH.Style.Pixel(energy)
  local thickness = (RH.db.style.borderSize or 0) * pixel
  if thickness <= 0 or width <= 0 or height <= 0 then
    for _, edge in ipairs(gcdEdges) do edge:Hide() end
    gcdSpark:Hide()
    return
  end
  local color = RH.db.gcd.color
  local distance = math.max(0, math.min(1, progress)) * 2 * (width + height)
  local remaining = distance
  for index, edge in ipairs(gcdEdges) do
    local span = (index == 1 or index == 3) and width or height
    local covered = math.min(span, remaining)
    remaining = math.max(0, remaining - span)
    if covered <= 0 then
      edge:Hide()
    else
      edge:ClearAllPoints()
      if index == 1 then
        edge:SetPoint("TOPLEFT", gcd, "TOPLEFT")
        edge:SetSize(covered, thickness)
      elseif index == 2 then
        edge:SetPoint("TOPRIGHT", gcd, "TOPRIGHT")
        edge:SetSize(thickness, covered)
      elseif index == 3 then
        edge:SetPoint("BOTTOMRIGHT", gcd, "BOTTOMRIGHT")
        edge:SetSize(covered, thickness)
      else
        edge:SetPoint("BOTTOMLEFT", gcd, "BOTTOMLEFT")
        edge:SetSize(thickness, covered)
      end
      edge:SetVertexColor(color[1], color[2], color[3], color[4] or 1)
      edge:Show()
    end
  end
  local half = thickness / 2
  local innerWidth, innerHeight = math.max(0, width - thickness), math.max(0, height - thickness)
  gcdSpark:ClearAllPoints()
  if distance <= width then
    gcdSpark:SetPoint("CENTER", gcd, "TOPLEFT", half + distance / width * innerWidth, -half)
  elseif distance <= width + height then
    gcdSpark:SetPoint("CENTER", gcd, "TOPRIGHT", -half, -half - (distance - width) / height * innerHeight)
  elseif distance <= 2 * width + height then
    gcdSpark:SetPoint("CENTER", gcd, "BOTTOMRIGHT", -half - (distance - width - height) / width * innerWidth, half)
  else
    gcdSpark:SetPoint("CENTER", gcd, "BOTTOMLEFT", half, half + (distance - 2 * width - height) / height * innerHeight)
  end
  local size = math.max(5 * pixel, 5 * thickness)
  gcdSpark:SetSize(size, size)
  gcdSpark:SetVertexColor(color[1], color[2], color[3], color[4] or 1)
  gcdSpark:Show()
end

local function Build()
  hud = CreateFrame("Frame", "RogueHUDFrame", UIParent)
  hud:SetSize(240, 72)
  hud:SetPoint("CENTER", UIParent, "CENTER", 0, -190)
  hud:SetFrameStrata("MEDIUM")
  hud:SetMovable(true)
  hud:EnableMouse(true)
  hud:RegisterForDrag("LeftButton")
  hud:SetScript("OnDragStart", function(self)
    if RH.db and not RH.db.locked and not InCombatLockdown() then self:StartMoving() end
  end)
  hud:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    if RH.db then
      local x, y = self:GetCenter()
      local px, py = UIParent:GetCenter()
      RH.db.x, RH.db.y = (x - px) / self:GetScale(), (y - py) / self:GetScale()
    end
  end)
  RH.hud = hud

  energy = Bar(hud, "energy")
  local energyOverlay = CreateFrame("Frame", nil, energy)
  energyOverlay:SetAllPoints(energy)
  energyOverlay:SetFrameLevel(energy:GetFrameLevel() + 8)
  energyText = RH.NewText(energyOverlay, 12)
  energyText:SetPoint("CENTER")
  RH.energyBar = energy
  RH.energyText = energyText
  for _, key in ipairs({"eviscerate", "rupture"}) do
    local mark = energy:CreateTexture(nil, "OVERLAY")
    mark:SetTexture(WHITE)
    mark:SetVertexColor(key == "rupture" and 0.95 or 0.25, key == "rupture" and 0.24 or 0.75, 0.2)
    mark:SetSize(2, 18)
    energyMarks[key] = mark
  end

  health = Bar(hud, "health")
  local healthOverlay = CreateFrame("Frame", nil, health)
  healthOverlay:SetAllPoints(health)
  healthOverlay:SetFrameLevel(health:GetFrameLevel() + 8)
  healthText = RH.NewText(healthOverlay, 12)
  healthText:SetPoint("CENTER")
  healthPercentText = RH.NewText(healthOverlay, 12)
  healthPercentText:SetPoint("RIGHT", health, "RIGHT", -4, 0)
  healthPercentText:SetJustifyH("RIGHT")
  healthPercentText:Hide()
  RH.healthBar = health
  RH.healthText = healthText
  RH.healthPercentText = healthPercentText

  combo = CreateFrame("Frame", nil, hud)
  combo.segments = {}
  for i = 1, 5 do
    local segment = Bar(combo, "energy")
    segment:SetMinMaxValues(i - 1, i)
    segment:SetStatusBarColor(Color("combo" .. i))
    combo.segments[i] = segment
  end
  RH.combo = combo

  swingMain = Bar(hud, "energy")
  swingOff = Bar(hud, "energy")
  swingMain:SetStatusBarColor(Color("swingMain"))
  swingOff:SetStatusBarColor(Color("swingOff"))
  RH.swingMain, RH.swingOff = swingMain, swingOff

  gcd = CreateFrame("Frame", nil, energy)
  gcd:SetAllPoints(energy)
  gcd:SetFrameLevel(energyOverlay:GetFrameLevel() + 1)
  for index = 1, 4 do
    local edge = gcd:CreateTexture(nil, "OVERLAY")
    edge:SetTexture(WHITE)
    if edge.SetSnapToPixelGrid then edge:SetSnapToPixelGrid(false) edge:SetTexelSnappingBias(0) end
    edge:Hide()
    gcdEdges[index] = edge
  end
  gcdSpark = gcd:CreateTexture(nil, "OVERLAY", nil, 1)
  gcdSpark:SetTexture("Interface\\AddOns\\RogueHUD\\Media\\gcd_glow")
  gcdSpark:SetBlendMode("ADD")
  if gcdSpark.SetSnapToPixelGrid then gcdSpark:SetSnapToPixelGrid(false) gcdSpark:SetTexelSnappingBias(0) end
  gcdSpark:Hide()
  gcd:Hide()
  RH.gcd = gcd

  hud:SetScript("OnUpdate", function(_, elapsed)
    RH.hudElapsed = (RH.hudElapsed or 0) + elapsed
    if RH.hudElapsed < 0.05 then return end
    RH.hudElapsed = 0
    RH.UpdateSwings()
  end)
end

local function PlainValue(v)
  return not RH.IsSecret(v) and type(v) == "number" and v or nil
end

local function CurrentHealthText(value)
  if value == nil then return "" end
  if RH.IsSecret(value) then
    local abbreviated = RH.Safe(AbbreviateLargeNumbers, value)
    if abbreviated ~= nil then return abbreviated end
    local ok, digits = pcall(string.format, "%d", value)
    return ok and digits or ""
  end
  if type(value) ~= "number" then return "" end
  if value >= 100000 then return tostring(math.floor(value / 1000)) .. " K" end
  return string.format("%d", value)
end

local function HealthText(value, percent)
  local shownPercent = ""
  if percent ~= nil then
    local ok, formatted = pcall(string.format, "%.0f%%", percent)
    if ok then shownPercent = formatted end
  end
  local mode = RH.db.health.mode
  if mode == "both" then
    healthText:SetText(CurrentHealthText(value))
    healthPercentText:SetText(shownPercent)
  elseif mode == "current" then
    healthText:SetText(CurrentHealthText(value))
    healthPercentText:SetText("")
  else
    healthText:SetText(shownPercent)
    healthPercentText:SetText("")
  end
end

function RH.UpdateResources()
  if not RH.db or not RH.db.enabled then return end
  if RH.preview then
    energy:SetMinMaxValues(0, 100)
    energy:SetValue(65)
    energyText:SetText("65")
    for _, segment in ipairs(combo.segments) do segment:SetValue(4) end
    health:SetMinMaxValues(0, 100)
    health:SetValue(75)
    HealthText(75, 75)
    return
  end
  local energyType = Enum and Enum.PowerType and Enum.PowerType.Energy or 3
  local pointsType = Enum and Enum.PowerType and Enum.PowerType.ComboPoints or 4
  local e, maxE = UnitPower("player", energyType), UnitPowerMax("player", energyType)
  if maxE then energy:SetMinMaxValues(0, maxE) end
  if e then energy:SetValue(e) end
  if e ~= nil then
    local ok, formatted = pcall(string.format, "%s", e)
    if ok then energyText:SetText(formatted)
    else energyText:SetText(e) end
  else energyText:SetText("") end

  local p
  if GetComboPoints then p = RH.Safe(GetComboPoints, "player", "target") end
  if p == nil then p = UnitPower("player", pointsType) end
  if p then for _, segment in ipairs(combo.segments) do segment:SetValue(p) end end
  local h, maxH = UnitHealth("player"), UnitHealthMax("player")
  if maxH then health:SetMinMaxValues(0, maxH) end
  if h then health:SetValue(h) end
  local percent
  if UnitHealthPercent and CurveConstants and CurveConstants.ScaleTo100 then
    percent = RH.Safe(UnitHealthPercent, "player", true, CurveConstants.ScaleTo100)
  end
  if percent == nil then
    local plainH, plainMaxH = PlainValue(h), PlainValue(maxH)
    if plainH and plainMaxH and plainMaxH > 0 then percent = plainH / plainMaxH * 100 end
  end
  HealthText(h, percent)
end

local function EnergyCost(id)
  if not (C_Spell and C_Spell.GetSpellPowerCost) then return nil end
  local costs = RH.Safe(C_Spell.GetSpellPowerCost, id)
  if type(costs) ~= "table" or RH.IsSecret(costs) then return nil end
  local energyType = Enum and Enum.PowerType and Enum.PowerType.Energy or 3
  for _, cost in ipairs(costs) do
    if type(cost) == "table" and not RH.IsSecret(cost) and RH.Plain(cost.type) == energyType then
      return RH.Plain(cost.cost)
    end
  end
end

function RH.UpdateEnergyMarks()
  if not RH.db then return end
  local enabled = RH.db.hints.enabled and RH.db.hints.energy and RH.db.energy.enabled
  local energyType = Enum and Enum.PowerType and Enum.PowerType.Energy or 3
  local maxEnergy = RH.Plain(UnitPowerMax("player", energyType))
  for key, mark in pairs(energyMarks) do
    local spell = RH.KnownRank(RH.spells[key])
    local cost = spell and EnergyCost(spell)
    if RH.preview then cost, maxEnergy = key == "rupture" and 25 or 35, 100 end
    if enabled and type(cost) == "number" and type(maxEnergy) == "number" and maxEnergy > 0 then
      local fraction = math.max(0, math.min(1, cost / maxEnergy))
      mark:ClearAllPoints()
      mark:SetPoint("CENTER", energy, "LEFT", energy:GetWidth() * fraction, 0)
      mark:SetHeight(energy:GetHeight())
      mark:Show()
    else mark:Hide() end
  end
end

function RH.UpdateSwings()
  if not RH.db or not RH.db.swing.enabled then return end
  if RH.preview then
    swingMain:SetMinMaxValues(0, 1)
    swingOff:SetMinMaxValues(0, 1)
    swingMain:SetValue(0.65)
    swingOff:SetValue(0.3)
    swingOff:Show()
    return
  end
  local mainSpeed, offSpeed = UnitAttackSpeed("player")
  mainSpeed, offSpeed = PlainValue(mainSpeed), PlainValue(offSpeed)
  mainSpeed = swingDuration.main or mainSpeed
  offSpeed = swingDuration.off or offSpeed
  local now = GetTime()
  if mainSpeed and mainSpeed > 0 then
    swingMain:SetMinMaxValues(0, mainSpeed)
    swingMain:SetValue(math.min(mainSpeed, now - swingStart.main))
  end
  swingOff:SetShown(offSpeed ~= nil and offSpeed > 0)
  if offSpeed and offSpeed > 0 then
    swingOff:SetMinMaxValues(0, offSpeed)
    swingOff:SetValue(math.min(offSpeed, now - swingStart.off))
  end
end

local VANISH_AURAS = {11327, 11329}
local function HasVanishAura()
  if not (C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID) then return false end
  for _, id in ipairs(VANISH_AURAS) do
    local aura = RH.Safe(C_UnitAuras.GetPlayerAuraBySpellID, id)
    if not RH.IsSecret(aura) and aura ~= nil then return true end
  end
  return false
end

function RH.UpdateEnergyColor()
  if not RH.db or not energy then return end
  if RH.preview then
    energy:SetStatusBarColor(Color("energy"))
  elseif HasVanishAura() then
    energy:SetStatusBarColor(0.48, 0.58, 0.69)
  elseif IsStealthed and RH.Plain(RH.Safe(IsStealthed)) == true then
    energy:SetStatusBarColor(0.75, 0.4, 0.95)
  else
    energy:SetStatusBarColor(Color("energy"))
  end
end

function RH.UpdateGCD()
  if not gcd or not RH.db then return end
  if not RH.db.enabled or not RH.db.energy.enabled or not RH.db.gcd.enabled
    or (RH.db.style.borderSize or 0) <= 0 then StopGCD() return end
  if RH.preview then
    StopGCD()
    gcd:Show()
    DrawGCD(0.4)
    return
  end
  local info = C_Spell and C_Spell.GetSpellCooldown and RH.Safe(C_Spell.GetSpellCooldown, 29515)
  if type(info) ~= "table" or RH.IsSecret(info) or RH.Plain(info.isActive) ~= true then
    StopGCD()
    return
  end
  local now = GetTime()
  local exactStart, exactDuration = PlainValue(info.startTime), PlainValue(info.duration)
  local hasExact = exactStart and exactStart > 0 and exactDuration and exactDuration > 0 and exactDuration <= 2
  if gcdStart and now < gcdEnd and (not hasExact or exactStart == gcdStart) then return end
  gcdStart = hasExact and exactStart or now
  gcdDuration = hasExact and exactDuration or 1
  gcdEstimated = not hasExact
  gcdEnd = gcdStart + gcdDuration
  if gcdEnd <= now then StopGCD() return end
  gcd:Show()
  DrawGCD((now - gcdStart) / gcdDuration)
  gcd:SetScript("OnUpdate", function()
    local progress = (GetTime() - gcdStart) / gcdDuration
    if progress >= 1 then StopGCD() else DrawGCD(progress) end
  end)
end

local function StackGap()
  return RH.db.stackGap
end

local function PositionStack(updateCastbar)
  if not hud or not RH.db then return end
  local db = RH.db
  local frames = {
    essential = RH.cooldownRows and RH.cooldownRows.essential,
    combo = combo, health = health, energy = energy, swing = swingMain,
    utility = RH.cooldownRows and RH.cooldownRows.utility,
  }
  local heights = {
    combo = db.combo.height, health = db.health.height,
    energy = db.energy.height, swing = db.swing.height * 2 + 1,
  }
  local visible = {
    combo = db.combo.enabled, health = db.health.enabled,
    energy = db.energy.enabled, swing = db.swing.enabled,
  }
  for _, key in ipairs({"essential", "utility"}) do
    local frame = frames[key]
    visible[key] = frame and frame:IsShown() or false
    heights[key] = frame and frame:GetHeight() or 0
  end
  local above, below = {}, {}
  for index, key in ipairs(db.barOrder) do
    if visible[key] and frames[key] then
      local list = index == 1 and above or below
      list[#list + 1] = key
    end
  end
  local positions = {}
  local function Place(key, top)
    positions[key] = top
    if key == "swing" then
      swingMain:ClearAllPoints()
      swingOff:ClearAllPoints()
      swingMain:SetPoint("TOP", hud, "TOP", 0, top)
      swingOff:SetPoint("TOP", hud, "TOP", 0, top - db.swing.height - 1)
    else
      frames[key]:ClearAllPoints()
      frames[key]:SetPoint("TOP", hud, "TOP", 0, top)
    end
  end
  local y, previous = 0, nil
  for _, key in ipairs(below) do
    if previous then y = y - heights[previous] - StackGap(previous, key) end
    Place(key, y)
    previous = key
  end
  local lower = below[1]
  local bottom = lower and StackGap(above[#above], lower) or 7
  for index = #above, 1, -1 do
    local key = above[index]
    local top = bottom + heights[key]
    Place(key, top)
    if index > 1 then bottom = top + StackGap(above[index - 1], key) end
  end
  for index, key in ipairs(db.barOrder) do
    if not visible[key] and frames[key] then
      local prior, nextKey
      for neighbor = index - 1, 1, -1 do
        local candidate = db.barOrder[neighbor]
        if positions[candidate] then prior = candidate break end
      end
      for neighbor = index + 1, #db.barOrder do
        local candidate = db.barOrder[neighbor]
        if positions[candidate] then nextKey = candidate break end
      end
      local top = prior and positions[prior] - heights[prior] - StackGap(prior, key)
        or nextKey and positions[nextKey] + StackGap(key, nextKey) + heights[key] or 0
      Place(key, top)
    end
  end
  local highest, lowest
  for key, top in pairs(positions) do
    if visible[key] then
      highest = math.max(highest or top, top)
      lowest = math.min(lowest or (top - heights[key]), top - heights[key])
    end
  end
  RH.hudStackTop = highest or 0
  RH.hudStackBottom = lowest or -hud:GetHeight()
  if updateCastbar and RH.PositionCastbar then RH.PositionCastbar() end
end
RH.ReflowHUDStack = function() PositionStack(false) end

local function Layout()
  if not hud or not RH.db then return end
  RH.UpdateEnergyColor()
  if InCombatLockdown() then RH.layoutPending = true RH.UpdateGCD() return end
  RH.layoutRunning = true
  local db = RH.db
  hud:SetShown(db.enabled)
  if not db.enabled then RH.layoutRunning = false RH.UpdateGCD() return end
  hud:SetScale(db.scale)
  hud:SetAlpha(db.alpha)
  for _, bar in ipairs({energy, health, swingMain, swingOff}) do RH.Style.ApplyBar(bar) end
  for i, segment in ipairs(combo.segments) do
    RH.Style.ApplyBar(segment)
    segment:SetStatusBarColor(Color("combo" .. i))
  end
  health:SetStatusBarColor(Color("health"))
  energy:SetStatusBarColor(Color("energy"))
  RH.UpdateEnergyColor()
  swingMain:SetStatusBarColor(Color("swingMain"))
  swingOff:SetStatusBarColor(Color("swingOff"))
  RH.Style.Text(energyText, db.energy.fontSize)
  RH.Style.Text(healthText, db.health.fontSize)
  RH.Style.Text(healthPercentText, db.health.fontSize)
  local width = db.width
  local coreHeight = 0
  for _, key in ipairs({"energy", "combo", "health"}) do
    if db[key].enabled then coreHeight = coreHeight + db[key].height + db.stackGap end
  end
  if db.swing.enabled then coreHeight = coreHeight + db.swing.height * 2 + db.stackGap + 1 end
  hud:SetSize(width, math.max(coreHeight, 1))
  hud:ClearAllPoints()
  hud:SetPoint("CENTER", UIParent, "CENTER", db.x, db.y)

  energy:SetShown(db.energy.enabled)
  if db.energy.enabled then
    energy:SetSize(width, db.energy.height)
    energyText:SetShown(db.energy.text)
    RH.Style.Text(energyText, db.energy.fontSize)
  end
  combo:SetShown(db.combo.enabled)
  if db.combo.enabled then
    combo:SetSize(width, db.combo.height)
    local gap = db.combo.gap
    local segmentWidth = (width - 4 * gap) / 5
    for i, segment in ipairs(combo.segments) do
      segment:SetSize(segmentWidth, db.combo.height)
      segment:ClearAllPoints()
      segment:SetPoint("LEFT", combo, "LEFT", (i - 1) * (segmentWidth + gap), 0)
    end
  end
  health:SetShown(db.health.enabled)
  if db.health.enabled then
    health:SetSize(width, db.health.height)
    healthText:SetShown(db.health.text)
    local both = db.health.text and db.health.mode == "both"
    healthPercentText:SetShown(both)
    healthText:ClearAllPoints()
    if both then
      healthText:SetPoint("LEFT", health, "LEFT", 4, 0)
      healthText:SetJustifyH("LEFT")
    else
      healthText:SetPoint("CENTER", health, "CENTER")
      healthText:SetJustifyH("CENTER")
    end
    RH.Style.Text(healthText, db.health.fontSize)
    RH.Style.Text(healthPercentText, db.health.fontSize)
  end
  swingMain:SetShown(db.swing.enabled)
  swingOff:SetShown(db.swing.enabled)
  if db.swing.enabled then
    local each = db.swing.height
    swingMain:SetSize(width, each)
    swingOff:SetSize(width, each)
  end
  PositionStack(true)
  RH.layoutRunning = false
  RH.UpdateResources()
  RH.UpdateEnergyMarks()
  RH.UpdateSwings()
  RH.UpdateGCD()
end
RH.LayoutHUD = Layout

RH.On("PLAYER_LOGIN", Build)
RH.AddRefresh(Layout)
RH.On("UNIT_POWER_UPDATE", function(_, unit) if unit == "player" then RH.UpdateResources() end end)
RH.On("UNIT_POWER_FREQUENT", function(_, unit) if unit == "player" then RH.UpdateResources() end end)
RH.On("UNIT_COMBO_POINTS", RH.UpdateResources)
RH.On("UNIT_MAXPOWER", function(_, unit) if unit == "player" then RH.UpdateResources() end end)
RH.On("SPELLS_CHANGED", RH.UpdateEnergyMarks)
RH.On("PLAYER_TALENT_UPDATE", RH.UpdateEnergyMarks)
RH.On("UNIT_HEALTH", function(_, unit) if unit == "player" then RH.UpdateResources() end end)
RH.On("UNIT_MAXHEALTH", function(_, unit) if unit == "player" then RH.UpdateResources() end end)
RH.On("PLAYER_TARGET_CHANGED", RH.UpdateResources)
RH.On("PLAYER_ENTERING_WORLD", RH.UpdateResources)
RH.On("PLAYER_SWING", function(_, duration, swingType)
  duration = PlainValue(duration)
  if not duration or duration <= 0 then return end
  local offType = Enum and Enum.PlayerSwingType and Enum.PlayerSwingType.OffHand or 1
  local mainType = Enum and Enum.PlayerSwingType and Enum.PlayerSwingType.MainHand or 0
  local hand = swingType == offType and "off" or swingType == mainType and "main" or nil
  if not hand then return end
  swingStart[hand], swingDuration[hand] = GetTime(), duration
  RH.UpdateSwings()
end)
RH.On("PLAYER_ENTERING_WORLD", function()
  swingStart.main, swingStart.off = 0, 0
  swingDuration.main, swingDuration.off = nil, nil
end)
RH.On("PLAYER_EQUIPMENT_CHANGED", function(_, slot)
  if slot == 16 then swingStart.main, swingDuration.main = 0, nil end
  if slot == 17 then swingStart.off, swingDuration.off = 0, nil end
  RH.UpdateSwings()
end)
RH.On("UNIT_AURA", function(_, unit) if unit == "player" then RH.UpdateEnergyColor() end end)
RH.On("UPDATE_STEALTH", RH.UpdateEnergyColor)
RH.On("PLAYER_ENTERING_WORLD", RH.UpdateEnergyColor)
RH.On("PLAYER_REGEN_DISABLED", function()
  RH.UpdateEnergyColor()
  if C_Timer and C_Timer.After then C_Timer.After(0, RH.UpdateEnergyColor) end
end)
RH.On("PLAYER_REGEN_ENABLED", RH.UpdateEnergyColor)
RH.On("SPELL_UPDATE_COOLDOWN", function(_, spellID)
  if spellID ~= nil and not RH.IsSecret(spellID) then gcdNamedAt = GetTime() end
  RH.UpdateGCD()
end)
RH.On("UNIT_SPELLCAST_SUCCEEDED", function(_, unit, _, spellID)
  if unit ~= "player" or not RH.db or not RH.db.gcd.enabled then return end
  local now = GetTime()
  RH.UpdateGCD()
  if not gcdStart or now - gcdStart < 0.4 or spellID == nil or RH.IsSecret(spellID) then return end
  local info = C_Spell and C_Spell.GetSpellCooldown and RH.Safe(C_Spell.GetSpellCooldown, spellID)
  if type(info) ~= "table" or RH.IsSecret(info) or RH.Plain(info.isOnGCD) ~= true then return end
  gcdStart, gcdEnd = nil, 0
  RH.UpdateGCD()
  if gcdStart and gcdEstimated and now - gcdNamedAt <= 0.3 then
    gcdStart = gcdNamedAt
    gcdEnd = gcdStart + gcdDuration
  end
end)
RH.On("PLAYER_REGEN_ENABLED", function() if RH.layoutPending then RH.layoutPending = nil Layout() end end)
