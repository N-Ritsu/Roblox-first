--!strict
-- アイテムのデザイン（部品の組み合わせ）の検証・価値計算・3Dモデル化
-- サーバー（検証・棚の表示）とクライアント（プレビュー）の両方で使う

local Catalog = require(script.Parent:WaitForChild("Catalog"))

export type PartData = {
	shape: string,
	color: string,
	material: string,
	size: { number }, -- {x, y, z}
	pos: { number }, -- {x, y, z}
	rot: { number }, -- {x, y}（45度単位、0〜7）
}
export type Design = {
	name: string,
	parts: { PartData },
}

local ItemBuilder = {}

ItemBuilder.MaxParts = 6
ItemBuilder.MaxNameLength = 20
ItemBuilder.SizeMin = 0.5
ItemBuilder.SizeMax = 4
ItemBuilder.PosLimit = 3
ItemBuilder.Step = 0.5

local function snap(value: any, min: number, max: number): number?
	if type(value) ~= "number" or value ~= value then -- NaN も弾く
		return nil
	end
	local snapped = math.floor(value / ItemBuilder.Step + 0.5) * ItemBuilder.Step
	return math.clamp(snapped, min, max)
end

local function vector(list: any, min: number, max: number, count: number): { number }?
	if type(list) ~= "table" then
		return nil
	end
	local result = {}
	for i = 1, count do
		local v = snap(list[i], min, max)
		if not v then
			return nil
		end
		result[i] = v
	end
	return result
end

-- 形ごとの大きさの決まり（球は全方向同じ、円柱は太さが同じ）
function ItemBuilder.NormalizeSize(shape: string, size: { number }): { number }
	if shape == "Ball" then
		return { size[1], size[1], size[1] }
	elseif shape == "Cylinder" then
		return { size[1], size[2], size[2] }
	end
	return { size[1], size[2], size[3] }
end

function ItemBuilder.NewPart(): PartData
	return {
		shape = "Block",
		color = "Red",
		material = "Plastic",
		size = { 2, 2, 2 },
		pos = { 0, 0, 0 },
		rot = { 0, 0 },
	}
end

-- 送られてきたデザインを検証し、整えたものを返す。unlocks を渡すと解放済みかも確認する
function ItemBuilder.Validate(raw: any, unlocks: any?): (Design?, string?)
	if type(raw) ~= "table" or type(raw.parts) ~= "table" then
		return nil, "デザインの形式が正しくありません"
	end
	local name = raw.name
	if type(name) ~= "string" then
		return nil, "名前を入れてください"
	end
	name = string.gsub(name, "^%s+", "")
	name = string.gsub(name, "%s+$", "")
	local length = utf8.len(name)
	if not length or length == 0 then
		return nil, "名前を入れてください"
	end
	if length > ItemBuilder.MaxNameLength then
		return nil, ("名前は%d文字までです"):format(ItemBuilder.MaxNameLength)
	end

	local count = #raw.parts
	if count < 1 or count > ItemBuilder.MaxParts then
		return nil, ("部品は1〜%d個にしてください"):format(ItemBuilder.MaxParts)
	end

	local parts = {}
	for i = 1, count do
		local p = raw.parts[i]
		if type(p) ~= "table" then
			return nil, "部品の形式が正しくありません"
		end
		local shape, color, material = p.shape, p.color, p.material
		if type(shape) ~= "string" or not Catalog.ShapeById[shape] then
			return nil, "使えない形があります"
		end
		if type(color) ~= "string" or not Catalog.ColorById[color] then
			return nil, "使えない色があります"
		end
		if type(material) ~= "string" or not Catalog.MaterialById[material] then
			return nil, "使えない素材があります"
		end
		if unlocks then
			if not unlocks.shapes[shape] or not unlocks.colors[color] or not unlocks.materials[material] then
				return nil, "まだ解放していない部品があります"
			end
		end
		local size = vector(p.size, ItemBuilder.SizeMin, ItemBuilder.SizeMax, 3)
		local pos = vector(p.pos, -ItemBuilder.PosLimit, ItemBuilder.PosLimit, 3)
		if not size or not pos or type(p.rot) ~= "table" then
			return nil, "部品の大きさか位置が正しくありません"
		end
		local rot = {}
		for j = 1, 2 do
			local r = p.rot[j]
			if type(r) ~= "number" or r ~= r then
				return nil, "部品の向きが正しくありません"
			end
			rot[j] = math.floor(r) % 8
		end
		table.insert(parts, {
			shape = shape,
			color = color,
			material = material,
			size = ItemBuilder.NormalizeSize(shape, size),
			pos = pos,
			rot = rot,
		})
	end
	return { name = name, parts = parts }, nil
end

-- アイテムの基本価値（お客さんが払ってくれる額の目安）
function ItemBuilder.Value(design: Design): number
	local total = 0
	for _, p in design.parts do
		local shape = Catalog.ShapeById[p.shape]
		local color = Catalog.ColorById[p.color]
		local material = Catalog.MaterialById[p.material]
		local base = 4 + p.size[1] + p.size[2] + p.size[3]
		total += base * (shape and shape.value or 1) * (color and color.value or 1) * (material and material.value or 1)
	end
	-- 部品が多いほど少し価値が上がる
	total *= 1 + 0.1 * (#design.parts - 1)
	return math.max(1, math.floor(total + 0.5))
end

-- 1個作るのにかかるコイン
function ItemBuilder.CraftCost(design: Design): number
	return math.max(1, math.ceil(ItemBuilder.Value(design) * 0.4))
end

-- 3Dモデルを作る。モデルの基準点（Pivot）は底面の中心
function ItemBuilder.Build(design: Design): Model
	local model = Instance.new("Model")
	model.Name = design.name
	for i, p in design.parts do
		local className = if p.shape == "Wedge" then "WedgePart" elseif p.shape == "CornerWedge" then "CornerWedgePart" else "Part"
		local part = Instance.new(className :: any) :: BasePart
		part.Name = "Piece" .. i
		if part:IsA("Part") then
			part.Shape = if p.shape == "Ball" then Enum.PartType.Ball elseif p.shape == "Cylinder" then Enum.PartType.Cylinder else Enum.PartType.Block
		end
		local size = ItemBuilder.NormalizeSize(p.shape, p.size)
		part.Size = Vector3.new(size[1], size[2], size[3])
		local color = Catalog.ColorById[p.color]
		local material = Catalog.MaterialById[p.material]
		part.Color = if color then color.color else Color3.new(1, 1, 1)
		part.Material = if material then material.material else Enum.Material.Plastic
		if p.material == "Glass" then
			part.Transparency = 0.35
		end
		part.CFrame = CFrame.new(p.pos[1], p.pos[2], p.pos[3]) * CFrame.Angles(math.rad(p.rot[1] * 45), math.rad(p.rot[2] * 45), 0)
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.Parent = model
	end
	model.WorldPivot = CFrame.new() -- 向きを揃えてから大きさを測る
	local bbCFrame, bbSize = model:GetBoundingBox()
	model.WorldPivot = CFrame.new(bbCFrame.Position - Vector3.new(0, bbSize.Y / 2, 0))
	return model
end

-- 指定した大きさ（一番長い辺）に収まるよう縮小して作る。棚に並べるときに使う
function ItemBuilder.BuildFitted(design: Design, maxExtent: number): Model
	local model = ItemBuilder.Build(design)
	local _, size = model:GetBoundingBox()
	local longest = math.max(size.X, size.Y, size.Z)
	if longest > maxExtent then
		model:ScaleTo(maxExtent / longest)
	end
	return model
end

return ItemBuilder
