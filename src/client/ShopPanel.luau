--!strict
-- 「お店」画面：陳列台を増やす・壁と床の内装を選ぶ

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local ShopUpgrades = require(Shared:WaitForChild("ShopUpgrades"))
local State = require(script.Parent:WaitForChild("State"))
local UI = require(script.Parent:WaitForChild("UI"))

local ShopPanel = {}

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local buySlotRemote = Net.Function("BuyShelfSlot")
local interiorRemote = Net.Function("SetInterior")
local sloganRemote = Net.Function("SetSlogan")
local openSlogan: () -> () = function() end

local panel: Frame
local content: ScrollingFrame
local busy = false

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
		UI.Toast(playerGui, "通信に失敗しました", UI.Colors.Accent)
	else
		UI.Toast(playerGui, tostring(message), if result then UI.Colors.Good else UI.Colors.Accent)
	end
end

local function heading(text: string, order: number)
	UI.Label(content, text, {
		Size = UDim2.new(1, -12, 0, 26),
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = order,
	})
end

local function grid(order: number): Frame
	local frame = UI.Frame(content, {
		Size = UDim2.new(1, -12, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = order,
	})
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.new(0, 140, 0, 40)
	layout.CellPadding = UDim2.new(0, 6, 0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = frame
	return frame
end

local function render()
	local profile = State.profile
	if not profile then
		return
	end
	for _, child in content:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end

	local stars = math.clamp(1 + math.floor((profile.reputation or 0) / 25), 1, 5)
	heading(("お店の評判 %s%s"):format(string.rep("★", stars) .. string.rep("☆", 5 - stars), if stars < 5 then "（相場くらいの値段で売ると上がる）" else ""), 0)
	heading(("陳列台：%d / %d 台"):format(profile.shelfSlots, ShopUpgrades.BaseShelves + #ShopUpgrades.ShelfPrices), 1)
	local price = ShopUpgrades.NextShelfPrice(profile.shelfSlots)
	if price then
		local button = UI.Button(content, ("店頭に1台増やす（%d コイン）"):format(price), if profile.coins >= price then UI.Colors.Coin else UI.Colors.Muted, {
			Size = UDim2.new(1, -12, 0, 42),
			LayoutOrder = 2,
			TextColor3 = Color3.fromRGB(110, 70, 20),
		})
		button.Activated:Connect(function()
			invoke(buySlotRemote)
		end)
	else
		UI.Label(content, "陳列台はぜんぶ増やしました！", { Size = UDim2.new(1, -12, 0, 30), LayoutOrder = 2, TextColor3 = UI.Colors.Good })
	end

	local sections = {
		{ kind = "wall", title = "壁の色", list = ShopUpgrades.Walls, current = profile.interior.wall },
		{ kind = "floor", title = "床", list = ShopUpgrades.Floors, current = profile.interior.floor },
	}
	for i, section in sections do
		heading(section.title, 10 * i)
		local frame = grid(10 * i + 1)
		for j, entry in section.list do
			local owned = entry.price == 0 or profile.ownedInterior[section.kind .. ":" .. entry.id] == true
			local isCurrent = section.current == entry.id
			local text = if isCurrent then entry.name .. " ✓" elseif owned then entry.name else ("%s %d"):format(entry.name, entry.price)
			local button = UI.Button(frame, text, entry.color, { LayoutOrder = j })
			local luminance = entry.color.R * 0.299 + entry.color.G * 0.587 + entry.color.B * 0.114
			button.TextColor3 = if luminance > 0.62 then UI.Colors.Text else Color3.new(1, 1, 1)
			if isCurrent then
				UI.Stroke(button, UI.Colors.Good, 3)
			end
			button.Activated:Connect(function()
				if not isCurrent then
					invoke(interiorRemote, section.kind, entry.id)
				end
			end)
		end
	end
end

function ShopPanel.Open()
	if not State.profile then
		UI.Toast(playerGui, "データを読み込み中です…")
		return
	end
	UI.CloseOtherPanels(ShopPanel.Close)
	panel.Visible = true
	openSlogan()
	render()
end

function ShopPanel.Close()
	panel.Visible = false
end

function ShopPanel.Start()
	UI.RegisterPanel(ShopPanel.Close)
	local gui = Instance.new("ScreenGui")
	gui.Name = "ShopPanel"
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

	UI.Label(panel, "お店の拡張・内装", {
		Size = UDim2.new(1, -80, 0, 34),
		Position = UDim2.new(0, 16, 0, 8),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	local close = UI.Button(panel, "×", UI.Colors.Accent, { Size = UDim2.new(0, 40, 0, 40), Position = UDim2.new(1, -50, 0, 6) })
	close.Activated:Connect(ShopPanel.Close)

	content = Instance.new("ScrollingFrame")
	content.Size = UDim2.new(1, -24, 1, -112)
	content.Position = UDim2.new(0, 12, 0, 50)
	content.BackgroundColor3 = UI.Colors.PanelDark
	content.BorderSizePixel = 0
	content.ScrollBarThickness = 6
	content.AutomaticCanvasSize = Enum.AutomaticSize.Y
	content.CanvasSize = UDim2.new()
	UI.Corner(content, 12)
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 6)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Parent = content
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 8)
	padding.PaddingBottom = UDim.new(0, 8)
	padding.Parent = content
	content.Parent = panel

	-- キャッチコピー（一覧の作り直しで入力中の文字が消えないよう、一覧の外に置く）
	local sloganBox = Instance.new("TextBox")
	sloganBox.Size = UDim2.new(1, -130, 0, 40)
	sloganBox.Position = UDim2.new(0, 12, 1, -52)
	sloganBox.BackgroundColor3 = Color3.new(1, 1, 1)
	sloganBox.Font = UI.Font
	sloganBox.TextScaled = true
	sloganBox.TextColor3 = UI.Colors.Text
	sloganBox.PlaceholderText = "お店のキャッチコピー（20文字まで）"
	sloganBox.ClearTextOnFocus = false
	sloganBox.Text = ""
	UI.Corner(sloganBox, 10)
	UI.Stroke(sloganBox)
	sloganBox.Parent = panel
	local sloganButton = UI.Button(panel, "看板に出す", UI.Colors.Good, { Size = UDim2.new(0, 106, 0, 40), Position = UDim2.new(1, -118, 1, -52) })
	sloganButton.Activated:Connect(function()
		invoke(sloganRemote, sloganBox.Text)
	end)
	openSlogan = function()
		local profile = State.profile
		sloganBox.Text = if profile then profile.slogan or "" else ""
	end

	-- 画面左の「お店」ボタン（部品ボタンの下）
	local openButton = UI.SideButton(playerGui, "OpenShopPanel", "お店", Color3.fromRGB(150, 110, 210), Color3.fromRGB(100, 70, 150), 3)
	openButton.Activated:Connect(function()
		if panel.Visible then
			ShopPanel.Close()
		else
			ShopPanel.Open()
		end
	end)

	State.Changed:Connect(function()
		if panel.Visible then
			render()
		end
	end)
end

return ShopPanel
