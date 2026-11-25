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

-- 自宅の壁・床：お店と同じ選択肢を使い、一度買えばお店と自宅の両方で使える
-- "Default" は自宅のはじめの色（color = nil）
ShopUpgrades.HomeWalls = { { id = "Default", name = "はじめの色", color = nil, price = 0 } } :: { any }
for _, entry in ShopUpgrades.Walls do
	table.insert(ShopUpgrades.HomeWalls, entry) -- お店のはじめの色（無料）も自宅で選べる
end
ShopUpgrades.HomeFloors = { { id = "Default", name = "はじめの床", color = nil, price = 0 } } :: { any }
for _, entry in ShopUpgrades.Floors do
	table.insert(ShopUpgrades.HomeFloors, entry)
end
-- 持っているかの記録（ownedInterior のキー）に使う種類名
ShopUpgrades.OwnedKind = { wall = "wall", floor = "floor", awning = "awning", sign = "sign", homeWall = "wall", homeFloor = "floor" } :: { [string]: string }

-- 自宅の灯り（無料で切り替え）。party は各自の画面で色が移り変わる
ShopUpgrades.HomeLights = {
	{ id = "normal", name = "ふつう", color = Color3.fromRGB(255, 240, 210) },
	{ id = "warm", name = "あたたか", color = Color3.fromRGB(255, 185, 115) },
	{ id = "cool", name = "ひんやり", color = Color3.fromRGB(185, 215, 255) },
	{ id = "party", name = "パーティー", color = Color3.fromRGB(255, 150, 220) },
}

-- 看板の板の色（文字は明るさに合わせて白か黒になる）
export type SignStyle = { id: string, name: string, color: Color3, price: number }
ShopUpgrades.Signs = {
	{ id = "Default", name = "木の色", color = Color3.fromRGB(120, 80, 55), price = 0 },
	{ id = "Black", name = "黒板", color = Color3.fromRGB(40, 55, 50), price = 40 },
	{ id = "White", name = "白", color = Color3.fromRGB(245, 245, 240), price = 40 },
	{ id = "Red", name = "赤", color = Color3.fromRGB(200, 60, 60), price = 40 },
	{ id = "Navy", name = "紺", color = Color3.fromRGB(40, 60, 120), price = 60 },
	{ id = "Mint", name = "ミント", color = Color3.fromRGB(150, 225, 195), price = 60 },
	{ id = "Pink", name = "ピンク", color = Color3.fromRGB(245, 160, 195), price = 60 },
	{ id = "Gold", name = "金", color = Color3.fromRGB(235, 185, 60), price = 200 },
} :: { SignStyle }

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
ShopUpgrades.SignById = index(ShopUpgrades.Signs)
ShopUpgrades.HomeWallById = index(ShopUpgrades.HomeWalls)
ShopUpgrades.HomeFloorById = index(ShopUpgrades.HomeFloors)
ShopUpgrades.HomeLightById = index(ShopUpgrades.HomeLights)

-- 背景色の上で読みやすい文字色
function ShopUpgrades.TextColorOn(color: Color3): Color3
	local luminance = color.R * 0.299 + color.G * 0.587 + color.B * 0.114
	return if luminance > 0.62 then Color3.fromRGB(45, 40, 35) else Color3.new(1, 1, 1)
end

-- 次の陳列台の値段（もう増やせなければ nil）
function ShopUpgrades.NextShelfPrice(current: number): number?
	return ShopUpgrades.ShelfPrices[current - ShopUpgrades.BaseShelves + 1]
end

return ShopUpgrades
