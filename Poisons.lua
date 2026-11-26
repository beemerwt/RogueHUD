local _, RH = ...
if not RH.isRogue then return end

local buttons, holder, weaponText = {}, nil, nil
RH.poisonButtons = buttons
local selected = {}
local pending, pendingProtected

local function ItemUsable(itemID)
  local fn = C_Item and C_Item.IsUsableItem or IsUsableItem
  return RH.Plain(RH.Safe(fn, itemID)) == true
end

local function PoisonChoice(key)
  local data = RH.poisons[key]
  if not data then return nil end
  if RH.preview then
    local last = data.ranks[#data.ranks]
    return {spell = last[1], item = last[2], count = 20, rank = #data.ranks}
  end
  local hasRecipe, best
  for rank = #data.ranks, 1, -1 do
    local spellID, itemID = data.ranks[rank][1], data.ranks[rank][2]
    local count = RH.ItemCount(itemID)
    if RH.Knows(spellID) or (count > 0 and ItemUsable(itemID)) then
      hasRecipe = true
      if not best or (count > 0 and best.count == 0) then
        best = {spell = spellID, item = itemID, count = count, rank = rank}
      end
      if count > 0 then break end
    end
  end
  if hasRecipe then return best end
end
RH.PoisonChoice = PoisonChoice

local function ReadHandModern(slot)
  local ok, list = pcall(C_Item.GetWeaponEnchantInfo, slot)
  if not ok then return nil, false end
  if list == nil then return nil, true end
  if RH.IsSecret(list) or type(list) ~= "table" then return nil, false end
  local temporary = Enum.ItemEnchantType.Temporary
  for _, entry in ipairs(list) do
    if RH.IsSecret(entry) then return nil, false end
    if type(entry) == "table" and not RH.IsSecret(entry.hasEnchant) and not RH.IsSecret(entry.enchantType)
      and entry.hasEnchant and entry.enchantType == temporary then
      if RH.IsSecret(entry.enchantID) or RH.IsSecret(entry.timeLeft) then return nil, false end
      return {id = entry.enchantID, time = entry.timeLeft}, true
    end
  end
  return nil, true
end

local function WeaponEnchants()
  if C_Item and C_Item.GetWeaponEnchantInfo and Enum and Enum.WeaponSlot and Enum.ItemEnchantType then
    local main, mainOK = ReadHandModern(Enum.WeaponSlot.MainHand)
    local off, offOK = ReadHandModern(Enum.WeaponSlot.OffHand)
    return main, off, mainOK and offOK
  end
  if not GetWeaponEnchantInfo then return nil, nil, false end
  local hasMain, mainTime, _, mainID, hasOff, offTime, _, offID = RH.Safe(GetWeaponEnchantInfo)
  if RH.IsSecret(hasMain) or RH.IsSecret(mainTime) or RH.IsSecret(mainID)
    or RH.IsSecret(hasOff) or RH.IsSecret(offTime) or RH.IsSecret(offID) then return nil, nil, false end
  return hasMain and {id = mainID, time = mainTime} or nil,
    hasOff and {id = offID, time = offTime} or nil, true
end
RH.WeaponEnchants = WeaponEnchants

local function TimeText(ms)
  if RH.IsSecret(ms) or type(ms) ~= "number" then return "" end
  local seconds = math.max(0, math.floor(ms / 1000))
  if seconds >= 3600 then return math.ceil(seconds / 3600) .. "h" end
  if seconds >= 60 then return math.ceil(seconds / 60) .. "m" end
  return seconds .. "s"
end

local function EnchantFamily(id)
  if type(id) ~= "number" or not RogueHUDDB or type(RogueHUDDB.enchants) ~= "table" then return nil end
  return RogueHUDDB.enchants[id]
end

local function UpdateWeaponState()
  if not RH.db or not holder then return end
  local main, off, readable = WeaponEnchants()
  for key, button in pairs(buttons) do
    button.mainText:SetText(readable and main and EnchantFamily(main.id) == key and "M" or "")
    button.offText:SetText(readable and off and EnchantFamily(off.id) == key and "O" or "")
  end
  if not RH.db.poison.showWeapon then weaponText:SetText("") return end
  if not readable then weaponText:SetText("MH ? OH ?") return end
  local function Label(hand, data)
    if not data then return hand .. " –" end
    local family = EnchantFamily(data.id)
    local name = family and RH.poisons[family] and RH.poisons[family].name or "enchant ?"
    return hand .. " " .. name .. " " .. TimeText(data.time)
  end
  weaponText:SetText(Label("MH", main) .. " " .. Label("OH", off))
end
RH.UpdateWeaponState = UpdateWeaponState

local function ConfirmApplied()
  if not pending then return end
  local expected = pending
  local main, off, readable = WeaponEnchants()
  local applied = expected.hand == "main" and main or off
  if readable and applied and type(applied.id) == "number"
    and RH.ItemCount(expected.item) < expected.before then
    RogueHUDDB.enchants = type(RogueHUDDB.enchants) == "table" and RogueHUDDB.enchants or {}
    RogueHUDDB.enchants[applied.id] = expected.family
    pending = nil
    UpdateWeaponState()
  end
end

local function UpdateSecure(button, choice)
  if InCombatLockdown() then pendingProtected = true return end
  if RH.preview then choice = nil end
  button.actionItem = choice and choice.count > 0 and choice.item or nil
  button:SetAttribute("type1", choice and choice.count > 0 and "item" or nil)
  button:SetAttribute("type2", choice and choice.count > 0 and "item" or nil)
  button:SetAttribute("item1", choice and ("item:" .. choice.item) or nil)
  button:SetAttribute("item2", choice and ("item:" .. choice.item) or nil)
  button:SetAttribute("target-slot1", 16)
  button:SetAttribute("target-slot2", 17)
end

local function Build()
  holder = CreateFrame("Frame", nil, RH.hud)
  RH.poisonHolder = holder
  local elapsedTime = 0
  holder:SetScript("OnUpdate", function(_, elapsed)
    elapsedTime = elapsedTime + elapsed
    if elapsedTime < 1 then return end
    elapsedTime = 0
    UpdateWeaponState()
  end)
  weaponText = RH.NewText(holder, 10)
  weaponText:SetJustifyH("CENTER")
  weaponText:SetPoint("TOP", holder, "BOTTOM", 0, -3)
  for key, data in pairs(RH.poisons) do
    local button = CreateFrame("Button", nil, holder, "SecureActionButtonTemplate")
    button:RegisterForClicks("AnyUp", "AnyDown")
    RH.Style.CreateIcon(button)
    RH.Style.ApplyIcon(button)
    button.count = RH.NewText(button, 13)
    button.count:SetPoint("BOTTOMRIGHT", -2, 1)
    button.mainText = RH.NewText(button, 9)
    button.mainText:SetPoint("TOPLEFT", 2, -1)
    button.offText = RH.NewText(button, 9)
    button.offText:SetPoint("TOPRIGHT", -2, -1)
    button:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:AddLine(data.name)
      local choice = selected[key]
      if choice then
        GameTooltip:AddLine("Rank " .. choice.rank .. " • " .. choice.count .. " in bags", 1, 1, 1)
        GameTooltip:AddLine("Left click: main hand   Right click: off hand", 0.8, 0.8, 0.8)
      else GameTooltip:AddLine("No learned recipe", 0.8, 0.8, 0.8) end
      GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    button:HookScript("PreClick", function(_, mouse)
      if not button.actionItem then return end
      local before = RH.ItemCount(button.actionItem)
      if before <= 0 then return end
      pending = {family = key, item = button.actionItem, before = before, hand = mouse == "RightButton" and "off" or "main"}
    end)
    button:HookScript("OnClick", function()
      if not pending then return end
      if C_Timer and C_Timer.After then
        C_Timer.After(0.5, ConfirmApplied)
        C_Timer.After(1.5, ConfirmApplied)
      end
    end)
    buttons[key] = button
  end
end

local function Refresh()
  if not RH.db or not holder then return end
  local cfg = RH.db.poison
  RH.Style.Text(weaponText, 10)
  if InCombatLockdown() then
    pendingProtected = true
    for _, key in ipairs(cfg.order) do
      local choice = selected[key]
      if choice then choice.count = RH.ItemCount(choice.item) end
      if buttons[key] then buttons[key].count:SetText(choice and tostring(choice.count) or "") end
    end
    UpdateWeaponState()
    return
  end
  holder:SetShown(RH.db.enabled and cfg.enabled)
  if not cfg.enabled then return end
  local keys = {}
  for _, key in ipairs(cfg.order) do
    local choice = PoisonChoice(key)
    selected[key] = choice
    local button = buttons[key]
    if button then
      button:SetSize(cfg.size, cfg.size)
      button.texture:SetTexture(RH.ItemIcon(choice and choice.item or RH.poisons[key].ranks[1][2]))
      RH.Style.ApplyIcon(button)
      RH.Style.Text(button.count, 13)
      RH.Style.Text(button.mainText, 9)
      RH.Style.Text(button.offText, 9)
      button.count:SetText(choice and tostring(choice.count) or "")
      button:SetAlpha(choice and (choice.count > 0 and 1 or 0.45) or 0.35)
      UpdateSecure(button, choice)
      if choice and cfg.visible[key] then keys[#keys + 1] = key end
    end
  end
  holder:SetShown(#keys > 0)
  for _, button in pairs(buttons) do button:Hide() end
  local width = #keys > 0 and (#keys * cfg.size + (#keys - 1) * cfg.gap) or 1
  holder:SetSize(width, cfg.size)
  holder:ClearAllPoints()
  if cfg.side == "LEFT" then
    holder:SetPoint("RIGHT", RH.hud, "LEFT", -8 + cfg.x, cfg.y)
  else
    holder:SetPoint("LEFT", RH.hud, "RIGHT", 8 + cfg.x, cfg.y)
  end
  for index, key in ipairs(keys) do
    local button = buttons[key]
    button:ClearAllPoints()
    button:SetPoint("LEFT", holder, "LEFT", (index - 1) * (cfg.size + cfg.gap), 0)
    button:Show()
  end
  UpdateWeaponState()
end

RH.On("PLAYER_LOGIN", Build)
RH.AddRefresh(Refresh)
RH.On("BAG_UPDATE_DELAYED", function() Refresh() ConfirmApplied() end)
RH.On("SPELLS_CHANGED", Refresh)
RH.On("PLAYER_TALENT_UPDATE", Refresh)
RH.On("UNIT_INVENTORY_CHANGED", function(_, unit) if unit == "player" then UpdateWeaponState() ConfirmApplied() end end)
RH.On("PLAYER_EQUIPMENT_CHANGED", UpdateWeaponState)
RH.On("ENCHANT_APPLIED", UpdateWeaponState)
RH.On("PLAYER_REGEN_ENABLED", function() if pendingProtected then pendingProtected = false Refresh() end end)
RH.On("PLAYER_ENTERING_WORLD", UpdateWeaponState)
