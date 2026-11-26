local _, RH = ...
if not RH.isRogue then return end

local window, scroll, content, page = nil, nil, nil, "welcome"
local rowY = -10
local olderWindows, focusedInput, childEscape, hookedPicker = {}, nil, false, nil

local function MarkChildEscape()
  childEscape = true
  window:SetScript("OnUpdate", function(self)
    childEscape = false
    self:SetScript("OnUpdate", nil)
  end)
end

local function TrackColorPicker()
  if not (ColorPickerFrame and ColorPickerFrame.HookScript) or hookedPicker == ColorPickerFrame then return end
  hookedPicker = ColorPickerFrame
  hookedPicker:HookScript("OnHide", function() if window:IsShown() then MarkChildEscape() end end)
end

local function TrackInput(edit)
  edit:HookScript("OnEditFocusGained", function(self) focusedInput = self end)
  edit:HookScript("OnEditFocusLost", function(self) if focusedInput == self then focusedInput = nil end end)
end

local function NativeEscape(enabled)
  if type(UISpecialFrames) ~= "table" then return end
  for i = #UISpecialFrames, 1, -1 do
    if UISpecialFrames[i] == "RogueHUDOptions" then table.remove(UISpecialFrames, i) end
  end
  if enabled then UISpecialFrames[#UISpecialFrames + 1] = "RogueHUDOptions" end
end

local function RememberOlderWindows()
  olderWindows = {}
  local function Add(frame)
    if frame and frame ~= window and frame.IsShown and frame:IsShown() then olderWindows[frame] = true end
  end
  if type(UISpecialFrames) == "table" then
    for _, name in ipairs(UISpecialFrames) do Add(_G[name]) end
  end
  for _, slot in ipairs({"left", "center", "doublewide", "fullscreen"}) do Add(UIParent[slot]) end
  Add(SettingsPanel)
  Add(GameMenuFrame)
end

local function OlderWindowOpen()
  for frame in pairs(olderWindows) do
    if frame:IsShown() then return true end
    olderWindows[frame] = nil
  end
  return false
end

local function UseNativeEscape()
  window:EnableKeyboard(false)
  NativeEscape(true)
end

local function UseKeyboardEscape()
  if (InCombatLockdown and InCombatLockdown()) or not window.SetPropagateKeyboardInput then
    UseNativeEscape()
    return
  end
  window:EnableKeyboard(true)
  if not pcall(window.SetPropagateKeyboardInput, window, true) then
    UseNativeEscape()
    return
  end
  NativeEscape(false)
end

local function PathGet(path)
  local value = RH.db
  for part in path:gmatch("[^.]+") do
    value = type(value) == "table" and value[part] or nil
  end
  return value
end

local function PathSet(path, value)
  local target, last = RH.db, nil
  for part in path:gmatch("[^.]+") do
    if last then target = target[last] end
    last = part
  end
  if type(target) == "table" then target[last] = value RH.Refresh() end
end

local function NewLabel(parent, text, size)
  local fs = RH.NewText(parent, size or 12)
  fs:SetJustifyH("LEFT")
  fs:SetText(text)
  return fs
end

local function Row(height)
  local frame = CreateFrame("Frame", nil, content)
  frame:SetSize(385, height or 28)
  frame:SetPoint("TOPLEFT", content, "TOPLEFT", 10, rowY)
  rowY = rowY - (height or 28) - 5
  content:SetHeight(math.max(1, -rowY + 20))
  return frame
end

local function Header(text)
  local frame = Row(30)
  local title = NewLabel(frame, text, 15)
  title:SetPoint("BOTTOMLEFT", 0, 4)
  title:SetTextColor(1, 0.69, 0.21)
  return frame
end

local function Note(text)
  local frame = Row(42)
  local label = NewLabel(frame, text, 11)
  label:SetTextColor(0.8, 0.8, 0.82)
  label:SetWidth(375)
  label:SetPoint("TOPLEFT", 0, -3)
  label:SetWordWrap(true)
end

local function Button(frame, text, width, callback)
  local button = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  button:SetSize(width, 23)
  button:SetText(text)
  button:SetScript("OnClick", callback)
  return button
end

local function Toggle(label, path)
  local frame = Row()
  local box = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
  box:SetPoint("LEFT", -4, 0)
  box:SetChecked(PathGet(path) == true)
  box:SetScript("OnClick", function(self) PathSet(path, self:GetChecked() == true) end)
  local text = NewLabel(frame, label)
  text:SetPoint("LEFT", box, "RIGHT", 1, 0)
end

local function Number(label, path, minValue, maxValue, step)
  local frame = Row()
  local text = NewLabel(frame, label)
  text:SetPoint("LEFT", 0, 0)
  local edit = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
  TrackInput(edit)
  edit:SetSize(67, 21)
  edit:SetAutoFocus(false)
  edit:SetPoint("RIGHT", -2, 0)
  edit:SetText(tostring(PathGet(path) or 0))
  edit:SetScript("OnEnterPressed", function(self)
    local value = tonumber(self:GetText())
    if value then
      value = math.max(minValue, math.min(maxValue, value))
      if step and step > 0 then value = math.floor(value / step + 0.5) * step end
      PathSet(path, value)
    end
    self:SetText(tostring(PathGet(path) or 0))
    self:ClearFocus()
  end)
  edit:SetScript("OnEscapePressed", function(self) MarkChildEscape() self:SetText(tostring(PathGet(path) or 0)) self:ClearFocus() end)
end

local function Choice(label, path, options)
  local frame = Row()
  local text = NewLabel(frame, label)
  text:SetPoint("LEFT", 0, 0)
  local function LabelFor(value)
    for _, option in ipairs(options) do if option[1] == value then return option[2] end end
    return tostring(value)
  end
  local button = Button(frame, LabelFor(PathGet(path)), 145, function(self)
    local current = PathGet(path)
    local index = 0
    for i, option in ipairs(options) do if option[1] == current then index = i end end
    local nextValue = options[index % #options + 1][1]
    PathSet(path, nextValue)
    self:SetText(LabelFor(nextValue))
  end)
  button:SetPoint("RIGHT", -2, 0)
end

local function ColorSetting(label, path)
  local frame = Row()
  local text = NewLabel(frame, label)
  text:SetPoint("LEFT", 0, 0)
  local function Current() return PathGet(path) or {1, 1, 1, 1} end
  local button = Button(frame, "Choose", 105, function()
    if not ColorPickerFrame then return end
    TrackColorPicker()
    local source = Current()
    local old = {source[1], source[2], source[3], source[4] or 1}
    local function Save()
      local r, g, b = ColorPickerFrame:GetColorRGB()
      local a = ColorPickerFrame.GetColorAlpha and ColorPickerFrame:GetColorAlpha() or old[4]
      PathSet(path, {r, g, b, a or 1})
      frame.swatch:SetVertexColor(r, g, b, a or 1)
    end
    local info = {
      r = old[1], g = old[2], b = old[3], opacity = old[4], hasOpacity = true,
      swatchFunc = Save, opacityFunc = Save,
      cancelFunc = function()
        PathSet(path, old)
        frame.swatch:SetVertexColor(old[1], old[2], old[3], old[4])
      end,
    }
    if ColorPickerFrame.SetupColorPickerAndShow then ColorPickerFrame:SetupColorPickerAndShow(info)
    else
      ColorPickerFrame.func, ColorPickerFrame.opacityFunc = Save, Save
      ColorPickerFrame.cancelFunc = info.cancelFunc
      ColorPickerFrame.hasOpacity, ColorPickerFrame.opacity = true, 1 - old[4]
      ColorPickerFrame:SetColorRGB(old[1], old[2], old[3])
      ColorPickerFrame:Show()
    end
  end)
  button:SetPoint("RIGHT", -2, 0)
  local swatch = frame:CreateTexture(nil, "ARTWORK")
  swatch:SetTexture("Interface\\Buttons\\WHITE8X8")
  swatch:SetSize(20, 20)
  swatch:SetPoint("RIGHT", button, "LEFT", -8, 0)
  local c = Current()
  swatch:SetVertexColor(c[1], c[2], c[3], c[4] or 1)
  frame.swatch = swatch
end

local function Action(label, buttonText, callback)
  local frame = Row()
  local text = NewLabel(frame, label)
  text:SetPoint("LEFT", 0, 0)
  local button = Button(frame, buttonText, 105, callback)
  button:SetPoint("RIGHT", -2, 0)
  return button
end

local function TextInput(label, value, onSave)
  local frame = Row(47)
  local title = NewLabel(frame, label, 11)
  title:SetPoint("TOPLEFT", 0, -2)
  local edit = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
  TrackInput(edit)
  edit:SetSize(335, 21)
  edit:SetAutoFocus(false)
  if edit.SetMaxLetters then edit:SetMaxLetters(0) end
  edit:SetPoint("BOTTOMLEFT", 7, 1)
  edit:SetText(value or "")
  edit:SetScript("OnEnterPressed", function(self) onSave(self:GetText()) self:ClearFocus() end)
  edit:SetScript("OnEscapePressed", function(self) MarkChildEscape() self:ClearFocus() end)
  return edit
end

local function IDs(list)
  local result = {}
  for _, id in ipairs(list or {}) do result[#result + 1] = tostring(id) end
  return table.concat(result, ", ")
end

local function ParseIDs(text)
  local result, seen = {}, {}
  for token in text:gmatch("[^,%s]+") do
    local id = tonumber(token)
    if id and id > 0 and id < 10000000 and id == math.floor(id) and not seen[id] then
      result[#result + 1] = id
      seen[id] = true
    end
  end
  return result
end

local function Hex(text)
  return tostring(text):gsub(".", function(char) return string.format("%02X", char:byte()) end)
end
local function Unhex(text)
  if #text % 2 ~= 0 or text:find("[^0-9A-F]") then return nil end
  return text:gsub("..", function(pair) return string.char(tonumber(pair, 16)) end)
end

local function ExportProfile()
  local entries = {}
  local function Visit(value, path)
    if type(value) == "table" then
      for key, child in pairs(value) do Visit(child, path == "" and tostring(key) or path .. "." .. tostring(key)) end
    else
      local kind = type(value) == "boolean" and "b" or type(value) == "number" and "n" or "s"
      entries[#entries + 1] = Hex(path) .. ":" .. kind .. ":" .. Hex(tostring(value))
    end
  end
  Visit(RH.db, "")
  table.sort(entries)
  return "RHUD1:" .. table.concat(entries, ";")
end
RH.ExportProfile = ExportProfile

local function ImportProfile(code)
  if type(code) ~= "string" or #code > 100000 or code:sub(1, 6) ~= "RHUD1:" then return false end
  local data = RH.Copy(RH.defaults)
  data.cast = {}
  data.styleVersion = 0
  for entry in code:sub(7):gmatch("[^;]+") do
    local rawPath, kind, rawValue = entry:match("^([0-9A-F]+):([bns]):([0-9A-F]*)$")
    local path, stringValue = rawPath and Unhex(rawPath), rawValue and Unhex(rawValue)
    if not path or not stringValue or not path:match("^[%w_.]+$") then return false end
    local value
    if kind == "b" then value = stringValue == "true"
    elseif kind == "n" then value = tonumber(stringValue)
    else value = stringValue end
    if value == nil then return false end
    local target, pieces = data, {}
    for part in path:gmatch("[^.]+") do pieces[#pieces + 1] = tonumber(part) or part end
    if RH.defaults[pieces[1]] == nil and pieces[1] ~= "stealth" then return false end
    if pieces[1] ~= "stealth" then
      for i = 1, #pieces - 1 do
        if type(target[pieces[i]]) ~= "table" then target[pieces[i]] = {} end
        target = target[pieces[i]]
      end
      target[pieces[#pieces]] = value
    end
  end
  RH.MigrateStyle(data)
  RH.MigrateCast(data)
  RH.MigrateTheme(data)
  RH.Fill(data, RH.defaults)
  RH.NormalizeBarOrder(data)
  local baseName = "Imported " .. date("%Y%m%d-%H%M%S")
  local newName = baseName
  local suffix = 2
  while RogueHUDDB.profiles[newName] do
    newName = baseName .. " " .. suffix
    suffix = suffix + 1
  end
  RogueHUDDB.profiles[newName] = data
  RogueHUDDB.active = newName
  RH.db = data
  RH.db.profile = newName
  RH.Refresh()
  return true
end
RH.ImportProfile = ImportProfile

local function OrderPoison(key, step)
  local order = RH.db.poison.order
  for i, value in ipairs(order) do
    if value == key then
      local other = i + step
      if other >= 1 and other <= #order then order[i], order[other] = order[other], order[i] end
      RH.Refresh()
      RH.ShowOptions("poisons")
      return
    end
  end
end

local function OrderBar(key, step)
  local order = RH.db.barOrder
  for index, value in ipairs(order) do
    if value == key then
      local other = index + step
      if other < 1 or other > #order then return end
      order[index], order[other] = order[other], order[index]
      RH.Refresh()
      RH.ShowOptions("bars")
      return
    end
  end
end

local pages = {}
pages.welcome = function()
  Header("ROGUEHUD")
  Note("Energy, combo points, poison stock and weapon state, cooldown rows, and rogue combat cues in one movable HUD.")
  Note("Use the game's Cooldown Manager to choose and order Essential and Utility abilities. RogueHUD offers a known-spell fallback when that list is unavailable.")
  Action("Move the HUD", RH.db.locked and "Unlock" or "Lock", function() RH.db.locked = not RH.db.locked RH.Refresh() RH.ShowOptions("welcome") end)
  Action("Preview sample HUD", RH.preview and "Stop preview" or "Preview", function() RH.preview = not RH.preview RH.Refresh() RH.ShowOptions("welcome") end)
end

pages.general = function()
  Header("GENERAL")
  Toggle("Show RogueHUD", "enabled")
  local minimapRow = Row()
  local minimapBox = CreateFrame("CheckButton", nil, minimapRow, "UICheckButtonTemplate")
  minimapBox:SetPoint("LEFT", -4, 0)
  minimapBox:SetChecked(RH.characterDB.minimapHidden ~= true)
  minimapBox:SetScript("OnClick", function(self)
    RH.characterDB.minimapHidden = self:GetChecked() ~= true
    RH.Refresh()
  end)
  local minimapLabel = NewLabel(minimapRow, "Show minimap icon")
  minimapLabel:SetPoint("LEFT", minimapBox, "RIGHT", 1, 0)
  Toggle("Lock position", "locked")
  Number("Horizontal position", "x", -1500, 1500, 1)
  Number("Vertical position", "y", -1000, 1000, 1)
  Number("Width", "width", 120, 700, 1)
  Number("Scale", "scale", 0.5, 2, 0.05)
  Number("Opacity", "alpha", 0.2, 1, 0.05)
  Choice("Theme", "theme", {{"default", "Default"}, {"dark", "Dark"}})
  Header("INTEGRATIONS")
  Toggle("EllesmereUI accent and mover", "ellesmere.enabled")
end

pages.appearance = function()
  Header("TEXTURES AND FONTS")
  Choice("Bar texture", "style.barTexture", {{"smooth", "Smooth"}, {"flat", "Flat"}, {"blizzard", "Blizzard"}})
  Choice("HUD font", "style.font", {{"Inter SemiBold", "Inter SemiBold"}, {"Inter Medium", "Inter Medium"}, {"Inter", "Inter"}, {"default", "Game default"}, {"friz", "Friz Quadrata"}, {"arial", "Arial Narrow"}})
  Number("General font size", "style.fontSize", 8, 24, 1)
  Choice("Font outline", "style.fontOutline", {{"", "None"}, {"OUTLINE", "Outline"}, {"THICKOUTLINE", "Thick outline"}})
  Header("BORDERS AND BACKGROUND")
  Number("Border size (pixels)", "style.borderSize", 0, 4, 1)
  ColorSetting("Border color", "style.borderColor")
  ColorSetting("Backdrop color", "style.backdropColor")
  Toggle("Drop shadow", "style.shadow")
  Header("ICONS")
  Choice("Icon shape", "style.iconShape", {{"square", "Square"}, {"rounded", "Rounded"}, {"circle", "Circle"}})
  Choice("Icon overlay", "style.iconOverlay", {{"none", "None"}, {"shade", "Shaded edges"}, {"gloss", "Gloss"}, {"both", "Shade and gloss"}})
  Number("Icon zoom", "style.iconZoom", 0, 0.25, 0.01)
  Toggle("Separate icon border", "style.ownIconBorder")
  Number("Icon border size (pixels)", "style.iconBorderSize", 0, 4, 1)
  ColorSetting("Icon border color", "style.iconBorderColor")
  Number("Cooldown swipe darkness", "style.swipeAlpha", 0, 1, 0.05)
  Header("RESOURCE COLORS")
  Note("Colors on this page edit the selected theme only. EllesmereUI can still supply the accent color.")
  local palette = RH.db.theme == "dark" and "darkColors" or "colors"
  for _, entry in ipairs({
    {"Energy", "energy"}, {"Health", "health"},
    {"Combo point 1", "combo1"}, {"Combo point 2", "combo2"},
    {"Combo point 3", "combo3"}, {"Combo point 4", "combo4"},
    {"Combo point 5", "combo5"}, {"Main-hand swing", "swingMain"},
    {"Off-hand swing", "swingOff"}, {"Text", "text"}, {"Accent", "accent"},
  }) do ColorSetting(entry[1], palette .. "." .. entry[2]) end
end

pages.bars = function()
  Header("BAR ORDER")
  Note("Top to bottom. Disabled bars keep their place in this list and take no HUD space.")
  local names = {
    essential = "Essential cooldowns", combo = "Combo Points",
    health = "Health", energy = "Energy", swing = "Swing lanes",
    utility = "Utility cooldowns",
  }
  for index, key in ipairs(RH.db.barOrder) do
    local frame = Row()
    local label = NewLabel(frame, names[key])
    label:SetPoint("LEFT", 0, 0)
    local down = Button(frame, "Down", 55, function() OrderBar(key, 1) end)
    down:SetPoint("RIGHT", -2, 0)
    down:SetEnabled(index < #RH.db.barOrder)
    local up = Button(frame, "Up", 55, function() OrderBar(key, -1) end)
    up:SetPoint("RIGHT", down, "LEFT", -5, 0)
    up:SetEnabled(index > 1)
  end
  Action("Restore default order", "Reset Order", function()
    RH.db.barOrder = RH.Copy(RH.defaults.barOrder)
    RH.Refresh()
    RH.ShowOptions("bars")
  end)
  Header("RESOURCE BARS")
  Number("Gap between HUD blocks", "stackGap", 0, 16, 1)
  Toggle("Energy bar", "energy.enabled")
  Number("Energy height", "energy.height", 1, 60, 1)
  Toggle("Energy number", "energy.text")
  Number("Energy text size", "energy.fontSize", 6, 40, 1)
  Toggle("Combo points", "combo.enabled")
  Number("Combo row height", "combo.height", 4, 30, 1)
  Number("Combo point gap", "combo.gap", 0, 16, 1)
  Toggle("Health bar", "health.enabled")
  Number("Health height", "health.height", 1, 60, 1)
  Toggle("Health text", "health.text")
  Choice("Health text format", "health.mode", {{"percent", "Percentage"}, {"current", "Current"}, {"both", "Both"}})
  Number("Health text size", "health.fontSize", 6, 40, 1)
  Header("SWING AND GCD")
  Toggle("Main-hand and off-hand swings", "swing.enabled")
  Number("Swing lane height", "swing.height", 1, 10, 1)
  Toggle("GCD border trail", "gcd.enabled")
  ColorSetting("GCD border color", "gcd.color")
end

pages.cast = function()
  Header("PLAYER CASTBAR")
  Note("A separate castbar for your casts and channels. It sits outside the HUD stack and replaces the game's player castbar while enabled.")
  Toggle("Show castbar", "cast.enabled")
  Choice("Placement", "cast.side", {{"BELOW", "Below HUD"}, {"ABOVE", "Above HUD"}})
  Number("Gap from HUD (screen pixels)", "cast.offset", 0, 200, 1)
  Number("Height", "cast.height", 12, 60, 1)
  Header("APPEARANCE")
  ColorSetting("Cast fill color", "cast.color")
  Choice("Texture", "cast.texture", {{"details", "Details Flat"}, {"flat", "Flat"}, {"smooth", "Smooth"}, {"blizzard", "Blizzard"}})
  Number("Text size", "cast.fontSize", 8, 24, 1)
  Choice("Spell name alignment", "cast.textAlign", {{"LEFT", "Left"}, {"CENTER", "Center"}, {"RIGHT", "Right"}})
  Number("Spell name horizontal offset (screen pixels)", "cast.textOffset", -200, 200, 1)
  Toggle("Show spell icon", "cast.icon")
  Number("Icon size", "cast.iconSize", 12, 80, 1)
  Number("Icon zoom", "cast.iconZoom", 0, 0.45, 0.01)
  Number("Icon gap (pixels)", "cast.iconGap", 0, 20, 1)
  Toggle("Show latency segment", "cast.latency")
end

pages.poisons = function()
  Header("POISONS")
  Note("Each badge counts the highest usable rank carried in your bags. Left click applies it to the main hand; right click applies it to the off hand.")
  Toggle("Show poison badges", "poison.enabled")
  Toggle("Show weapon status and time", "poison.showWeapon")
  Choice("Side", "poison.side", {{"LEFT", "Left"}, {"RIGHT", "Right"}})
  Number("Badge size", "poison.size", 20, 56, 1)
  Number("Badge gap", "poison.gap", 0, 16, 1)
  Number("Horizontal offset", "poison.x", -300, 300, 1)
  Number("Vertical offset", "poison.y", -300, 300, 1)
  Header("VISIBILITY AND ORDER")
  for _, key in ipairs(RH.db.poison.order) do
    Toggle(RH.poisons[key].name, "poison.visible." .. key)
    local frame = Row(25)
    local up = Button(frame, "Up", 55, function() OrderPoison(key, -1) end)
    up:SetPoint("LEFT", 20, 0)
    local down = Button(frame, "Down", 55, function() OrderPoison(key, 1) end)
    down:SetPoint("LEFT", up, "RIGHT", 5, 0)
  end
end

pages.cooldowns = function()
  Header("COOLDOWN ROWS")
  Toggle("Essential row", "cooldown.essential")
  Toggle("Utility row", "cooldown.utility")
  Choice("Source", "cooldown.source", {{"game", "Game categories"}, {"curated", "Curated rogue list"}, {"custom", "Custom lists"}})
  Number("Essential icon size", "cooldown.essentialSize", 20, 56, 1)
  Number("Essential icon gap", "cooldown.essentialGap", 0, 16, 1)
  Number("Utility icon size", "cooldown.utilitySize", 20, 56, 1)
  Number("Utility icon gap", "cooldown.utilityGap", 0, 16, 1)
  Header("ICON STATES")
  Toggle("Cooldown swipe", "cooldown.showSwipe")
  Toggle("Countdown numbers", "cooldown.showNumbers")
  Toggle("Grey out on cooldown", "cooldown.desaturate")
  Toggle("Tint when unusable or low on energy", "cooldown.dimUnusable")
  Toggle("Tint when out of range", "cooldown.outOfRange")
  Toggle("Only show on cooldown", "cooldown.hideReady")
  Note("Riposte is appended to Essential when learned. It appears during its cooldown or a detected post-parry opportunity, then closes its slot when hidden. Hidden spell IDs can suppress it. Riposte ignores the row's ready and cooldown opacity settings.")
  Number("Ready opacity", "cooldown.readyAlpha", 0, 1, 0.05)
  Number("Cooldown opacity", "cooldown.cooldownAlpha", 0, 1, 0.05)
  Note("Utility fallback: Kick, Sprint, Vanish, Evasion, Blind, Gouge, Kidney Shot, Sap, Distract, Feint, Preparation, and Shadowstep when known.")
  for _, name in ipairs({"extraEssential", "extraUtility", "customEssential", "customUtility"}) do
    TextInput(name .. " spell IDs (comma separated)", IDs(RH.db.cooldown[name]), function(value)
      RH.db.cooldown[name] = ParseIDs(value)
      RH.Refresh()
    end)
  end
  TextInput("Hidden spell IDs (comma separated)", (function()
    local list = {}
    for id, hide in pairs(RH.db.cooldown.hidden) do if hide then list[#list + 1] = tonumber(id) end end
    table.sort(list)
    return IDs(list)
  end)(), function(value)
    RH.db.cooldown.hidden = {}
    for _, id in ipairs(ParseIDs(value)) do RH.db.cooldown.hidden[id] = true end
    RH.Refresh()
  end)
end

pages.hints = function()
  Header("ROTATION CUES")
  Toggle("Show cues", "hints.enabled")
  Note("Show cues also controls Riposte's red border during its post-parry opportunity. Riposte's icon visibility is unchanged.")
  Toggle("Slice and Dice expiry", "hints.slice")
  Toggle("Rupture expiry", "hints.rupture")
  Toggle("Finisher energy marks", "hints.energy")
  Number("Slice and Dice warning, seconds", "hints.sliceExpiry", 1, 15, 1)
  Number("Rupture warning, seconds", "hints.ruptureExpiry", 1, 15, 1)
end

pages.sounds = function()
  Header("CAST SOUNDS")
  Toggle("Enable custom cast sounds", "sounds.enabled")
  Note("One rule per line: spell ID, success or start, sound file path, channel. Files must be inside the game folder and use .ogg, .wav, or .mp3.")
  local lines = {}
  for _, rule in ipairs(RH.db.sounds.rules or {}) do
    lines[#lines + 1] = table.concat({rule.spell or 0, rule.when or "success", rule.path or "", rule.channel or "Master"}, ",")
  end
  TextInput("Rules, separated by semicolons", table.concat(lines, "; "), function(value)
    local rules = {}
    for line in value:gmatch("[^;]+") do
      local id, when, path, channel = line:match("^%s*(%d+)%s*,%s*(%w+)%s*,%s*([^,]+)%s*,%s*(%w+)%s*$")
      if id and (when == "start" or when == "success") and path and path:match("%.%w+$") then
        rules[#rules + 1] = {enabled = true, spell = tonumber(id), when = when, path = path, channel = channel}
      end
    end
    RH.db.sounds.rules = rules
    RH.Refresh()
  end)
end

pages.profiles = function()
  Header("PROFILES")
  Note("Profiles are independent of ForeverCatLitter. Changes save to the active profile immediately.")
  local names = {}
  for name in pairs(RogueHUDDB.profiles) do names[#names + 1] = name end
  table.sort(names)
  Note("Available: " .. table.concat(names, ", "))
  TextInput("Active profile", RogueHUDDB.active or "Default", function(name)
    if name == "" then return end
    if not RogueHUDDB.profiles[name] then RogueHUDDB.profiles[name] = RH.Copy(RH.db) end
    RogueHUDDB.active = name
    RH.db = RogueHUDDB.profiles[name]
    RH.Fill(RH.db, RH.defaults)
    RH.NormalizeBarOrder(RH.db)
    RH.db.profile = name
    RH.Refresh()
    RH.ShowOptions("profiles")
  end)
  Action("Reset active profile", "Reset", function()
    RogueHUDDB.profiles[RogueHUDDB.active] = RH.Copy(RH.defaults)
    RH.db = RogueHUDDB.profiles[RogueHUDDB.active]
    RH.db.profile = RogueHUDDB.active
    RH.Refresh()
    RH.ShowOptions("profiles")
  end)
  Action("Delete active profile", "Delete", function()
    local active = RogueHUDDB.active
    if active == "Default" then return end
    RogueHUDDB.profiles[active] = nil
    RogueHUDDB.active = "Default"
    RogueHUDDB.profiles.Default = RogueHUDDB.profiles.Default or RH.Copy(RH.defaults)
    RH.db = RogueHUDDB.profiles.Default
    RH.Refresh()
    RH.ShowOptions("profiles")
  end)
  local code = TextInput("Export / import code", ExportProfile(), function(value)
    if ImportProfile(value) then RH.Message("Profile imported") RH.ShowOptions("profiles")
    else RH.Message("Invalid profile code") end
  end)
  code:HookScript("OnEditFocusGained", function(self) self:HighlightText() end)
  Note("Press Enter in the code box to import. Exported codes can be copied with Ctrl+C.")
end

local order = {"welcome", "general", "appearance", "bars", "cast", "poisons", "cooldowns", "hints", "sounds", "profiles"}
local labels = {welcome = "Welcome", general = "General", appearance = "Appearance", bars = "Bars", cast = "Castbar", poisons = "Poisons", cooldowns = "Cooldowns", hints = "Cues", sounds = "Sounds", profiles = "Profiles"}

local function Rebuild()
  if not window or not RH.db then return end
  if content then content:Hide() end
  content = CreateFrame("Frame", nil, scroll)
  content:SetSize(390, 1)
  scroll:SetScrollChild(content)
  rowY = -10
  pages[page]()
  scroll:SetVerticalScroll(0)
end

local function Build()
  window = CreateFrame("Frame", "RogueHUDOptions", UIParent, "BasicFrameTemplateWithInset")
  window:SetSize(590, 540)
  window:SetPoint("CENTER")
  window:SetFrameStrata("DIALOG")
  window:SetMovable(true)
  window:EnableMouse(true)
  window:RegisterForDrag("LeftButton")
  window:SetScript("OnDragStart", window.StartMoving)
  window:SetScript("OnDragStop", window.StopMovingOrSizing)
  window.TitleText:SetText("RogueHUD")
  window:SetScript("OnShow", UseKeyboardEscape)
  window:SetScript("OnHide", function(self)
    self:EnableKeyboard(false)
    olderWindows, focusedInput, childEscape = {}, nil, false
    self:SetScript("OnUpdate", nil)
    if RH.preview then RH.preview = false RH.Refresh() end
  end)
  window:SetScript("OnKeyDown", function(self, key)
    local pass = key ~= "ESCAPE" or childEscape
      or (focusedInput and focusedInput.HasFocus and focusedInput:HasFocus())
      or (ColorPickerFrame and ColorPickerFrame:IsShown()) or OlderWindowOpen()
    if not pcall(self.SetPropagateKeyboardInput, self, pass and true or false) then
      UseNativeEscape()
      if key == "ESCAPE" and not pass then self:Hide() end
      return
    end
    if key == "ESCAPE" and not pass then self:Hide() end
  end)
  window:RegisterEvent("PLAYER_REGEN_DISABLED")
  window:RegisterEvent("PLAYER_REGEN_ENABLED")
  window:SetScript("OnEvent", function(self, event)
    if not self:IsShown() then
      if event == "PLAYER_REGEN_ENABLED" then NativeEscape(false) end
    elseif event == "PLAYER_REGEN_DISABLED" then UseNativeEscape()
    else UseKeyboardEscape() end
  end)
  TrackColorPicker()
  window:Hide()
  local sidebar = CreateFrame("Frame", nil, window)
  sidebar:SetPoint("TOPLEFT", 12, -33)
  sidebar:SetSize(145, 480)
  for index, key in ipairs(order) do
    local button = Button(sidebar, labels[key], 135, function() page = key Rebuild() end)
    button:SetPoint("TOPLEFT", 4, -(index - 1) * 30)
  end
  scroll = CreateFrame("ScrollFrame", nil, window, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 165, -37)
  scroll:SetPoint("BOTTOMRIGHT", -30, 18)
  Rebuild()
end

function RH.ShowOptions(which)
  if not window then return end
  if which and pages[which] then page = which end
  Rebuild()
  if not window:IsShown() then RememberOlderWindows() end
  window:Show()
end

function RH.ToggleOptions()
  if not window then return end
  if window:IsShown() then window:Hide() else RH.ShowOptions() end
end

RH.On("PLAYER_LOGIN", Build)
SLASH_ROGUEHUD1 = "/roguehud"
SLASH_ROGUEHUD2 = "/rhud"
SlashCmdList.ROGUEHUD = function(msg)
  msg = (msg or ""):lower()
  if msg == "lock" then RH.db.locked = true RH.Message("HUD locked")
  elseif msg == "unlock" then RH.db.locked = false RH.Message("Drag the HUD to move it")
  elseif msg == "reset" then RH.db.x, RH.db.y = 0, -190 RH.Refresh()
  elseif msg == "preview" then RH.preview = not RH.preview RH.Refresh()
  elseif msg == "status" then RH.Message(RH.lastError or "No module errors reported")
  else RH.ShowOptions() end
end
