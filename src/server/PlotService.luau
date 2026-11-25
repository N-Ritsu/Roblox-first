--!strict
-- 店舗区画：中央広場のまわりに区画を並べ、入ってきたプレイヤーに1つずつ割り当てる
-- 区画のローカル座標：-Z が広場側（店の正面）、+Z が店の奥

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Build = require(script.Parent:WaitForChild("Build"))

local PlotService = {}

export type Plot = {
	index: number,
	model: Model,
	origin: CFrame,
	owner: Player?,
	signLabel: TextLabel,
}

local plots: { Plot } = {}
local plotByPlayer: { [Player]: Plot } = {}
local assignedEvent = Instance.new("BindableEvent")
PlotService.Assigned = assignedEvent.Event -- (player, plot)
local releasedEvent = Instance.new("BindableEvent")
PlotService.Released = releasedEvent.Event -- (player, plot)

local WALL = Color3.fromRGB(250, 240, 225)
local TRIM = Color3.fromRGB(120, 80, 55)
local FLOOR = Color3.fromRGB(200, 155, 105)
local AWNING_COLORS = {
	Color3.fromRGB(230, 80, 80),
	Color3.fromRGB(70, 150, 230),
	Color3.fromRGB(90, 190, 110),
	Color3.fromRGB(245, 170, 60),
	Color3.fromRGB(170, 100, 220),
	Color3.fromRGB(240, 120, 170),
}

-- 店の中で、棚（陳列台）の位置（ローカル座標、台の上面中央）
PlotService.ShelfOffsets = {
	CFrame.new(-8, 3.9, 1),
	CFrame.new(-8, 3.9, 8),
	CFrame.new(8, 3.9, 1),
	CFrame.new(8, 3.9, 8),
}
PlotService.SpawnOffset = CFrame.new(0, 4, 10) -- 店の入口の方を向いて立つ
PlotService.WorkbenchOffset = CFrame.new(-8, 0.9, 14)
PlotService.EntranceOffset = CFrame.new(0, 1, -10) -- 店の前の歩道

local function buildPlot(index: number, origin: CFrame, parent: Instance): Plot
	local model = Instance.new("Model")
	model.Name = "Plot" .. index
	local function at(x: number, y: number, z: number): CFrame
		return origin * CFrame.new(x, y, z)
	end

	-- 地面と歩道
	Build.Part(model, { Name = "Ground", Size = Vector3.new(44, 0.5, 44), CFrame = at(0, 0.25, 4), Color = Color3.fromRGB(110, 175, 90), Material = Enum.Material.Grass })
	Build.Part(model, { Name = "Sidewalk", Size = Vector3.new(30, 0.6, 10), CFrame = at(0, 0.3, -10), Color = Color3.fromRGB(205, 205, 200), Material = Enum.Material.Concrete })

	-- 床・壁・屋根
	Build.Part(model, { Name = "Floor", Size = Vector3.new(28, 0.4, 21), CFrame = at(0, 0.7, 6), Color = FLOOR, Material = Enum.Material.WoodPlanks })
	Build.Part(model, { Name = "BackWall", Size = Vector3.new(30, 12, 1), CFrame = at(0, 6.9, 17), Color = WALL })
	Build.Part(model, { Name = "LeftWall", Size = Vector3.new(1, 12, 21), CFrame = at(-14.5, 6.9, 6), Color = WALL })
	Build.Part(model, { Name = "RightWall", Size = Vector3.new(1, 12, 21), CFrame = at(14.5, 6.9, 6), Color = WALL })
	Build.Part(model, { Name = "FrontLeft", Size = Vector3.new(9, 12, 1), CFrame = at(-10.5, 6.9, -4.5), Color = WALL })
	Build.Part(model, { Name = "FrontRight", Size = Vector3.new(9, 12, 1), CFrame = at(10.5, 6.9, -4.5), Color = WALL })
	Build.Part(model, { Name = "FrontHeader", Size = Vector3.new(12, 3, 1), CFrame = at(0, 11.4, -4.5), Color = WALL })
	Build.Part(model, { Name = "Roof", Size = Vector3.new(31, 1, 23), CFrame = at(0, 13.4, 6), Color = TRIM, Material = Enum.Material.Wood })
	-- ショーウィンドウ（正面の窓）
	for _, x in { -10.5, 10.5 } do
		Build.Part(model, { Name = "WindowFrame", Size = Vector3.new(6.6, 5.6, 0.2), CFrame = at(x, 6, -5.05), Color = TRIM, Material = Enum.Material.Wood })
		Build.Part(model, { Name = "Window", Size = Vector3.new(6, 5, 0.2), CFrame = at(x, 6, -5.2), Color = Color3.fromRGB(170, 215, 250), Material = Enum.Material.Glass, Transparency = 0.15 })
	end

	-- 縞模様のひさし
	local awningColor = AWNING_COLORS[(index - 1) % #AWNING_COLORS + 1]
	for i = 0, 7 do
		local x = -14 + 3.5 * i + 1.75
		Build.Part(model, {
			Name = "Awning",
			Size = Vector3.new(3.5, 0.3, 5),
			CFrame = at(x, 11.5, -6.6) * CFrame.Angles(math.rad(-20), 0, 0),
			Color = if i % 2 == 0 then awningColor else Color3.new(1, 1, 1),
			Material = Enum.Material.Fabric,
		})
	end

	-- 看板
	local signBoard = Build.Part(model, { Name = "Sign", Size = Vector3.new(16, 3, 0.6), CFrame = at(0, 15.6, -4.6), Color = TRIM, Material = Enum.Material.Wood })
	local signLabel = Build.Sign(signBoard, "空き店舗", Enum.NormalId.Front)

	-- 陳列台
	for i, offset in PlotService.ShelfOffsets do
		Build.Part(model, { Name = "ShelfTable" .. i, Size = Vector3.new(4, 3, 4), CFrame = origin * offset * CFrame.new(0, -1.5, 0), Color = TRIM, Material = Enum.Material.Wood })
	end
	-- レジカウンター
	Build.Part(model, { Name = "Counter", Size = Vector3.new(8, 3.5, 2), CFrame = at(8, 2.65, 13.5), Color = TRIM, Material = Enum.Material.Wood })
	Build.Part(model, { Name = "CounterTop", Size = Vector3.new(8.4, 0.3, 2.4), CFrame = at(8, 4.55, 13.5), Color = Color3.fromRGB(240, 240, 240), Material = Enum.Material.Marble })

	-- 照明
	local lampPart = Build.Part(model, { Name = "Lamp", Size = Vector3.new(4, 0.4, 4), CFrame = at(0, 12.7, 6), Color = Color3.fromRGB(255, 245, 210), Material = Enum.Material.Neon, CanCollide = false })
	local light = Instance.new("PointLight")
	light.Range = 26
	light.Brightness = 1.2
	light.Color = Color3.fromRGB(255, 235, 200)
	light.Shadows = true
	light.Parent = lampPart

	model.Parent = parent
	return {
		index = index,
		model = model,
		origin = origin,
		owner = nil,
		signLabel = signLabel,
	}
end

function PlotService.Get(player: Player): Plot?
	return plotByPlayer[player]
end

function PlotService.All(): { Plot }
	return plots
end

local function teleportHome(player: Player, character: Model)
	local plot = plotByPlayer[player]
	if not plot then
		return
	end
	character:WaitForChild("HumanoidRootPart", 5)
	task.wait() -- スポーン直後の位置決定に上書きされないよう1フレーム待つ
	if character.Parent then
		character:PivotTo(plot.origin * PlotService.SpawnOffset)
	end
end

local function assign(player: Player)
	for _, plot in plots do
		if not plot.owner then
			plot.owner = player
			plotByPlayer[player] = plot
			plot.model:SetAttribute("OwnerUserId", player.UserId)
			plot.signLabel.Text = player.DisplayName .. " のお店"
			assignedEvent:Fire(player, plot)
			if player.Character then
				task.spawn(teleportHome, player, player.Character)
			end
			return
		end
	end
	warn("[PlotService] 空き区画がありません:", player.Name)
end

local function release(player: Player)
	local plot = plotByPlayer[player]
	if not plot then
		return
	end
	releasedEvent:Fire(player, plot)
	plot.owner = nil
	plotByPlayer[player] = nil
	plot.model:SetAttribute("OwnerUserId", nil)
	plot.signLabel.Text = "空き店舗"
end

function PlotService.TeleportHome(player: Player)
	if player.Character then
		task.spawn(teleportHome, player, player.Character)
	end
end

function PlotService.Start()
	local folder = Instance.new("Folder")
	folder.Name = "Plots"
	folder.Parent = workspace
	for i = 1, Config.PlotCount do
		local angle = (i - 1) / Config.PlotCount * math.pi * 2
		local position = Vector3.new(math.sin(angle) * Config.PlotRadius, 0, math.cos(angle) * Config.PlotRadius)
		-- 区画の -Z（店の正面）が広場の中心を向くようにする
		local origin = CFrame.lookAt(position, Vector3.zero)
		table.insert(plots, buildPlot(i, origin, folder))
	end

	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function(character)
			teleportHome(player, character)
		end)
		assign(player)
	end)
	Players.PlayerRemoving:Connect(release)
	for _, player in Players:GetPlayers() do
		player.CharacterAdded:Connect(function(character)
			teleportHome(player, character)
		end)
		assign(player)
	end
end

return PlotService
