--!strict
-- 初回の操作ガイド（画面上部の「次にやること」）と、デイリーボーナスの表示

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"))
local State = require(script.Parent:WaitForChild("State"))
local UI = require(script.Parent:WaitForChild("UI"))
local Sounds = require(script.Parent:WaitForChild("Sounds"))

local Guide = {}

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- 今のデータから、次にやることを決める
local function currentStep(profile: any): (number, string)
	local hasDesign = false
	for _, design in profile.designs do
		if not design.boughtFrom then
			hasDesign = true
		end
	end
	if not hasDesign then
		return 1, "① 左の「工房」で見本を選ぶか、アイテムをデザインして保存しよう"
	end
	local hasStock = false
	for id, count in profile.stock do
		local design = profile.designs[id]
		if count > 0 and design and not design.boughtFrom then
			hasStock = true
		end
	end
	local hasShelf = next(profile.shelves) ~= nil
	if not hasStock and profile.stats.sold == 0 then
		return 2, "② 工房の「1個」ボタンで商品を作ろう"
	end
	if not hasShelf then
		return 3, "③ お店の陳列台に近づいて、商品を並べよう"
	end
	if profile.stats.sold == 0 then
		return 4, "④ お客さんが来るのを待とう（値段が高すぎると売れないよ）"
	end
	return 5, ""
end

local function showDaily(gui: ScreenGui, streak: number, reward: number, tomorrow: number)
	local card = UI.Frame(gui, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.new(0, 300, 0, 214),
	})
	UI.Corner(card, 16)
	UI.Stroke(card, UI.Colors.Coin, 4)
	UI.Label(card, "ログインボーナス！", { Size = UDim2.new(1, -20, 0, 36), Position = UDim2.new(0, 10, 0, 10) })
	UI.Label(card, ("+%d コイン"):format(reward), {
		Size = UDim2.new(1, -20, 0, 46),
		Position = UDim2.new(0, 10, 0, 48),
		TextColor3 = Color3.fromRGB(210, 140, 20),
	})
	UI.Label(card, ("%d日連続ログイン・明日は +%d"):format(streak, tomorrow), {
		Size = UDim2.new(1, -20, 0, 24),
		Position = UDim2.new(0, 10, 0, 98),
	})
	-- 7日分の印（7日目で最大の額になる。7日目以降は全部ついたまま）
	local filled = math.min(streak, 7)
	for i = 1, 7 do
		local dot = UI.Frame(card, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, (i - 4) * 30, 0, 138),
			Size = if i == 7 then UDim2.new(0, 22, 0, 22) else UDim2.new(0, 16, 0, 16),
			BackgroundColor3 = if i <= filled then UI.Colors.Coin else Color3.fromRGB(220, 220, 220),
		})
		UI.Corner(dot, 11)
		if i == 7 then
			UI.Stroke(dot, Color3.fromRGB(210, 140, 20), 2)
		end
	end
	local ok = UI.Button(card, "やったね！", UI.Colors.Good, { Size = UDim2.new(0, 160, 0, 40), Position = UDim2.new(0.5, -80, 1, -52) })
	local scale = Instance.new("UIScale")
	scale.Scale = 0.6
	scale.Parent = card
	TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	ok.Activated:Connect(function()
		card:Destroy()
	end)
	task.delay(10, function()
		if card.Parent then
			card:Destroy()
		end
	end)
end

function Guide.Start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Guide"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 20
	gui.Parent = playerGui

	local bar = UI.Frame(gui, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 10),
		Size = UDim2.new(0.6, 0, 0, 40),
		BackgroundColor3 = Color3.fromRGB(255, 240, 190),
		Visible = false,
	})
	UI.Corner(bar, 12)
	UI.Stroke(bar, UI.Colors.Coin, 3)
	local constraint = Instance.new("UISizeConstraint")
	constraint.MaxSize = Vector2.new(560, 40)
	constraint.MinSize = Vector2.new(260, 40)
	constraint.Parent = bar
	local text = UI.Label(bar, "", { Size = UDim2.new(1, -16, 1, -8), Position = UDim2.new(0, 8, 0, 4) })

	local lastStep = 0
	local finished = false
	State.Observe(function(profile)
		if profile.tutorialDone or finished then
			bar.Visible = false
			return
		end
		local step, message = currentStep(profile)
		if step >= 5 then
			finished = true
			bar.Visible = false
			Net.Event("TutorialDone"):FireServer()
			if lastStep ~= 4 then
				return -- 以前から売ったことがある人には出さない
			end
			UI.Toast(playerGui, "初めての売上おめでとう！「部品」で新しい部品を解放しよう", UI.Colors.Good)
			return
		end
		bar.Visible = true
		text.Text = message
		if step ~= lastStep then
			lastStep = step
			bar.Size = UDim2.new(0.6, 0, 0, 40)
			local pulse = Instance.new("UIScale")
			pulse.Scale = 1.12
			pulse.Parent = bar
			local tween = TweenService:Create(pulse, TweenInfo.new(0.4, Enum.EasingStyle.Back), { Scale = 1 })
			tween.Completed:Connect(function()
				pulse:Destroy()
			end)
			tween:Play()
		end
	end)

	Net.Event("DailyBonus").OnClientEvent:Connect(function(streak: number, reward: number, tomorrow: number)
		Sounds.Play("reward")
		showDaily(gui, streak, reward, tomorrow)
	end)

	-- 留守中の売上
	Net.Event("OfflineSales").OnClientEvent:Connect(function(count: number, earned: number)
		Sounds.Play("reward")
		local card = UI.Frame(gui, {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0.72, 0),
			Size = UDim2.new(0, 320, 0, 70),
			BackgroundColor3 = Color3.fromRGB(230, 250, 230),
		})
		UI.Corner(card, 14)
		UI.Stroke(card, UI.Colors.Good, 3)
		UI.Label(card, ("留守の間に %d 個売れました！"):format(count), { Size = UDim2.new(1, -20, 0, 30), Position = UDim2.new(0, 10, 0, 6) })
		UI.Label(card, ("+%d コイン"):format(earned), {
			Size = UDim2.new(1, -20, 0, 28),
			Position = UDim2.new(0, 10, 0, 36),
			TextColor3 = Color3.fromRGB(210, 140, 20),
		})
		task.delay(7, function()
			card:Destroy()
		end)
	end)
end

return Guide
