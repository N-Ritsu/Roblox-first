--!strict
-- 画面左上のコイン表示

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"))
local State = require(script.Parent:WaitForChild("State"))
local UI = require(script.Parent:WaitForChild("UI"))
local Sounds = require(script.Parent:WaitForChild("Sounds"))

local Hud = {}

function Hud.Start()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local gui = Instance.new("ScreenGui")
	gui.Name = "Hud"
	gui.ResetOnSpawn = false
	gui.Parent = playerGui

	local coinFrame = UI.Frame(gui, {
		Name = "Coins",
		Size = UDim2.new(0, 190, 0, 48),
		Position = UDim2.new(0, 16, 0, 64),
	})
	UI.Corner(coinFrame, 24)
	UI.Stroke(coinFrame)
	local icon = UI.Frame(coinFrame, {
		Size = UDim2.new(0, 34, 0, 34),
		Position = UDim2.new(0, 7, 0.5, -17),
		BackgroundColor3 = UI.Colors.Coin,
	})
	UI.Corner(icon, 17)
	UI.Stroke(icon, Color3.fromRGB(200, 140, 30))
	UI.Label(icon, "C", { Size = UDim2.fromScale(1, 1), TextColor3 = Color3.fromRGB(150, 95, 20) })
	local amount = UI.Label(coinFrame, "0", {
		Size = UDim2.new(1, -56, 1, -12),
		Position = UDim2.new(0, 48, 0, 6),
		TextXAlignment = Enum.TextXAlignment.Left,
	})

	local last: number? = nil
	State.Observe(function(profile)
		local coins = profile.coins :: number
		amount.Text = tostring(coins)
		if last and coins ~= last then
			-- 増減したら少し跳ねる
			icon.Size = UDim2.new(0, 42, 0, 42)
			icon.Position = UDim2.new(0, 3, 0.5, -21)
			TweenService:Create(icon, TweenInfo.new(0.25, Enum.EasingStyle.Back), {
				Size = UDim2.new(0, 34, 0, 34),
				Position = UDim2.new(0, 7, 0.5, -17),
			}):Play()
		end
		last = coins
	end)

	-- 今週のお題（画面下）
	local Theme = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Theme"))
	local themeFrame = UI.Frame(gui, {
		Name = "Theme",
		AnchorPoint = Vector2.new(0.5, 1),
		Size = UDim2.new(0, 230, 0, 44),
		Position = UDim2.new(0.5, 0, 1, -12), -- 下の真ん中（右上はプレイヤー一覧と重なるため）
		BackgroundColor3 = Color3.fromRGB(255, 240, 190),
	})
	UI.Corner(themeFrame, 12)
	UI.Stroke(themeFrame, UI.Colors.Coin, 2)
	UI.Label(themeFrame, "今週のお題（高く売れる）", { Size = UDim2.new(1, -12, 0, 16), Position = UDim2.new(0, 6, 0, 3) })
	local themeText = UI.Label(themeFrame, Theme.Text(Theme.Current()), { Size = UDim2.new(1, -12, 0, 22), Position = UDim2.new(0, 6, 0, 19) })
	task.spawn(function()
		while true do
			task.wait(60)
			themeText.Text = Theme.Text(Theme.Current())
		end
	end)

	-- お客さんの注文（お題の上。注文がないときは隠す）
	local orderFrame = UI.Frame(gui, {
		Name = "Order",
		AnchorPoint = Vector2.new(0.5, 1),
		Size = UDim2.new(0, 260, 0, 44), -- スマホの移動スティック・ジャンプボタンにかからない幅
		Position = UDim2.new(0.5, 0, 1, -62),
		BackgroundColor3 = Color3.fromRGB(215, 240, 255),
		Visible = false,
	})
	UI.Corner(orderFrame, 12)
	UI.Stroke(orderFrame, Color3.fromRGB(90, 170, 240), 2)
	local orderTitle = UI.Label(orderFrame, "", { Size = UDim2.new(1, -12, 0, 16), Position = UDim2.new(0, 6, 0, 3) })
	local orderText = UI.Label(orderFrame, "", { Size = UDim2.new(1, -12, 0, 22), Position = UDim2.new(0, 6, 0, 19) })
	local currentOrder: any = nil
	local function updateOrder()
		if not currentOrder then
			orderFrame.Visible = false
			return
		end
		local left = math.max(0, (currentOrder.expires :: number) - workspace:GetServerTimeNow())
		orderFrame.Visible = left > 0
		orderTitle.Text = ("お客さんの注文（あと%d分%02d秒）"):format(math.floor(left / 60), math.floor(left % 60))
		orderText.Text = ("%sを売るとボーナス +%d"):format(currentOrder.label, currentOrder.bonus)
	end
	Net.Event("Order").OnClientEvent:Connect(function(order: any)
		currentOrder = order
		updateOrder()
	end)
	Net.Event("RequestOrder"):FireServer()
	task.spawn(function()
		while true do
			task.wait(1)
			updateOrder()
		end
	end)

	-- サーバーからのお知らせ
	Net.Event("Notice").OnClientEvent:Connect(function(text: string)
		UI.Toast(playerGui, text, UI.Colors.Accent)
	end)

	-- 商品が売れたときのお知らせ
	Net.Event("Sale").OnClientEvent:Connect(function(itemName: string, price: number, buyerName: string?)
		Sounds.Play("sale")
		if buyerName then
			UI.Toast(playerGui, ("%s さんが「%s」を買ってくれた！ +%d"):format(buyerName, itemName, price), UI.Colors.Good)
		else
			UI.Toast(playerGui, ("「%s」が売れた！ +%d コイン"):format(itemName, price), UI.Colors.Good)
		end
	end)
end

return Hud
