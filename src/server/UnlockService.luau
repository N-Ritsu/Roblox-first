--!strict
-- 部品ショップ：コインで新しい形・色・素材を解放する
-- 将来、課金での解放を足すときもこの「解放済みにする」処理を使う

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Catalog = require(Shared:WaitForChild("Catalog"))
local Net = require(Shared:WaitForChild("Net"))
local Season = require(Shared:WaitForChild("Season"))
local ItemBuilder = require(Shared:WaitForChild("ItemBuilder"))
local DataService = require(script.Parent:WaitForChild("DataService"))

local UnlockService = {}

local byKind = {
	shapes = Catalog.ShapeById,
	colors = Catalog.ColorById,
	materials = Catalog.MaterialById,
} :: { [string]: { [string]: any } }

local function unlock(player: Player, kind: any, id: any): (boolean, string)
	local profile = DataService.Get(player)
	if not profile then
		return false, "データを読み込み中です"
	end
	if type(kind) ~= "string" or type(id) ~= "string" or not byKind[kind] then
		return false, "見つかりません"
	end
	local entry = byKind[kind][id]
	if not entry then
		return false, "見つかりません"
	end
	local unlocks = (profile.unlocks :: any)[kind]
	if unlocks[id] then
		return false, "もう解放しています"
	end
	if not Season.IsActive(entry.season) then
		return false, "期間限定の部品です。イベント期間中に解放できます"
	end
	if not DataService.TrySpend(player, entry.unlockPrice) then
		return false, ("コインが足りません（%d コイン必要）"):format(entry.unlockPrice)
	end
	unlocks[id] = true
	DataService.Changed(player)
	return true, ("「%s」を解放しました！"):format(entry.name)
end

local function buyPartLimit(player: Player): (boolean, string)
	local profile = DataService.Get(player)
	if not profile then
		return false, "データを読み込み中です"
	end
	local step = ItemBuilder.NextPartLimit(profile.maxParts)
	if not step then
		return false, "これ以上は増やせません"
	end
	if not DataService.TrySpend(player, step.price) then
		return false, ("コインが足りません（%d コイン必要）"):format(step.price)
	end
	profile.maxParts = step.limit
	DataService.Changed(player)
	return true, ("部品を%d個まで使えるようになりました！"):format(step.limit)
end

function UnlockService.Start()
	Net.Function("BuyPartLimit").OnServerInvoke = function(player)
		local ok, a, b = pcall(buyPartLimit, player)
		if not ok then
			warn("[UnlockService] エラー:", a)
			return false, "エラーが起きました"
		end
		return a, b
	end
	Net.Function("Unlock").OnServerInvoke = function(player, kind, id)
		local ok, a, b = pcall(unlock, player, kind, id)
		if not ok then
			warn("[UnlockService] エラー:", a)
			return false, "エラーが起きました"
		end
		return a, b
	end
end

return UnlockService
