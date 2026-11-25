-- サーバーの起動スクリプト：各サービスを順に起動する

local services = {
	"WorldService",
	"DataService",
	"PlotService",
	"DesignService",
	"ShopService",
	"CustomerService",
	"UnlockService",
	"DailyService",
}

for _, name in services do
	local ok, err = pcall(function()
		require(script.Parent:WaitForChild(name)).Start()
	end)
	if not ok then
		warn(("[Main] %s の起動に失敗: %s"):format(name, tostring(err)))
	end
end
