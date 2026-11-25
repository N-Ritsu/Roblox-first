-- ゲーム全体の設定値
local Config = {
	Version = "0.18.0",

	-- セーブデータ
	DataStoreName = "PlayerData_v1",
	AutosaveInterval = 120, -- 秒
	StartingCoins = 50,

	-- 店舗区画
	PlotCount = 6,
	PlotRadius = 75, -- 中央広場から各区画までの距離
}

return Config
