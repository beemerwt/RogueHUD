local _, RH = ...
if not RH.isRogue then return end

local WHITE = "Interface\\Buttons\\WHITE8X8"
local frame, bar, icon, nameClip, nameText, timeText, latency
local borders = {}
local durationObject, startMS, endMS, channel, timed
local takenEvents = {}
local gameFrame

local GAME_EVENTS = {
  "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_DELAYED",
  "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_STOP", "UNIT_SPELLCAST_CHANNEL_UPDATE",
  "UNIT_SPELLCAST_EMPOWER_START", "UNIT_SPELLCAST_EMPOWER_STOP", "UNIT_SPELLCAST_EMPOWER_UPDATE",
  "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED",
  "UNIT_SPELLCAST_INTERRUPTIBLE", "UNIT_SPELLCAST_NOT_INTERRUPTIBLE",
}

local function Wanted()
  return RH.db and RH.db.enabled and RH.db.cast.enabled
end

local function RestoreGameBar()
  if gameFrame and gameFrame.RegisterUnitEvent then
    for event in pairs(takenEvents) do
      if RH.Safe(gameFrame.IsEventRegistered, gameFrame, event) ~= true then
        RH.Safe(gameFrame.RegisterUnitEvent, gameFrame, event, "player")
      end
    end
  end
  takenEvents = {}
  gameFrame = nil
end

local function SyncGameBar()
  if not Wanted() then RestoreGameBar() return end
  local game = rawget(_G, "PlayerCastingBarFrame")
  if not (game and game.IsEventRegistered and game.UnregisterEvent) then return end
  if gameFrame and gameFrame ~= game then RestoreGameBar() end
  gameFrame = game
  for _, event in ipairs(GAME_EVENTS) do
    if RH.Safe(game.IsEventRegistered, game, event) == true then
      local ok = pcall(game.UnregisterEvent, game, event)
      if ok then takenEvents[event] = true end
    end
  end
  if game.IsShown and RH.Safe(game.IsShown, game) == true then RH.Safe(game.Hide, game) end
end

local function MediaTexture()
  local choice = RH.db.cast.texture
  if choice == "details" then
    if LibStub then
      local media = RH.Safe(LibStub, "LibSharedMedia-3.0", true)
      local path = media and RH.Safe(media.Fetch, media, "statusbar", "Details Flat", true)
      if type(path) == "string" and path ~= "" then return path end
    end
    return WHITE
  end
  if choice == "blizzard" then return "Interface\\TargetingFrame\\UI-StatusBar" end
  if choice == "smooth" then return "Interface\\AddOns\\RogueHUD\\Media\\bar_smooth" end
  return WHITE
end

local function NewSolid(parent, layer)
  local texture = parent:CreateTexture(nil, layer)
  texture:SetTexture(WHITE)
  return texture
end

local function Build()
  frame = CreateFrame("Frame", "RogueHUDCastbar", UIParent)
  frame:SetFrameStrata("MEDIUM")
  frame:Hide()
  frame:EnableMouse(false)

  icon = frame:CreateTexture(nil, "ARTWORK")

  bar = CreateFrame("StatusBar", nil, frame)
  bar:SetMinMaxValues(0, 1)
  bar:SetValue(0)
  bar:EnableMouse(false)
  local bg = NewSolid(bar, "BACKGROUND")
  bg:SetAllPoints(bar)
  bg:SetVertexColor(0, 0, 0, 0.5)
  local borderLayer = CreateFrame("Frame", nil, bar)
  borderLayer:SetAllPoints(bar)
  borderLayer:SetFrameLevel(bar:GetFrameLevel() + 2)
  for _, side in ipairs({"TOP", "BOTTOM", "LEFT", "RIGHT"}) do
    local edge = NewSolid(borderLayer, "OVERLAY")
    borders[side] = edge
    edge:SetVertexColor(0, 0, 0, 1)
    if side == "TOP" then edge:SetPoint("TOPLEFT") edge:SetPoint("TOPRIGHT")
    elseif side == "BOTTOM" then edge:SetPoint("BOTTOMLEFT") edge:SetPoint("BOTTOMRIGHT")
    elseif side == "LEFT" then edge:SetPoint("TOPLEFT") edge:SetPoint("BOTTOMLEFT")
    else edge:SetPoint("TOPRIGHT") edge:SetPoint("BOTTOMRIGHT") end
    if side == "TOP" or side == "BOTTOM" then edge:SetHeight(1) else edge:SetWidth(1) end
  end

  latency = CreateFrame("StatusBar", nil, bar)
  latency:SetAllPoints(bar)
  latency:SetFrameLevel(bar:GetFrameLevel() + 1)
  latency:SetStatusBarTexture(WHITE)
  latency:SetStatusBarColor(1, 0.1, 0.1, 0.7)
  latency:Hide()

  local overlay = CreateFrame("Frame", nil, frame)
  overlay:SetAllPoints(frame)
  overlay:SetFrameLevel(bar:GetFrameLevel() + 3)
  nameClip = CreateFrame("Frame", nil, overlay)
  nameClip:SetClipsChildren(true)
  nameText = RH.NewText(nameClip, 12)
  nameText:SetJustifyH("CENTER")
  nameText:SetWordWrap(false)
  timeText = RH.NewText(overlay, 12)
  timeText:SetJustifyH("RIGHT")
  timeText:SetWidth(48)
  timeText:SetPoint("RIGHT", bar, "RIGHT", -4, 0)
  frame:SetScript("OnUpdate", function(_, elapsed)
    if RH.preview then return end
    frame.elapsed = (frame.elapsed or 0) + elapsed
    if frame.elapsed < 0.05 then return end
    frame.elapsed = 0
    local remaining
    if durationObject and durationObject.GetRemainingDuration then
      remaining = RH.Safe(durationObject.GetRemainingDuration, durationObject)
    end
    if not RH.IsSecret(remaining) and remaining == nil and type(endMS) == "number" then
      remaining = math.max(0, endMS / 1000 - GetTime())
    end
    local shownTime = RH.Safe(string.format, "%.1f", remaining)
    if RH.IsSecret(shownTime) then timeText:SetText(shownTime)
    else timeText:SetText(shownTime or "") end
    if not timed and type(startMS) == "number" and type(endMS) == "number" and endMS > startMS then
      local progress = math.max(0, math.min(1, (GetTime() * 1000 - startMS) / (endMS - startMS)))
      bar:SetValue(channel and 1 - progress or progress)
    end
    if not RH.IsSecret(remaining) and remaining == 0 then RH.UpdateCastbar() end
  end)
  RH.castBar = frame
end

function RH.PositionCastbar()
  if not (frame and RH.hud and RH.db) then return end
  local cfg = RH.db.cast
  frame:SetScale(RH.db.scale)
  frame:SetAlpha(1)
  frame:SetSize(RH.db.width, cfg.height)
  icon:SetShown(cfg.icon)
  local zoom = math.max(0, math.min(0.45, cfg.iconZoom))
  icon:SetTexCoord(zoom, 1 - zoom, zoom, 1 - zoom)
  icon:ClearAllPoints()
  icon:SetPoint("LEFT", frame, "LEFT")
  icon:SetSize(cfg.iconSize, cfg.iconSize)
  bar:ClearAllPoints()
  local iconSpace = cfg.icon and (cfg.iconSize + cfg.iconGap * RH.Style.Pixel(frame)) or 0
  bar:SetPoint("TOPLEFT", frame, "TOPLEFT", iconSpace, 0)
  bar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT")
  bar:SetStatusBarTexture(MediaTexture())
  local pixel = RH.Style.Pixel(bar)
  borders.TOP:SetHeight(pixel)
  borders.BOTTOM:SetHeight(pixel)
  borders.LEFT:SetWidth(pixel)
  borders.RIGHT:SetWidth(pixel)
  local c = cfg.color
  bar:SetStatusBarColor(c[1], c[2], c[3], c[4] or 1)
  RH.Style.Text(nameText, cfg.fontSize)
  RH.Style.Text(timeText, cfg.fontSize)
  nameClip:ClearAllPoints()
  nameClip:SetPoint("LEFT", bar, "LEFT", 4, 0)
  nameClip:SetSize(math.max(1, RH.db.width - iconSpace - 60), cfg.height)
  nameText:SetJustifyH(cfg.textAlign)
  nameText:ClearAllPoints()
  local textOffset = cfg.textOffset * RH.Style.Pixel(frame)
  nameText:SetPoint("LEFT", nameClip, "LEFT", textOffset, 0)
  nameText:SetPoint("RIGHT", nameClip, "RIGHT", textOffset, 0)
  frame:ClearAllPoints()
  local gap = cfg.offset * RH.Style.Pixel(RH.hud)
  local protrusion = cfg.icon and math.max(0, (cfg.iconSize - cfg.height) / 2) or 0
  if cfg.side == "ABOVE" then
    frame:SetPoint("BOTTOM", RH.hud, "TOP", 0, (RH.hudStackTop or 0) + gap + protrusion)
  else
    frame:SetPoint("TOP", RH.hud, "TOP", 0, (RH.hudStackBottom or -RH.hud:GetHeight()) - gap - protrusion)
  end
end

local function SetLatency()
  latency:Hide()
  if not RH.db.cast.latency then return end
  local _, _, _, world = RH.Safe(GetNetStats)
  world = RH.Plain(world)
  if type(world) ~= "number" then return end
  local total = durationObject and durationObject.GetTotalDuration
    and RH.Safe(durationObject.GetTotalDuration, durationObject)
  if not RH.IsSecret(total) and type(total) ~= "number" and startMS and endMS then
    total = (endMS - startMS) / 1000
  end
  if not RH.IsSecret(total) and (type(total) ~= "number" or total <= 0) then return end
  if not pcall(latency.SetMinMaxValues, latency, 0, total) then return end
  latency:SetValue(world / 1000)
  if latency.SetReverseFill then latency:SetReverseFill(not channel) end
  latency:Show()
end

function RH.UpdateCastbar(resetTimer)
  if not frame then return end
  SyncGameBar()
  if not Wanted() then frame:Hide() durationObject = nil return end
  if RH.preview then
    durationObject, startMS, endMS, timed = nil, nil, nil, false
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0.6)
    nameText:SetText("Sample cast")
    timeText:SetText("1.4")
    icon:SetTexture("Interface\\Icons\\Ability_Rogue_Eviscerate")
    latency:SetMinMaxValues(0, 3)
    latency:SetValue(0.1)
    if latency.SetReverseFill then latency:SetReverseFill(true) end
    latency:SetShown(RH.db.cast.latency)
    frame:Show()
    return
  end
  local casting = RH.Safe(function() return UnitCastingInfo("player") ~= nil end) == true
  local isChannel = not casting and RH.Safe(function() return UnitChannelInfo("player") ~= nil end) == true
  if not casting and not isChannel then frame:Hide() durationObject = nil return end
  if resetTimer or not frame:IsShown() or channel ~= isChannel then
    channel = isChannel
    local name, texture, startTime, endTime
    if channel then name, _, texture, startTime, endTime = RH.Safe(UnitChannelInfo, "player")
    else name, _, texture, startTime, endTime = RH.Safe(UnitCastingInfo, "player") end
    nameText:SetText(name)
    icon:SetTexture(texture)
    startMS, endMS = RH.Plain(startTime), RH.Plain(endTime)
    durationObject = RH.Safe(channel and UnitChannelDuration or UnitCastingDuration, "player")
    timed = false
    if durationObject and bar.SetTimerDuration and Enum and Enum.StatusBarTimerDirection then
      local direction = channel and Enum.StatusBarTimerDirection.RemainingTime or Enum.StatusBarTimerDirection.ElapsedTime
      local interpolation = Enum.StatusBarInterpolation and Enum.StatusBarInterpolation.Immediate
      timed = pcall(bar.SetTimerDuration, bar, durationObject, interpolation, direction)
    end
    if not timed then bar:SetMinMaxValues(0, 1) bar:SetValue(0) end
    SetLatency()
  end
  frame:Show()
end

local function Refresh()
  if not frame then return end
  RH.PositionCastbar()
  RH.UpdateCastbar(true)
end

RH.On("PLAYER_LOGIN", Build)
RH.AddRefresh(Refresh)
RH.On("PLAYER_ENTERING_WORLD", function() if frame then RH.UpdateCastbar(true) end end)
for _, event in ipairs({
  "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_DELAYED", "UNIT_SPELLCAST_CHANNEL_UPDATE",
  "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_CHANNEL_STOP", "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_FAILED",
}) do
  RH.On(event, function(_, unit)
    if unit ~= "player" then return end
    RH.UpdateCastbar(true)
    if event == "UNIT_SPELLCAST_STOP" or event == "UNIT_SPELLCAST_CHANNEL_STOP"
      or event == "UNIT_SPELLCAST_INTERRUPTED" or event == "UNIT_SPELLCAST_FAILED" then
      if C_Timer and C_Timer.After then C_Timer.After(0.1, function() RH.UpdateCastbar(true) end) end
    end
  end)
end
