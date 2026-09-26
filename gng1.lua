--[[
	LUNA UI  •  v1.0.0
	Libreria de interfaz futurista para Roblox. Un solo archivo, sin assets externos,
	0 loops por frame (solo eventos + tweens).

	ES COMPATIBLE CON LOCALScript Y CON EXECUTORS (Lua 5.1 / LuaJIT):
	no usa +=, continue, //, goto, math.clamp, math.round, table.clear, table.clone
	ni task.delay (si no existe task usa spawn/wait), y si no hay PlayerGui cae a CoreGui.
	En executors la libreria queda en getgenv().LunaUI.

	CARGA:
		LocalScript: local lib = require(script.Parent.Luna)
		Executor con loadfile: local lib = loadfile("Luna.lua")()
		Executor con readfile/loadstring: local lib = loadstring(readfile("Luna.lua"))()

	EJEMPLO:
		local win = lib:CreateWindow{ Title = "LUNA", Subtitle = "FUTURISTIC UI" }
		local tab = win:AddTab("Principal")
		local sec = tab:AddSection("Opciones")

		sec:AddToggle("Aura",    { Default = false, Callback = function(v) end })
		sec:AddSlider("Velocidad", { Min = 0, Max = 100, Default = 50, Suffix = "%" })
		sec:AddInput("Usuario", { Placeholder = "nombre..." })
		sec:AddButton("Ejecutar", function() print("go") end)
		sec:AddDropdown("Modo", { Options = {"A","B","C"}, Default = "A" })
		sec:AddProgress("Carga", { Default = 40 })
		sec:AddKeybind("Bindeo")

		win:SetKeybind(Enum.KeyCode.RightControl) -- ocultar/mostrar
		lib:Notify{ Title = "Listo", Text = "UI cargada", Type = "success" }
		lib:Theme("Matrix")           -- Cyber / Matrix / Ember / Frost / Mono, o una tabla
		lib.Config.Debug = true       -- imprime que propiedad no se pudo asignar (si la hay)
		lib:Unload()                  -- limpia todo

	TEMAS: Cyber (por defecto), Matrix, Ember, Frost, Mono
		ELEMENTOS: Button, Toggle, Slider, Input, Dropdown, Label, Progress, Keybind
			Los elementos se anaden a la pestana o a una seccion, con o sin tabla de opciones:
			sec:AddToggle("Aura", { Default = true })   ==   sec:AddToggle{ Name = "Aura", Default = true }
]]


--[[ COMPATIBILIDAD (LocalScript y executors: Lua 5.1 / LuaJIT / Luau) ]]
-- No usamos math.clamp, math.round, table.clear, table.clone, +=, continue ni //
-- porque no existen (o no parsean) en el Lua de la mayoria de executors.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer

-- Utils 100% Lua 5.1
local floor, min, max, abs = math.floor, math.min, math.max, math.abs

local function clamp(value, low, high)
	if value < low then
		return low
	elseif value > high then
		return high
	end
	return value
end

local function roundValue(value)
	return floor(value + 0.5)
end

local function clearTable(target)
	for key in pairs(target) do
		target[key] = nil
	end
end

local function copyTable(source)
	local result = {}
	for key, value in pairs(source) do
		result[key] = value
	end
	return result
end

-- Retrasos: task no existe en algunos executors
local defer = nil
if type(task) == "table" and type(task.delay) == "function" then
	defer = task.delay
else
	defer = function(seconds, callback)
		spawn(function()
			wait(seconds)
			callback()
		end)
	end
end

-- PlayerGui puede tardar en existir al inyectar; si no, usamos CoreGui
local function resolvePlayerGui()
	if not LocalPlayer then
		return nil
	end
	local existing = LocalPlayer:FindFirstChild("PlayerGui")
	if existing then
		return existing
	end
	local ok, waited = pcall(function()
		return LocalPlayer:WaitForChild("PlayerGui", 10)
	end)
	if ok and waited then
		return waited
	end
	return nil
end

local lib = {}
lib.__index = lib
lib.Version = "1.0.0"
-- Huella: si el executor carga otra version, el numero no coincide con este.
lib.Build = "luna-1.0.0-b15-centered-chip-text"

--[[ CONFIG ]]--

local Config = {
	Accent = Color3.fromRGB(0, 229, 255),
	Accent2 = Color3.fromRGB(150, 105, 255),
	Background = Color3.fromRGB(8, 10, 16),
	Panel = Color3.fromRGB(13, 16, 24),
	Card = Color3.fromRGB(21, 25, 35),
	Stroke = Color3.fromRGB(46, 58, 82),
	Text = Color3.fromRGB(216, 227, 245),
	Muted = Color3.fromRGB(122, 136, 163),

	Font = Enum.Font.GothamSemibold,
	MonoFont = Enum.Font.Code,
	TextSize = 13,
	Radius = 6,
	Gutter = 12,
	Anim = 0.16,
	BarHeight = 36,
	Sidebar = 134,
	Blur = false,
	Scanline = true,
	Debug = false,
}

local Themes = {
	Cyber = {
		Accent = Color3.fromRGB(0, 229, 255),
		Accent2 = Color3.fromRGB(150, 105, 255),
	},
	Matrix = {
		Accent = Color3.fromRGB(0, 255, 130),
		Accent2 = Color3.fromRGB(0, 190, 95),
		Background = Color3.fromRGB(4, 10, 6),
		Panel = Color3.fromRGB(6, 14, 10),
		Card = Color3.fromRGB(10, 22, 15),
		Stroke = Color3.fromRGB(24, 74, 46),
	},
	Ember = {
		Accent = Color3.fromRGB(255, 116, 40),
		Accent2 = Color3.fromRGB(255, 40, 96),
		Background = Color3.fromRGB(14, 8, 8),
		Panel = Color3.fromRGB(20, 11, 11),
		Card = Color3.fromRGB(30, 16, 16),
		Stroke = Color3.fromRGB(84, 40, 34),
	},
	Frost = {
		Accent = Color3.fromRGB(120, 190, 255),
		Accent2 = Color3.fromRGB(205, 228, 255),
		Background = Color3.fromRGB(7, 9, 14),
		Panel = Color3.fromRGB(11, 15, 22),
		Card = Color3.fromRGB(18, 24, 33),
		Stroke = Color3.fromRGB(48, 62, 80),
	},
	Mono = {
		Accent = Color3.fromRGB(235, 238, 248),
		Accent2 = Color3.fromRGB(150, 160, 185),
		Stroke = Color3.fromRGB(60, 66, 82),
	},
}

lib.Config = Config
lib.Themes = Themes

local themeLookup = {}
for name, values in pairs(Themes) do
	themeLookup[string.lower(name)] = values
end

--[[ UTILIDADES ]]--

local function warnProperty(class, key, message)
	if Config.Debug then
		print("[LunaUI] " .. class .. "." .. tostring(key) .. ": " .. tostring(message))
	end
end

local function warnElement(kind, message)
	print("[LunaUI] Add" .. kind .. " no se pudo crear: " .. tostring(message))
end

local function new(class, properties, parent)
	local object = Instance.new(class)
	if properties then
		for key, value in pairs(properties) do
			-- pcall: si una version de Roblox/executor no soporta la propiedad,
			-- la libreria debe seguir viva en vez de abortar toda la UI
			local ok, message = pcall(function()
				object[key] = value
			end)
			if not ok then
				warnProperty(class, key, message)
			end
		end
	end
	if parent then
		object.Parent = parent
	end
	return object
end

local tweenCache = {}

local function tweenInfo(seconds, style, direction)
	seconds = seconds or Config.Anim
	style = style or Enum.EasingStyle.Quint
	direction = direction or Enum.EasingDirection.Out
	local key = seconds .. "/" .. style.Name .. "/" .. direction.Name
	local cached = tweenCache[key]
	if not cached then
		cached = TweenInfo.new(seconds, style, direction)
		tweenCache[key] = cached
	end
	return cached
end

local function tween(object, properties, seconds, style, direction)
	local animation = TweenService:Create(object, tweenInfo(seconds, style, direction), properties)
	animation:Play()
	return animation
end

local function lighten(color, amount)
	return Color3.new(
		math.min(1, color.R + amount),
		math.min(1, color.G + amount),
		math.min(1, color.B + amount)
	)
end

local function formatNumber(value)
	if value % 1 == 0 then
		return tostring(value)
	end
	local text = string.format("%.2f", value)
	local trimmed = text:gsub("0+$", "")
	return (trimmed:gsub("%.$", ""))
end

local function pointerPosition(input)
	if input.UserInputType == Enum.UserInputType.Touch then
		return Vector2.new(input.Position.X, input.Position.Y)
	end
	local mouse = UserInputService:GetMouseLocation()
	return Vector2.new(mouse.X, mouse.Y)
end

local function inside(guiObject, position)
	local origin = guiObject.AbsolutePosition
	local size = guiObject.AbsoluteSize
	return position.X >= origin.X
		and position.X <= origin.X + size.X
		and position.Y >= origin.Y
		and position.Y <= origin.Y + size.Y
end

local function beginDrag(onMove, onEnd)
	local moveConnection
	moveConnection = UserInputService.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch then
			if onMove then
				onMove(input)
			end
		end
	end)
	local endConnection
	endConnection = UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			moveConnection:Disconnect()
			endConnection:Disconnect()
			if onEnd then
				onEnd()
			end
		end
	end)
	return function()
		moveConnection:Disconnect()
		endConnection:Disconnect()
	end
end

--[[ REGISTRO DE TINTE (para lib:Theme en vivo) ]]--

local tint = {
	Accent = {},
	Card = {},
	Stroke = {},
	Text = {},
	Muted = {},
	Panel = {},
	Background = {},
}

local function tag(role, object)
	local list = tint[role]
	if list then
		table.insert(list, object)
	end
	return object
end

local function round(object, radius)
	return new("UICorner", { CornerRadius = UDim.new(0, radius or Config.Radius) }, object)
end

local function outline(object, color, thickness, transparency)
	if transparency == nil then
		transparency = 0.4
	end
	return tag("Stroke", new("UIStroke", {
		Color = color or Config.Stroke,
		Thickness = thickness or 1,
		Transparency = transparency,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, object))
end

local function accentFill(object, rotation)
	return tag("Accent", new("UIGradient", {
		Color = ColorSequence.new(Config.Accent, Config.Accent2),
		Rotation = rotation or 0,
	}, object))
end

local function card(parent, size, position, class)
	local object = new(class or "Frame", {
		Size = size or UDim2.fromScale(1, 1),
		Position = position,
		BackgroundColor3 = Config.Card,
		BorderSizePixel = 0,
	}, parent)
	round(object)
	return tag("Card", object)
end

local function label(parent, properties, role)
	properties = properties or {}
	properties.BackgroundTransparency = 1
	properties.Font = properties.Font or Config.Font
	properties.TextSize = properties.TextSize or Config.TextSize
	properties.TextColor3 = properties.TextColor3 or Config.Text
	if properties.TextXAlignment == nil then
		properties.TextXAlignment = Enum.TextXAlignment.Left
	end
	return tag(role or "Text", new("TextLabel", properties, parent))
end

local function button(parent, properties)
	properties.AutoButtonColor = false
	properties.BackgroundColor3 = properties.BackgroundColor3 or Config.Card
	properties.BorderSizePixel = 0
	properties.Font = properties.Font or Config.Font
	properties.TextSize = properties.TextSize or Config.TextSize
	properties.TextColor3 = properties.TextColor3 or Config.Text
	return tag("Card", new("TextButton", properties, parent))
end

local function hoverFill(object)
	object.MouseEnter:Connect(function()
		tween(object, { BackgroundColor3 = lighten(object.BackgroundColor3, 0.07) }, Config.Anim)
	end)
	object.MouseLeave:Connect(function()
		tween(object, { BackgroundColor3 = Config.Card }, Config.Anim)
	end)
end

local function hoverGhost(object)
	object.MouseEnter:Connect(function()
		tween(object, { BackgroundTransparency = 0 }, Config.Anim)
	end)
	object.MouseLeave:Connect(function()
		tween(object, { BackgroundTransparency = 1 }, Config.Anim)
	end)
end

--[[ RAIZ DE LA GUI ]]--

local playerGui = resolvePlayerGui()
if not playerGui then
	playerGui = game:GetService("CoreGui")
end

local previous = playerGui:FindFirstChild("LunaUI")
if previous then
	previous:Destroy()
end

local screen = new("ScreenGui", {
	Name = "LunaUI",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	DisplayOrder = 500,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, playerGui)

local root = new("Frame", {
	Name = "Root",
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
}, screen)

local toastLayer = new("Frame", {
	Name = "Toasts",
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	ZIndex = 40,
}, root)

local scaleValue = 1
local uiScale = new("UIScale", { Scale = 1 }, root)

local function viewport()
	local camera = Workspace.CurrentCamera
	if camera then
		return camera.ViewportSize
	end
	return Vector2.new(1920, 1080)
end

local function applyScale()
	local size = viewport()
	scaleValue = clamp(size.Y / 1000, 0.7, 1.15)
	uiScale.Scale = scaleValue
end

applyScale()

do
	local camera = Workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(applyScale)
	end
	Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(applyScale)
end

local function toRootPosition(guiObject)
	local origin = guiObject.AbsolutePosition - root.AbsolutePosition
	return Vector2.new(origin.X / scaleValue, origin.Y / scaleValue)
end

--[[ BASE DE ELEMENTOS ]]--

local Elements = {}
local ElementKinds = { "Button", "Toggle", "Slider", "Input", "Dropdown", "Label", "Progress", "Keybind" }

local function makeRow(page, height, automatic)
	local order = page.order
	page.order = order + 1
	return new("Frame", {
		Size = UDim2.new(1, 0, 0, height),
		AutomaticSize = automatic or Enum.AutomaticSize.None,
		BackgroundTransparency = 1,
		LayoutOrder = order,
	}, page.container)
end

local function rowHeader(frame, name, value)
	local left = label(frame, {
		Size = UDim2.new(1, -74, 1, 0),
		Text = tostring(name or ""),
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
	local right = label(frame, {
		Size = UDim2.new(0, 70, 1, 0),
		Position = UDim2.new(1, -70, 0, 0),
		Text = tostring(value or ""),
		TextColor3 = Config.Accent,
		TextXAlignment = Enum.TextXAlignment.Right,
		Font = Config.MonoFont,
		TextSize = 12,
	}, "Accent")
	return left, right
end

local function normalizeOptions(nameOrOptions, extra)
	if type(nameOrOptions) == "string" then
		if type(extra) == "table" then
			local options = copyTable(extra)
			options.Name = nameOrOptions
			return options
		end
		if type(extra) == "function" then
			return { Name = nameOrOptions, Callback = extra }
		end
		return { Name = nameOrOptions }
	end
	if type(nameOrOptions) == "table" then
		if type(extra) == "function" then
			local options = copyTable(nameOrOptions)
			options.Callback = options.Callback or extra
			return options
		end
		return nameOrOptions
	end
	if type(extra) == "table" then
		return extra
	end
	if type(extra) == "function" then
		return { Callback = extra }
	end
	return {}
end

-- Si un executor rechaza algo de un elemento, no queremos cortar el script del
-- usuario: devolvemos una API minima para que AddX siga y el resto de la tab exista.
local installElementMethods

local function stubApi(options)
	local api = { _stub = true, _conns = {} }
	local value = options and (options.Default ~= nil and options.Default or options.Text)
	local text = options and options.Text or ""
	function api:GetValue() return value end
	function api:SetValue(newValue) value = newValue end
	function api:GetText() return text end
	function api:SetText(newText) text = tostring(newText or "") end
	function api:Select() end
	function api:Destroy() end
	function api:AddConnection() end
	return installElementMethods(api, nil)
end

installElementMethods = function(target, page)
	for index = 1, #ElementKinds do
		local kind = ElementKinds[index]
		target["Add" .. kind] = function(_, a, b)
			local options = normalizeOptions(a, b)
			local ok, result = pcall(Elements[kind], page, options)
			if ok then
				return result
			end
			warnElement(kind, result)
			return stubApi(options)
		end
	end
	return target
end

local function elementApi(frame, page)
	local api = { Frame = frame, _conns = {} }
	local window = page and page.window

	function api:AddConnection(item)
		table.insert(self._conns, item)
	end

	local unregister = nil
	if window then
		unregister = window:AddConnection(function()
			api:Destroy()
		end)
	end

	function api:Destroy()
		if unregister then
			unregister()
			unregister = nil
		end
		if self.dragCancel then
			self.dragCancel()
			self.dragCancel = nil
		end
		for index = 1, #self._conns do
			local item = self._conns[index]
			if type(item) == "function" then
				item()
			else
				item:Disconnect()
			end
		end
		clearTable(self._conns)
		if self.Frame then
			self.Frame:Destroy()
		end
	end

	return installElementMethods(api, page)
end

--[[ ELEMENTOS ]]--

function Elements.Button(page, nameOrOptions, extra)
	local options = normalizeOptions(nameOrOptions, extra)
	local frame = makeRow(page, 34)
	local control = button(frame, {
		Size = UDim2.fromScale(1, 1),
		Text = tostring(options.Name or "Boton"),
	})
	new("UIPadding", { PaddingLeft = UDim.new(0, 12) }, control)
	outline(control)
	hoverFill(control)

	local api = elementApi(frame, page)
	control.Activated:Connect(function()
		tween(control, { BackgroundColor3 = lighten(Config.Card, 0.16) }, 0.06)
		defer(0.09, function()
			if control.Parent then
				tween(control, { BackgroundColor3 = Config.Card }, Config.Anim)
			end
		end)
		if options.Callback then
			options.Callback(api)
		end
	end)
	return api
end

function Elements.Toggle(page, nameOrOptions, extra)
	local options = normalizeOptions(nameOrOptions, extra)
	local frame = makeRow(page, 32)
	label(frame, {
		Size = UDim2.new(1, -56, 1, 0),
		Text = tostring(options.Name or "Toggle"),
		TextTruncate = Enum.TextTruncate.AtEnd,
	})

	local track = card(frame, UDim2.fromOffset(42, 20), UDim2.new(1, -42, 0.5, -10), "TextButton")
	outline(track, Config.Stroke, 1, 0.35)
	local knob = new("Frame", {
		Size = UDim2.fromOffset(14, 14),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.24, 0, 0.5, 0),
		BackgroundColor3 = Config.Muted,
		BorderSizePixel = 0,
	}, track)
	round(knob, 7)

	local state = options.Default and true or false

	local function render(animate)
		local knobOffset = state and 0.76 or 0.24
		local knobColor = state and Color3.new(1, 1, 1) or Config.Muted
		if animate then
			tween(track, { BackgroundColor3 = state and Config.Accent or Config.Card }, Config.Anim)
			tween(knob, { Position = UDim2.new(knobOffset, 0, 0.5, 0), BackgroundColor3 = knobColor }, Config.Anim)
		else
			track.BackgroundColor3 = state and Config.Accent or Config.Card
			knob.Position = UDim2.new(knobOffset, 0, 0.5, 0)
			knob.BackgroundColor3 = knobColor
		end
	end

	local api = elementApi(frame, page)
	track.Activated:Connect(function()
		state = not state
		render(true)
		if options.Callback then
			options.Callback(state)
		end
	end)
	render(false)

	function api:SetValue(value)
		state = value and true or false
		render(true)
	end

	function api:GetValue()
		return state
	end

	function api:Toggle()
		self:SetValue(not state)
	end

	return api
end

function Elements.Slider(page, nameOrOptions, extra)
	local options = normalizeOptions(nameOrOptions, extra)
	local minimum = options.Min or 0
	local maximum = options.Max or 100
	local step = options.Step or 1
	local suffix = options.Suffix or ""
	local value = options.Default or minimum

	local frame = makeRow(page, 48)
	local nameLabel, valueLabel = rowHeader(frame, options.Name or "Slider", "")

	local track = new("Frame", {
		Size = UDim2.new(1, 0, 0, 4),
		Position = UDim2.fromOffset(0, 30),
		BackgroundColor3 = Config.Card,
		BorderSizePixel = 0,
	}, frame)
	round(track, 2)
	outline(track, Config.Stroke, 1, 0.6)

	local fill = new("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = Config.Accent,
		BorderSizePixel = 0,
	}, track)
	accentFill(fill)

	local knob = new("Frame", {
		Size = UDim2.fromOffset(12, 12),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ZIndex = 3,
	}, track)
	round(knob, 6)
	new("UIStroke", {
		Color = Color3.new(0, 0, 0),
		Transparency = 0.55,
		Thickness = 1,
	}, knob)

	local hit = new("Frame", {
		Size = UDim2.new(1, 0, 0, 20),
		Position = UDim2.fromOffset(0, 22),
		BackgroundTransparency = 1,
		Active = true,
		ZIndex = 4,
	}, frame)

	local function render(animate)
		local ratio = (value - minimum) / ((maximum - minimum) or 1)
		if ratio < 0 then
			ratio = 0
		elseif ratio > 1 then
			ratio = 1
		end
		valueLabel.Text = formatNumber(value) .. suffix
		if animate then
			tween(fill, { Size = UDim2.fromScale(ratio, 1) }, 0.12)
			tween(knob, { Position = UDim2.fromScale(ratio, 0.5) }, 0.12)
		else
			fill.Size = UDim2.fromScale(ratio, 1)
			knob.Position = UDim2.fromScale(ratio, 0.5)
		end
	end

	local function setValue(newValue, animate)
		newValue = clamp(newValue, minimum, maximum)
		if step and step > 0 then
			newValue = minimum + math.floor((newValue - minimum) / step + 0.5) * step
		end
		local changed = newValue ~= value
		value = newValue
		render(animate ~= false)
		if changed and options.Callback then
			options.Callback(value)
		end
	end

	local function valueFromPointer(position)
		local origin = track.AbsolutePosition.X
		local size = track.AbsoluteSize.X
		if size == 0 then
			return value
		end
		local ratio = clamp((position.X - origin) / size, 0, 1)
		return minimum + ratio * (maximum - minimum)
	end

	local api = elementApi(frame, page)

	hit.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			setValue(valueFromPointer(pointerPosition(input)), false)
			if api.dragCancel then
				api.dragCancel()
			end
			api.dragCancel = beginDrag(function(move)
				setValue(valueFromPointer(pointerPosition(move)), false)
			end)
		end
	end)

	render(false)

	function api:SetValue(newValue)
		setValue(newValue, true)
	end

	function api:GetValue()
		return value
	end

	api.Label = nameLabel
	return api
end

function Elements.Input(page, nameOrOptions, extra)
	local options = normalizeOptions(nameOrOptions, extra)
	local frame = makeRow(page, 50)
	label(frame, {
		Size = UDim2.new(1, 0, 0, 15),
		Text = string.upper(tostring(options.Name or "Input")),
		TextSize = 11,
		Font = Config.MonoFont,
		TextColor3 = Config.Muted,
	}, "Muted")

	local field = card(frame, UDim2.new(1, 0, 0, 28), UDim2.fromOffset(0, 19))
	local border = outline(field, Config.Stroke, 1, 0.4)

	local box = new("TextBox", {
		Size = UDim2.new(1, -16, 1, 0),
		Position = UDim2.fromOffset(8, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundTransparency = 1,
		Text = tostring(options.Default or ""),
		PlaceholderText = options.Placeholder or "",
		PlaceholderColor3 = Config.Muted,
		TextColor3 = Config.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = Config.MonoFont,
		TextSize = 12,
		ClearTextOnFocus = false,
		MultiLine = false,
	}, field)

	local api = elementApi(frame, page)

	local function focusStyle(focused)
		if border and border.Parent then
			tween(border, {
				Color = focused and Config.Accent or Config.Stroke,
				Transparency = focused and 0.05 or 0.4,
			}, 0.12)
		end
	end

	box.Focused:Connect(function()
		focusStyle(true)
	end)
	box.FocusLost:Connect(function()
		focusStyle(false)
		if options.Callback then
			options.Callback(box.Text)
		end
	end)

	function api:SetValue(text)
		box.Text = tostring(text or "")
	end

	function api:GetValue()
		return box.Text
	end

	function api:Focus()
		box:CaptureFocus()
	end

	return api
end

function Elements.Dropdown(page, nameOrOptions, extra)
	local options = normalizeOptions(nameOrOptions, extra)
	local list = options.Options or { "Opcion A", "Opcion B", "Opcion C" }
	local selected = options.Default or list[1]

	local frame = makeRow(page, 32)
	local control = button(frame, {
		Size = UDim2.fromScale(1, 1),
		Text = "",
	})
	outline(control)
	hoverFill(control)

	label(control, {
		Size = UDim2.new(1, -76, 1, 0),
		Position = UDim2.fromOffset(12, 0),
		Text = tostring(options.Name or "Dropdown"),
		TextColor3 = Config.Muted,
		TextSize = 12,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, "Muted")

	local valueLabel = label(control, {
		Size = UDim2.new(0, 60, 1, 0),
		Position = UDim2.new(1, -76, 0, 0),
		Text = tostring(selected),
		TextColor3 = Config.Accent,
		TextXAlignment = Enum.TextXAlignment.Right,
		Font = Config.MonoFont,
		TextSize = 12,
	}, "Accent")

	local arrow = tag("Accent", new("Frame", {
		Size = UDim2.fromOffset(6, 6),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -16, 0.5, 0),
		Rotation = 45,
		BackgroundColor3 = Config.Accent,
		BorderSizePixel = 0,
	}, control))
	round(arrow, 1)

	local visible = math.min(#list, 6)
	local menuHeight = visible * 26 + 8
	local menu = card(root, UDim2.fromOffset(200, menuHeight), UDim2.fromOffset(0, 0), "Frame")
	menu.Visible = false
	menu.ZIndex = 60
	outline(menu, Config.Accent, 1, 0.15)

	local scroller = new("ScrollingFrame", {
		Size = UDim2.new(1, -4, 1, -4),
		Position = UDim2.fromOffset(2, 2),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		Active = true,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 2,
		ScrollBarImageColor3 = Config.Accent,
		ScrollBarImageTransparency = 0.2,
		ZIndex = 60,
	}, menu)
	new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2) }, scroller)

	local api = elementApi(frame, page)
	local optionButtons = {}
	local open = false
	local watchConnection = nil

	local function close()
		if not open then
			return
		end
		open = false
		menu.Visible = false
		tween(arrow, { Rotation = 45 }, Config.Anim)
		if watchConnection then
			watchConnection:Disconnect()
			watchConnection = nil
		end
	end

	local function place()
		local size = viewport()
		local width = math.max(120, control.AbsoluteSize.X / scaleValue)
		local anchor = toRootPosition(control)
		local y = anchor.Y + (control.AbsoluteSize.Y / scaleValue) + 4
		if (y + menuHeight) > (size.Y / scaleValue) - 8 then
			y = math.max(8, anchor.Y - menuHeight - 4)
		end
		local x = clamp(anchor.X, 8, math.max(8, (size.X / scaleValue) - width - 8))
		menu.Size = UDim2.fromOffset(width, menuHeight)
		menu.Position = UDim2.fromOffset(x, y)
	end

	local function openMenu()
		if open or #list == 0 then
			return
		end
		open = true
		menu.Visible = true
		tween(arrow, { Rotation = 225 }, Config.Anim)
		place()
		watchConnection = UserInputService.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch then
				local position = pointerPosition(input)
				if not inside(control, position) and not inside(menu, position) then
					close()
				end
			end
		end)
	end

	local function refreshOptions()
	for index = #optionButtons, 1, -1 do
		local entry = optionButtons[index]
		entry:Destroy()
		optionButtons[index] = nil
	end

		for index = 1, #list do
			local value = list[index]
			local option = button(scroller, {
				Size = UDim2.new(1, 0, 0, 26),
				LayoutOrder = index,
				Text = tostring(value),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = tostring(value) == tostring(selected) and Config.Accent or Config.Text,
				TextSize = 12,
				ZIndex = 60,
			})
			new("UIPadding", { PaddingLeft = UDim.new(0, 10) }, option)
			hoverGhost(option)
			option.Activated:Connect(function()
				selected = value
				valueLabel.Text = tostring(selected)
				for position, entry in ipairs(optionButtons) do
					entry.TextColor3 = tostring(list[position]) == tostring(selected)
						and Config.Accent
						or Config.Text
				end
				close()
				if options.Callback then
					options.Callback(selected)
				end
			end)
			table.insert(optionButtons, option)
		end
	end

	control.Activated:Connect(function()
		if open then
			close()
		else
			openMenu()
		end
	end)

	refreshOptions()

	local overlay = { Close = close }
	if page.window then
		page.window:AddRelayout(place)
		page.window:AddOverlay(overlay)
	end

	api:AddConnection(function()
		close()
		menu:Destroy()
		if page.window then
			page.window:RemoveRelayout(place)
			page.window:RemoveOverlay(overlay)
		end
	end)

	function api:SetValue(value)
		selected = value
		valueLabel.Text = tostring(value)
		for index, entry in ipairs(optionButtons) do
			entry.TextColor3 = tostring(list[index]) == tostring(value) and Config.Accent or Config.Text
		end
	end

	function api:GetValue()
		return selected
	end

	function api:SetOptions(newList)
		list = newList or {}
		visible = math.min(#list, 6)
		menuHeight = visible * 26 + 8
		menu.Size = UDim2.fromOffset(menu.Size.X.Offset, menuHeight)
		refreshOptions()
		if #list == 0 then
			close()
		elseif open then
			place()
		end
	end

	function api:GetOptions()
		return list
	end

	return api
end

function Elements.Label(page, nameOrOptions, extra)
	local options = normalizeOptions(nameOrOptions, extra)
	local frame = makeRow(page, 18, Enum.AutomaticSize.Y)
	local text = label(frame, {
		Size = UDim2.new(1, 0, 0, 18),
		AutomaticSize = Enum.AutomaticSize.Y,
		Text = tostring(options.Text or options.Name or "Etiqueta"),
		TextWrapped = true,
		TextColor3 = options.Color or Config.Muted,
		TextSize = options.Size or 12,
		Font = Config.MonoFont,
	}, options.Color and "Text" or "Muted")
	local api = elementApi(frame, page)
	api.Label = text
	function api:SetValue(newText)
		text.Text = tostring(newText)
	end
	function api:GetValue()
		return text.Text
	end
	return api
end

function Elements.Progress(page, nameOrOptions, extra)
	local options = normalizeOptions(nameOrOptions, extra)
	local value = clamp(options.Default or 0, 0, 100)

	local frame = makeRow(page, 40)
	local nameLabel, valueLabel = rowHeader(frame, options.Name or "Progreso", formatNumber(value) .. "%")

	local track = new("Frame", {
		Size = UDim2.new(1, 0, 0, 6),
		Position = UDim2.fromOffset(0, 26),
		BackgroundColor3 = Config.Card,
		BorderSizePixel = 0,
	}, frame)
	round(track, 3)

	local fill = new("Frame", {
		Size = UDim2.fromScale(value / 100, 1),
		BackgroundColor3 = Config.Accent,
		BorderSizePixel = 0,
	}, track)
	accentFill(fill)

	local api = elementApi(frame, page)

	function api:SetValue(newValue, seconds)
		value = clamp(newValue, 0, 100)
		valueLabel.Text = formatNumber(value) .. "%"
		tween(fill, { Size = UDim2.fromScale(value / 100, 1) }, seconds or 0.25)
	end

	function api:GetValue()
		return value
	end

	api.Label = nameLabel
	return api
end

function Elements.Keybind(page, nameOrOptions, extra)
	local options = normalizeOptions(nameOrOptions, extra)
	local frame = makeRow(page, 32)
	local control = button(frame, {
		Size = UDim2.fromScale(1, 1),
		Text = "",
	})
	outline(control)
	hoverFill(control)

	label(control, {
		Size = UDim2.new(1, -108, 1, 0),
		Position = UDim2.fromOffset(12, 0),
		Text = tostring(options.Name or "Bindeo"),
		TextColor3 = Config.Muted,
		TextSize = 12,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, "Muted")

	local valueLabel = label(control, {
		Size = UDim2.new(0, 92, 1, 0),
		Position = UDim2.new(1, -104, 0, 0),
		Text = "",
		TextColor3 = Config.Accent,
		TextXAlignment = Enum.TextXAlignment.Right,
		Font = Config.MonoFont,
		TextSize = 12,
	}, "Accent")

	local key = options.Key or Enum.KeyCode.Unknown
	local armed = false
	local waiting = nil

	local function render()
		if armed then
			valueLabel.Text = "[ pulsa una tecla ]"
		elseif key == Enum.KeyCode.Unknown then
			valueLabel.Text = "Click para bindear"
		else
			valueLabel.Text = key.Name
		end
	end

	local api = elementApi(frame, page)

	control.Activated:Connect(function()
		if armed then
			return
		end
		armed = true
		render()
		local connection
		connection = UserInputService.InputBegan:Connect(function(input, processed)
			if processed or UserInputService:GetFocusedTextBox() then
				return
			end
			connection:Disconnect()
			armed = false
			key = input.KeyCode
			render()
			if options.Callback then
				options.Callback(key)
			end
		end)
		api:AddConnection(function()
			if connection then
				connection:Disconnect()
			end
		end)
	end)

	function api:SetValue(newKey)
		key = newKey
		render()
	end

	function api:GetValue()
		return key
	end

	render()
	return api
end

--[[ VENTANAS ]]--

local Windows = {}

function lib:CreateWindow(nameOrOptions, extra)
	local options = normalizeOptions(nameOrOptions, extra)
	local window = { _conns = {}, tabs = {}, scrollbars = {}, _relayout = {}, _overlays = {}, activeTab = nil, minimized = false }

	local width = options.Width or 520
	local height = options.Height or 620
	local cascade = #Windows * 26

	local function centerPosition(offsetX, offsetY)
		local size = viewport()
		local x = ((size.X / scaleValue) - width) / 2 + (offsetX or 0)
		local y = ((size.Y / scaleValue) - height) / 2 + (offsetY or 0)
		return UDim2.fromOffset(roundValue(x), roundValue(y))
	end

	local frame = new("Frame", {
		Name = "Window",
		Size = UDim2.fromOffset(width, height),
		Position = centerPosition(cascade, cascade),
		AnchorPoint = Vector2.new(0, 0),
		BackgroundColor3 = Config.Panel,
		BorderSizePixel = 0,
		Active = true,
		ClipsDescendants = true,
	}, root)
	tag("Panel", frame)
	round(frame, Config.Radius + 2)
	new("UIStroke", {
		Color = Color3.new(0, 0, 0),
		Thickness = 8,
		Transparency = 0.5,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, frame)

	local intro = new("UIScale", { Scale = 0.96 }, frame)
	window.Frame = frame

	local bar = tag("Background", new("Frame", {
		Size = UDim2.new(1, 0, 0, Config.BarHeight),
		BackgroundColor3 = Config.Background,
		BorderSizePixel = 0,
		Active = true,
	}, frame))

	tag("Accent", new("Frame", {
		Size = UDim2.fromOffset(6, 6),
		Position = UDim2.new(0, 14, 0.5, -1),
		AnchorPoint = Vector2.new(0, 0.5),
		Rotation = 45,
		BackgroundColor3 = Config.Accent,
		BorderSizePixel = 0,
	}, bar))

	local titleLabel = label(bar, {
		Size = UDim2.new(0.45, -20, 0, 18),
		Position = UDim2.fromOffset(28, 0),
		Text = tostring(options.Title or "LUNA"),
		Font = Config.MonoFont,
		TextSize = 14,
		TextTruncate = Enum.TextTruncate.AtEnd,
	})

	local chip = new("Frame", {
		Size = UDim2.fromOffset(0, 20),
		Position = UDim2.new(1, -104, 0, 8),
		AnchorPoint = Vector2.new(1, 0),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = Config.Card,
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
	}, bar)
	round(chip, 3)
	local chipLabel = label(chip, {
		Size = UDim2.fromOffset(0, 20),
		AutomaticSize = Enum.AutomaticSize.X,
		Text = "",
		TextColor3 = Config.Accent,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
		Font = Config.MonoFont,
		TextSize = 11,
	}, "Accent")
	new("UIPadding", {
		PaddingLeft = UDim.new(0, 8),
		PaddingRight = UDim.new(0, 8),
	}, chip)

	label(bar, {
		Size = UDim2.new(0.45, -20, 0, 14),
		Position = UDim2.fromOffset(28, 18),
		Text = tostring(options.Subtitle or lib.Version),
		TextColor3 = Config.Muted,
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = Config.MonoFont,
		TextSize = 10,
	}, "Muted")

	local minimizeButton = button(bar, {
		Size = UDim2.fromOffset(24, 22),
		Position = UDim2.new(1, -58, 0.5, -11),
		Text = "-",
		TextSize = 13,
		TextColor3 = Config.Muted,
		Font = Config.MonoFont,
	})
	round(minimizeButton, 4)
	local closeButton = button(bar, {
		Size = UDim2.fromOffset(24, 22),
		Position = UDim2.new(1, -30, 0.5, -11),
		Text = "x",
		TextSize = 12,
		TextColor3 = Config.Muted,
		Font = Config.MonoFont,
	})
	round(closeButton, 4)

	local sidebar = tag("Background", new("Frame", {
		Size = UDim2.new(0, Config.Sidebar, 1, -Config.BarHeight),
		Position = UDim2.fromOffset(0, Config.BarHeight),
		BackgroundColor3 = Config.Background,
		BorderSizePixel = 0,
	}, frame))
	new("Frame", {
		Size = UDim2.fromOffset(1, 0),
		Position = UDim2.new(1, -1, 0, 0),
		BackgroundColor3 = Config.Stroke,
		BorderSizePixel = 0,
	}, sidebar)

	local tabList = new("ScrollingFrame", {
		Size = UDim2.new(1, 0, 1, -10),
		Position = UDim2.fromOffset(0, 8),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		Active = true,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 2,
		ScrollBarImageColor3 = Config.Accent,
		ScrollBarImageTransparency = 0.3,
	}, sidebar)
	table.insert(window.scrollbars, tabList)
	new("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }, tabList)
	new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2) }, tabList)

	local content = tag("Panel", new("Frame", {
		Size = UDim2.new(1, -Config.Sidebar, 1, -Config.BarHeight),
		Position = UDim2.new(0, Config.Sidebar, 0, Config.BarHeight),
		BackgroundColor3 = Config.Panel,
		BorderSizePixel = 0,
	}, frame))
	window.content = content

	if Config.Scanline then
		local sweep = tag("Accent", new("Frame", {
			Size = UDim2.fromOffset(46, 0),
			Position = UDim2.fromOffset(-46, 0),
			BackgroundColor3 = Config.Accent,
			BackgroundTransparency = 0.88,
			BorderSizePixel = 0,
		}, bar))
		-- TweenInfo.new(time, estilo, direccion, repeatCount, reverses, delayTime)
		TweenService:Create(sweep, TweenInfo.new(2.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true, 1.1), {
			Position = UDim2.fromOffset(width + 46, 0),
		}):Play()
	end

	local function clampPosition(position)
		local size = viewport()
		local maxX = (size.X / scaleValue) - width + 90
		local maxY = (size.Y / scaleValue) - Config.BarHeight
		return UDim2.new(
			0,
			clamp(position.X.Offset, -(width - 90), maxX),
			0,
			clamp(position.Y.Offset, 0, maxY)
		)
	end

	bar.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1
			and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		local startPointer = pointerPosition(input)
		local startPosition = frame.Position
		if window.dragCancel then
			window.dragCancel()
		end
		window.dragCancel = beginDrag(function(move)
			local delta = (pointerPosition(move) - startPointer) / scaleValue
			-- UDim2 + Vector2 no existe en Roblox: hay que sumar offset a offset
			frame.Position = clampPosition(UDim2.new(
				startPosition.X.Scale,
				startPosition.X.Offset + delta.X,
				startPosition.Y.Scale,
				startPosition.Y.Offset + delta.Y
			))
			window:Relayout()
		end)
	end)

	function window:AddConnection(item)
		table.insert(self._conns, item)
		return function()
			for index = #self._conns, 1, -1 do
				if self._conns[index] == item then
					table.remove(self._conns, index)
				end
			end
		end
	end

	function window:AddRelayout(callback)
		table.insert(self._relayout, callback)
		return callback
	end

	function window:RemoveRelayout(callback)
		for index = #self._relayout, 1, -1 do
			if self._relayout[index] == callback then
				table.remove(self._relayout, index)
			end
		end
	end

	function window:Relayout()
		for index = 1, #self._relayout do
			self._relayout[index]()
		end
	end

	function window:AddOverlay(entry)
		table.insert(self._overlays, entry)
		return entry
	end

	function window:RemoveOverlay(entry)
		for index = #self._overlays, 1, -1 do
			if self._overlays[index] == entry then
				table.remove(self._overlays, index)
			end
		end
	end

	function window:CloseOverlays()
		for index = 1, #self._overlays do
			local entry = self._overlays[index]
			if entry and entry.Close then
				entry.Close()
			end
		end
	end

	function window:AddTabButton(name)
		local index = #self.tabs + 1
		local tabButton = button(tabList, {
			Size = UDim2.new(1, 0, 0, 30),
			Position = UDim2.fromOffset(0, 0),
			LayoutOrder = index,
			Text = tostring(name),
			TextColor3 = Config.Muted,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextSize = 12,
			TextWrapped = false,
			TextTruncate = Enum.TextTruncate.AtEnd,
			BackgroundTransparency = 1,
		})
		round(tabButton, 4)
		hoverGhost(tabButton)
		new("UIPadding", { PaddingLeft = UDim.new(0, 24), PaddingRight = UDim.new(0, 6) }, tabButton)
		return { Frame = tabButton, Indicator = nil, Name = tostring(name) }
	end

	function window:SelectTab(tab)
		self:CloseOverlays()
		for index = 1, #self.tabs do
			local entry = self.tabs[index]
			local active = entry.tab == tab
			entry.page.scroller.Visible = active
			tween(entry.button, {
				TextColor3 = active and Config.Accent or Config.Muted,
				BackgroundTransparency = active and 0.2 or 1,
			}, Config.Anim)
			if entry.indicator then
				tween(entry.indicator, { BackgroundTransparency = active and 0 or 1 }, Config.Anim)
			end
		end
		self.activeTab = tab
		chipLabel.Text = tab and tab.Name or ""
	end

	function window:AddTab(name)
		local page = {}
		local scroller = new("ScrollingFrame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			CanvasSize = UDim2.new(),
			Active = true,
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollingDirection = Enum.ScrollingDirection.Y,
			ScrollBarThickness = 3,
			ScrollBarImageColor3 = Config.Accent,
			ScrollBarImageTransparency = 0.15,
			Visible = false,
		}, content)
		table.insert(self.scrollbars, scroller)

		page.order = 0
		page.scroller = scroller
		page.window = self
		page.container = new("Frame", {
			Size = UDim2.new(1, -Config.Gutter, 0, 0),
			Position = UDim2.fromOffset(Config.Gutter, 10),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
		}, scroller)
		new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8) }, page.container)
		new("UIPadding", { PaddingBottom = UDim.new(0, 20) }, page.container)

		local tab = { _page = page, Name = tostring(name), Window = self }
		tab.Button = self:AddTabButton(name)
		self:AddConnection(tab.Button.Frame.Activated:Connect(function()
			self:SelectTab(tab)
		end))

		function tab:Select()
			self.Window:SelectTab(self)
		end

		function tab:SetName(newName)
			self.Name = tostring(newName)
			self.Button.Frame.Text = self.Name
			if self.Window.activeTab == self then
				chipLabel.Text = self.Name
			end
		end

		function tab:AddSection(sectionName)
			local ok, result = pcall(function()
				local frame = makeRow(page, 26)
				tag("Accent", new("Frame", {
					Size = UDim2.fromOffset(14, 2),
					Position = UDim2.fromOffset(0, 7),
					BackgroundColor3 = Config.Accent,
					BorderSizePixel = 0,
				}, frame))
				label(frame, {
					Size = UDim2.new(1, -22, 0, 16),
					Position = UDim2.fromOffset(20, 0),
					Text = string.upper(tostring(sectionName or "Seccion")),
					TextSize = 11,
					Font = Config.MonoFont,
					TextColor3 = Config.Muted,
				}, "Muted")
				new("Frame", {
					Size = UDim2.new(1, 0, 0, 1),
					Position = UDim2.fromOffset(0, 20),
					BackgroundColor3 = Config.Stroke,
					BackgroundTransparency = 0.55,
					BorderSizePixel = 0,
				}, frame)
				return installElementMethods({ _page = page, Window = self }, page)
			end)
			if not ok then
				warnElement("Section", result)
				return installElementMethods({ _page = page, Window = self }, page)
			end
			return result
		end

		local entry = {
			tab = tab,
			page = page,
			button = tab.Button.Frame,
			indicator = tab.Button.Indicator,
		}
		tab.entry = entry
		table.insert(self.tabs, entry)

		if not self.activeTab then
			self:SelectTab(tab)
		end
		return installElementMethods(tab, page)
	end

	function window:SetTitle(text)
		titleLabel.Text = tostring(text)
	end

	function window:SetVisible(isVisible)
		if not isVisible then
			self:CloseOverlays()
		end
		frame.Visible = isVisible and true or false
	end

	function window:Toggle()
		frame.Visible = not frame.Visible
		return frame.Visible
	end

	function window:IsVisible()
		return frame.Visible
	end

	function window:Center()
		frame.Position = centerPosition(0, 0)
		self:Relayout()
	end

	function window:SetKeybind(key)
		if self.keyConnection then
			self.keyConnection:Disconnect()
			self.keyConnection = nil
		end
		if not key then
			return
		end
		self.keyConnection = UserInputService.InputBegan:Connect(function(input, processed)
			if processed or input.KeyCode ~= key or UserInputService:GetFocusedTextBox() then
				return
			end
			frame.Visible = not frame.Visible
		end)
		self:AddConnection(function()
			if self.keyConnection then
				self.keyConnection:Disconnect()
			end
		end)
	end

	function window:Minimize(isMinimized)
		self.minimized = isMinimized == nil and (not self.minimized) or (isMinimized and true or false)
		local target = self.minimized and Config.BarHeight or self.fullHeight
		minimizeButton.Text = self.minimized and "+" or "-"
		if self.minimized then
			self:CloseOverlays()
		end
		tween(frame, { Size = UDim2.new(0, self.fullWidth, 0, target) }, Config.Anim)
	end

	closeButton.MouseEnter:Connect(function()
		tween(closeButton, { BackgroundColor3 = Color3.fromRGB(180, 55, 65) }, Config.Anim)
	end)
	closeButton.MouseLeave:Connect(function()
		tween(closeButton, { BackgroundColor3 = Config.Card }, Config.Anim)
	end)
	minimizeButton.MouseEnter:Connect(function()
		tween(minimizeButton, { BackgroundColor3 = Color3.fromRGB(70, 80, 100) }, Config.Anim)
	end)
	minimizeButton.MouseLeave:Connect(function()
		tween(minimizeButton, { BackgroundColor3 = Config.Card }, Config.Anim)
	end)
	closeButton.Activated:Connect(function()
		window:Destroy()
	end)
	minimizeButton.Activated:Connect(function()
		window:Minimize()
	end)

	function window:Destroy()
		if self.dragCancel then
			self.dragCancel()
			self.dragCancel = nil
		end
		self:CloseOverlays()
		local conns = {}
		for index = 1, #self._conns do
			conns[index] = self._conns[index]
		end
		clearTable(self._conns)
		for index = 1, #conns do
			local item = conns[index]
			if type(item) == "function" then
				item()
			else
				item:Disconnect()
			end
		end
		clearTable(self._relayout)
		clearTable(self._overlays)
		for index = #Windows, 1, -1 do
			if Windows[index] == self then
				table.remove(Windows, index)
			end
		end
		tween(intro, { Scale = 0.92 }, 0.12)
		tween(frame, { BackgroundTransparency = 1 }, 0.12)
		defer(0.14, function()
			if frame.Parent then
				frame:Destroy()
			end
		end)
	end

	window.fullWidth = width
	window.fullHeight = height

	tween(intro, { Scale = 1 }, 0.24, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
	tween(frame, { BackgroundTransparency = 0 }, 0.24)

	table.insert(Windows, window)
	return window
end

--[[ NOTIFICACIONES ]]--

local toastTypes = {
	info = { label = "i", color = nil },
	success = { label = "v", color = Color3.fromRGB(80, 220, 130) },
	warn = { label = "!", color = Color3.fromRGB(255, 190, 70) },
	error = { label = "x", color = Color3.fromRGB(255, 90, 100) },
}

local toasts = {}
local toastHeight = 66

local function restackToasts()
	local offset = 20
	for index = #toasts, 1, -1 do
		local toast = toasts[index]
		tween(toast.Frame, {
			Position = UDim2.new(1, -24, 1, -offset),
		}, 0.2)
		offset = offset + toastHeight + 10
	end
end

function lib:Notify(nameOrOptions, extra)
	local options
	if type(nameOrOptions) == "string" then
		options = { Title = nameOrOptions, Text = extra }
	else
		options = nameOrOptions or extra or {}
	end
	local kind = toastTypes[options.Type or "info"] or toastTypes.info

	local toast = card(toastLayer, UDim2.fromOffset(300, toastHeight), UDim2.new(1, 40, 1, -20), "Frame")
	toast.AnchorPoint = Vector2.new(1, 1)
	toast.ZIndex = 45
	outline(toast, Config.Stroke, 1, 0.25)

	local bar = tag("Accent", new("Frame", {
		Size = UDim2.fromOffset(3, toastHeight - 16),
		Position = UDim2.fromOffset(7, 8),
		BackgroundColor3 = kind.color or Config.Accent,
		BorderSizePixel = 0,
	}, toast))
	round(bar, 2)

	new("TextLabel", {
		Size = UDim2.fromOffset(20, 20),
		Position = UDim2.fromOffset(18, 10),
		BackgroundTransparency = 1,
		Text = kind.label,
		TextColor3 = kind.color or Config.Accent,
		Font = Config.MonoFont,
		TextSize = 14,
		ZIndex = 46,
	}, toast)

	label(toast, {
		Size = UDim2.new(1, -46, 0, 18),
		Position = UDim2.fromOffset(44, 9),
		Text = tostring(options.Title or "Luna"),
		TextSize = 13,
		ZIndex = 46,
	})

	label(toast, {
		Size = UDim2.new(1, -24, 0, 32),
		Position = UDim2.fromOffset(18, 28),
		Text = tostring(options.Text or ""),
		TextSize = 12,
		TextWrapped = true,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextColor3 = Config.Muted,
		Font = Config.MonoFont,
		ZIndex = 46,
	}, "Muted")

	local entry = { Frame = toast }
	table.insert(toasts, entry)

	local function removeToast(target)
		if target.Removed or not target.Frame.Parent then
			return
		end
		target.Removed = true
		for index = #toasts, 1, -1 do
			if toasts[index] == target then
				table.remove(toasts, index)
				break
			end
		end
		tween(target.Frame, {
			Position = UDim2.new(1, 340, 1, target.Frame.Position.Y.Offset),
		}, 0.18)
		defer(0.2, function()
			if target.Frame.Parent then
				target.Frame:Destroy()
			end
		end)
		restackToasts()
	end

	restackToasts()

	while #toasts > 4 do
		removeToast(toasts[1])
	end

	defer(options.Duration or 3, function()
		removeToast(entry)
	end)
	return { Close = function() removeToast(entry) end, Frame = toast }
end

--[[ TEMA ]]--

function lib:Theme(theme)
	if type(theme) == "string" then
		theme = Themes[theme] or themeLookup[string.lower(theme)]
	end
	if type(theme) ~= "table" then
		return false
	end
	for key, value in pairs(theme) do
		if Config[key] ~= nil then
			Config[key] = value
		end
	end
	for role, instances in pairs(tint) do
		local color = Config[role]
		for index = 1, #instances do
			local object = instances[index]
			if object and object.Parent then
				if object:IsA("UIGradient") then
					object.Color = ColorSequence.new(color, Config.Accent2)
				elseif object:IsA("UIStroke") then
					object.Color = color
				elseif role == "Text" or role == "Muted" then
					object.TextColor3 = color
				else
					object.BackgroundColor3 = color
				end
			end
		end
	end
	for index = 1, #Windows do
		local window = Windows[index]
		for position = 1, #window.scrollbars do
			window.scrollbars[position].ScrollBarImageColor3 = Config.Accent
		end
	end
	return true
end

--[[ UTILIDADES PUBLICAS ]]--

function lib:ToggleAll()
	local anyVisible = false
	for index = 1, #Windows do
		if Windows[index].Frame.Visible then
			anyVisible = true
			break
		end
	end
	for index = 1, #Windows do
		Windows[index].Frame.Visible = not anyVisible
	end
end

function lib:Unload()
	for index = #Windows, 1, -1 do
		Windows[index]:Destroy()
	end
	clearTable(Windows)
	if screen and screen.Parent then
		screen:Destroy()
	end
end

function lib:GetWindows()
	return Windows
end

function lib:GetAccent()
	return Config.Accent
end

-- En executors deja la libreria accesible con getgenv().LunaUI.
if type(getgenv) == "function" then
	local ok, env = pcall(getgenv)
	if ok and type(env) == "table" then
		env.LunaUI = lib
	end
end

print("[LunaUI] " .. lib.Build .. " cargado")

return lib
