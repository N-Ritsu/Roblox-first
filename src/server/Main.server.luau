-- 仮のサーバースクリプト（公開パイプラインの動作確認用）
-- 最初の自動実行で、Claude が DIRECTION.md に沿ってゲーム本体に置き換えます。

local Players = game:GetService("Players")

local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))

Players.PlayerAdded:Connect(function(player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	local points = Instance.new("IntValue")
	points.Name = "Points"
	points.Value = 0
	points.Parent = leaderstats

	task.spawn(function()
		while player.Parent do
			task.wait(Config.PointInterval)
			points.Value += 1
		end
	end)
end)
