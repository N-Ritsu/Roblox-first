--!strict
-- 画面左上のコイン表示

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"))
local State = require(script.Parent:WaitForChild("State"))
local UI = require(script.Parent:WaitForChild("UI"))

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

	-- 商品が売れたときのお知らせ
	Net.Event("Sale").OnClientEvent:Connect(function(itemName: string, price: number)
		UI.Toast(playerGui, ("「%s」が売れた！ +%d コイン"):format(itemName, price), UI.Colors.Good)
	end)
end

return Hud
