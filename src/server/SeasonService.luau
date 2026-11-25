--!strict
-- 季節イベントの飾り（冬：広場に雪とツリー）。期間はサーバー起動時に判定する

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Season = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Season"))
local Build = require(script.Parent:WaitForChild("Build"))

local SeasonService = {}

local function buildTree(parent: Instance, position: Vector3)
	local tree = Instance.new("Model")
	tree.Name = "WinterTree"
	-- 幹
	Build.Part(tree, {
		Name = "Trunk",
		Size = Vector3.new(3, 1.6, 1.6),
		CFrame = CFrame.new(position + Vector3.new(0, 1.5, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(110, 70, 40),
		Material = Enum.Material.Wood,
		Shape = Enum.PartType.Cylinder,
	})
	-- 葉（円柱を小さくしながら重ねて円すいのように見せる）
	local layers = { { 9, 3 }, { 7, 6 }, { 5, 9 }, { 3, 11.5 } }
	for _, layer in layers do
		local diameter, height = layer[1], layer[2]
		Build.Part(tree, {
			Name = "Leaves",
			Size = Vector3.new(3, diameter, diameter),
			CFrame = CFrame.new(position + Vector3.new(0, height + 1.5, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Color = Color3.fromRGB(40, 130, 70),
			Material = Enum.Material.Grass,
			Shape = Enum.PartType.Cylinder,
		})
	end
	-- 飾りの玉
	local colors = { Color3.fromRGB(230, 50, 60), Color3.fromRGB(250, 210, 60), Color3.fromRGB(80, 150, 240), Color3.fromRGB(250, 250, 255) }
	local random = Random.new(7)
	for i = 1, 18 do
		local layer = layers[(i - 1) % #layers + 1]
		local angle = random:NextNumber() * math.pi * 2
		local radius = layer[1] / 2
		Build.Part(tree, {
			Name = "Ornament",
			Size = Vector3.new(0.7, 0.7, 0.7),
			CFrame = CFrame.new(position + Vector3.new(math.cos(angle) * radius, layer[2] + 1.5 + random:NextNumber(-1, 1), math.sin(angle) * radius)),
			Color = colors[(i - 1) % #colors + 1],
			Material = Enum.Material.Neon,
			Shape = Enum.PartType.Ball,
			CanCollide = false,
		})
	end
	-- てっぺんの星
	local star = Build.Part(tree, {
		Name = "Star",
		Size = Vector3.new(1.6, 1.6, 1.6),
		CFrame = CFrame.new(position + Vector3.new(0, 15, 0)) * CFrame.Angles(0, 0, math.rad(45)),
		Color = Color3.fromRGB(255, 220, 80),
		Material = Enum.Material.Neon,
		CanCollide = false,
	})
	local light = Instance.new("PointLight")
	light.Range = 16
	light.Color = Color3.fromRGB(255, 220, 140)
	light.Parent = star
	tree.Parent = parent
end

local function buildSnow(parent: Instance)
	local cloud = Build.Part(parent, {
		Name = "SnowCloud",
		Size = Vector3.new(260, 1, 260),
		CFrame = CFrame.new(0, 70, 0),
		Transparency = 1,
		CanCollide = false,
	})
	cloud.CanQuery = false
	local snow = Instance.new("ParticleEmitter")
	snow.Color = ColorSequence.new(Color3.new(1, 1, 1))
	snow.LightEmission = 0.3
	snow.Size = NumberSequence.new(0.35)
	snow.Transparency = NumberSequence.new(0.1)
	snow.Speed = NumberRange.new(6, 9)
	snow.SpreadAngle = Vector2.new(10, 10)
	snow.Lifetime = NumberRange.new(9, 11)
	snow.Rate = 220
	snow.RotSpeed = NumberRange.new(-40, 40)
	snow.EmissionDirection = Enum.NormalId.Bottom
	snow.Parent = cloud
end

function SeasonService.Start()
	if not Season.IsActive("winter") then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "WinterDecor"
	folder.Parent = workspace
	buildTree(folder, Vector3.new(6.5, 0.4, 11.3)) -- 噴水とベンチの間（店への道を避けた30°の方向）
	buildSnow(folder)
end

return SeasonService
