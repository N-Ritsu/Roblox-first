--!strict
-- 店舗区画：中央広場のまわりに区画を並べ、入ってきたプレイヤーに1つずつ割り当てる
-- 区画のローカル座標：-Z が広場側（店の正面）、+Z が店の奥

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Build = require(script.Parent:WaitForChild("Build"))

local PlotService = {}

local noticeEvent = Net.Event("Notice")

export type Plot = {
	index: number,
	model: Model,
	origin: CFrame,
	owner: Player?,
	signLabel: TextLabel,
	sloganLabel: TextLabel,
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
-- 1〜4は店の中、5〜8は店の前の歩道に置く「店頭の台」（コインで増やす）
PlotService.ShelfOffsets = {
	CFrame.new(-8, 3.9, 1),
	CFrame.new(-8, 3.9, 8),
	CFrame.new(8, 3.9, 1),
	CFrame.new(8, 3.9, 8),
	CFrame.new(-6, 3.6, -14),
	CFrame.new(6, 3.6, -14),
	CFrame.new(-11.5, 3.6, -14),
	CFrame.new(11.5, 3.6, -14),
}
-- お客さんが商品を見るときに立つ位置
PlotService.ShelfStandOffsets = {
	Vector3.new(-4.4, 0.9, 1),
	Vector3.new(-4.4, 0.9, 8),
	Vector3.new(4.4, 0.9, 1),
	Vector3.new(4.4, 0.9, 8),
	Vector3.new(-6, 0.6, -10.8),
	Vector3.new(6, 0.6, -10.8),
	Vector3.new(-11.5, 0.6, -10.8),
	Vector3.new(11.5, 0.6, -10.8),
}
function PlotService.IsOutdoorShelf(slot: number): boolean
	return slot > 4
end
-- 内装の色を変える部品
PlotService.WallParts = { "BackWall", "LeftWall", "RightWall", "FrontLeft", "FrontRight", "FrontHeader" }
PlotService.SpawnOffset = CFrame.new(0, 4, 10) -- 店の入口の方を向いて立つ
PlotService.WorkbenchOffset = CFrame.new(-8, 0.9, 14)
PlotService.EntranceOffset = CFrame.new(0, 1, -10) -- 店の前の歩道

-- 自宅：店の上空にある部屋。床にマス目（GridSize×GridSize）があり、作ったアイテムを飾れる
PlotService.HomeOffset = CFrame.new(0, 250, 4) -- 部屋の床の上面中央
PlotService.HomeGridSize = 6
PlotService.HomeCellSize = 4.5
PlotService.HomeSpawnOffset = PlotService.HomeOffset * CFrame.new(0, 3, -18.5) * CFrame.Angles(0, math.pi, 0) -- 部屋の奥を向く
PlotService.HomeRoomHalf = 22 -- 部屋の内側の半分の広さ（壁の内面まで）
PlotService.HomeExpandPrice = 800 -- 自宅を 8×8 に広げる値段

-- 使えるマス目の範囲。広げると外側に1列ずつ増える（6×6 の場所はそのまま）
function PlotService.HomeGridRange(expanded: boolean): (number, number)
	if expanded then
		return 0, PlotService.HomeGridSize + 1
	end
	return 1, PlotService.HomeGridSize
end
PlotService.HomeDoorOffset = CFrame.new(-13.85, 4.4, 4.5) -- 店の中の「自宅」ドア

-- マス目 (x, z)（1〜GridSize）の中心（自宅の床の上面、区画のローカル座標）
function PlotService.HomeCellOffset(x: number, z: number): CFrame
	local half = (PlotService.HomeGridSize + 1) / 2
	return PlotService.HomeOffset * CFrame.new((x - half) * PlotService.HomeCellSize, 0, (z - half) * PlotService.HomeCellSize + 2)
end

local function buildHome(model: Model, origin: CFrame, accent: Color3)
	local home = Instance.new("Model")
	home.Name = "Home"
	local base = origin * PlotService.HomeOffset
	local function at(x: number, y: number, z: number): CFrame
		return base * CFrame.new(x, y, z)
	end
	local wall = Color3.fromRGB(245, 235, 250)
	local h = PlotService.HomeRoomHalf
	local full = h * 2 + 2
	Build.Part(home, { Name = "Floor", Size = Vector3.new(full, 1, full), CFrame = at(0, -0.5, 0), Color = Color3.fromRGB(190, 145, 100), Material = Enum.Material.WoodPlanks })
	Build.Part(home, { Name = "Rug", Size = Vector3.new(28, 0.1, 28), CFrame = at(0, 0.05, 2), Color = accent:Lerp(Color3.new(1, 1, 1), 0.55), Material = Enum.Material.Fabric, CanCollide = false })
	Build.Part(home, { Name = "Ceiling", Size = Vector3.new(full, 1, full), CFrame = at(0, 14.5, 0), Color = Color3.new(1, 1, 1) })
	Build.Part(home, { Name = "WallBack", Size = Vector3.new(full, 14, 1), CFrame = at(0, 7, h + 0.5), Color = wall })
	Build.Part(home, { Name = "WallFront", Size = Vector3.new(full, 14, 1), CFrame = at(0, 7, -h - 0.5), Color = wall })
	Build.Part(home, { Name = "WallLeft", Size = Vector3.new(1, 14, full), CFrame = at(-h - 0.5, 7, 0), Color = wall })
	Build.Part(home, { Name = "WallRight", Size = Vector3.new(1, 14, full), CFrame = at(h + 0.5, 7, 0), Color = wall })
	-- 窓（外の景色の代わりに明るい空色の板）
	for _, x in { -(h - 0.1), h - 0.1 } do
		Build.Part(home, { Name = "Window", Size = Vector3.new(0.2, 5, 9), CFrame = at(x, 8, 0), Color = Color3.fromRGB(170, 220, 255), Material = Enum.Material.Neon, CanCollide = false })
	end
	-- 天井の照明（広いので2つ）
	for _, z in { -8, 10 } do
		local lamp = Build.Part(home, { Name = "Lamp", Size = Vector3.new(6, 0.4, 6), CFrame = at(0, 13.8, z), Color = Color3.fromRGB(255, 245, 215), Material = Enum.Material.Neon, CanCollide = false })
		local light = Instance.new("PointLight")
		light.Range = 36
		light.Brightness = 1.4
		light.Color = Color3.fromRGB(255, 240, 210)
		light.Parent = lamp
	end

	-- 出口のドア
	local door = Build.Part(home, { Name = "ExitDoor", Size = Vector3.new(5, 8, 0.4), CFrame = at(-10, 4, -h + 0.2), Color = accent, Material = Enum.Material.Wood })
	Build.Sign(door, "お店へ", Enum.NormalId.Back)
	local exitPrompt = Instance.new("ProximityPrompt")
	exitPrompt.Name = "HomeExitPrompt"
	exitPrompt.ActionText = "お店にもどる"
	exitPrompt.ObjectText = "ドア"
	exitPrompt.HoldDuration = 0
	exitPrompt.MaxActivationDistance = 9
	exitPrompt.RequiresLineOfSight = false
	exitPrompt.Parent = door

	-- いいねの看板（訪れた人が押せる）
	local likeBoard = Build.Part(home, { Name = "LikeBoard", Size = Vector3.new(5, 3, 0.4), CFrame = at(0, 5, -h + 0.2), Color = Color3.fromRGB(240, 120, 150), Material = Enum.Material.SmoothPlastic })
	Build.Sign(likeBoard, "いいね ♥ 0", Enum.NormalId.Back)
	local likePrompt = Instance.new("ProximityPrompt")
	likePrompt.Name = "HomeLikePrompt"
	likePrompt.ActionText = "いいね！"
	likePrompt.ObjectText = "この部屋"
	likePrompt.HoldDuration = 0
	likePrompt.MaxActivationDistance = 9
	likePrompt.RequiresLineOfSight = false
	likePrompt.Parent = likeBoard

	-- 模様替えの看板
	local board = Build.Part(home, { Name = "DecorBoard", Size = Vector3.new(6, 3, 0.4), CFrame = at(10, 4, -h + 0.2), Color = Color3.fromRGB(120, 80, 55), Material = Enum.Material.Wood })
	Build.Sign(board, "模様替え", Enum.NormalId.Back)
	local decorPrompt = Instance.new("ProximityPrompt")
	decorPrompt.Name = "HomeDecorPrompt"
	decorPrompt.ActionText = "アイテムを飾る"
	decorPrompt.ObjectText = "模様替え"
	decorPrompt.HoldDuration = 0
	decorPrompt.MaxActivationDistance = 9
	decorPrompt.RequiresLineOfSight = false
	decorPrompt.Parent = board

	-- マス目の目印（うっすら）
	local minCell, maxCell = PlotService.HomeGridRange(true)
	for x = minCell, maxCell do
		for z = minCell, maxCell do
			local extra = x < 1 or z < 1 or x > PlotService.HomeGridSize or z > PlotService.HomeGridSize
			Build.Part(home, {
				Name = if extra then "CellExtra" else "Cell", -- CellExtra は広げるまで見えない
				Size = Vector3.new(PlotService.HomeCellSize - 0.4, 0.05, PlotService.HomeCellSize - 0.4),
				CFrame = origin * PlotService.HomeCellOffset(x, z) * CFrame.new(0, 0.12, 0),
				Color = Color3.new(1, 1, 1),
				Transparency = if extra then 1 else 0.75,
				CanCollide = false,
			})
		end
	end
	home.Parent = model
end

local function buildPlot(index: number, origin: CFrame, parent: Instance): Plot
	local model = Instance.new("Model")
	model.Name = "Plot" .. index
	local function at(x: number, y: number, z: number): CFrame
		return origin * CFrame.new(x, y, z)
	end

	-- 地面と歩道
	Build.Part(model, { Name = "Ground", Size = Vector3.new(44, 0.5, 44), CFrame = at(0, 0.25, 4), Color = Color3.fromRGB(110, 175, 90), Material = Enum.Material.Grass })
	Build.Part(model, { Name = "Sidewalk", Size = Vector3.new(30, 0.6, 11.5), CFrame = at(0, 0.3, -10.75), Color = Color3.fromRGB(205, 205, 200), Material = Enum.Material.Concrete })

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

	-- 店の前の立て看板（キャッチコピー）
	local standBoard = Build.Part(model, { Name = "SloganBoard", Size = Vector3.new(5, 2.6, 0.3), CFrame = at(-9, 2.6, -7.5), Color = Color3.fromRGB(45, 55, 50), Material = Enum.Material.Slate })
	for _, x in { -2, 2 } do
		Build.Part(model, { Name = "SloganLeg", Size = Vector3.new(0.3, 2.6, 0.3), CFrame = at(-9 + x, 1.3, -7.5), Color = TRIM, Material = Enum.Material.Wood })
	end
	local sloganLabel = Build.Sign(standBoard, "", Enum.NormalId.Front, Color3.fromRGB(250, 250, 240))

	-- 陳列台
	for i, offset in PlotService.ShelfOffsets do
		local shelfTable = Build.Part(model, { Name = "ShelfTable" .. i, Size = Vector3.new(4, 3, 4), CFrame = origin * offset * CFrame.new(0, -1.5, 0), Color = TRIM, Material = Enum.Material.Wood })
		if PlotService.IsOutdoorShelf(i) then
			-- 店頭の台は、増やすまで見えない（ShopService が表示を切り替える）
			shelfTable.Transparency = 1
			shelfTable.CanCollide = false
			shelfTable:SetAttribute("Outdoor", true)
		end
	end
	-- レジカウンター
	Build.Part(model, { Name = "Counter", Size = Vector3.new(8, 3.5, 2), CFrame = at(8, 2.65, 13.5), Color = TRIM, Material = Enum.Material.Wood })
	Build.Part(model, { Name = "CounterTop", Size = Vector3.new(8.4, 0.3, 2.4), CFrame = at(8, 4.55, 13.5), Color = Color3.fromRGB(240, 240, 240), Material = Enum.Material.Marble })

	-- 工房（作業台）
	local bench = Build.Part(model, { Name = "Workbench", Size = Vector3.new(7, 3, 3.5), CFrame = origin * PlotService.WorkbenchOffset * CFrame.new(0, 1.5, 0), Color = Color3.fromRGB(150, 105, 70), Material = Enum.Material.WoodPlanks })
	Build.Part(model, { Name = "BenchTool", Size = Vector3.new(1.2, 1.2, 1.2), CFrame = origin * PlotService.WorkbenchOffset * CFrame.new(-2, 3.6, 0), Color = Color3.fromRGB(90, 170, 240), Material = Enum.Material.SmoothPlastic })
	Build.Part(model, { Name = "BenchTool", Size = Vector3.new(1, 1, 1), CFrame = origin * PlotService.WorkbenchOffset * CFrame.new(1.5, 3.5, 0.5), Color = Color3.fromRGB(240, 120, 80), Material = Enum.Material.SmoothPlastic, Shape = Enum.PartType.Ball })
	local benchSign = Build.Part(model, { Name = "BenchSign", Size = Vector3.new(6, 1.6, 0.3), CFrame = origin * PlotService.WorkbenchOffset * CFrame.new(0, 6, 1.6), Color = Color3.fromRGB(90, 170, 240) })
	Build.Sign(benchSign, "工房", Enum.NormalId.Front)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "WorkbenchPrompt"
	prompt.ActionText = "アイテムを作る"
	prompt.ObjectText = "工房"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = bench

	-- 自宅へのドア（左の壁）
	local homeDoor = Build.Part(model, { Name = "HomeDoor", Size = Vector3.new(0.3, 7, 4), CFrame = origin * PlotService.HomeDoorOffset, Color = awningColor, Material = Enum.Material.Wood })
	Build.Sign(homeDoor, "自宅", Enum.NormalId.Right)
	local homePrompt = Instance.new("ProximityPrompt")
	homePrompt.Name = "HomeEnterPrompt"
	homePrompt.ActionText = "自宅に入る"
	homePrompt.ObjectText = "ドア"
	homePrompt.HoldDuration = 0
	homePrompt.MaxActivationDistance = 9
	homePrompt.RequiresLineOfSight = false
	homePrompt.Parent = homeDoor
	buildHome(model, origin, awningColor)

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
		sloganLabel = sloganLabel,
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
	noticeEvent:FireClient(player, "このサーバーは満員でお店を持てません。別のサーバーに入り直してください")
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
	plot.sloganLabel.Text = ""
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
