local _, RH = ...
if not RH.isRogue then return end

local Style = {}
RH.Style = Style
local WHITE = "Interface\\Buttons\\WHITE8X8"
local MEDIA = "Interface\\AddOns\\RogueHUD\\Media\\"
local bars = {smooth = MEDIA .. "bar_smooth", flat = WHITE,
  blizzard = "Interface\\TargetingFrame\\UI-StatusBar"}
local fonts = {default = nil, friz = "Fonts\\FRIZQT__.TTF", arial = "Fonts\\ARIALN.TTF"}
local bundledFonts = {
  ["Inter"] = MEDIA .. "Fonts\\Inter-Regular.ttf",
  ["Inter Medium"] = MEDIA .. "Fonts\\Inter-Medium.ttf",
  ["Inter SemiBold"] = MEDIA .. "Fonts\\Inter-SemiBold.ttf",
}
local styledText = setmetatable({}, {__mode = "k"})
local watchedMedia, pendingFonts

local function SharedMedia()
  if not LibStub then return nil end
  local ok, media = pcall(LibStub, "LibSharedMedia-3.0", true)
  return ok and media or nil
end

function Style.ResolveFont(name)
  if bundledFonts[name] then
    local media = SharedMedia()
    if media and media.Fetch then
      local ok, path = pcall(media.Fetch, media, "font", name, true)
      if ok and type(path) == "string" and path ~= "" then return path end
    end
  end
  return bundledFonts[name] or fonts[name] or STANDARD_TEXT_FONT
end

function Style.RefreshFonts()
  if not RH.db then return end
  if InCombatLockdown and InCombatLockdown() then pendingFonts = true return end
  pendingFonts = nil
  for fs, size in pairs(styledText) do Style.Text(fs, size or nil) end
end

local function WatchMedia()
  local media = SharedMedia()
  if not media or media == watchedMedia then return end
  watchedMedia = media
  if media.RegisterCallback then
    media.RegisterCallback(Style, "LibSharedMedia_Registered", function(_, mediaType, name)
      if mediaType == "font" and bundledFonts[name] and RH.db and RH.db.style.font == name then
        Style.RefreshFonts()
      end
    end)
  end
  Style.RefreshFonts()
end

RH.On("ADDON_LOADED", WatchMedia)
RH.On("PLAYER_LOGIN", WatchMedia)
RH.On("PLAYER_REGEN_ENABLED", function() if pendingFonts then Style.RefreshFonts() end end)

local function Tint(region, color)
  region:SetVertexColor(color[1], color[2], color[3], color[4] or 1)
end

function Style.Pixel(frame)
  local scale = frame:GetEffectiveScale()
  local height
  if GetPhysicalScreenSize then
    local _, physicalHeight = GetPhysicalScreenSize()
    height = physicalHeight
  end
  return 768 / (height and height > 0 and height or 768) / (scale and scale > 0 and scale or 1)
end

local function Solid(frame, layer, sublevel)
  local tex = frame:CreateTexture(nil, layer, nil, sublevel)
  tex:SetTexture(WHITE)
  if tex.SetSnapToPixelGrid then tex:SetSnapToPixelGrid(false) tex:SetTexelSnappingBias(0) end
  return tex
end

function Style.CreatePanel(frame)
  if frame.rhPanel then return frame.rhPanel end
  local panel = {edges = {}}
  panel.bg = Solid(frame, "BACKGROUND", -8)
  panel.bg:SetAllPoints(frame)
  for _, side in ipairs({"top", "bottom", "left", "right"}) do
    panel.edges[side] = Solid(frame, "OVERLAY", 7)
  end
  panel.edges.top:SetPoint("TOPLEFT")
  panel.edges.top:SetPoint("TOPRIGHT")
  panel.edges.bottom:SetPoint("BOTTOMLEFT")
  panel.edges.bottom:SetPoint("BOTTOMRIGHT")
  panel.edges.left:SetPoint("TOPLEFT")
  panel.edges.left:SetPoint("BOTTOMLEFT")
  panel.edges.right:SetPoint("TOPRIGHT")
  panel.edges.right:SetPoint("BOTTOMRIGHT")
  frame.rhPanel = panel
  return panel
end

function Style.BorderColor(frame, color)
  local panel = frame.rhPanel
  if not panel then return end
  for _, edge in pairs(panel.edges) do Tint(edge, color) end
  if frame.rhPlate then Tint(frame.rhPlate, color) end
end

function Style.ApplyPanel(frame, icon)
  local cfg = RH.db.style
  local panel = Style.CreatePanel(frame)
  local size = icon and cfg.ownIconBorder and cfg.iconBorderSize or cfg.borderSize
  local color = icon and cfg.ownIconBorder and cfg.iconBorderColor or cfg.borderColor
  local inset = math.max(0, size or 0) * Style.Pixel(frame)
  Tint(panel.bg, cfg.backdropColor)
  for side, edge in pairs(panel.edges) do
    edge:SetShown(inset > 0 and not (icon and cfg.iconShape ~= "square"))
    if side == "top" or side == "bottom" then edge:SetHeight(inset)
    else edge:SetWidth(inset) end
  end
  Style.BorderColor(frame, color)
  if cfg.shadow then
    if not frame.rhShadow then
      frame.rhShadow = frame:CreateTexture(nil, "BACKGROUND", nil, -7)
      frame.rhShadow:SetTexture(MEDIA .. "shadow")
      frame.rhShadow:SetVertexColor(0, 0, 0, 0.65)
      frame.rhShadow:SetPoint("TOPLEFT", -6, 6)
      frame.rhShadow:SetPoint("BOTTOMRIGHT", 6, -6)
    end
    frame.rhShadow:Show()
  elseif frame.rhShadow then frame.rhShadow:Hide() end
  return inset
end

local function Inset(region, frame, amount)
  region:ClearAllPoints()
  region:SetPoint("TOPLEFT", frame, "TOPLEFT", amount, -amount)
  region:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -amount, amount)
end

function Style.ApplyBar(frame)
  local cfg = RH.db.style
  local texture = bars[cfg.barTexture] or bars.smooth
  if frame.rhBarTexture ~= texture then
    frame:SetStatusBarTexture(texture)
    frame.rhBarTexture = texture
  end
  local inset = Style.ApplyPanel(frame, false)
  Inset(frame:GetStatusBarTexture(), frame, inset)
end

function Style.CreateIcon(frame, texture)
  Style.CreatePanel(frame)
  frame.texture = texture or frame:CreateTexture(nil, "ARTWORK")
  frame.rhPlate = frame:CreateTexture(nil, "BACKGROUND", nil, -7)
  frame.rhPlate:SetAllPoints(frame)
  frame.rhShade = frame:CreateTexture(nil, "OVERLAY", nil, 1)
  frame.rhShade:SetTexture(MEDIA .. "icon_shade")
  frame.rhGloss = frame:CreateTexture(nil, "OVERLAY", nil, 2)
  frame.rhGloss:SetTexture(MEDIA .. "icon_gloss")
  frame.rhGloss:SetBlendMode("ADD")
end

function Style.ApplyIcon(frame)
  local cfg = RH.db.style
  local inset = Style.ApplyPanel(frame, true)
  local shape = cfg.iconShape
  local maskPath = shape == "circle" and MEDIA .. "mask_circle"
    or shape == "rounded" and MEDIA .. "mask_rounded" or nil
  if frame.rhMask then
    frame.texture:RemoveMaskTexture(frame.rhMask)
    frame.rhShade:RemoveMaskTexture(frame.rhMask)
    frame.rhGloss:RemoveMaskTexture(frame.rhMask)
  end
  if maskPath then
    if not frame.rhMask then frame.rhMask = frame:CreateMaskTexture() end
    frame.rhMask:SetTexture(maskPath)
    Inset(frame.rhMask, frame, inset)
    frame.texture:AddMaskTexture(frame.rhMask)
    frame.rhShade:AddMaskTexture(frame.rhMask)
    frame.rhGloss:AddMaskTexture(frame.rhMask)
    frame.rhPlate:SetTexture(maskPath)
    frame.rhPlate:SetShown(inset > 0)
    frame.rhPanel.bg:Hide()
    local bc = cfg.ownIconBorder and cfg.iconBorderColor or cfg.borderColor
    Tint(frame.rhPlate, bc)
  else
    frame.rhPlate:Hide()
    frame.rhPanel.bg:Show()
  end
  for _, region in ipairs({frame.texture, frame.rhShade, frame.rhGloss}) do Inset(region, frame, inset) end
  local zoom = math.max(0, math.min(0.25, cfg.iconZoom or 0))
  frame.texture:SetTexCoord(zoom, 1 - zoom, zoom, 1 - zoom)
  frame.rhShade:SetShown(cfg.iconOverlay == "shade" or cfg.iconOverlay == "both")
  frame.rhGloss:SetShown(cfg.iconOverlay == "gloss" or cfg.iconOverlay == "both")
  if frame.cooldown then
    Inset(frame.cooldown, frame, inset)
    if frame.cooldown.SetSwipeColor then frame.cooldown:SetSwipeColor(0, 0, 0, cfg.swipeAlpha) end
    if frame.cooldown.SetSwipeTexture then pcall(frame.cooldown.SetSwipeTexture, frame.cooldown, maskPath or WHITE) end
    if frame.cooldown.SetUseCircularEdge then pcall(frame.cooldown.SetUseCircularEdge, frame.cooldown, shape == "circle") end
  end
  if frame.auraCooldown then
    Inset(frame.auraCooldown, frame, inset)
    if frame.auraCooldown.SetSwipeTexture then pcall(frame.auraCooldown.SetSwipeTexture, frame.auraCooldown, maskPath or WHITE) end
  end
  return inset
end

function Style.Text(fs, size)
  local cfg = RH.db.style
  styledText[fs] = size or false
  if InCombatLockdown and InCombatLockdown() then pendingFonts = true return end
  local path = Style.ResolveFont(cfg.font)
  local ok, applied = pcall(fs.SetFont, fs, path, size or cfg.fontSize, cfg.fontOutline)
  if (not ok or applied == false) and bundledFonts[cfg.font] then
    fs:SetFont(bundledFonts[cfg.font], size or cfg.fontSize, cfg.fontOutline)
  end
  local palette = RH.db.theme == "dark" and RH.db.darkColors or RH.db.colors
  local c = palette.text
  fs:SetTextColor(c[1], c[2], c[3], c[4])
end
