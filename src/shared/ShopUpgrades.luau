--!strict
-- 店の拡張：陳列台の追加と内装（壁・床）の選択肢
-- 将来、課金での拡張を足すときもこの一覧に項目を足す形にする

local ShopUpgrades = {}

ShopUpgrades.BaseShelves = 4
-- 5台目〜8台目を増やす値段
ShopUpgrades.ShelfPrices = { 300, 600, 1000, 1500 }

export type WallStyle = { id: string, name: string, color: Color3, price: number }
export type FloorStyle = { id: string, name: string, color: Color3, material: Enum.Material, price: number }

ShopUpgrades.Walls = {
	{ id = "Cream", name = "クリーム", color = Color3.fromRGB(250, 240, 225), price = 0 },
	{ id = "Mint", name = "ミント", color = Color3.fromRGB(200, 240, 220), price = 50 },
	{ id = "Sakura", name = "さくら", color = Color3.fromRGB(255, 215, 225), price = 50 },
	{ id = "Sky", name = "そら", color = Color3.fromRGB(205, 230, 255), price = 50 },
	{ id = "Lemon", name = "レモン", color = Color3.fromRGB(255, 245, 180), price = 80 },
	{ id = "Lavender", name = "ラベンダー", color = Color3.fromRGB(225, 210, 250), price = 80 },
	{ id = "Charcoal", name = "すみ", color = Color3.fromRGB(80, 80, 90), price = 150 },
} :: { WallStyle }

ShopUpgrades.Floors = {
	{ id = "Wood", name = "木の床", color = Color3.fromRGB(200, 155, 105), material = Enum.Material.WoodPlanks, price = 0 },
	{ id = "DarkWood", name = "こげ茶の床", color = Color3.fromRGB(120, 80, 50), material = Enum.Material.WoodPlanks, price = 60 },
	{ id = "Tile", name = "白タイル", color = Color3.fromRGB(235, 235, 235), material = Enum.Material.Marble, price = 100 },
	{ id = "Carpet", name = "赤じゅうたん", color = Color3.fromRGB(170, 50, 60), material = Enum.Material.Fabric, price = 120 },
	{ id = "Brick", name = "レンガ", color = Color3.fromRGB(180, 100, 80), material = Enum.Material.Brick, price = 150 },
} :: { FloorStyle }

-- ひさしの色（"Default" は区画ごとの最初の色）
export type AwningStyle = { id: string, name: string, color: Color3?, price: number }
ShopUpgrades.Awnings = {
	{ id = "Default", name = "はじめの色", color = nil, price = 0 },
	{ id = "Red", name = "赤", color = Color3.fromRGB(230, 80, 80), price = 40 },
	{ id = "Blue", name = "青", color = Color3.fromRGB(70, 150, 230), price = 40 },
	{ id = "Green", name = "緑", color = Color3.fromRGB(90, 190, 110), price = 40 },
	{ id = "Orange", name = "オレンジ", color = Color3.fromRGB(245, 170, 60), price = 40 },
	{ id = "Purple", name = "紫", color = Color3.fromRGB(170, 100, 220), price = 40 },
	{ id = "Pink", name = "ピンク", color = Color3.fromRGB(240, 120, 170), price = 40 },
	{ id = "Black", name = "黒", color = Color3.fromRGB(45, 45, 55), price = 80 },
	{ id = "Gold", name = "金", color = Color3.fromRGB(240, 190, 60), price = 200 },
} :: { AwningStyle }

local function index<T>(list: { T }): { [string]: T }
	local map = {}
	for _, entry in list do
		map[(entry :: any).id] = entry
	end
	return map
end
ShopUpgrades.WallById = index(ShopUpgrades.Walls)
ShopUpgrades.FloorById = index(ShopUpgrades.Floors)
ShopUpgrades.AwningById = index(ShopUpgrades.Awnings)

-- 次の陳列台の値段（もう増やせなければ nil）
function ShopUpgrades.NextShelfPrice(current: number): number?
	return ShopUpgrades.ShelfPrices[current - ShopUpgrades.BaseShelves + 1]
end

return ShopUpgrades
