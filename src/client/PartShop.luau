--!strict
-- 部品ショップ画面：形・色・素材をコインで解放する

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Catalog = require(Shared:WaitForChild("Catalog"))
local Net = require(Shared:WaitForChild("Net"))
local Season = require(Shared:WaitForChild("Season"))
local ItemBuilder = require(Shared:WaitForChild("ItemBuilder"))
local State = require(script.Parent:WaitForChild("State"))
local UI = require(script.Parent:WaitForChild("UI"))

local PartShop = {}

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local unlockRemote = Net.Function("Unlock")
local partLimitRemote = Net.Function("BuyPartLimit")

local TABS = {
	{ kind = "shapes", name = "形" },
	{ kind = "colors", name = "色" },
	{ kind = "materials", name = "素材" },
}

local panel: Frame
local list: ScrollingFrame
local tabButtons: { TextButton } = {}
local currentTab = 1
local busy = false

local function render()
	local profile = State.profile
	if not profile then
		return
	end
	for i, button in tabButtons do
		button.BackgroundColor3 = if i == currentTab then UI.Colors.Good else Color3.fromRGB(205, 150, 110)
	end
	for _, child in list:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	-- 部品の数の上限を増やす（どのタブでも一番上に出す）
	local maxParts = profile.maxParts or ItemBuilder.MaxParts
	local step = ItemBuilder.NextPartLimit(maxParts)
	local limitRow = UI.Frame(list, { Size = UDim2.new(1, -12, 0, 44), BackgroundColor3 = Color3.fromRGB(255, 245, 210), LayoutOrder = 0 })
	UI.Corner(limitRow, 8)
	UI.Label(limitRow, ("アイテムの部品の数：%d個まで"):format(maxParts), {
		Size = UDim2.new(1, -170, 1, -10),
		Position = UDim2.new(0, 10, 0, 5),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	if step then
		local limitButton = UI.Button(limitRow, ("%d個に（%d）"):format(step.limit, step.price), if profile.coins >= step.price then UI.Colors.Coin else UI.Colors.Muted, {
			Size = UDim2.new(0, 150, 1, -10),
			Position = UDim2.new(1, -156, 0, 5),
			TextColor3 = Color3.fromRGB(110, 70, 20),
		})
		limitButton.Activated:Connect(function()
			if busy then
				return
			end
			busy = true
			local ok, result, message = pcall(function()
				return partLimitRemote:InvokeServer()
			end)
			busy = false
			if ok then
				UI.Toast(playerGui, tostring(message), if result then UI.Colors.Good else UI.Colors.Accent)
			else
				UI.Toast(playerGui, "通信に失敗しました", UI.Colors.Accent)
			end
		end)
	end

	local tab = TABS[currentTab]
	local entries = table.clone(Catalog.Kinds[tab.kind])
	table.sort(entries, function(a, b)
		return a.unlockPrice < b.unlockPrice
	end)
	for i, entry in entries do
		local owned = profile.unlocks[tab.kind][entry.id] == true
		if entry.season and not owned and not Season.IsActive(entry.season) then
			continue -- 期間外の限定部品は出さない
		end
		local row = UI.Frame(list, {
			Size = UDim2.new(1, -12, 0, 44),
			BackgroundColor3 = Color3.new(1, 1, 1),
			LayoutOrder = i,
		})
		UI.Corner(row, 8)
		local swatch = UI.Frame(row, {
			Size = UDim2.new(0, 32, 0, 32),
			Position = UDim2.new(0, 6, 0.5, -16),
			BackgroundColor3 = if tab.kind == "colors" then entry.color else UI.Colors.PanelDark,
		})
		UI.Corner(swatch, 8)
		UI.Label(row, ("%s%s（価値 ×%.1f）"):format(entry.name, if entry.season then "【期間限定】" else "", entry.value), {
			Size = UDim2.new(1, -170, 1, -10),
			Position = UDim2.new(0, 46, 0, 5),
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		if owned then
			UI.Label(row, "解放ずみ", {
				Size = UDim2.new(0, 110, 1, -12),
				Position = UDim2.new(1, -116, 0, 6),
				TextColor3 = UI.Colors.Good,
			})
		else
			local canBuy = profile.coins >= entry.unlockPrice
			local buy = UI.Button(row, ("%d コイン"):format(entry.unlockPrice), if canBuy then UI.Colors.Coin else UI.Colors.Muted, {
				Size = UDim2.new(0, 110, 1, -10),
				Position = UDim2.new(1, -116, 0, 5),
				TextColor3 = Color3.fromRGB(110, 70, 20),
			})
			buy.Activated:Connect(function()
				if busy then
					return
				end
				busy = true
				local ok, result, message = pcall(function()
					return unlockRemote:InvokeServer(tab.kind, entry.id)
				end)
				busy = false
				if not ok then
					UI.Toast(playerGui, "通信に失敗しました", UI.Colors.Accent)
				else
					UI.Toast(playerGui, tostring(message), if result then UI.Colors.Good else UI.Colors.Accent)
				end
			end)
		end
	end
end

function PartShop.Open()
	if not State.profile then
		UI.Toast(playerGui, "データを読み込み中です…")
		return
	end
	UI.CloseOtherPanels(PartShop.Close)
	panel.Visible = true
	render()
end

function PartShop.Close()
	panel.Visible = false
end

function PartShop.Start()
	UI.RegisterPanel(PartShop.Close)
	local gui = Instance.new("ScreenGui")
	gui.Name = "PartShop"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 12
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
	constraint.MaxSize = Vector2.new(520, 540)
	constraint.Parent = panel

	UI.Label(panel, "部品ショップ", {
		Size = UDim2.new(1, -80, 0, 34),
		Position = UDim2.new(0, 16, 0, 8),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	local close = UI.Button(panel, "×", UI.Colors.Accent, { Size = UDim2.new(0, 40, 0, 40), Position = UDim2.new(1, -50, 0, 6) })
	close.Activated:Connect(PartShop.Close)

	for i, tab in TABS do
		local button = UI.Button(panel, tab.name, Color3.fromRGB(205, 150, 110), {
			Size = UDim2.new(1 / #TABS, -12, 0, 36),
			Position = UDim2.new((i - 1) / #TABS, 8, 0, 50),
		})
		button.Activated:Connect(function()
			currentTab = i
			render()
		end)
		tabButtons[i] = button
	end

	list = Instance.new("ScrollingFrame")
	list.Size = UDim2.new(1, -24, 1, -112)
	list.Position = UDim2.new(0, 12, 0, 96)
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

	-- 画面左の「部品」ボタン（工房ボタンの下）
	local openButton = UI.SideButton(playerGui, "OpenPartShop", "部品", Color3.fromRGB(240, 150, 60), Color3.fromRGB(170, 95, 30), 2)
	openButton.Activated:Connect(function()
		if panel.Visible then
			PartShop.Close()
		else
			PartShop.Open()
		end
	end)

	State.Changed:Connect(function()
		if panel.Visible then
			render()
		end
	end)
end

return PartShop
