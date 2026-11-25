--!strict
-- アイテム作成に使える部品（形・色・素材）の一覧
-- unlockPrice = 0 のものは最初から使える。それ以外はコインで解放する（部品ショップ）

export type Shape = { id: string, name: string, unlockPrice: number, value: number }
-- season がある部品は、その季節イベントの期間だけ解放できる（解放したものはずっと使える）
export type ColorEntry = { id: string, name: string, color: Color3, unlockPrice: number, value: number, season: string? }
export type MaterialEntry = { id: string, name: string, material: Enum.Material, unlockPrice: number, value: number }

local Catalog = {}

Catalog.Shapes = {
	{ id = "Block", name = "箱", unlockPrice = 0, value = 1 },
	{ id = "Ball", name = "球", unlockPrice = 0, value = 1 },
	{ id = "Cylinder", name = "円柱", unlockPrice = 0, value = 1 },
	{ id = "Wedge", name = "くさび", unlockPrice = 120, value = 1.3 },
	{ id = "CornerWedge", name = "角くさび", unlockPrice = 250, value = 1.5 },
} :: { Shape }

Catalog.Colors = {
	{ id = "White", name = "白", color = Color3.fromRGB(245, 245, 245), unlockPrice = 0, value = 1 },
	{ id = "Black", name = "黒", color = Color3.fromRGB(35, 35, 40), unlockPrice = 0, value = 1 },
	{ id = "Red", name = "赤", color = Color3.fromRGB(220, 60, 60), unlockPrice = 0, value = 1 },
	{ id = "Orange", name = "橙", color = Color3.fromRGB(245, 150, 50), unlockPrice = 0, value = 1 },
	{ id = "Yellow", name = "黄", color = Color3.fromRGB(250, 215, 70), unlockPrice = 0, value = 1 },
	{ id = "Green", name = "緑", color = Color3.fromRGB(80, 190, 90), unlockPrice = 0, value = 1 },
	{ id = "Blue", name = "青", color = Color3.fromRGB(60, 120, 220), unlockPrice = 0, value = 1 },
	{ id = "Brown", name = "茶", color = Color3.fromRGB(130, 85, 50), unlockPrice = 0, value = 1 },
	{ id = "Pink", name = "桃", color = Color3.fromRGB(250, 150, 190), unlockPrice = 60, value = 1.1 },
	{ id = "Purple", name = "紫", color = Color3.fromRGB(150, 90, 210), unlockPrice = 60, value = 1.1 },
	{ id = "Sky", name = "空色", color = Color3.fromRGB(130, 200, 250), unlockPrice = 60, value = 1.1 },
	{ id = "Mint", name = "ミント", color = Color3.fromRGB(150, 235, 200), unlockPrice = 100, value = 1.2 },
	{ id = "Gold", name = "金", color = Color3.fromRGB(240, 190, 60), unlockPrice = 300, value = 1.5 },
	{ id = "Silver", name = "銀", color = Color3.fromRGB(190, 195, 205), unlockPrice = 200, value = 1.4 },
	{ id = "SnowWhite", name = "雪白", color = Color3.fromRGB(248, 252, 255), unlockPrice = 150, value = 1.4, season = "winter" },
	{ id = "Holly", name = "ヒイラギ緑", color = Color3.fromRGB(30, 115, 60), unlockPrice = 150, value = 1.4, season = "winter" },
	{ id = "Berry", name = "ヒイラギ赤", color = Color3.fromRGB(185, 25, 45), unlockPrice = 150, value = 1.4, season = "winter" },
} :: { ColorEntry }

Catalog.Materials = {
	{ id = "Plastic", name = "プラスチック", material = Enum.Material.Plastic, unlockPrice = 0, value = 1 },
	{ id = "SmoothPlastic", name = "つるつる", material = Enum.Material.SmoothPlastic, unlockPrice = 0, value = 1 },
	{ id = "Wood", name = "木", material = Enum.Material.Wood, unlockPrice = 0, value = 1.1 },
	{ id = "Fabric", name = "布", material = Enum.Material.Fabric, unlockPrice = 80, value = 1.2 },
	{ id = "Brick", name = "レンガ", material = Enum.Material.Brick, unlockPrice = 80, value = 1.2 },
	{ id = "Marble", name = "大理石", material = Enum.Material.Marble, unlockPrice = 150, value = 1.4 },
	{ id = "Metal", name = "金属", material = Enum.Material.Metal, unlockPrice = 150, value = 1.4 },
	{ id = "Glass", name = "ガラス", material = Enum.Material.Glass, unlockPrice = 250, value = 1.6 },
	{ id = "Neon", name = "ネオン", material = Enum.Material.Neon, unlockPrice = 400, value = 2 },
} :: { MaterialEntry }

local function index<T>(list: { T }): { [string]: T }
	local map = {}
	for _, entry in list do
		map[(entry :: any).id] = entry
	end
	return map
end

Catalog.ShapeById = index(Catalog.Shapes)
Catalog.ColorById = index(Catalog.Colors)
Catalog.MaterialById = index(Catalog.Materials)

-- 種類名 → 一覧（部品ショップなどで使う）
Catalog.Kinds = {
	shapes = Catalog.Shapes,
	colors = Catalog.Colors,
	materials = Catalog.Materials,
} :: { [string]: { any } }

-- 最初から使える部品の id 一覧
function Catalog.DefaultUnlocks(): { shapes: { [string]: boolean }, colors: { [string]: boolean }, materials: { [string]: boolean } }
	local result = { shapes = {}, colors = {}, materials = {} }
	for kind, list in Catalog.Kinds do
		for _, entry in list do
			if entry.unlockPrice == 0 then
				(result :: any)[kind][entry.id] = true
			end
		end
	end
	return result
end

return Catalog
