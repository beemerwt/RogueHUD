local _, RH = ...
if not RH.isRogue then return end

local button
local ICON = "Interface\\Icons\\Ability_Rogue_Eviscerate"
local DEFAULT_POSITION = 225

local function Position()
  if not button then return end
  local angle = math.rad(RH.characterDB.minimapPos or DEFAULT_POSITION)
  local radius = Minimap:GetWidth() / 2 + 10
  button:ClearAllPoints()
  button:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

local function Refresh()
  if not button then return end
  button:SetShown(RH.db.enabled and RH.characterDB.minimapHidden ~= true)
  Position()
end

local function Drag(self)
  local centerX, centerY = Minimap:GetCenter()
  if not centerX or not centerY then return end
  local scale = Minimap:GetEffectiveScale()
  if not scale or scale == 0 then return end
  local cursorX, cursorY = GetCursorPosition()
  RH.characterDB.minimapPos = math.deg(math.atan2(cursorY / scale - centerY, cursorX / scale - centerX)) % 360
  Position()
end

local function Build()
  button = CreateFrame("Button", "RogueHUDMinimapButton", Minimap)
  button:SetSize(31, 31)
  button:SetFrameStrata("MEDIUM")
  button:SetFrameLevel(8)
  button:RegisterForClicks("LeftButtonUp")
  button:RegisterForDrag("LeftButton")
  button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight", "ADD")

  local background = button:CreateTexture(nil, "BACKGROUND")
  background:SetSize(20, 20)
  background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
  background:SetPoint("TOPLEFT", 7, -5)

  local icon = button:CreateTexture(nil, "ARTWORK")
  icon:SetSize(17, 17)
  icon:SetTexture(ICON)
  icon:SetPoint("TOPLEFT", 7, -6)

  local border = button:CreateTexture(nil, "OVERLAY")
  border:SetSize(53, 53)
  border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  border:SetPoint("TOPLEFT")

  button:SetScript("OnClick", function() RH.ToggleOptions() end)
  button:SetScript("OnDragStart", function(self)
    self:LockHighlight()
    self:SetScript("OnUpdate", Drag)
  end)
  button:SetScript("OnDragStop", function(self)
    Drag(self)
    self:SetScript("OnUpdate", nil)
    self:UnlockHighlight()
  end)
  button:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("RogueHUD")
    GameTooltip:AddLine("Left-click: Open or close settings", 1, 1, 1)
    GameTooltip:AddLine("Drag: Move around minimap", 1, 1, 1)
    GameTooltip:Show()
  end)
  button:SetScript("OnLeave", function() GameTooltip:Hide() end)
  Refresh()
end

RH.On("PLAYER_LOGIN", Build)
RH.AddRefresh(Refresh)
