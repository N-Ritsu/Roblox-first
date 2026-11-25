--!strict
-- 棚（陳列台）に並べる商品と値段を決める画面

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ItemBuilder = require(Shared:WaitForChild("ItemBuilder"))
local Net = require(Shared:WaitForChild("Net"))
local State = require(script.Parent:WaitForChild("State"))
local UI = require(script.Parent:WaitForChild("UI"))

local ShelfPanel = {}

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local setShelfRemote = Net.Function("SetShelf")
local craftRemote = Net.Function("CraftItem")

local gui: ScreenGui
local panel: Frame
local list: ScrollingFrame
local title: TextLabel
local priceBox: TextBox
local hint: TextLabel
local currentSlot = 1
local chosenId: string? = nil
local busy = false

local function toast(text: string, color: Color3?)
	UI.Toast(playerGui, text, color)
end

local function invoke(remote: RemoteFunction, ...: any)
	if busy then
		return
	end
	busy = true
	local args = table.pack(...)
	local ok, result, message = pcall(function()
		return remote:InvokeServer(table.unpack(args, 1, args.n))
	end)
	busy = false
	if not ok then
		toast("通信に失敗しました", UI.Colors.Accent)
		return false
	end
	toast(tostring(message), if result then UI.Colors.Good else UI.Colors.Accent)
	return result
end

local function render()
	local profile = State.profile
	if not profile then
		return
	end
	local shelf = profile.shelves[tostring(currentSlot)]
	title.Text = ("陳列台 %d"):format(currentSlot)

	for _, child in list:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local ids = {}
	for id in profile.designs do
		table.insert(ids, id)
	end
	table.sort(ids, function(a, b)
		return (tonumber(string.sub(a, 2)) or 0) < (tonumber(string.sub(b, 2)) or 0)
	end)
	if #ids == 0 then
		UI.Label(list, "まだデザインがありません。工房でアイテムを作りましょう！", {
			Size = UDim2.new(1, -12, 0, 60),
			TextWrapped = true,
		})
	end
	for i, id in ids do
		local design = profile.designs[id]
		local stock = profile.stock[id] or 0
		local active = id == chosenId
		local row = UI.Frame(list, {
			Size = UDim2.new(1, -12, 0, 40),
			BackgroundColor3 = if active then Color3.fromRGB(200, 235, 205) else Color3.new(1, 1, 1),
			LayoutOrder = i,
		})
		UI.Corner(row, 8)
		if active then
			UI.Stroke(row, UI.Colors.Good, 2)
		end
		local pick = UI.Button(row, ("%s（在庫 %d）"):format(design.name, stock), Color3.new(1, 1, 1), {
			Size = UDim2.new(1, -120, 1, -6),
			Position = UDim2.new(0, 4, 0, 3),
			BackgroundTransparency = 1,
			TextColor3 = UI.Colors.Text,
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		pick.Activated:Connect(function()
			chosenId = id
			priceBox.Text = tostring(ItemBuilder.Value(design))
			render()
		end)
		local cost = ItemBuilder.CraftCost(design)
		local make = UI.Button(row, ("+1（%d）"):format(cost), UI.Colors.Coin, {
			Size = UDim2.new(0, 108, 1, -8),
			Position = UDim2.new(1, -112, 0, 4),
			TextColor3 = Color3.fromRGB(110, 70, 20),
		})
		make.Activated:Connect(function()
			invoke(craftRemote, id, 1)
		end)
	end

	if chosenId and profile.designs[chosenId] then
		local value = ItemBuilder.Value(profile.designs[chosenId])
		hint.Text = ("相場は約 %d コイン。高いほど売れにくく、安いほど早く売れます"):format(value)
	elseif shelf then
		hint.Text = "今並べている商品を選ぶと値段を変えられます"
	else
		hint.Text = "並べる商品を選んでください"
	end
end

local function createGui()
	gui = Instance.new("ScreenGui")
	gui.Name = "ShelfPanel"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 11
	gui.Parent = playerGui

	panel = UI.Frame(gui, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromScale(0.9, 0.8),
		Visible = false,
	})
	UI.Corner(panel, 16)
	UI.Stroke(panel, nil, 3)
	local constraint = Instance.new("UISizeConstraint")
	constraint.MaxSize = Vector2.new(520, 520)
	constraint.Parent = panel

	title = UI.Label(panel, "陳列台", {
		Size = UDim2.new(1, -80, 0, 34),
		Position = UDim2.new(0, 16, 0, 8),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	local close = UI.Button(panel, "×", UI.Colors.Accent, { Size = UDim2.new(0, 40, 0, 40), Position = UDim2.new(1, -50, 0, 6) })
	close.Activated:Connect(function()
		ShelfPanel.Close()
	end)

	list = Instance.new("ScrollingFrame")
	list.Size = UDim2.new(1, -24, 1, -190)
	list.Position = UDim2.new(0, 12, 0, 50)
	list.BackgroundColor3 = UI.Colors.PanelDark
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 6
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	UI.Corner(list, 12)
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 4)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Parent = list
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 6)
	padding.PaddingBottom = UDim.new(0, 6)
	padding.Parent = list
	list.Parent = panel

	hint = UI.Label(panel, "", {
		Size = UDim2.new(1, -24, 0, 34),
		Position = UDim2.new(0, 12, 1, -134),
		TextWrapped = true,
	})

	UI.Label(panel, "値段", {
		Size = UDim2.new(0, 60, 0, 40),
		Position = UDim2.new(0, 12, 1, -94),
	})
	priceBox = Instance.new("TextBox")
	priceBox.Size = UDim2.new(1, -84, 0, 40)
	priceBox.Position = UDim2.new(0, 72, 1, -94)
	priceBox.BackgroundColor3 = Color3.new(1, 1, 1)
	priceBox.Font = UI.Font
	priceBox.TextScaled = true
	priceBox.TextColor3 = UI.Colors.Text
	priceBox.PlaceholderText = "コイン"
	priceBox.ClearTextOnFocus = false
	priceBox.Text = ""
	UI.Corner(priceBox, 10)
	UI.Stroke(priceBox)
	priceBox.Parent = panel
	priceBox:GetPropertyChangedSignal("Text"):Connect(function()
		local digits = string.gsub(priceBox.Text, "%D", "")
		digits = string.sub(digits, 1, 4)
		if digits ~= priceBox.Text then
			priceBox.Text = digits
		end
	end)

	local clear = UI.Button(panel, "片付ける", UI.Colors.Muted, {
		Size = UDim2.new(0.4, -18, 0, 42),
		Position = UDim2.new(0, 12, 1, -48),
	})
	clear.Activated:Connect(function()
		if invoke(setShelfRemote, currentSlot, nil, nil) then
			chosenId = nil
			render()
		end
	end)
	local place = UI.Button(panel, "並べる", UI.Colors.Good, {
		Size = UDim2.new(0.6, -18, 0, 42),
		Position = UDim2.new(0.4, 6, 1, -48),
	})
	place.Activated:Connect(function()
		if not chosenId then
			toast("並べる商品を選んでください", UI.Colors.Accent)
			return
		end
		local price = tonumber(priceBox.Text)
		if not price or price < 1 then
			toast("値段を入れてください", UI.Colors.Accent)
			return
		end
		if invoke(setShelfRemote, currentSlot, chosenId, price) then
			ShelfPanel.Close()
		end
	end)
end

function ShelfPanel.Open(slot: number)
	local profile = State.profile
	if not profile then
		toast("データを読み込み中です…")
		return
	end
	currentSlot = slot
	local shelf = profile.shelves[tostring(slot)]
	if shelf and profile.designs[shelf.designId] then
		chosenId = shelf.designId
		priceBox.Text = tostring(shelf.price)
	else
		chosenId = nil
		priceBox.Text = ""
	end
	panel.Visible = true
	render()
end

function ShelfPanel.Close()
	panel.Visible = false
end

function ShelfPanel.Start()
	createGui()
	ProximityPromptService.PromptTriggered:Connect(function(prompt, who)
		if who ~= player or prompt.Name ~= "ShelfPrompt" then
			return
		end
		local plot = prompt:FindFirstAncestorWhichIsA("Model")
		if plot and plot:GetAttribute("OwnerUserId") == player.UserId then
			ShelfPanel.Open(prompt:GetAttribute("Slot") :: number)
		else
			toast("ここは他の人のお店の棚です")
		end
	end)
	State.Changed:Connect(function()
		if panel.Visible then
			render()
		end
	end)
end

return ShelfPanel
