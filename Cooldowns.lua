local _, RH = ...
if not RH.isRogue then return end

local rows = {}
RH.cooldownIcons = {}
RH.cooldownRows = {}
local pendingLayout = false
local UpdateHints
local UpdateRiposte
local LayoutRow
local RIPOSTE_ID = 14251
local auraState = {slice = {seen = false}, rupture = {seen = false}}
local targetWasDead = false

local function ResetAuraState()
  auraState.slice.seen = false
  auraState.rupture.seen = false
  targetWasDead = false
end

local function NativeIDs(which)
  if not (C_CooldownViewer and C_CooldownViewer.GetCooldownViewerCategorySet
    and C_CooldownViewer.GetCooldownViewerCooldownInfo and Enum and Enum.CooldownViewerCategory) then return nil end
  local category = Enum.CooldownViewerCategory[which == "essential" and "Essential" or "Utility"]
  if category == nil then return nil end
  local viewer = _G[which == "essential" and "EssentialCooldownViewer" or "UtilityCooldownViewer"]
  local ids = viewer and viewer.GetCooldownIDs and RH.Safe(viewer.GetCooldownIDs, viewer)
  if type(ids) ~= "table" or #ids == 0 then
    ids = RH.Safe(C_CooldownViewer.GetCooldownViewerCategorySet, category, false)
  end
  if type(ids) ~= "table" or RH.IsSecret(ids) then return nil end
  local result, seen = {}, {}
  for _, id in ipairs(ids) do
    if not RH.IsSecret(id) then
      local info = RH.Safe(C_CooldownViewer.GetCooldownViewerCooldownInfo, id)
      if type(info) == "table" and not RH.IsSecret(info) then
        local spellID = RH.Plain(info.overrideSpellID) or RH.Plain(info.spellID)
        if type(spellID) == "number" and RH.BestKnownForID(spellID) and not seen[spellID] then
          seen[spellID] = true
          result[#result + 1] = spellID
        end
      end
    end
  end
  return result
end

local function Catalogue(which)
  local result = {}
  local catalogue = which == "essential" and RH.essentialFallback or RH.utilityFallback
  for _, key in ipairs(catalogue) do
    local id = RH.KnownRank(RH.spells[key]) or (RH.preview and RH.spells[key][1])
    if id then result[#result + 1] = id end
  end
  return result
end

local function Entries(which)
  local cfg = RH.db.cooldown
  local base
  if RH.preview then base = Catalogue(which)
  elseif cfg.source == "curated" then base = Catalogue(which)
  elseif cfg.source == "custom" then base = cfg[which == "essential" and "customEssential" or "customUtility"] or {}
  else base = NativeIDs(which) or Catalogue(which) end
  local extras = cfg[which == "essential" and "extraEssential" or "extraUtility"] or {}
  local result, seen = {}, {}
  local function Add(value)
    if type(value) ~= "number" then return end
    local known = RH.BestKnownForID(value) or (RH.preview and value)
    if known == RIPOSTE_ID then return end
    if known and not cfg.hidden[value] and not cfg.hidden[tostring(value)] and not seen[known] then
      seen[known] = true
      result[#result + 1] = known
    end
  end
  for _, id in ipairs(base) do Add(id) end
  for _, id in ipairs(extras) do Add(id) end
  if which == "essential" and RH.Knows(RIPOSTE_ID)
    and not cfg.hidden[RIPOSTE_ID] and not cfg.hidden[tostring(RIPOSTE_ID)] then
    result[#result + 1] = RIPOSTE_ID
  end
  return result
end
RH.CooldownEntries = Entries

local function CreateIcon(row)
  local frame = RH.NewIcon(row.holder, RH.db.cooldown.essentialSize)
  frame:EnableMouse(false)
  frame.cooldown = CreateFrame("Cooldown", nil, frame, "CooldownFrameTemplate")
  frame.cooldown:SetAllPoints(frame.texture)
  frame.cooldown:EnableMouse(false)
  if frame.cooldown.SetDrawEdge then frame.cooldown:SetDrawEdge(false) end
  frame.auraCooldown = CreateFrame("Cooldown", nil, frame, "CooldownFrameTemplate")
  frame.auraCooldown:SetAllPoints(frame.texture)
  frame.auraCooldown:EnableMouse(false)
  if frame.auraCooldown.SetDrawSwipe then frame.auraCooldown:SetDrawSwipe(false) end
  if frame.auraCooldown.SetDrawEdge then frame.auraCooldown:SetDrawEdge(true) end
  if frame.auraCooldown.SetHideCountdownNumbers then frame.auraCooldown:SetHideCountdownNumbers(true) end
  frame.auraCooldown:Hide()
  RH.Style.ApplyIcon(frame)
  frame.hintOverlay = CreateFrame("Frame", nil, frame)
  frame.hintOverlay:SetAllPoints(frame.texture)
  frame.hintOverlay:SetFrameLevel(math.max(frame.cooldown:GetFrameLevel(), frame.auraCooldown:GetFrameLevel()) + 2)
  frame.hint = RH.NewText(frame.hintOverlay, 10)
  frame.hint:SetPoint("CENTER")
  frame.hint:SetText("")
  RH.Style.Text(frame.hint, 10)
  return frame
end

local function Build()
  for _, which in ipairs({"essential", "utility"}) do
    local row = {holder = CreateFrame("Frame", nil, RH.hud), icons = {}}
    rows[which] = row
    RH.cooldownRows[which] = row.holder
    row.holder:SetSize(1, 1)
  end
  local ticker = CreateFrame("Frame", nil, RH.hud)
  local elapsedTime = 0
  ticker:SetScript("OnUpdate", function(_, elapsed)
    elapsedTime = elapsedTime + elapsed
    if elapsedTime < 0.1 then return end
    elapsedTime = 0
    if RH.db and RH.db.enabled then
      if RH.db.hints.enabled then UpdateHints() else UpdateRiposte() end
    end
  end)
end

local armedRange = {}
local function ArmRange(wanted)
  if not (C_Spell and C_Spell.EnableSpellRangeCheck) then return end
  for id in pairs(armedRange) do
    if not wanted[id] then
      RH.Safe(C_Spell.EnableSpellRangeCheck, id, false)
      armedRange[id] = nil
    end
  end
  for id in pairs(wanted) do
    if not armedRange[id] then
      local ok = pcall(C_Spell.EnableSpellRangeCheck, id, true)
      if ok then armedRange[id] = true end
    end
  end
end

local function CooldownState(id)
  if not (C_Spell and C_Spell.GetSpellCooldown) then return nil end
  local info = RH.Safe(C_Spell.GetSpellCooldown, id)
  if type(info) ~= "table" or RH.IsSecret(info) then return nil end
  local enabled, active, onGCD = info.isEnabled, info.isActive, info.isOnGCD
  if RH.IsSecret(enabled) or RH.IsSecret(active) or RH.IsSecret(onGCD) then return nil, info end
  if enabled == false and id ~= RIPOSTE_ID then return true, info end
  if active == nil then
    local duration = RH.Plain(info.duration)
    local startTime = RH.Plain(info.startTime)
    if type(duration) == "number" then
      if id == RIPOSTE_ID then
        return type(startTime) == "number" and startTime > 0
          and duration > 1.5 and startTime + duration > GetTime(), info
      end
      return duration > 1.5, info
    end
    return nil, info
  end
  return active == true and onGCD ~= true, info
end

local function ClearCooldown(cooldown)
  if cooldown.Clear then cooldown:Clear()
  else cooldown:SetCooldown(0, 0) end
end

local function UpdateCooldown(frame)
  if not frame.spell or not RH.db then return end
  local cfg, id = RH.db.cooldown, frame.spell
  if frame.cooldown.SetDrawSwipe then frame.cooldown:SetDrawSwipe(cfg.showSwipe) end
  if frame.cooldown.SetHideCountdownNumbers then frame.cooldown:SetHideCountdownNumbers(not cfg.showNumbers or frame.auraActive) end
  local onCooldown, info = CooldownState(id)
  if onCooldown == nil then onCooldown = frame.onCooldown or false end
  frame.onCooldown = onCooldown
  if onCooldown then
    local applied = false
    if C_Spell and C_Spell.GetSpellCooldownDuration and frame.cooldown.SetCooldownFromDurationObject then
      local duration = RH.Safe(C_Spell.GetSpellCooldownDuration, id, true)
      if duration then applied = pcall(frame.cooldown.SetCooldownFromDurationObject, frame.cooldown, duration, true) end
    end
    if not applied and info and not RH.IsSecret(info.startTime) and not RH.IsSecret(info.duration)
      and type(info.startTime) == "number" and type(info.duration) == "number" then
      frame.cooldown:SetCooldown(info.startTime, info.duration)
    end
  else
    ClearCooldown(frame.cooldown)
  end
  local r, g, b = 1, 1, 1
  if not onCooldown and cfg.dimUnusable and C_Spell and C_Spell.IsSpellUsable then
    local usable, noPower = RH.Safe(C_Spell.IsSpellUsable, id)
    if not RH.IsSecret(usable) and not RH.IsSecret(noPower) then
      if noPower == true then r, g, b = 0.5, 0.5, 1
      elseif usable == false then r, g, b = 0.4, 0.4, 0.4 end
    end
  end
  if cfg.outOfRange and C_Spell and C_Spell.IsSpellInRange and UnitExists and UnitExists("target") then
    local inRange = RH.Safe(C_Spell.IsSpellInRange, id, "target")
    if not RH.IsSecret(inRange) and inRange == false then r, g, b = 0.64, 0.15, 0.15 end
  end
  frame.texture:SetVertexColor(r, g, b)
  frame.texture:SetDesaturated(onCooldown and cfg.desaturate or false)
  if id == RIPOSTE_ID then
    local usable = C_Spell and C_Spell.IsSpellUsable and RH.Plain(RH.Safe(C_Spell.IsSpellUsable, id))
    local pending = frame.riposteCastPendingUntil and GetTime() < frame.riposteCastPendingUntil
    if onCooldown then frame.riposteCastPendingUntil = nil end
    frame.riposteReady = not onCooldown and not pending and usable == true
    frame.riposteVisible = onCooldown or frame.riposteReady or pending or false
    frame.warningActive = frame.riposteReady and RH.db.hints.enabled or false
    RH.Style.BorderColor(frame, frame.warningActive and {1, 0.16, 0.14, 1}
      or (RH.db.style.ownIconBorder and RH.db.style.iconBorderColor or RH.db.style.borderColor))
    frame:SetAlpha(1)
  else
    frame:SetAlpha(frame.warningActive and 1 or (onCooldown and cfg.cooldownAlpha or (cfg.hideReady and 0 or cfg.readyAlpha)))
  end
end

LayoutRow = function(row, force)
  if not row or not row.enabled then return end
  local riposte = RH.cooldownIcons.riposte
  local visible = riposte and riposte.riposteVisible or false
  if not force and row.riposteVisible == visible then return end
  row.riposteVisible = visible
  local size, gap = RH.db.cooldown.essentialSize, RH.db.cooldown.essentialGap
  local perLine = math.max(1, math.floor((RH.db.width + gap) / (size + gap)))
  local count = 0
  for _, frame in ipairs(row.icons) do
    if frame.spell then
      local show = frame.spell ~= RIPOSTE_ID or visible
      frame:SetShown(show)
      if show then
        local column = count % perLine
        local line = math.floor(count / perLine)
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", row.holder, "TOPLEFT", column * (size + gap), -line * (size + gap))
        count = count + 1
      end
    end
  end
  row.holder:SetShown(count > 0)
  if count > 0 then
    local columns = math.min(perLine, count)
    local lines = math.ceil(count / perLine)
    row.holder:SetSize(columns * size + (columns - 1) * gap, lines * size + (lines - 1) * gap)
  end
  if not force and RH.ReflowHUDStack then RH.ReflowHUDStack() end
end

UpdateRiposte = function()
  local frame = RH.cooldownIcons.riposte
  if not frame or not rows.essential or not rows.essential.enabled then return end
  UpdateCooldown(frame)
  LayoutRow(rows.essential)
end

local function UpdateAllCooldowns()
  for _, row in pairs(rows) do
    for _, frame in ipairs(row.icons) do if frame.spell then UpdateCooldown(frame) end end
  end
  LayoutRow(rows.essential)
end
RH.UpdateCooldowns = UpdateAllCooldowns

local function AuraByName(name, unit, filter)
  if not name then return nil end
  if C_UnitAuras and C_UnitAuras.GetAuraDataBySpellName then
    local aura = RH.Safe(C_UnitAuras.GetAuraDataBySpellName, unit, name, filter)
    if RH.IsSecret(aura) then return {unknown = true} end
    if type(aura) == "table" and not RH.IsSecret(aura) then return aura end
  end
  if AuraUtil and AuraUtil.FindAuraByName then
    local auraName, _, _, _, duration, expiration = RH.Safe(AuraUtil.FindAuraByName, name, unit, filter)
    if auraName then
      return {duration = duration, expirationTime = expiration}
    end
  end
end

local function AuraForKey(key)
  local spellID = RH.KnownRank(RH.spells[key]) or RH.spells[key][1]
  local info = RH.SpellInfo(spellID)
  if not info or RH.IsSecret(info) then return nil end
  local name = RH.Plain(info.name)
  return AuraByName(name, key == "slice" and "player" or "target", key == "slice" and "HELPFUL" or "HARMFUL|PLAYER")
end

UpdateHints = function()
  if not RH.db then return end
  local cfg = RH.db.hints
  local targetDead = UnitIsDeadOrGhost and RH.Plain(RH.Safe(UnitIsDeadOrGhost, "target")) == true
  if targetDead and not targetWasDead then
    auraState.slice.seen = false
    auraState.rupture.seen = false
  end
  targetWasDead = targetDead
  for _, frame in pairs(RH.cooldownIcons) do
    frame.hint:SetText("")
    frame.auraActive = false
    frame.warningActive = false
    RH.Style.BorderColor(frame, RH.db.style.ownIconBorder and RH.db.style.iconBorderColor or RH.db.style.borderColor)
    frame.auraCooldown:Hide()
  end
  if cfg.enabled then
    for _, key in ipairs({"slice", "rupture"}) do
      if cfg[key] then
        local frame = RH.cooldownIcons[key]
        if frame then
          local aura = (key == "rupture" and targetDead) and nil or AuraForKey(key)
          local state = auraState[key]
          local expiration = aura and RH.Plain(aura.expirationTime)
          local remaining = type(expiration) == "number" and expiration - GetTime() or nil
          if aura and not aura.unknown and (remaining == nil or remaining > 0) then
            state.seen = true
            frame.auraActive = true
          end
          local auraID = aura and RH.Plain(aura.auraInstanceID)
          if frame.auraActive and auraID and C_UnitAuras and C_UnitAuras.GetAuraDuration
            and frame.auraCooldown.SetCooldownFromDurationObject then
            local unit = key == "slice" and "player" or "target"
            local durationObject = RH.Safe(C_UnitAuras.GetAuraDuration, unit, auraID)
            if durationObject and pcall(frame.auraCooldown.SetCooldownFromDurationObject, frame.auraCooldown, durationObject, true) then
              frame.auraCooldown:Show()
            end
          end
          if frame.auraActive and remaining then
            frame.hint:SetText(math.ceil(remaining) .. "s")
            frame.warningActive = remaining < (cfg[key .. "Expiry"] or 5)
          elseif not aura and state.seen and not targetDead then
            frame.warningActive = true
          elseif remaining and remaining <= 0 and state.seen and not targetDead then
            frame.warningActive = true
          end
          if frame.warningActive then
            RH.Style.BorderColor(frame, {1, 0.16, 0.14, 1})
          end
        end
      end
    end
  end
  for _, key in ipairs({"slice", "rupture", "riposte"}) do
    local frame = RH.cooldownIcons[key]
    if frame then UpdateCooldown(frame) end
  end
  LayoutRow(rows.essential)
end
RH.UpdateHints = UpdateHints

local function Refresh()
  if not RH.db or not RH.hud then return end
  if InCombatLockdown() then
    pendingLayout = true
    UpdateAllCooldowns()
    UpdateHints()
    return
  end
  RH.cooldownIcons = {}
  local cfg = RH.db.cooldown
  local wantedRange = {}
  for _, which in ipairs({"essential", "utility"}) do
    local row = rows[which]
    local enabled = RH.db.enabled and cfg[which]
    local entries = enabled and Entries(which) or {}
    enabled = enabled and #entries > 0
    row.enabled = enabled
    row.holder:SetShown(enabled)
    if enabled then
      local size, gap = cfg[which .. "Size"], cfg[which .. "Gap"]
      local perLine = math.max(1, math.floor((RH.db.width + gap) / (size + gap)))
      local columns = math.min(perLine, math.max(1, #entries))
      local lines = math.max(1, math.ceil(#entries / perLine))
      row.holder:SetSize(columns * size + (columns - 1) * gap, lines * size + (lines - 1) * gap)
      for index, id in ipairs(entries) do
        wantedRange[id] = true
        local frame = row.icons[index]
        if not frame then frame = CreateIcon(row) row.icons[index] = frame end
        if frame.spell ~= id then
          frame.onCooldown = nil
          frame.riposteCastPendingUntil = nil
          frame.riposteReady = nil
          frame.riposteVisible = nil
          ClearCooldown(frame.cooldown)
        end
        frame.spell = id
        frame:SetSize(size, size)
        frame.texture:SetTexture(RH.SpellIcon(id))
        RH.Style.ApplyIcon(frame)
        RH.Style.Text(frame.hint, 10)
        frame:ClearAllPoints()
        local column = (index - 1) % perLine
        local line = math.floor((index - 1) / perLine)
        frame:SetPoint("TOPLEFT", row.holder, "TOPLEFT", column * (size + gap), -line * (size + gap))
        frame:Show()
        local key = RH.SpellKeyForID(id)
        if key then RH.cooldownIcons[key] = frame end
        UpdateCooldown(frame)
      end
      for index = #entries + 1, #row.icons do row.icons[index]:Hide() row.icons[index].spell = nil end
      if which == "essential" then LayoutRow(row, true) end
    else
      for _, frame in ipairs(row.icons) do frame:Hide() frame.spell = nil end
    end
  end
  ArmRange(wantedRange)
  RH.LayoutHUD()
  UpdateHints()
end

RH.On("PLAYER_LOGIN", Build)
RH.AddRefresh(Refresh)
RH.On("SPELLS_CHANGED", Refresh)
RH.On("PLAYER_TALENT_UPDATE", Refresh)
RH.On("PLAYER_ENTERING_WORLD", Refresh)
RH.On("SPELL_UPDATE_COOLDOWN", UpdateAllCooldowns)
RH.On("SPELL_UPDATE_CHARGES", UpdateAllCooldowns)
RH.On("ACTIONBAR_UPDATE_COOLDOWN", UpdateAllCooldowns)
RH.On("SPELL_UPDATE_USABLE", UpdateAllCooldowns)
RH.On("ACTIONBAR_UPDATE_USABLE", UpdateRiposte)
RH.On("UNIT_SPELLCAST_SUCCEEDED", function(_, unit, _, id)
  if unit == "player" and id == RIPOSTE_ID then
    local frame = RH.cooldownIcons.riposte
    if frame then frame.riposteCastPendingUntil = GetTime() + 1 UpdateRiposte() end
  end
end)
RH.On("SPELL_RANGE_CHECK_UPDATE", UpdateAllCooldowns)
RH.On("PLAYER_TARGET_CHANGED", UpdateAllCooldowns)
RH.On("UNIT_AURA", function(_, unit) if unit == "player" or unit == "target" then UpdateHints() end end)
RH.On("PLAYER_TARGET_CHANGED", function() ResetAuraState() UpdateHints() end)
RH.On("UNIT_HEALTH", function(_, unit) if unit == "target" then UpdateHints() end end)
RH.On("UNIT_FLAGS", function(_, unit) if unit == "target" then UpdateHints() end end)
RH.On("PLAYER_REGEN_ENABLED", UpdateHints)
RH.On("PLAYER_REGEN_ENABLED", function()
  if pendingLayout then pendingLayout = false Refresh() end
end)
