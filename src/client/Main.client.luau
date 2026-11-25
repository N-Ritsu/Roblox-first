-- クライアントの起動スクリプト
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))

local modules = {
	"Hud",
	"Workshop",
	"ShelfPanel",
	"PartShop",
	"ShopPanel",
	"GoalsPanel",
	"TravelPanel",
	"Guide",
	"HomePanel",
	"Prompts", -- Plots を待つので最後
}

-- どれか1つが待ち続けても他の画面が動くよう、別々に起動する
for _, name in modules do
	task.spawn(function()
		local ok, err = pcall(function()
			require(script.Parent:WaitForChild(name)).Start()
		end)
		if not ok then
			warn(("[Client] %s の起動に失敗: %s"):format(name, tostring(err)))
		end
	end)
end

print(("Roblox-first v%s"):format(Config.Version))
