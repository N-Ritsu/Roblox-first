--!strict
-- ライティングと中央広場の見た目

local Lighting = game:GetService("Lighting")

local Build = require(script.Parent:WaitForChild("Build"))

local WorldService = {}

local function setupLighting()
	Lighting.ClockTime = 14.5
	Lighting.Brightness = 2.2
	Lighting.Ambient = Color3.fromRGB(110, 105, 120)
	Lighting.OutdoorAmbient = Color3.fromRGB(140, 140, 150)
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.6
	pcall(function()
		Lighting.Technology = Enum.Technology.Future
	end)

	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = 0.28
	atmosphere.Haze = 1.2
	atmosphere.Color = Color3.fromRGB(200, 220, 255)
	atmosphere.Decay = Color3.fromRGB(255, 220, 190)
	atmosphere.Parent = Lighting

	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.6
	bloom.Size = 30
	bloom.Threshold = 1.6
	bloom.Parent = Lighting

	local color = Instance.new("ColorCorrectionEffect")
	color.Saturation = 0.12
	color.Contrast = 0.05
	color.Parent = Lighting
end

local function setupPlaza()
	local plaza = Instance.new("Model")
	plaza.Name = "Plaza"
	-- 石畳の丸い広場（円柱を横倒しにして円盤にする）
	Build.Part(plaza, {
		Name = "PlazaFloor",
		Size = Vector3.new(0.4, 60, 60),
		CFrame = CFrame.new(0, 0.2, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(215, 205, 190),
		Material = Enum.Material.Cobblestone,
		Shape = Enum.PartType.Cylinder,
	})
	-- 噴水
	Build.Part(plaza, {
		Name = "FountainBase",
		Size = Vector3.new(2, 16, 16),
		CFrame = CFrame.new(0, 1, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(235, 235, 240),
		Material = Enum.Material.Marble,
		Shape = Enum.PartType.Cylinder,
	})
	local water = Build.Part(plaza, {
		Name = "FountainWater",
		Size = Vector3.new(0.3, 14, 14),
		CFrame = CFrame.new(0, 2.05, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(90, 170, 240),
		Material = Enum.Material.Glass,
		Transparency = 0.3,
		Shape = Enum.PartType.Cylinder,
		CanCollide = false,
	})
	local pillar = Build.Part(plaza, {
		Name = "FountainPillar",
		Size = Vector3.new(6, 2, 2),
		CFrame = CFrame.new(0, 4, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(235, 235, 240),
		Material = Enum.Material.Marble,
		Shape = Enum.PartType.Cylinder,
	})
	local attachment = Instance.new("Attachment")
	attachment.Position = Vector3.new(3, 0, 0) -- 円柱の軸方向（横倒しなので上）
	attachment.Parent = pillar
	local spray = Instance.new("ParticleEmitter")
	spray.Color = ColorSequence.new(Color3.fromRGB(200, 235, 255))
	spray.LightEmission = 0.4
	spray.Size = NumberSequence.new(0.5, 0.1)
	spray.Transparency = NumberSequence.new(0.2, 1)
	spray.Speed = NumberRange.new(10, 14)
	spray.SpreadAngle = Vector2.new(12, 12)
	spray.Acceleration = Vector3.new(0, -30, 0)
	spray.Lifetime = NumberRange.new(0.8, 1.1)
	spray.Rate = 60
	spray.EmissionDirection = Enum.NormalId.Right
	spray.Parent = attachment
	water.Parent = plaza

	-- 街灯
	for i = 0, 5 do
		local angle = (i + 0.5) / 6 * math.pi * 2
		local base = Vector3.new(math.sin(angle) * 27, 0, math.cos(angle) * 27)
		Build.Part(plaza, { Name = "LampPost", Size = Vector3.new(0.6, 10, 0.6), CFrame = CFrame.new(base + Vector3.new(0, 5, 0)), Color = Color3.fromRGB(50, 50, 60), Material = Enum.Material.Metal })
		local bulb = Build.Part(plaza, {
			Name = "LampBulb",
			Size = Vector3.new(1.4, 1.4, 1.4),
			CFrame = CFrame.new(base + Vector3.new(0, 10.5, 0)),
			Color = Color3.fromRGB(255, 230, 170),
			Material = Enum.Material.Neon,
			Shape = Enum.PartType.Ball,
			CanCollide = false,
		})
		local light = Instance.new("PointLight")
		light.Range = 18
		light.Brightness = 1
		light.Color = Color3.fromRGB(255, 220, 160)
		light.Parent = bulb
	end

	plaza.Parent = workspace
end

-- 昼と夜：1日＝約20分。夜（19時〜5時）は2倍の速さで進めて、暗い時間を短くする
WorldService.DaySeconds = 950 -- 夜が2倍速なので、実際の1日は約20分になる
local function runDayNight()
	local hoursPerSecond = 24 / WorldService.DaySeconds
	local last = os.clock()
	while true do
		task.wait(0.5)
		local now = os.clock()
		local dt = now - last
		last = now
		local clock = Lighting.ClockTime
		local speed = if clock >= 19 or clock < 5 then 2 else 1
		Lighting.ClockTime = (clock + dt * hoursPerSecond * speed) % 24
	end
end

function WorldService.Start()
	setupLighting()
	setupPlaza()
	Lighting.ClockTime = 9
	task.spawn(runDayNight)
end

return WorldService
