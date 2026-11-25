--!strict
-- 自宅の模様替え画面：マス目を選んで、作ったアイテムを飾る

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Catalog = require(Shared:WaitForChild("Catalog"))
local Net = require(Shared:WaitForChild("Net"))
local State = require(script.Parent:WaitForChild("State"))
local UI = require(script.Parent:WaitForChild("UI"))

local HomePanel = {}

local GRID = 6 -- サーバーの PlotService.HomeGridSize と同じ
local WALL_SLOTS = 6 -- サーバーの PlotService.HomeWallSlots と同じ
local wallRow: Frame
local EXPAND_PRICE = 800 -- サーバーの PlotService.HomeExpandPrice と同じ
local gridLayout: UIGridLayout

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local setCellRemote = Net.Function("SetHomeCell")
local publicRemote = Net.Function("SetHomePublic")
local lightRemote = Net.Function("SetHomeLight")
local ShopUpgrades = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("ShopUpgrades"))
local expandRemote = Net.Function("ExpandHome")
local deleteRemote = Net.Function("DeleteDesign")
local discardArmed: string? = nil
local publicButton: TextButton
local lightButton: TextButton

local panel: Frame
local grid: Frame
local list: ScrollingFrame
local info: TextLabel
local selectedCell: string? = nil
local busy = false

local function toast(text: string, color: Color3?)
	UI.Toast(playerGui, text, color)
end

local function invoke(action: string, designId: string?)
	if busy or not selectedCell then
		return
	end
	busy = true
	local cell = selectedCell
	local ok, result, message = pcall(function()
		return setCellRemote:InvokeServer(cell, action, designId)
	end)
	busy = false
	if not ok then
		toast("通信に失敗しました", UI.Colors.Accent)
	elseif not result then
		toast(tostring(message), UI.Colors.Accent)
	end
end

local function render()
	local profile = State.profile
	if not profile then
		return
	end
	local currentLight = ShopUpgrades.HomeLightById[profile.homeLight or "normal"] or ShopUpgrades.HomeLights[1]
	lightButton.Text = "灯り：" .. currentLight.name
	publicButton.Text = if profile.homePublic then ("公開中 ♥%d"):format(profile.homeLikes or 0) else "非公開"
	publicButton.BackgroundColor3 = if profile.homePublic then UI.Colors.Good else UI.Colors.Muted
	-- 壁かけ：奥の壁を向いたとき +X が左なので、左から w6, w5, … w1
	for _, child in wallRow:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	for col = 1, WALL_SLOTS do
		local key = "w" .. (WALL_SLOTS + 1 - col)
		local placed = profile.home[key]
		local design = placed and profile.designs[placed.designId]
		local text = "壁"
		local color = Color3.fromRGB(200, 175, 140)
		if design then
			local first = design.parts[1]
			local entry = first and Catalog.ColorById[first.color]
			color = if entry then entry.color else UI.Colors.Good
			local length = utf8.len(design.name) or 0
			text = if length > 2 then string.sub(design.name, 1, (utf8.offset(design.name, 3) or 1) - 1) else design.name
		end
		local button = UI.Button(wallRow, text, color, { LayoutOrder = col })
		local luminance = color.R * 0.299 + color.G * 0.587 + color.B * 0.114
		button.TextColor3 = if luminance > 0.62 then UI.Colors.Text else Color3.new(1, 1, 1)
		if key == selectedCell then
			UI.Stroke(button, Color3.fromRGB(40, 40, 40), 3)
		end
		button.Activated:Connect(function()
			selectedCell = key
			render()
		end)
	end

	for _, child in grid:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	-- 部屋の奥（z が大きい方）を上に、入口側を下に並べる。部屋の奥を向いたとき +X は左手側
	-- 広げると外側に1列ずつ増える（キーは 0〜GRID+1）
	local minCell, maxCell = if profile.homeExpanded then 0 else 1, if profile.homeExpanded then GRID + 1 else GRID
	local count = maxCell - minCell + 1
	gridLayout.CellSize = UDim2.new(1 / count, -4, 1 / count, -4)
	for row = 1, count do
		local z = maxCell + 1 - row
		for col = 1, count do
			local x = maxCell + 1 - col
			local key = x .. "_" .. z
			local placed = profile.home[key]
			local design = placed and profile.designs[placed.designId]
			local color = Color3.fromRGB(235, 225, 210)
			local text = ""
			if design then
				local first = design.parts[1]
				local entry = first and Catalog.ColorById[first.color]
				color = if entry then entry.color else UI.Colors.Good
				local length = utf8.len(design.name) or 0
				text = if length > 2 then string.sub(design.name, 1, (utf8.offset(design.name, 3) or 1) - 1) else design.name
			end
			local button = UI.Button(grid, text, color, { LayoutOrder = row * 10 + col })
			local luminance = color.R * 0.299 + color.G * 0.587 + color.B * 0.114
			button.TextColor3 = if luminance > 0.62 then UI.Colors.Text else Color3.new(1, 1, 1)
			if key == selectedCell then
				UI.Stroke(button, Color3.fromRGB(40, 40, 40), 3)
			end
			button.Activated:Connect(function()
				selectedCell = key
				render()
			end)
		end
	end

	for _, child in list:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	if not profile.homeExpanded then
		local expand = UI.Button(list, ("自宅を 8×8 に広げる（%d）"):format(EXPAND_PRICE), if profile.coins >= EXPAND_PRICE then UI.Colors.Coin else UI.Colors.Muted, {
			Size = UDim2.new(1, -12, 0, 34),
			LayoutOrder = -1,
			TextColor3 = Color3.fromRGB(110, 70, 20),
		})
		expand.Activated:Connect(function()
			if busy then
				return
			end
			busy = true
			local ok, result, message = pcall(function()
				return expandRemote:InvokeServer()
			end)
			busy = false
			if ok then
				toast(tostring(message), if result then UI.Colors.Good else UI.Colors.Accent)
			else
				toast("通信に失敗しました", UI.Colors.Accent)
			end
		end)
	end
	if not selectedCell then
		info.Text = "飾りたいマスを選んでね"
		return
	end
	local placed = profile.home[selectedCell]
	local placedDesign = placed and profile.designs[placed.designId]
	info.Text = if placedDesign then ("置いているもの：%s"):format(placedDesign.name) else "空いているマス"

	if placedDesign then
		local rotate = UI.Button(list, "回す", Color3.fromRGB(90, 170, 240), { Size = UDim2.new(1, -12, 0, 34), LayoutOrder = 0 })
		rotate.Activated:Connect(function()
			invoke("rotate")
		end)
		local remove = UI.Button(list, "片付ける（在庫に戻す）", UI.Colors.Muted, { Size = UDim2.new(1, -12, 0, 34), LayoutOrder = 1 })
		remove.Activated:Connect(function()
			invoke("remove")
		end)
	end
	local ids = {}
	for id in profile.designs do
		table.insert(ids, id)
	end
	table.sort(ids, function(a, b)
		return (tonumber(string.sub(a, 2)) or 0) < (tonumber(string.sub(b, 2)) or 0)
	end)
	if #ids == 0 then
		UI.Label(list, "まだアイテムがありません", { Size = UDim2.new(1, -12, 0, 30), LayoutOrder = 2 })
	end
	for i, id in ids do
		local design = profile.designs[id]
		local stock = profile.stock[id] or 0
		local label = if design.gift then ("%s（%s さんから）"):format(design.name, design.boughtFrom) elseif design.boughtFrom then ("%s（%s さんの店）"):format(design.name, design.boughtFrom) else design.name
		local button = UI.Button(list, ("%s を置く（%d）"):format(label, stock), if stock > 0 then UI.Colors.Good else UI.Colors.Muted, {
			Size = UDim2.new(1, -12, 0, 34),
			LayoutOrder = 10 + i * 2,
		})
		if design.boughtFrom then
			-- 買った・もらったアイテムを手放す（2回押しで確定）
			local armed = discardArmed == id
			local discard = UI.Button(list, if armed then "本当に捨てる？（もう一度押す）" else ("「%s」を捨てる"):format(design.name), UI.Colors.Muted, {
				Size = UDim2.new(1, -12, 0, 28),
				LayoutOrder = 11 + i * 2,
			})
			discard.Activated:Connect(function()
				if discardArmed ~= id then
					discardArmed = id
					render()
					return
				end
				discardArmed = nil
				if busy then
					return
				end
				busy = true
				local ok, result = pcall(function()
					return deleteRemote:InvokeServer(id)
				end)
				busy = false
				toast(if ok and result then "捨てました" else "捨てられませんでした", if ok and result then nil else UI.Colors.Accent)
			end)
		end
		button.Activated:Connect(function()
			if stock <= 0 then
				toast("在庫がありません。工房で作りましょう", UI.Colors.Accent)
				return
			end
			invoke("place", id)
		end)
	end
end

function HomePanel.Open()
	if not State.profile then
		toast("データを読み込み中です…")
		return
	end
	UI.CloseOtherPanels(HomePanel.Close)
	panel.Visible = true
	render()
end

function HomePanel.Close()
	panel.Visible = false
end

function HomePanel.Start()
	UI.RegisterPanel(HomePanel.Close)
	local gui = Instance.new("ScreenGui")
	gui.Name = "HomePanel"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 13
	gui.Parent = playerGui

	panel = UI.Frame(gui, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromScale(0.94, 0.84),
		Visible = false,
	})
	UI.Corner(panel, 16)
	UI.Stroke(panel, nil, 3)
	local constraint = Instance.new("UISizeConstraint")
	constraint.MaxSize = Vector2.new(760, 480)
	constraint.Parent = panel

	UI.Label(panel, "模様替え", {
		Size = UDim2.new(1, -370, 0, 34),
		Position = UDim2.new(0, 16, 0, 8),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	local close = UI.Button(panel, "×", UI.Colors.Accent, { Size = UDim2.new(0, 40, 0, 40), Position = UDim2.new(1, -50, 0, 6) })
	close.Activated:Connect(HomePanel.Close)
	publicButton = UI.Button(panel, "公開中", UI.Colors.Good, { Size = UDim2.new(0, 150, 0, 36), Position = UDim2.new(1, -210, 0, 8) })
	-- 灯り：押すたびに次の灯りへ（無料）
	lightButton = UI.Button(panel, "灯り：ふつう", Color3.fromRGB(250, 215, 120), { Size = UDim2.new(0, 120, 0, 36), Position = UDim2.new(1, -336, 0, 8) })
	lightButton.Activated:Connect(function()
		local profile = State.profile
		if not profile or busy then
			return
		end
		local index = 1
		for i, entry in ShopUpgrades.HomeLights do
			if entry.id == (profile.homeLight or "normal") then
				index = i
			end
		end
		local nextLight = ShopUpgrades.HomeLights[index % #ShopUpgrades.HomeLights + 1]
		busy = true
		local ok, result, message = pcall(function()
			return lightRemote:InvokeServer(nextLight.id)
		end)
		busy = false
		if ok then
			toast(tostring(message), if result then UI.Colors.Good else UI.Colors.Accent)
		else
			toast("通信に失敗しました", UI.Colors.Accent)
		end
	end)
	publicButton.Activated:Connect(function()
		local profile = State.profile
		if not profile or busy then
			return
		end
		busy = true
		local ok, result, message = pcall(function()
			return publicRemote:InvokeServer(not profile.homePublic)
		end)
		busy = false
		if ok then
			toast(tostring(message), if result then UI.Colors.Good else UI.Colors.Accent)
		else
			toast("通信に失敗しました", UI.Colors.Accent)
		end
	end)

	-- 左：マス目（正方形を保つ）
	-- 奥の壁の「壁かけ」の棚（マス目の上に1列）
	wallRow = UI.Frame(panel, {
		Size = UDim2.new(0.5, -18, 0, 36),
		Position = UDim2.new(0, 12, 0, 50),
		BackgroundTransparency = 1,
	})
	local wallLayout = Instance.new("UIGridLayout")
	wallLayout.CellSize = UDim2.new(1 / WALL_SLOTS, -4, 1, 0)
	wallLayout.CellPadding = UDim2.new(0, 4, 0, 0)
	wallLayout.SortOrder = Enum.SortOrder.LayoutOrder
	wallLayout.Parent = wallRow

	grid = UI.Frame(panel, {
		Size = UDim2.new(0.5, -18, 1, -132),
		Position = UDim2.new(0, 12, 0, 92),
		BackgroundColor3 = UI.Colors.PanelDark,
	})
	UI.Corner(grid, 12)
	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.AspectRatio = 1
	aspect.Parent = grid
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.new(1 / GRID, -4, 1 / GRID, -4)
	gridLayout = layout
	layout.CellPadding = UDim2.new(0, 4, 0, 4)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = grid
	UI.Label(panel, "↑ 部屋の奥　／　↓ 入口", {
		Size = UDim2.new(0.5, -18, 0, 26),
		Position = UDim2.new(0, 12, 1, -34),
	})

	-- 右：選んだマスの操作
	info = UI.Label(panel, "", {
		Size = UDim2.new(0.5, -18, 0, 30),
		Position = UDim2.new(0.5, 6, 0, 50),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	list = Instance.new("ScrollingFrame")
	list.Size = UDim2.new(0.5, -18, 1, -100)
	list.Position = UDim2.new(0.5, 6, 0, 86)
	list.BackgroundColor3 = UI.Colors.PanelDark
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 6
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	UI.Corner(list, 12)
	local listLayout = Instance.new("UIListLayout")
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Padding = UDim.new(0, 4)
	listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	listLayout.Parent = list
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 6)
	padding.PaddingBottom = UDim.new(0, 6)
	padding.Parent = list
	list.Parent = panel

	ProximityPromptService.PromptTriggered:Connect(function(prompt, who)
		if who ~= player or prompt.Name ~= "HomeDecorPrompt" then
			return
		end
		local plot = prompt:FindFirstAncestor("Home")
		local plotModel = plot and plot.Parent
		if plotModel and plotModel:GetAttribute("OwnerUserId") == player.UserId then
			HomePanel.Open()
		end
	end)
	State.Changed:Connect(function()
		if panel.Visible then
			render()
		end
	end)
end

return HomePanel
