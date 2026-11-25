--!strict
-- お店めぐり画面：サーバー内のお店の一覧から選んでワープする

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"))
local UI = require(script.Parent:WaitForChild("UI"))

local TravelPanel = {}

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local travelRemote = Net.Function("Travel")

local panel: Frame
local list: ScrollingFrame
local busy = false

local function go(target: any)
	if busy then
		return
	end
	busy = true
	local ok, result, message = pcall(function()
		return travelRemote:InvokeServer(target)
	end)
	busy = false
	if not ok then
		UI.Toast(playerGui, "通信に失敗しました", UI.Colors.Accent)
	elseif result then
		TravelPanel.Close()
	else
		UI.Toast(playerGui, tostring(message), UI.Colors.Accent)
	end
end

local function render()
	for _, child in list:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local home = UI.Button(list, "自分のお店にもどる", UI.Colors.Good, { Size = UDim2.new(1, -12, 0, 40), LayoutOrder = 0 })
	home.Activated:Connect(function()
		go("mine")
	end)
	local plaza = UI.Button(list, "広場へ行く", Color3.fromRGB(90, 170, 240), { Size = UDim2.new(1, -12, 0, 40), LayoutOrder = 1 })
	plaza.Activated:Connect(function()
		go("plaza")
	end)

	local plots = workspace:FindFirstChild("Plots")
	local entries = {}
	if plots then
		for _, plot in plots:GetChildren() do
			local ownerId = plot:GetAttribute("OwnerUserId")
			if type(ownerId) == "number" and ownerId ~= player.UserId then
				local owner = Players:GetPlayerByUserId(ownerId)
				if owner then
					table.insert(entries, {
						userId = ownerId,
						name = owner.DisplayName,
						stars = tonumber(plot:GetAttribute("Stars")) or 1,
						onSale = tonumber(plot:GetAttribute("OnSale")) or 0,
					})
				end
			end
		end
	end
	-- 商品が並んでいて評判の高い店を上に
	table.sort(entries, function(a, b)
		if (a.onSale > 0) ~= (b.onSale > 0) then
			return a.onSale > 0
		end
		return a.stars > b.stars
	end)
	if #entries == 0 then
		UI.Label(list, "ほかのお店はまだありません", { Size = UDim2.new(1, -12, 0, 34), LayoutOrder = 2 })
	end
	for i, entry in entries do
		local stars = string.rep("★", entry.stars) .. string.rep("☆", 5 - entry.stars)
		local text = ("%s のお店 %s ・ %s"):format(entry.name, stars, if entry.onSale > 0 then ("%d品 販売中"):format(entry.onSale) else "準備中")
		local button = UI.Button(list, text, Color3.fromRGB(205, 150, 110), { Size = UDim2.new(1, -12, 0, 40), LayoutOrder = 10 + i })
		button.Activated:Connect(function()
			go(entry.userId)
		end)
	end
end

function TravelPanel.Open()
	UI.CloseOtherPanels(TravelPanel.Close)
	panel.Visible = true
	render()
end

function TravelPanel.Close()
	panel.Visible = false
end

function TravelPanel.Start()
	UI.RegisterPanel(TravelPanel.Close)
	local gui = Instance.new("ScreenGui")
	gui.Name = "TravelPanel"
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
	constraint.MaxSize = Vector2.new(480, 480)
	constraint.Parent = panel
	UI.Label(panel, "お店めぐり", {
		Size = UDim2.new(1, -80, 0, 34),
		Position = UDim2.new(0, 16, 0, 8),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	local close = UI.Button(panel, "×", UI.Colors.Accent, { Size = UDim2.new(0, 40, 0, 40), Position = UDim2.new(1, -50, 0, 6) })
	close.Activated:Connect(TravelPanel.Close)

	list = Instance.new("ScrollingFrame")
	list.Size = UDim2.new(1, -24, 1, -62)
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

	local openButton = UI.SideButton(playerGui, "OpenTravel", "めぐる", Color3.fromRGB(230, 110, 140), Color3.fromRGB(160, 60, 90), 5)
	openButton.Activated:Connect(function()
		if panel.Visible then
			TravelPanel.Close()
		else
			TravelPanel.Open()
		end
	end)
end

return TravelPanel
