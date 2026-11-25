--!strict
-- 目標画面：進み具合と報酬の受け取り。受け取れるものがあるとボタンに印が出る

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Goals = require(Shared:WaitForChild("Goals"))
local Season = require(Shared:WaitForChild("Season"))
local Net = require(Shared:WaitForChild("Net"))
local State = require(script.Parent:WaitForChild("State"))
local UI = require(script.Parent:WaitForChild("UI"))
local Sounds = require(script.Parent:WaitForChild("Sounds"))

local GoalsPanel = {}

local celebrate: (string, number) -> ()

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local claimRemote = Net.Function("ClaimGoal")

local panel: Frame
local list: ScrollingFrame
local badge: TextLabel
local busy = false

-- 達成のお祝い：画面中央に大きく出して、少しして消える
local celebrateGui: ScreenGui? = nil
celebrate = function(text: string, reward: number)
	if not celebrateGui then
		local gui = Instance.new("ScreenGui")
		gui.Name = "Celebrate"
		gui.ResetOnSpawn = false
		gui.DisplayOrder = 40
		gui.Parent = playerGui
		celebrateGui = gui
	end
	local card = UI.Frame(celebrateGui :: ScreenGui, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.4),
		Size = UDim2.new(0, 320, 0, 130),
		BackgroundColor3 = Color3.fromRGB(255, 245, 200),
	})
	UI.Corner(card, 18)
	UI.Stroke(card, UI.Colors.Coin, 4)
	UI.Label(card, "目標達成！", { Size = UDim2.new(1, -20, 0, 40), Position = UDim2.new(0, 10, 0, 8), TextColor3 = Color3.fromRGB(210, 120, 20) })
	UI.Label(card, text, { Size = UDim2.new(1, -20, 0, 30), Position = UDim2.new(0, 10, 0, 50) })
	UI.Label(card, ("+%d コイン"):format(reward), { Size = UDim2.new(1, -20, 0, 32), Position = UDim2.new(0, 10, 0, 86), TextColor3 = Color3.fromRGB(210, 140, 20) })
	local scale = Instance.new("UIScale")
	scale.Scale = 0.4
	scale.Parent = card
	TweenService:Create(scale, TweenInfo.new(0.4, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	task.delay(2.5, function()
		local fade = TweenService:Create(scale, TweenInfo.new(0.25), { Scale = 0 })
		fade.Completed:Connect(function()
			card:Destroy()
		end)
		fade:Play()
	end)
end

local function render()
	local profile = State.profile
	if not profile then
		return
	end
	for _, child in list:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	-- 受け取れるもの → 進行中 → 受け取り済み の順に並べる
	for i, goal in Goals.List do
		local claimed = profile.goalsClaimed[goal.id] == true
		local done = Goals.IsDone(goal, profile)
		if goal.season and not claimed and not done and not Season.IsActive(goal.season) then
			continue -- 季節の目標は、その季節の間だけ出す
		end
		local order = if claimed then 2000 + i elseif done then i else 1000 + i
		local row = UI.Frame(list, {
			Size = UDim2.new(1, -12, 0, 56),
			BackgroundColor3 = if claimed then Color3.fromRGB(225, 225, 225) elseif done then Color3.fromRGB(255, 245, 200) else Color3.new(1, 1, 1),
			LayoutOrder = order,
		})
		UI.Corner(row, 8)
		UI.Label(row, goal.text, {
			Size = UDim2.new(1, -140, 0, 24),
			Position = UDim2.new(0, 10, 0, 4),
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		local progress = math.min(goal.progress(profile), goal.target)
		local barBack = UI.Frame(row, {
			Size = UDim2.new(1, -140, 0, 12),
			Position = UDim2.new(0, 10, 0, 34),
			BackgroundColor3 = UI.Colors.PanelDark,
		})
		UI.Corner(barBack, 6)
		local fill = UI.Frame(barBack, {
			Size = UDim2.new(math.clamp(progress / goal.target, 0, 1), 0, 1, 0),
			BackgroundColor3 = UI.Colors.Good,
		})
		UI.Corner(fill, 6)
		if claimed then
			UI.Label(row, "受け取りずみ", { Size = UDim2.new(0, 120, 0, 40), Position = UDim2.new(1, -126, 0, 8), TextColor3 = UI.Colors.Muted })
		elseif done then
			local button = UI.Button(row, ("+%d 受け取る"):format(goal.reward), UI.Colors.Coin, {
				Size = UDim2.new(0, 120, 0, 40),
				Position = UDim2.new(1, -126, 0, 8),
				TextColor3 = Color3.fromRGB(110, 70, 20),
			})
			button.Activated:Connect(function()
				if busy then
					return
				end
				busy = true
				local ok, result, message = pcall(function()
					return claimRemote:InvokeServer(goal.id)
				end)
				busy = false
				if ok then
					if result then
						Sounds.Play("reward")
						celebrate(goal.text, goal.reward)
					end
					UI.Toast(playerGui, tostring(message), if result then UI.Colors.Good else UI.Colors.Accent)
				else
					UI.Toast(playerGui, "通信に失敗しました", UI.Colors.Accent)
				end
			end)
		else
			UI.Label(row, ("%d / %d\n報酬 %d"):format(progress, goal.target, goal.reward), {
				Size = UDim2.new(0, 120, 0, 44),
				Position = UDim2.new(1, -126, 0, 6),
			})
		end
	end
end

function GoalsPanel.Open()
	UI.CloseOtherPanels(GoalsPanel.Close)
	panel.Visible = true
	render()
end

function GoalsPanel.Close()
	panel.Visible = false
end

function GoalsPanel.Start()
	UI.RegisterPanel(GoalsPanel.Close)
	local gui = Instance.new("ScreenGui")
	gui.Name = "GoalsPanel"
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
	UI.Label(panel, "目標", {
		Size = UDim2.new(1, -80, 0, 34),
		Position = UDim2.new(0, 16, 0, 8),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	local close = UI.Button(panel, "×", UI.Colors.Accent, { Size = UDim2.new(0, 40, 0, 40), Position = UDim2.new(1, -50, 0, 6) })
	close.Activated:Connect(GoalsPanel.Close)

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

	-- 画面左の「目標」ボタン（お店ボタンの下）
	local openButton = UI.SideButton(playerGui, "OpenGoals", "目標", Color3.fromRGB(90, 185, 110), Color3.fromRGB(50, 120, 70), 4)
	badge = UI.Label(openButton, "!", {
		Size = UDim2.new(0, 24, 0, 24),
		Position = UDim2.new(1, -14, 0, -6),
		BackgroundTransparency = 0,
		BackgroundColor3 = UI.Colors.Accent,
		TextColor3 = Color3.new(1, 1, 1),
		Visible = false,
		ZIndex = 3,
	})
	UI.Corner(badge, 12)
	openButton.Activated:Connect(function()
		if panel.Visible then
			GoalsPanel.Close()
		else
			GoalsPanel.Open()
		end
	end)

	State.Observe(function(profile)
		local count = Goals.ClaimableCount(profile)
		badge.Visible = count > 0
		badge.Text = tostring(count)
		if panel.Visible then
			render()
		end
	end)
end

return GoalsPanel
