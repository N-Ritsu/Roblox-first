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

local lastRequest: { [Player]: number } = {}
local likedBy: { [Player]: { [number]: boolean } } = {}

local function cellKey(x: number, z: number): string
	return x .. "_" .. z
end

local function parseCell(key: any): (number?, number?)
	if type(key) ~= "string" then
		return nil, nil
	end
	local xs, zs = string.match(key, "^(%d+)_(%d+)$")
	local x, z = tonumber(xs), tonumber(zs)
	local n = PlotService.HomeGridSize
	if not x or not z or x < 1 or x > n or z < 1 or z > n then
		return nil, nil
	end
	return x, z
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
	setLikes(plot, profile.homeLikes)
	for key, placed in profile.home do
		local x, z = parseCell(key)
		local design = profile.designs[placed.designId]
		if x and z and design then
			local item = ItemBuilder.BuildFitted(design, PlotService.HomeCellSize - 0.5)
			item.Name = key
			item:PivotTo(plot.origin * PlotService.HomeCellOffset(x, z) * CFrame.Angles(0, math.rad((placed.rot or 0) * 90), 0))
			item.Parent = folder
		end
	end
end

local function clear(plot: PlotService.Plot)
	plot.model:SetAttribute("HomePublic", nil)
	setLikes(plot, 0)
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
	local x, z = parseCell(key)
	if not profile or not x or not z then
		return false, "その場所には置けません"
	end
	local cell = cellKey(x, z)
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

function HomeService.Start()
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
					likedBy[owner] = likedBy[owner] or {}
					if likedBy[owner][player.UserId] then
						noticeEvent:FireClient(player, "もういいねしました")
						return
					end
					likedBy[owner][player.UserId] = true
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
		clear(plot)
	end)
	Net.Function("SetHomePublic").OnServerInvoke = function(player, value)
		local profile = DataService.Get(player)
		if not profile or type(value) ~= "boolean" then
			return false, "設定できませんでした"
		end
		profile.homePublic = value
		DataService.Changed(player)
		HomeService.Render(player)
		return true, if value then "自宅を公開しました" else "自宅を非公開にしました"
	end
	game:GetService("Players").PlayerRemoving:Connect(function(player)
		lastRequest[player] = nil
		likedBy[player] = nil
	end)
end

return HomeService
