--!strict
-- プレゼント画面：贈る相手を選び、自分の在庫のアイテムを1つ贈る

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"))
local State = require(script.Parent:WaitForChild("State"))
local UI = require(script.Parent:WaitForChild("UI"))
local Sounds = require(script.Parent:WaitForChild("Sounds"))

local GiftPanel = {}

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local giftRemote = Net.Function("SendGift")

local panel: Frame
local list: ScrollingFrame
local title: TextLabel
local targetId: number? = nil
local busy = false

local function clear()
	for _, child in list:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function render()
	clear()
	local target = targetId and Players:GetPlayerByUserId(targetId)
	if not target then
		-- 1. 贈る相手を選ぶ
		targetId = nil
		title.Text = "プレゼント：だれに贈る？"
		local others = 0
		for _, other in Players:GetPlayers() do
			if other ~= player then
				others += 1
				local button = UI.Button(list, other.DisplayName, Color3.fromRGB(230, 110, 140), { Size = UDim2.new(1, -12, 0, 40), LayoutOrder = others })
				button.Activated:Connect(function()
					targetId = other.UserId
					render()
				end)
			end
		end
		if others == 0 then
			UI.Label(list, "このサーバーにはまだ他の人がいません", { Size = UDim2.new(1, -12, 0, 34) })
		end
		return
	end

	-- 2. 贈るアイテムを選ぶ（自分で作ったもので在庫があるもの）
	title.Text = ("%s さんに贈る"):format(target.DisplayName)
	local back = UI.Button(list, "← 相手を選びなおす", UI.Colors.Muted, { Size = UDim2.new(1, -12, 0, 34), LayoutOrder = 0 })
	back.Activated:Connect(function()
		targetId = nil
		render()
	end)
	local profile = State.profile
	local count = 0
	if profile then
		for id, design in profile.designs do
			local stock = profile.stock[id] or 0
			if not design.boughtFrom and stock > 0 then
				count += 1
				local button = UI.Button(list, ("%s（在庫 %d）"):format(design.name, stock), UI.Colors.Good, { Size = UDim2.new(1, -12, 0, 40), LayoutOrder = count })
				button.Activated:Connect(function()
					if busy then
						return
					end
					busy = true
					local ok, result, message = pcall(function()
						return giftRemote:InvokeServer(target.UserId, id)
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
	if count == 0 then
		UI.Label(list, "贈れるアイテムがありません。工房で作りましょう", { Size = UDim2.new(1, -12, 0, 34), LayoutOrder = 1 })
	end
end

function GiftPanel.Open()
	UI.CloseOtherPanels(GiftPanel.Close)
	targetId = nil
	panel.Visible = true
	render()
end

function GiftPanel.Close()
	panel.Visible = false
end

function GiftPanel.Start()
	UI.RegisterPanel(GiftPanel.Close)
	local gui = Instance.new("ScreenGui")
	gui.Name = "GiftPanel"
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
	constraint.MaxSize = Vector2.new(460, 460)
	constraint.Parent = panel
	title = UI.Label(panel, "プレゼント", {
		Size = UDim2.new(1, -80, 0, 34),
		Position = UDim2.new(0, 16, 0, 8),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	local close = UI.Button(panel, "×", UI.Colors.Accent, { Size = UDim2.new(0, 40, 0, 40), Position = UDim2.new(1, -50, 0, 6) })
	close.Activated:Connect(GiftPanel.Close)

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

	State.Changed:Connect(function()
		if panel.Visible and targetId then
			render()
		end
	end)

	-- プレゼントを受け取ったとき
	Net.Event("GiftReceived").OnClientEvent:Connect(function(fromName: string, itemName: string)
		Sounds.Play("reward")
		UI.Toast(playerGui, ("%s さんから「%s」のプレゼント！ 自宅に飾れます"):format(fromName, itemName), UI.Colors.Good)
	end)
end

return GiftPanel
