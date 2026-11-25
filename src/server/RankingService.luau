--!strict
-- 広場の「人気のお店」ランキング掲示板（このサーバーにいる人の、売った数の多い順）

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local DataService = require(script.Parent:WaitForChild("DataService"))
local Build = require(script.Parent:WaitForChild("Build"))
local WorldService = require(script.Parent:WaitForChild("WorldService"))

local RankingService = {}

RankingService.Shown = 6

-- 全サーバーのランキング（OrderedDataStore）。掲示板の裏面に表示する。失敗してもゲームは止めない
RankingService.GlobalInterval = 300 -- 秒（DataStore の回数制限に配慮して5分ごと）
RankingService.GlobalShown = 10

local function startGlobal(board: BasePart)
	local ok, store = pcall(function()
		return DataStoreService:GetOrderedDataStore("SoldRanking_v1")
	end)
	if not ok then
		warn("[RankingService] 全サーバーランキングを使えません:", store)
		return
	end
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.LightInfluence = 0
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0, 2)
	layout.Parent = gui
	local function line(order: number, text: string, color: Color3, height: number): TextLabel
		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(0.92, 0, 0, height)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.TextColor3 = color
		label.Text = text
		label.LayoutOrder = order
		label.Parent = gui
		return label
	end
	line(0, "全サーバー 売った数ランキング", Color3.fromRGB(255, 220, 90), 40)
	local rows = {}
	for i = 1, RankingService.GlobalShown do
		rows[i] = line(i, "", Color3.new(1, 1, 1), 23)
	end
	rows[1].Text = "集計中…"
	gui.Parent = board

	local names: { [number]: string } = {}
	local function nameOf(userId: number): string
		if names[userId] then
			return names[userId]
		end
		local okName, name = pcall(function()
			return Players:GetNameFromUserIdAsync(userId)
		end)
		if okName and type(name) == "string" then
			names[userId] = name -- 失敗したときは覚えず、次回また調べる
			return name
		end
		return "？"
	end

	-- 記録を書き込む（変わっていなければ書かない）。退出時にも呼ぶので、セーブデータが先に消えていたら leaderstats から読む
	local lastWritten: { [number]: number } = {}
	local writing: { [number]: boolean } = {}
	local function writeScore(player: Player)
		if writing[player.UserId] then
			return -- 同じ人の書き込みが進行中なら重ねない
		end
		local profile = DataService.Get(player)
		local sold = profile and profile.stats.sold
		if not sold then
			local leaderstats = player:FindFirstChild("leaderstats")
			local value = leaderstats and leaderstats:FindFirstChild("売った数")
			sold = if value and value:IsA("IntValue") then value.Value else nil
		end
		if not sold or sold <= 0 then
			return
		end
		sold = math.floor(sold)
		if lastWritten[player.UserId] == sold then
			return
		end
		writing[player.UserId] = true
		local okWrite = pcall(function()
			(store :: OrderedDataStore):SetAsync(tostring(player.UserId), sold)
		end)
		writing[player.UserId] = nil
		if okWrite then
			lastWritten[player.UserId] = sold
		end
	end
	Players.PlayerRemoving:Connect(function(player)
		writeScore(player)
		lastWritten[player.UserId] = nil
	end)
	game:BindToClose(function()
		local pending = 0
		for _, player in Players:GetPlayers() do
			pending += 1
			task.spawn(function()
				writeScore(player)
				pending -= 1
			end)
		end
		local started = os.clock()
		while pending > 0 and os.clock() - started < 20 do
			task.wait(0.1)
		end
	end)

	task.spawn(function()
		while true do
			-- このサーバーにいる人の記録を書き込む
			for _, player in Players:GetPlayers() do
				writeScore(player)
			end
			-- 上位を読み込む
			local okRead, page = pcall(function()
				return (store :: OrderedDataStore):GetSortedAsync(false, RankingService.GlobalShown):GetCurrentPage()
			end)
			if okRead and type(page) == "table" then
				for i, row in rows do
					local entry = page[i]
					local userId = entry and tonumber(entry.key)
					row.Text = if entry and userId then ("%d位　%s　%d個"):format(i, nameOf(userId), entry.value) else ""
				end
				if #page == 0 then
					rows[1].Text = "まだ記録がありません"
				end
			end
			task.wait(RankingService.GlobalInterval)
		end
	end)
end

function RankingService.Start()
	local board = Build.Part(workspace:WaitForChild("Plaza"), {
		Name = "RankingBoard",
		Size = Vector3.new(14, 10, 0.6),
		-- 広場の外周（店への道を避けた場所）に、噴水の方を向けて立てる
		CFrame = CFrame.lookAt(WorldService.SpotPosition(WorldService.RankingSpot, 22) + Vector3.new(0, 7, 0), Vector3.new(0, 7, 0)),
		Color = Color3.fromRGB(120, 80, 55),
		Material = Enum.Material.Wood,
	})
	for _, x in { -6, 6 } do
		Build.Part(workspace.Plaza, {
			Name = "BoardLeg",
			Size = Vector3.new(0.6, 3, 0.6),
			CFrame = board.CFrame * CFrame.new(x, -6.5, 0),
			Color = Color3.fromRGB(90, 60, 40),
			Material = Enum.Material.Wood,
		})
	end
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.LightInfluence = 0
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0, 4)
	layout.Parent = gui
	local function line(order: number, text: string, color: Color3, height: number): TextLabel
		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(0.92, 0, 0, height)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.TextColor3 = color
		label.Text = text
		label.LayoutOrder = order
		label.Parent = gui
		return label
	end
	line(0, "人気のお店ランキング", Color3.fromRGB(255, 220, 90), 56)
	local rows = {}
	for i = 1, RankingService.Shown do
		rows[i] = line(i, "", Color3.new(1, 1, 1), 36)
	end
	gui.Parent = board

	task.spawn(function()
		while true do
			local entries = {}
			for _, player in Players:GetPlayers() do
				local profile = DataService.Get(player)
				if profile then
					table.insert(entries, { name = player.DisplayName, sold = profile.stats.sold })
				end
			end
			table.sort(entries, function(a, b)
				return a.sold > b.sold
			end)
			for i, row in rows do
				local entry = entries[i]
				row.Text = if entry then ("%d位　%s のお店　%d個"):format(i, entry.name, entry.sold) else ""
			end
			if #entries == 0 then
				rows[1].Text = "まだだれもいません"
			end
			task.wait(10)
		end
	end)

	startGlobal(board)
end

return RankingService
