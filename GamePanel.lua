local _, RH = ...
if not RH.isRogue then return end

local function RegisterGamePanel()
  if not (Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory) then return end

  local panel = CreateFrame("Frame", "RogueHUDGamePanel", UIParent)
  local title = RH.NewText(panel, 20)
  title:SetPoint("TOPLEFT", panel, "TOPLEFT", 18, -20)
  title:SetText("RogueHUD")

  local description = RH.NewText(panel, 13)
  description:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -15)
  description:SetWidth(500)
  description:SetJustifyH("LEFT")
  description:SetWordWrap(true)
  description:SetText("Energy, combo points, poisons, cooldowns, and combat cues for rogues. Open the RogueHUD window to configure them.")

  local button = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
  button:SetSize(200, 28)
  button:SetPoint("TOPLEFT", description, "BOTTOMLEFT", 0, -18)
  button:SetText("Open RogueHUD Settings")
  button:SetScript("OnClick", function()
    if SettingsPanel and HideUIPanel and not InCombatLockdown() then
      pcall(HideUIPanel, SettingsPanel)
    end
    RH.ShowOptions()
  end)

  local category = Settings.RegisterCanvasLayoutCategory(panel, "RogueHUD")
  Settings.RegisterAddOnCategory(category)
  RH.settingsCategory = category
end

RH.On("PLAYER_LOGIN", RegisterGamePanel)
