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

local decor: Folder? = nil

local function setDecor(active: boolean)
	if active and not decor then
		local folder = Instance.new("Folder")
		folder.Name = "WinterDecor"
		buildTree(folder, WorldService.SpotPosition(WorldService.SeasonSpot, 22) + Vector3.new(0, 0.4, 0)) -- ベンチを置いていない外周の場所
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
