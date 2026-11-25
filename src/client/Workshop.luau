--!strict
-- 工房UI：部品を組み合わせて自分だけのアイテムをデザインする

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Catalog = require(Shared:WaitForChild("Catalog"))
local ItemBuilder = require(Shared:WaitForChild("ItemBuilder"))
local Net = require(Shared:WaitForChild("Net"))
local Season = require(Shared:WaitForChild("Season"))
local Templates = require(Shared:WaitForChild("Templates"))
local State = require(script.Parent:WaitForChild("State"))
local UI = require(script.Parent:WaitForChild("UI"))

local Workshop = {}

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local saveRemote = Net.Function("SaveDesign")
local deleteRemote = Net.Function("DeleteDesign")
local craftRemote = Net.Function("CraftItem")

local editing: any = nil -- 編集中のデザイン { name, parts }
local editId: string? = nil -- 保存済みデザインを編集中ならその ID
local selected = 1
local busy = false
local deleteArmed = false

local gui: ScreenGui
local panel: Frame
local controls: ScrollingFrame
local designList: ScrollingFrame
local viewport: ViewportFrame
local viewportCamera: Camera
local previewModel: Model? = nil
local nameBox: TextBox
local infoLabel: TextLabel
local deleteButton: TextButton
local craftButton: TextButton
local craft5Button: TextButton
local highlight: BasePart? = nil -- プレビューで選択中の部品を示す光る枠
local orbitAngle = 0
local orbitDistance = 10
local orbitHeight = 1

local function deepCopy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for k, v in value do
		copy[k] = deepCopy(v)
	end
	return copy
end

local function newDesign()
	editing = { name = "", parts = { ItemBuilder.NewPart() } }
	editId = nil
	selected = 1
end

local function unlocked(kind: string, id: string): boolean
	local profile = State.profile
	return profile ~= nil and profile.unlocks[kind] ~= nil and profile.unlocks[kind][id] == true
end

local function toast(text: string, color: Color3?)
	UI.Toast(playerGui, text, color)
end

---------------------------------------------------------------- プレビュー

local function refreshPreview()
	if previewModel then
		previewModel:Destroy()
		previewModel = nil
	end
	local model = ItemBuilder.Build(editing)
	model:PivotTo(CFrame.new())
	model.Parent = viewport
	previewModel = model
	-- 選択中の部品に、少し大きい半透明の光る殻をかぶせて目立たせる
	highlight = nil
	local piece = model:FindFirstChild("Piece" .. selected)
	if piece and piece:IsA("BasePart") and #editing.parts > 1 then
		local shell = piece:Clone()
		shell.Name = "Highlight"
		shell.Size = piece.Size + Vector3.new(0.25, 0.25, 0.25)
		shell.Material = Enum.Material.Neon
		shell.Color = Color3.fromRGB(255, 230, 90)
		shell.Transparency = 0.6
		shell.Parent = model
		highlight = shell
	end
	local _, size = model:GetBoundingBox()
	local longest = math.max(size.X, size.Y, size.Z)
	orbitDistance = longest * 1.4 + 3
	orbitHeight = size.Y / 2
end

local function updateCamera()
	local target = Vector3.new(0, orbitHeight, 0)
	local offset = Vector3.new(math.sin(orbitAngle), 0.45, math.cos(orbitAngle)).Unit * orbitDistance
	viewportCamera.CFrame = CFrame.lookAt(target + offset, target)
end

---------------------------------------------------------------- 操作パネル

local refresh: () -> ()

local function section(title: string, cell: UDim2?): Frame
	local holder = UI.Frame(controls, {
		Size = UDim2.new(1, -8, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = #controls:GetChildren(),
	})
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 4)
	layout.Parent = holder
	UI.Label(holder, title, {
		Size = UDim2.new(1, 0, 0, 20),
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = 0,
	})
	local grid = UI.Frame(holder, {
		Name = "Grid",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = 1,
	})
	local gridLayout = Instance.new("UIGridLayout")
	gridLayout.CellSize = cell or UDim2.new(0, 92, 0, 32)
	gridLayout.CellPadding = UDim2.new(0, 6, 0, 6)
	gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
	gridLayout.Parent = grid
	return grid
end

local function choiceButton(parent: Instance, text: string, active: boolean, isUnlocked: boolean, order: number, onClick: () -> ()): TextButton
	local color = if not isUnlocked then UI.Colors.Muted elseif active then UI.Colors.Good else Color3.fromRGB(205, 150, 110)
	local button = UI.Button(parent, text, color, { LayoutOrder = order })
	if active then
		UI.Stroke(button, Color3.fromRGB(60, 120, 70), 3)
	end
	button.Activated:Connect(onClick)
	return button
end

local function stepper(parent: Instance, label: string, getValue: () -> number, format: (number) -> string, step: number, min: number, max: number, setValue: (number) -> ())
	local row = UI.Frame(parent, { Size = UDim2.new(1, 0, 0, 32), BackgroundTransparency = 1, LayoutOrder = #parent:GetChildren() })
	UI.Label(row, label, { Size = UDim2.new(0.36, 0, 1, -6), Position = UDim2.new(0, 0, 0, 3), TextXAlignment = Enum.TextXAlignment.Left })
	local minus = UI.Button(row, "－", Color3.fromRGB(205, 150, 110), { Size = UDim2.new(0, 40, 1, 0), Position = UDim2.new(0.38, 0, 0, 0) })
	UI.Label(row, format(getValue()), { Size = UDim2.new(0.62, -96, 1, -6), Position = UDim2.new(0.38, 44, 0, 3) })
	local plus = UI.Button(row, "＋", Color3.fromRGB(205, 150, 110), { Size = UDim2.new(0, 40, 1, 0), Position = UDim2.new(1, -44, 0, 0) })
	minus.Activated:Connect(function()
		setValue(math.clamp(getValue() - step, min, max))
		refresh()
	end)
	plus.Activated:Connect(function()
		setValue(math.clamp(getValue() + step, min, max))
		refresh()
	end)
end

local function stepperSection(title: string): Frame
	local holder = UI.Frame(controls, {
		Size = UDim2.new(1, -8, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = #controls:GetChildren(),
	})
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 4)
	layout.Parent = holder
	UI.Label(holder, title, { Size = UDim2.new(1, 0, 0, 20), TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 0 })
	return holder
end

local function fmtNumber(v: number): string
	return string.format("%.1f", v)
end

local function buildControls()
	for _, child in controls:GetChildren() do
		if not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
			child:Destroy()
		end
	end
	local parts = editing.parts
	selected = math.clamp(selected, 1, #parts)
	local part = parts[selected]

	-- 部品の選択・追加・削除
	local maxParts = if State.profile then State.profile.maxParts or ItemBuilder.MaxParts else ItemBuilder.MaxParts
	local partsGrid = section(("部品（%d/%d）"):format(#parts, maxParts), UDim2.new(0, 56, 0, 32))
	for i = 1, #parts do
		choiceButton(partsGrid, tostring(i), i == selected, true, i, function()
			selected = i
			refresh()
		end)
	end
	if #parts < maxParts then
		choiceButton(partsGrid, "＋追加", false, true, 100, function()
			local newPart = ItemBuilder.NewPart()
			newPart.pos = { 0, math.min(ItemBuilder.PosLimit, part.pos[2] + 1), 0 }
			newPart.color = part.color
			newPart.material = part.material
			newPart.size = { 1, 1, 1 }
			table.insert(parts, newPart)
			selected = #parts
			refresh()
		end)
		choiceButton(partsGrid, "複製", false, true, 101, function()
			local copy = deepCopy(part)
			copy.pos[1] = math.min(ItemBuilder.PosLimit, copy.pos[1] + 1)
			table.insert(parts, copy)
			selected = #parts
			refresh()
		end)
	end
	if #parts > 1 then
		choiceButton(partsGrid, "削除", false, true, 102, function()
			table.remove(parts, selected)
			selected = math.max(1, selected - 1)
			refresh()
		end)
	end

	-- 形
	local shapeGrid = section("形")
	for i, shape in Catalog.Shapes do
		local isUnlocked = unlocked("shapes", shape.id)
		local text = if isUnlocked then shape.name else shape.name .. " 🔒"
		choiceButton(shapeGrid, text, part.shape == shape.id, isUnlocked, i, function()
			if not isUnlocked then
				toast(("「%s」は部品ショップで解放できます（%d コイン）"):format(shape.name, shape.unlockPrice))
				return
			end
			part.shape = shape.id
			part.size = ItemBuilder.NormalizeSize(shape.id, part.size)
			refresh()
		end)
	end

	-- 色
	local colorGrid = section("色", UDim2.new(0, 36, 0, 36))
	for i, color in Catalog.Colors do
		local isUnlocked = unlocked("colors", color.id)
		if color.season and not isUnlocked and not Season.IsActive(color.season) then
			continue -- 期間外の限定色は出さない
		end
		local swatch = UI.Button(colorGrid, if isUnlocked then "" else "🔒", color.color, { LayoutOrder = i })
		if not isUnlocked then
			swatch.BackgroundTransparency = 0.6
		end
		if part.color == color.id then
			UI.Stroke(swatch, Color3.fromRGB(40, 40, 40), 3)
		end
		swatch.Activated:Connect(function()
			if not isUnlocked then
				toast(("「%s」は部品ショップで解放できます（%d コイン）"):format(color.name, color.unlockPrice))
				return
			end
			part.color = color.id
			refresh()
		end)
	end

	-- 素材
	local materialGrid = section("素材", UDim2.new(0, 110, 0, 32))
	for i, material in Catalog.Materials do
		local isUnlocked = unlocked("materials", material.id)
		local text = if isUnlocked then material.name else material.name .. " 🔒"
		choiceButton(materialGrid, text, part.material == material.id, isUnlocked, i, function()
			if not isUnlocked then
				toast(("「%s」は部品ショップで解放できます（%d コイン）"):format(material.name, material.unlockPrice))
				return
			end
			part.material = material.id
			refresh()
		end)
	end

	-- 大きさ
	local step = ItemBuilder.Step
	local sMin, sMax = ItemBuilder.SizeMin, ItemBuilder.SizeMax
	local sizeSection = stepperSection("大きさ")
	local sizeLabels = if part.shape == "Ball" then { "直径" } elseif part.shape == "Cylinder" then { "長さ", "太さ" } else { "横", "高さ", "奥行き" }
	for axis, label in sizeLabels do
		stepper(sizeSection, label, function()
			return part.size[axis]
		end, fmtNumber, step, sMin, sMax, function(v)
			part.size[axis] = v
			part.size = ItemBuilder.NormalizeSize(part.shape, part.size)
		end)
	end

	-- 位置
	local limit = ItemBuilder.PosLimit
	local posSection = stepperSection("位置")
	for axis, label in { "左右", "上下", "前後" } do
		stepper(posSection, label, function()
			return part.pos[axis]
		end, fmtNumber, step, -limit, limit, function(v)
			part.pos[axis] = v
		end)
	end

	-- 向き：よく使う向きはワンタッチで（円柱は横向きが基本なので「立てる」が便利）
	local presetGrid = section("向き（かんたん）")
	local presets = {
		{ text = "立てる", rot = { 2, 2 } },
		{ text = "横向き", rot = { 0, 0 } },
		{ text = "前後向き", rot = { 0, 2 } },
	}
	for i, preset in presets do
		local active = part.rot[1] == preset.rot[1] and part.rot[2] == preset.rot[2]
		choiceButton(presetGrid, preset.text, active, true, i, function()
			part.rot = { preset.rot[1], preset.rot[2] }
			refresh()
		end)
	end
	local rotSection = stepperSection("向き（細かく）")
	for axis, label in { "たて回転", "よこ回転" } do
		stepper(rotSection, label, function()
			return part.rot[axis]
		end, function(v)
			return ("%d°"):format(v * 45)
		end, 1, -1, 8, function(v)
			part.rot[axis] = v % 8
		end)
	end
end

local function buildDesignList()
	for _, child in designList:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local newButton = UI.Button(designList, "＋ 新しく作る", UI.Colors.Good, { Size = UDim2.new(1, -8, 0, 30), LayoutOrder = 0 })
	newButton.Activated:Connect(function()
		newDesign()
		nameBox.Text = ""
		refresh()
	end)
	if editId then
		-- 今のデザインを元に、別のデザインとして作り始める
		local copyButton = UI.Button(designList, "今のデザインをコピー", Color3.fromRGB(90, 170, 240), { Size = UDim2.new(1, -8, 0, 30), LayoutOrder = 1 })
		copyButton.Activated:Connect(function()
			editing = deepCopy(editing)
			editId = nil
			local base = nameBox.Text
			if utf8.len(base) and (utf8.len(base) :: number) <= 18 then
				nameBox.Text = base .. "2"
			end
			refresh()
			toast("コピーしました。名前を変えて保存してください")
		end)
	end
	-- 見本から作る（一覧の一番下）
	UI.Label(designList, "見本から作る", { Size = UDim2.new(1, -8, 0, 22), LayoutOrder = 1000 })
	for i, template in Templates do
		local button = UI.Button(designList, "見本：" .. template.name, Color3.fromRGB(150, 110, 210), { Size = UDim2.new(1, -8, 0, 30), LayoutOrder = 1000 + i })
		button.Activated:Connect(function()
			editing = deepCopy(template)
			editId = nil
			selected = 1
			nameBox.Text = template.name
			refresh()
			toast("見本を読み込みました。好きに変えて保存しよう")
		end)
	end

	local profile = State.profile
	if not profile then
		return
	end
	local ids = {}
	for id, design in profile.designs do
		if not design.boughtFrom then -- 買ったアイテムは工房では編集できない
			table.insert(ids, id)
		end
	end
	table.sort(ids, function(a, b)
		return (tonumber(string.sub(a, 2)) or 0) < (tonumber(string.sub(b, 2)) or 0)
	end)
	for i, id in ids do
		local design = profile.designs[id]
		local active = id == editId
		local sales = profile.designSales and profile.designSales[id] or 0
		local label = if sales > 0 then ("%s（%d個売れた）"):format(design.name, sales) else design.name
		local button = UI.Button(designList, label, if active then UI.Colors.Good else Color3.fromRGB(205, 150, 110), {
			Size = UDim2.new(1, -8, 0, 30),
			LayoutOrder = i + 1,
		})
		button.Activated:Connect(function()
			editing = deepCopy(design)
			editId = id
			selected = 1
			nameBox.Text = design.name or ""
			refresh()
		end)
	end
end

local function updateInfo()
	local value = ItemBuilder.Value(editing)
	local cost = ItemBuilder.CraftCost(editing)
	local stock = 0
	local profile = State.profile
	if editId and profile and profile.stock[editId] then
		stock = profile.stock[editId]
	end
	if editId then
		infoLabel.Text = ("価値 約%d ・ 在庫 %d"):format(value, stock)
	else
		infoLabel.Text = ("価値 約%d ・ 製作 %d コイン（保存すると作れます）"):format(value, cost)
	end
	craftButton.Visible = editId ~= nil
	craftButton.Text = ("1個（%d）"):format(cost)
	craft5Button.Visible = editId ~= nil
	craft5Button.Text = ("5個（%d）"):format(cost * 5)
	deleteButton.Visible = editId ~= nil
	deleteButton.Text = if deleteArmed then "本当に消す？" else "消す"
end

refresh = function()
	buildControls()
	refreshPreview()
	updateInfo()
	buildDesignList()
end

---------------------------------------------------------------- 保存・削除

local function save()
	if busy then
		return
	end
	editing.name = nameBox.Text
	busy = true
	local ok, result, message = pcall(function()
		return saveRemote:InvokeServer(editing, editId)
	end)
	busy = false
	if not ok then
		toast("通信に失敗しました。もう一度どうぞ", UI.Colors.Accent)
		return
	end
	if result then
		editId = message
		toast("デザインを保存しました！", UI.Colors.Good)
		-- 保存されたもの（名前のフィルター後）を読み込み直す
		task.defer(function()
			local profile = State.profile
			if profile and editId and profile.designs[editId] then
				editing = deepCopy(profile.designs[editId])
				nameBox.Text = editing.name
				refresh()
			end
		end)
	else
		toast(tostring(message), UI.Colors.Accent)
	end
end

-- 部品の内容が同じか（保存していない変更があるかの判定）
local function samePartList(a: any, b: any): boolean
	if #a ~= #b then
		return false
	end
	for i = 1, #a do
		local p, q = a[i], b[i]
		if p.shape ~= q.shape or p.color ~= q.color or p.material ~= q.material then
			return false
		end
		for _, field in { "size", "pos", "rot" } do
			local u, v = p[field], q[field]
			for j = 1, #u do
				if u[j] ~= v[j] then
					return false
				end
			end
		end
	end
	return true
end

local function craft(count: number)
	if busy or not editId then
		return
	end
	local profile = State.profile
	local saved = profile and profile.designs[editId]
	if saved then
		-- 保存していない変更があるときは、保存したデザインで作ることを知らせる
		if not samePartList(saved.parts, editing.parts) then
			toast("変更が保存されていません。先に「保存」してください", UI.Colors.Accent)
			return
		end
	end
	busy = true
	local ok, result, message = pcall(function()
		return craftRemote:InvokeServer(editId, count)
	end)
	busy = false
	if not ok then
		toast("通信に失敗しました", UI.Colors.Accent)
	elseif result then
		toast(tostring(message), UI.Colors.Good)
	else
		toast(tostring(message), UI.Colors.Accent)
	end
end

local function delete()
	if busy or not editId then
		return
	end
	if not deleteArmed then
		deleteArmed = true
		updateInfo()
		task.delay(3, function()
			deleteArmed = false
			if panel and panel.Visible then
				updateInfo()
			end
		end)
		return
	end
	deleteArmed = false
	busy = true
	local ok, result = pcall(function()
		return deleteRemote:InvokeServer(editId)
	end)
	busy = false
	if ok and result then
		toast("デザインを消しました")
		newDesign()
		nameBox.Text = ""
		refresh()
	else
		toast("消せませんでした", UI.Colors.Accent)
	end
end

---------------------------------------------------------------- 画面の組み立て

local function createGui()
	gui = Instance.new("ScreenGui")
	gui.Name = "Workshop"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 10
	gui.Parent = playerGui

	panel = UI.Frame(gui, {
		Name = "Panel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromScale(0.94, 0.84),
		Visible = false,
	})
	UI.Corner(panel, 16)
	UI.Stroke(panel, nil, 3)
	local constraint = Instance.new("UISizeConstraint")
	constraint.MaxSize = Vector2.new(920, 580)
	constraint.Parent = panel

	UI.Label(panel, "工房 ― アイテムを作ろう", {
		Size = UDim2.new(1, -120, 0, 34),
		Position = UDim2.new(0, 16, 0, 8),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	local close = UI.Button(panel, "×", UI.Colors.Accent, { Size = UDim2.new(0, 40, 0, 40), Position = UDim2.new(1, -50, 0, 6) })
	close.Activated:Connect(function()
		Workshop.Close()
	end)

	-- 左：プレビューとデザイン一覧
	local left = UI.Frame(panel, {
		Size = UDim2.new(0.4, -16, 1, -60),
		Position = UDim2.new(0, 12, 0, 50),
		BackgroundTransparency = 1,
	})
	viewport = Instance.new("ViewportFrame")
	viewport.Size = UDim2.new(1, 0, 0.6, -4)
	viewport.BackgroundColor3 = Color3.fromRGB(225, 235, 245)
	viewport.Ambient = Color3.fromRGB(170, 170, 180)
	viewport.LightColor = Color3.fromRGB(255, 250, 240)
	viewport.LightDirection = Vector3.new(-1, -2, -1)
	UI.Corner(viewport, 12)
	viewport.Parent = left
	viewportCamera = Instance.new("Camera")
	viewportCamera.FieldOfView = 40
	viewportCamera.Parent = viewport
	viewport.CurrentCamera = viewportCamera

	designList = Instance.new("ScrollingFrame")
	designList.Size = UDim2.new(1, 0, 0.4, -4)
	designList.Position = UDim2.new(0, 0, 0.6, 4)
	designList.BackgroundColor3 = UI.Colors.PanelDark
	designList.BorderSizePixel = 0
	designList.ScrollBarThickness = 6
	designList.AutomaticCanvasSize = Enum.AutomaticSize.Y
	designList.CanvasSize = UDim2.new()
	UI.Corner(designList, 12)
	local listLayout = Instance.new("UIListLayout")
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Padding = UDim.new(0, 4)
	listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	listLayout.Parent = designList
	local listPadding = Instance.new("UIPadding")
	listPadding.PaddingTop = UDim.new(0, 6)
	listPadding.PaddingBottom = UDim.new(0, 6)
	listPadding.Parent = designList
	designList.Parent = left

	-- 右：部品の設定、名前と保存
	local right = UI.Frame(panel, {
		Size = UDim2.new(0.6, -16, 1, -60),
		Position = UDim2.new(0.4, 4, 0, 50),
		BackgroundTransparency = 1,
	})
	controls = Instance.new("ScrollingFrame")
	controls.Size = UDim2.new(1, 0, 1, -96)
	controls.BackgroundColor3 = UI.Colors.PanelDark
	controls.BorderSizePixel = 0
	controls.ScrollBarThickness = 6
	controls.AutomaticCanvasSize = Enum.AutomaticSize.Y
	controls.CanvasSize = UDim2.new()
	UI.Corner(controls, 12)
	local controlsLayout = Instance.new("UIListLayout")
	controlsLayout.SortOrder = Enum.SortOrder.LayoutOrder
	controlsLayout.Padding = UDim.new(0, 10)
	controlsLayout.Parent = controls
	local controlsPadding = Instance.new("UIPadding")
	controlsPadding.PaddingTop = UDim.new(0, 8)
	controlsPadding.PaddingLeft = UDim.new(0, 10)
	controlsPadding.PaddingRight = UDim.new(0, 6)
	controlsPadding.PaddingBottom = UDim.new(0, 8)
	controlsPadding.Parent = controls
	controls.Parent = right

	nameBox = Instance.new("TextBox")
	nameBox.Size = UDim2.new(1, -200, 0, 40)
	nameBox.Position = UDim2.new(0, 0, 1, -88)
	nameBox.BackgroundColor3 = Color3.new(1, 1, 1)
	nameBox.Font = UI.Font
	nameBox.TextScaled = true
	nameBox.TextColor3 = UI.Colors.Text
	nameBox.PlaceholderText = "アイテムの名前"
	nameBox.ClearTextOnFocus = false
	nameBox.Text = ""
	UI.Corner(nameBox, 10)
	UI.Stroke(nameBox)
	nameBox.Parent = right

	deleteButton = UI.Button(right, "消す", UI.Colors.Muted, { Size = UDim2.new(0, 84, 0, 40), Position = UDim2.new(1, -190, 1, -88) })
	deleteButton.Activated:Connect(delete)
	local saveButton = UI.Button(right, "保存", UI.Colors.Good, { Size = UDim2.new(0, 96, 0, 40), Position = UDim2.new(1, -96, 1, -88) })
	saveButton.Activated:Connect(save)

	craftButton = UI.Button(right, "1個", UI.Colors.Coin, {
		Size = UDim2.new(0, 96, 0, 38),
		Position = UDim2.new(1, -200, 1, -40),
		TextColor3 = Color3.fromRGB(110, 70, 20),
	})
	craftButton.Activated:Connect(function()
		craft(1)
	end)
	craft5Button = UI.Button(right, "5個", UI.Colors.Coin, {
		Size = UDim2.new(0, 96, 0, 38),
		Position = UDim2.new(1, -96, 1, -40),
		TextColor3 = Color3.fromRGB(110, 70, 20),
	})
	craft5Button.Activated:Connect(function()
		craft(5)
	end)
	infoLabel = UI.Label(right, "", {
		Size = UDim2.new(1, -208, 0, 28),
		Position = UDim2.new(0, 0, 1, -40),
		TextXAlignment = Enum.TextXAlignment.Left,
	})

	-- 画面左下の「工房」ボタン（どこからでも開ける）
	local openButton = UI.SideButton(playerGui, "OpenWorkshop", "工房", Color3.fromRGB(90, 170, 240), Color3.fromRGB(40, 100, 170), 1)
	openButton.Activated:Connect(function()
		if panel.Visible then
			Workshop.Close()
		else
			Workshop.Open()
		end
	end)
end

function Workshop.Open()
	if not State.profile then
		toast("データを読み込み中です…")
		return
	end
	if not editing then
		newDesign()
	end
	nameBox.Text = editing.name or ""
	UI.CloseOtherPanels(Workshop.Close)
	panel.Visible = true
	refresh()
end

function Workshop.Close()
	panel.Visible = false
	if editing then
		editing.name = nameBox.Text
	end
end

function Workshop.Start()
	UI.RegisterPanel(Workshop.Close)
	createGui()

	RunService.RenderStepped:Connect(function(dt)
		if panel.Visible then
			orbitAngle += dt * 0.6
			updateCamera()
			if highlight then
				highlight.Transparency = 0.55 + 0.25 * math.sin(os.clock() * 5)
			end
		end
	end)

	-- 自分の店の作業台で開く
	ProximityPromptService.PromptTriggered:Connect(function(prompt, who)
		if who ~= player or prompt.Name ~= "WorkbenchPrompt" then
			return
		end
		local plot = prompt:FindFirstAncestorWhichIsA("Model")
		if plot and plot:GetAttribute("OwnerUserId") == player.UserId then
			Workshop.Open()
		else
			toast("ここは他の人のお店の工房です")
		end
	end)

	-- 解放状況などが変わったら開いている画面を更新する
	State.Changed:Connect(function()
		if panel.Visible then
			buildControls()
			buildDesignList()
			updateInfo()
		end
	end)
end

return Workshop
