-- 仮のクライアントスクリプト
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))

print(("Roblox-first v%s"):format(Config.Version))
