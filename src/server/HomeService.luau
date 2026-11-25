--!strict
-- 自宅：店と自宅の行き来、作ったアイテムをマス目に飾る

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ItemBuilder = require(Shared:WaitForChild("ItemBuilder"))
local Net = require(Shared:WaitForChild("Net"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local PlotService = require(script.Parent:WaitForChild("PlotService"))
local ShopService = require(script.Parent:WaitForChild("ShopService"))

local HomeService = {}

local evictVisitors: (plot: any, owner: Player?) -> ()

local lastRequest: { [Player]: number } = {}
HomeService.MaxLikers = 200 -- いいねした人の記録の上限（同じ人は1回まで）


-- 置き場所のキーから、区画ローカルの置く位置を返す（床のマス "x_z" か、壁かけ "w1"〜）
local function placement(key: any, expanded: boolean?): CFrame?
	if type(key) ~= "string" then
		return nil
	end
	local w = tonumber(string.match(key, "^w(%d+)$"))
	if w then
		if w >= 1 and w <= PlotService.HomeWallSlots and key == "w" .. w then
			return PlotService.HomeWallOffset(w)
		end
		return nil
	end
	local xs, zs = string.match(key, "^(%d+)_(%d+)$")
	local x, z = tonumber(xs), tonumber(zs)
	local minCell, maxCell = PlotService.HomeGridRange(expanded == true)
	if not x or not z or x < minCell or x > maxCell or z < minCell or z > maxCell or key ~= x .. "_" .. z then
		return nil -- "01_02" のような別表記で同じマスに重ねて置けないようにする
	end
	return PlotService.HomeCellOffset(x, z)
end


local function decorFolder(plot: PlotService.Plot): Folder
	local home = plot.model:FindFirstChild("Home") :: Model
	local folder = home:FindFirstChild("Decor")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Decor"
		folder.Parent = home
	end
	return folder :: Folder
end

-- 広げた分のマス目の目印を見せる／隠す
local function setExtraCells(plot: PlotService.Plot, visible: boolean)
	local home = plot.model:FindFirstChild("Home")
	if not home then
		return
	end
	for _, part in home:GetChildren() do
		if part.Name == "CellExtra" and part:IsA("BasePart") then
			part.Transparency = if visible then 0.75 else 1
		end
	end
end

local function setLikes(plot: PlotService.Plot, likes: number)
	local home = plot.model:FindFirstChild("Home")
	local board = home and home:FindFirstChild("LikeBoard")
	local gui = board and board:FindFirstChildOfClass("SurfaceGui")
	local label = gui and gui:FindFirstChild("Text")
	if label and label:IsA("TextLabel") then
		label.Text = ("いいね ♥ %d"):format(likes)
	end
end

function HomeService.Render(player: Player)
	local plot = PlotService.Get(player)
	local profile = DataService.Get(player)
	if not plot or not profile then
		return
	end
	local folder = decorFolder(plot)
	folder:ClearAllChildren()
	plot.model:SetAttribute("HomePublic", profile.homePublic) -- クライアントのドアの表示に使う
	setExtraCells(plot, profile.homeExpanded)
	setLikes(plot, profile.homeLikes)
	for key, placed in profile.home do
		local spot = placement(key, profile.homeExpanded)
		local design = profile.designs[placed.designId]
		if spot and design then
			local isWall = string.sub(key, 1, 1) == "w"
			local item = ItemBuilder.BuildFitted(design, if isWall then 2.5 else PlotService.HomeCellSize - 0.5)
			item.Name = key
			item:PivotTo(plot.origin * spot * CFrame.Angles(0, math.rad((placed.rot or 0) * 90), 0))
			item.Parent = folder
		end
	end
end

local function clear(plot: PlotService.Plot)
	plot.model:SetAttribute("HomePublic", nil)
	setLikes(plot, 0)
	setExtraCells(plot, false)
	local home = plot.model:FindFirstChild("Home")
	local folder = home and home:FindFirstChild("Decor")
	if folder then
		folder:ClearAllChildren()
	end
end

-- マス目に置く / 回す / 片付ける
-- action: "place"（designId を置く。在庫を1つ使う）, "rotate", "remove"（在庫に戻す）
local function setCell(player: Player, key: any, action: any, designId: any): (boolean, string)
	local now = os.clock()
	if lastRequest[player] and now - lastRequest[player] < 0.2 then
		return false, "少し待ってからどうぞ"
	end
	lastRequest[player] = now
	local profile = DataService.Get(player)
	if not profile or not placement(key, profile.homeExpanded) then
		return false, "その場所には置けません"
	end
	local cell = key :: string
	local current = profile.home[cell]
	if action == "place" then
		if type(designId) ~= "string" or not profile.designs[designId] then
			return false, "デザインが見つかりません"
		end
		if current and current.designId == designId then
			return false, "もう置いてあります"
		end
		if (profile.stock[designId] or 0) <= 0 then
			return false, "在庫がありません。工房で作りましょう"
		end
		-- すでに何か置いてあれば在庫に戻してから置き換える
		if current and profile.designs[current.designId] then
			profile.stock[current.designId] = (profile.stock[current.designId] or 0) + 1
		end
		profile.stock[designId] = (profile.stock[designId] or 0) - 1
		profile.home[cell] = { designId = designId, rot = 0 }
	elseif action == "rotate" then
		if not current then
			return false, "何も置いていません"
		end
		current.rot = ((current.rot or 0) + 1) % 4
	elseif action == "remove" then
		if not current then
			return false, "何も置いていません"
		end
		if profile.designs[current.designId] then
			profile.stock[current.designId] = (profile.stock[current.designId] or 0) + 1
		end
		profile.home[cell] = nil
	else
		return false, "操作が正しくありません"
	end
	DataService.Changed(player)
	HomeService.Render(player)
	-- 在庫が変わったので店の棚の表示も更新する
	ShopService.Render(player)
	return true, if action == "place" then "飾りました！" elseif action == "rotate" then "回しました" else "片付けました"
end

local function teleport(player: Player, cf: CFrame)
	local character = player.Character
	if character and character:FindFirstChild("HumanoidRootPart") then
		-- StreamingEnabled のとき、移動先の床が届く前に落ちないよう先に読み込ませる
		pcall(function()
			player:RequestStreamAroundAsync(cf.Position, 5)
		end)
		if character.Parent then
			character:PivotTo(cf)
		end
	end
end

-- 部屋の中にいる、店主以外の人を店へ帰す（店主が抜けたとき・非公開にしたとき）
evictVisitors = function(plot: PlotService.Plot, owner: Player?)
	local room = plot.origin * PlotService.HomeOffset
	for _, other in game:GetService("Players"):GetPlayers() do
		local root = other ~= owner and other.Character and other.Character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			local p = room:PointToObjectSpace(root.Position)
			local half = PlotService.HomeRoomHalf
			if math.abs(p.X) < half and math.abs(p.Z) < half and p.Y > -1 and p.Y < 15 then
				local home = PlotService.Get(other) or plot
				task.spawn(teleport, other, home.origin * PlotService.SpawnOffset)
				Net.Event("Notice"):FireClient(other, "この自宅は閉じられました")
			end
		end
	end
end

-- その区画の自宅の部屋の中にいるか
local function inRoom(plot: PlotService.Plot, player: Player): boolean
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return false
	end
	local p = (plot.origin * PlotService.HomeOffset):PointToObjectSpace(root.Position)
	local half = PlotService.HomeRoomHalf
	return math.abs(p.X) < half and math.abs(p.Z) < half and p.Y > -1 and p.Y < 15
end

-- おうちパーティー：店主が自宅にいて訪問者もいると、1分ごとに店主と訪問者にコイン
HomeService.PartyInterval = 60
HomeService.PartyCoinsPerGuest = 5 -- 店主がもらう（訪問者1人あたり、最大5人分）
HomeService.PartyGuestCoins = 3 -- 訪問者がもらう
HomeService.PartyDailyLimit = 30 -- 1人が1日に受け取れる回数（サブアカウントでの放置稼ぎ対策）

-- 今日まだ受け取れるなら回数を1つ使って true（2つ目は今日の最後の1回だったか）
local function takePartyTurn(player: Player): (boolean, boolean)
	local profile = DataService.Get(player)
	if not profile then
		return false, false
	end
	local day = math.floor((os.time() + 9 * 3600) / 86400) -- 日本時間の通し日数
	if profile.partyDay ~= day then
		profile.partyDay = day
		profile.partyCount = 0
	end
	if profile.partyCount >= HomeService.PartyDailyLimit then
		return false, false
	end
	profile.partyCount += 1
	return true, profile.partyCount >= HomeService.PartyDailyLimit
end

local LAST_NOTE = "（今日のパーティーボーナスはここまで。また明日！）"

local function partyTick()
	local players = game:GetService("Players"):GetPlayers()
	for _, plot in PlotService.All() do
		local owner = plot.owner
		if owner and inRoom(plot, owner) then
			local guests = {}
			for _, other in players do
				if other ~= owner and inRoom(plot, other) then
					table.insert(guests, other)
				end
			end
			if #guests > 0 then
				local ok, last = takePartyTurn(owner)
				if ok then
					local reward = math.min(#guests, 5) * HomeService.PartyCoinsPerGuest
					DataService.AddCoins(owner, reward)
					local text = ("おうちパーティー！ お客さん%d人で +%d コイン"):format(#guests, reward)
					Net.Event("Notice"):FireClient(owner, if last then text .. LAST_NOTE else text)
				end
				for _, guest in guests do
					local okGuest, lastGuest = takePartyTurn(guest)
					if okGuest then
						DataService.AddCoins(guest, HomeService.PartyGuestCoins)
						local text = ("おうちパーティー！ +%d コイン"):format(HomeService.PartyGuestCoins)
						Net.Event("Notice"):FireClient(guest, if lastGuest then text .. LAST_NOTE else text)
					end
				end
			end
		end
	end
end

local function runParties()
	while true do
		task.wait(HomeService.PartyInterval)
		-- 1回のエラーでパーティーが止まったままにならないよう、毎回 pcall で包む
		local ok, err = pcall(partyTick)
		if not ok then
			warn("[HomeService] パーティーのエラー:", err)
		end
	end
end

function HomeService.Start()
	task.spawn(runParties)
	Net.Function("SetHomeCell").OnServerInvoke = function(player, key, action, designId)
		local ok, a, b = pcall(setCell, player, key, action, designId)
		if not ok then
			warn("[HomeService] エラー:", a)
			return false, "エラーが起きました"
		end
		return a, b
	end

	-- ドアのプロンプト（店主だけが自宅に入れる。訪問は今後の機能）
	local noticeEvent = Net.Event("Notice")
	for _, plot in PlotService.All() do
		for _, prompt in plot.model:GetDescendants() do
			if prompt:IsA("ProximityPrompt") and prompt.Name == "HomeEnterPrompt" then
				prompt.Triggered:Connect(function(player)
					local ownerProfile = plot.owner and DataService.Get(plot.owner)
					if plot.owner == player or (ownerProfile and ownerProfile.homePublic) then
						teleport(player, plot.origin * PlotService.HomeSpawnOffset)
					else
						noticeEvent:FireClient(player, "この自宅は公開されていません")
					end
				end)
			elseif prompt:IsA("ProximityPrompt") and prompt.Name == "HomeLikePrompt" then
				prompt.Triggered:Connect(function(player)
					local owner = plot.owner
					local ownerProfile = owner and DataService.Get(owner)
					if not owner or not ownerProfile then
						return
					end
					if owner == player then
						noticeEvent:FireClient(player, "自分の部屋にはいいねできません")
						return
					end
					-- 同じ人からのいいねは、このサーバーにいる間は1回まで
					-- 同じ人からのいいねは1回まで（セーブデータに記録する）
					local likers = ownerProfile.homeLikedBy
					local likerKey = tostring(player.UserId)
					if likers[likerKey] then
						noticeEvent:FireClient(player, "もういいねしました")
						return
					end
					local likerCount = 0
					for _ in likers do
						likerCount += 1
					end
					if likerCount >= HomeService.MaxLikers then
						-- 記録がいっぱいなら古いものを1つ消す（順番は問わない）
						local oldest = next(likers)
						if oldest then
							likers[oldest] = nil
						end
					end
					likers[likerKey] = true
					ownerProfile.homeLikes += 1
					setLikes(plot, ownerProfile.homeLikes)
					DataService.Changed(owner)
					noticeEvent:FireClient(player, "いいねしました！")
					noticeEvent:FireClient(owner, ("%s さんが自宅にいいねしてくれた！"):format(player.DisplayName))
				end)
			elseif prompt:IsA("ProximityPrompt") and prompt.Name == "HomeExitPrompt" then
				prompt.Triggered:Connect(function(player)
					local own = PlotService.Get(player)
					if own then
						teleport(player, own.origin * PlotService.SpawnOffset)
					else
						teleport(player, plot.origin * PlotService.SpawnOffset)
					end
				end)
			end
		end
	end

	PlotService.Assigned:Connect(function(player)
		HomeService.Render(player)
	end)
	DataService.OnLoaded(function(player)
		HomeService.Render(player)
	end)
	PlotService.Released:Connect(function(_, plot)
		evictVisitors(plot, nil)
		clear(plot)
	end)
	Net.Function("ExpandHome").OnServerInvoke = function(player)
		local profile = DataService.Get(player)
		if not profile then
			return false, "データを読み込み中です"
		end
		if profile.homeExpanded then
			return false, "もう広げています"
		end
		if not DataService.TrySpend(player, PlotService.HomeExpandPrice) then
			return false, ("コインが足りません（%d コイン必要）"):format(PlotService.HomeExpandPrice)
		end
		profile.homeExpanded = true
		DataService.Changed(player)
		HomeService.Render(player)
		return true, "自宅が 8×8 に広くなりました！"
	end
	Net.Function("SetHomePublic").OnServerInvoke = function(player, value)
		local now = os.clock()
		if lastRequest[player] and now - lastRequest[player] < 0.5 then
			return false, "少し待ってからどうぞ"
		end
		lastRequest[player] = now
		local profile = DataService.Get(player)
		if not profile or type(value) ~= "boolean" then
			return false, "設定できませんでした"
		end
		profile.homePublic = value
		DataService.Changed(player)
		local plot = PlotService.Get(player)
		if plot then
			plot.model:SetAttribute("HomePublic", value)
			if not value then
				evictVisitors(plot, player)
			end
		end
		return true, if value then "自宅を公開しました" else "自宅を非公開にしました"
	end
	game:GetService("Players").PlayerRemoving:Connect(function(player)
		lastRequest[player] = nil
	end)
end

return HomeService
