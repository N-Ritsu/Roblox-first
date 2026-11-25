--!strict
-- デイリーログインボーナス（日本時間の日付で1日1回、連続ログインで増える）と、初回ガイドの完了記録

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local DataService = require(script.Parent:WaitForChild("DataService"))

local DailyService = {}

DailyService.BaseReward = 30
DailyService.StreakStep = 15
DailyService.MaxStreakBonusDays = 6 -- 7日目以降は同じ額

local dailyEvent = Net.Event("DailyBonus")
local tutorialDoneEvent = Net.Event("TutorialDone")

local function today(): number
	return math.floor((os.time() + 9 * 3600) / 86400) -- 日本時間の通し日数
end

function DailyService.RewardFor(streak: number): number
	return DailyService.BaseReward + math.min(streak - 1, DailyService.MaxStreakBonusDays) * DailyService.StreakStep
end

local function check(player: Player, profile: any)
	local day = today()
	local last = tonumber(profile.lastDaily) or 0
	if day <= last then
		return
	end
	local streak = if day == last + 1 then (tonumber(profile.dailyStreak) or 0) + 1 else 1
	local reward = DailyService.RewardFor(streak)
	profile.lastDaily = day
	profile.dailyStreak = streak
	DataService.AddCoins(player, reward)
	-- 初回プレイ時はガイドと重なるので、少し遅らせて出す
	task.delay(3, function()
		if player.Parent then
			dailyEvent:FireClient(player, streak, reward, DailyService.RewardFor(streak + 1))
		end
	end)
end

function DailyService.Start()
	DataService.OnLoaded(check)
	tutorialDoneEvent.OnServerEvent:Connect(function(player)
		local profile = DataService.Get(player)
		if profile and not profile.tutorialDone then
			profile.tutorialDone = true
			DataService.Changed(player)
		end
	end)
	-- 日付をまたいで遊び続けている人にも渡す
	task.spawn(function()
		while true do
			task.wait(60)
			for _, player in game:GetService("Players"):GetPlayers() do
				local profile = DataService.Get(player)
				if profile then
					check(player, profile)
				end
			end
		end
	end)
end

return DailyService
