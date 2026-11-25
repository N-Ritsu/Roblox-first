-- クライアントの起動スクリプト
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))

local modules = {
	"Hud",
	"Workshop",
	"ShelfPanel",
	"PartShop",
	"Guide",
}

for _, name in modules do
	local ok, err = pcall(function()
		require(script.Parent:WaitForChild(name)).Start()
	end)
	if not ok then
		warn(("[Client] %s の起動に失敗: %s"):format(name, tostring(err)))
	end
end

print(("Roblox-first v%s"):format(Config.Version))
