--!strict
-- 目標の報酬を受け取る

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Goals = require(Shared:WaitForChild("Goals"))
local Net = require(Shared:WaitForChild("Net"))
local DataService = require(script.Parent:WaitForChild("DataService"))

local GoalService = {}

local function claim(player: Player, id: any): (boolean, string)
	local profile = DataService.Get(player)
	local goal = type(id) == "string" and Goals.ById[id] or nil
	if not profile or not goal then
		return false, "見つかりません"
	end
	if profile.goalsClaimed[goal.id] then
		return false, "もう受け取りました"
	end
	if not Goals.IsDone(goal, profile) then
		return false, "まだ達成していません"
	end
	profile.goalsClaimed[goal.id] = true
	DataService.AddCoins(player, goal.reward)
	return true, ("「%s」達成！ +%d コイン"):format(goal.text, goal.reward)
end

function GoalService.Start()
	Net.Function("ClaimGoal").OnServerInvoke = function(player, id)
		local ok, a, b = pcall(claim, player, id)
		if not ok then
			warn("[GoalService] エラー:", a)
			return false, "エラーが起きました"
		end
		return a, b
	end
end

return GoalService
