--!strict
-- お店めぐり：広場・自分の店・他の人の店へワープする

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"))
local PlotService = require(script.Parent:WaitForChild("PlotService"))

local TravelService = {}

local lastTravel: { [Player]: number } = {}

local function travel(player: Player, target: any): (boolean, string)
	local now = os.clock()
	if lastTravel[player] and now - lastTravel[player] < 1 then
		return false, "少し待ってからどうぞ"
	end
	local character = player.Character
	if not character or not character:FindFirstChild("HumanoidRootPart") then
		return false, "いまは移動できません"
	end
	local destination: CFrame
	if target == "plaza" then
		destination = CFrame.new(0, 4, -14)
	elseif target == "mine" then
		local plot = PlotService.Get(player)
		if not plot then
			return false, "お店がありません"
		end
		destination = plot.origin * PlotService.SpawnOffset
	elseif type(target) == "number" then
		local owner = Players:GetPlayerByUserId(target)
		local plot = owner and PlotService.Get(owner)
		if not plot then
			return false, "そのお店は見つかりません"
		end
		-- 店の前の歩道に、店の方を向いて立つ
		destination = plot.origin * CFrame.new(0, 4, -12) * CFrame.Angles(0, math.pi, 0)
	else
		return false, "行き先が正しくありません"
	end
	lastTravel[player] = now
	pcall(function()
		player:RequestStreamAroundAsync(destination.Position, 5)
	end)
	if character.Parent then
		character:PivotTo(destination)
	end
	return true, "到着！"
end

function TravelService.Start()
	Net.Function("Travel").OnServerInvoke = function(player, target)
		local ok, a, b = pcall(travel, player, target)
		if not ok then
			warn("[TravelService] エラー:", a)
			return false, "エラーが起きました"
		end
		return a, b
	end
	Players.PlayerRemoving:Connect(function(player)
		lastTravel[player] = nil
	end)
end

return TravelService
