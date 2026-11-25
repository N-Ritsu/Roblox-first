--!strict
-- 季節イベントの飾り（冬：広場に雪とツリー）。期間は1分ごとに判定する

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Season = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Season"))
local Build = require(script.Parent:WaitForChild("Build"))
local WorldService = require(script.Parent:WaitForChild("WorldService"))

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

-- ツリーのまわりの雪だるまとプレゼント箱（position は地面の高さ）
local function buildExtras(parent: Instance, position: Vector3)
	local extras = Instance.new("Model")
	extras.Name = "WinterExtras"
	-- 通路をふさがないよう、広場の中心から見て横（外周に沿う向き）に雪だるまを置く
	local outward = Vector3.new(position.X, 0, position.Z)
	outward = if outward.Magnitude > 0 then outward.Unit else Vector3.new(0, 0, 1)
	local side = Vector3.new(-outward.Z, 0, outward.X)
	for _, sign in { -1, 1 } do
		local at = position + side * (7.5 * sign)
		local face = CFrame.lookAt(at, at - outward) -- 広場の中心を向く
		Build.Part(extras, { Name = "SnowBody", Size = Vector3.new(3.4, 3.4, 3.4), CFrame = face * CFrame.new(0, 1.6, 0), Color = Color3.fromRGB(250, 252, 255), Material = Enum.Material.Snow, Shape = Enum.PartType.Ball })
		Build.Part(extras, { Name = "SnowHead", Size = Vector3.new(2.3, 2.3, 2.3), CFrame = face * CFrame.new(0, 4.1, 0), Color = Color3.fromRGB(250, 252, 255), Material = Enum.Material.Snow, Shape = Enum.PartType.Ball })
		for _, x in { -0.4, 0.4 } do
			Build.Part(extras, { Name = "Eye", Size = Vector3.new(0.3, 0.3, 0.3), CFrame = face * CFrame.new(x, 4.4, -1.05), Color = Color3.fromRGB(30, 30, 35), Shape = Enum.PartType.Ball, CanCollide = false })
		end
		-- にんじんの鼻（前に向けた細い円柱）
		Build.Part(extras, { Name = "Nose", Size = Vector3.new(0.8, 0.3, 0.3), CFrame = face * CFrame.new(0, 4.1, -1.35) * CFrame.Angles(0, math.rad(90), 0), Color = Color3.fromRGB(245, 140, 40), Shape = Enum.PartType.Cylinder, CanCollide = false })
		-- マフラー
		Build.Part(extras, { Name = "Scarf", Size = Vector3.new(0.5, 2.3, 2.3), CFrame = face * CFrame.new(0, 3.05, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = if sign < 0 then Color3.fromRGB(200, 40, 50) else Color3.fromRGB(40, 120, 70), Material = Enum.Material.Fabric, Shape = Enum.PartType.Cylinder, CanCollide = false })
	end
	-- プレゼント箱（ツリーの下）
	local giftColors = { Color3.fromRGB(200, 40, 55), Color3.fromRGB(60, 130, 220), Color3.fromRGB(250, 205, 70), Color3.fromRGB(40, 140, 80), Color3.fromRGB(170, 90, 210) }
	local random = Random.new(12)
	for i = 1, 5 do
		local angle = (i - 1) / 5 * math.pi * 2 + 0.4
		local size = random:NextNumber(1.2, 1.9)
		local cf = CFrame.new(position + Vector3.new(math.cos(angle) * 3.3, size / 2, math.sin(angle) * 3.3)) * CFrame.Angles(0, random:NextNumber(0, math.pi), 0)
		Build.Part(extras, { Name = "Gift", Size = Vector3.new(size, size, size), CFrame = cf, Color = giftColors[i], Material = Enum.Material.SmoothPlastic })
		Build.Part(extras, { Name = "Ribbon", Size = Vector3.new(size + 0.05, size + 0.05, 0.25), CFrame = cf, Color = Color3.fromRGB(250, 250, 250), Material = Enum.Material.SmoothPlastic, CanCollide = false })
		Build.Part(extras, { Name = "Ribbon", Size = Vector3.new(0.25, size + 0.05, size + 0.05), CFrame = cf, Color = Color3.fromRGB(250, 250, 250), Material = Enum.Material.SmoothPlastic, CanCollide = false })
	end
	extras.Parent = parent
end

local decor: Folder? = nil

local function setDecor(active: boolean)
	if active and not decor then
		local folder = Instance.new("Folder")
		folder.Name = "WinterDecor"
		local spot = WorldService.SpotPosition(WorldService.SeasonSpot, 22) + Vector3.new(0, 0.4, 0) -- ベンチを置いていない外周の場所
		buildTree(folder, spot)
		buildExtras(folder, spot)
		buildSnow(folder)
		folder.Parent = workspace
		decor = folder
	elseif not active and decor then
		decor:Destroy()
		decor = nil
	end
end

local WINTER_NOTE = "冬のイベント開催中（1/7まで）！ 部品の限定色と、サンタさんのお客さんが来るよ"

function SeasonService.Start()
	local Players = game:GetService("Players")
	local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"))
	local noticeEvent = Net.Event("Notice")
	local wasActive = Season.IsActive("winter")
	setDecor(wasActive)
	-- 入ってきた人に、開催中なら一度だけ知らせる（ほかのお知らせと重ならないよう少し待つ）
	Players.PlayerAdded:Connect(function(player)
		task.delay(20, function()
			if player.Parent and Season.IsActive("winter") then
				noticeEvent:FireClient(player, WINTER_NOTE)
			end
		end)
	end)
	-- 長く動いているサーバーでも、日付が変わったら飾りを出し入れする（以前は起動時だけ判定していた）
	task.spawn(function()
		while true do
			task.wait(60)
			local ok, err = pcall(function()
				local active = Season.IsActive("winter")
				if active ~= wasActive then
					wasActive = active
					setDecor(active)
					if active then
						noticeEvent:FireAllClients("冬のイベントが始まりました！ 広場に雪とツリー、部品に限定色が登場")
					end
				end
			end)
			if not ok then
				warn("[SeasonService] エラー:", err)
			end
		end
	end)
end

return SeasonService
