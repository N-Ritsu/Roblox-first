--!strict
-- 製作（デザインから在庫を作る）と、店の棚への陳列・表示

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ItemBuilder = require(Shared:WaitForChild("ItemBuilder"))
local ShopUpgrades = require(Shared:WaitForChild("ShopUpgrades"))
local Net = require(Shared:WaitForChild("Net"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local PlotService = require(script.Parent:WaitForChild("PlotService"))
local Build = require(script.Parent:WaitForChild("Build"))

local ShopService = {}

ShopService.MaxStock = 99
ShopService.MaxPrice = 9999
ShopService.SlotCount = #PlotService.ShelfOffsets

local saleEvent = Net.Event("Sale")
local lastRequest: { [Player]: number } = {}
local function tooFast(player: Player): boolean
	local now = os.clock()
	if lastRequest[player] and now - lastRequest[player] < 0.25 then
		return true
	end
	lastRequest[player] = now
	return false
end

local function displayFolder(plot: PlotService.Plot): Folder
	local folder = plot.model:FindFirstChild("Displays")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Displays"
		folder.Parent = plot.model
	end
	return folder :: Folder
end

-- 棚のプロンプトに商品名と値段を出す（訪れた人が何を売っているか分かるように）
-- 値段（Price 属性）は購入時に「見た値段」として送り返してもらい、途中で値上げされていないか確かめる
local function setPromptText(plot: PlotService.Plot, slot: number, text: string?, price: number?)
	local tablePart = plot.model:FindFirstChild("ShelfTable" .. slot)
	local prompt = tablePart and tablePart:FindFirstChild("ShelfPrompt")
	if prompt and prompt:IsA("ProximityPrompt") then
		prompt.ObjectText = text or ("陳列台 " .. slot)
		prompt:SetAttribute("Price", price)
	end
end

-- 使える陳列台の数と内装を区画に反映する
local function applyLayout(plot: PlotService.Plot, shelfSlots: number, wallId: string, floorId: string)
	for slot = 1, ShopService.SlotCount do
		local tablePart = plot.model:FindFirstChild("ShelfTable" .. slot) :: BasePart?
		if tablePart then
			local usable = slot <= shelfSlots
			if tablePart:GetAttribute("Outdoor") then
				tablePart.Transparency = if usable then 0 else 1
				tablePart.CanCollide = usable
			end
			local prompt = tablePart:FindFirstChild("ShelfPrompt")
			if prompt then
				prompt:SetAttribute("Locked", not usable) -- クライアントの Prompts が見て表示を切り替える
			end
		end
	end
	local wall = ShopUpgrades.WallById[wallId] or ShopUpgrades.Walls[1]
	for _, name in PlotService.WallParts do
		local part = plot.model:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			part.Color = wall.color
		end
	end
	local floor = ShopUpgrades.FloorById[floorId] or ShopUpgrades.Floors[1]
	local floorPart = plot.model:FindFirstChild("Floor")
	if floorPart and floorPart:IsA("BasePart") then
		floorPart.Color = floor.color
		floorPart.Material = floor.material
	end
end

local function clearDisplays(plot: PlotService.Plot)
	displayFolder(plot):ClearAllChildren()
	for slot = 1, ShopService.SlotCount do
		setPromptText(plot, slot, nil)
	end
	applyLayout(plot, ShopUpgrades.BaseShelves, ShopUpgrades.Walls[1].id, ShopUpgrades.Floors[1].id)
end

-- 店主の棚の表示を作り直す
function ShopService.Render(player: Player)
	local plot = PlotService.Get(player)
	local profile = DataService.Get(player)
	if not plot or not profile then
		return
	end
	local folder = displayFolder(plot)
	folder:ClearAllChildren()
	applyLayout(plot, profile.shelfSlots, profile.interior.wall, profile.interior.floor)
	for slot = 1, math.min(ShopService.SlotCount, profile.shelfSlots) do
		local shelf = profile.shelves[tostring(slot)]
		local design = shelf and profile.designs[shelf.designId]
		if shelf and design then
			local left = profile.stock[shelf.designId] or 0
			setPromptText(plot, slot, if left > 0 then ("%s・%d コイン"):format(design.name, shelf.price) else design.name .. "・売り切れ", shelf.price)
		else
			setPromptText(plot, slot, nil)
		end
		if shelf and design then
			local top = plot.origin * PlotService.ShelfOffsets[slot]
			local display = Instance.new("Model")
			display.Name = "Display" .. slot
			display:SetAttribute("Slot", slot)

			local item = ItemBuilder.BuildFitted(design, 3.4)
			item:PivotTo(top)
			item.Parent = display

			local stock = profile.stock[shelf.designId] or 0
			local tag = Build.Part(display, {
				Name = "Tag",
				Size = Vector3.new(0.2, 0.2, 0.2),
				CFrame = top * CFrame.new(0, 4.2, 0),
				Transparency = 1,
				CanCollide = false,
			})
			tag.CanQuery = false
			local billboard = Instance.new("BillboardGui")
			billboard.Size = UDim2.new(0, 150, 0, 54)
			billboard.MaxDistance = 45
			billboard.LightInfluence = 0
			local bg = Instance.new("Frame")
			bg.Size = UDim2.fromScale(1, 1)
			bg.BackgroundColor3 = if stock > 0 then Color3.fromRGB(255, 248, 235) else Color3.fromRGB(200, 200, 200)
			bg.BackgroundTransparency = 0.1
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0, 10)
			corner.Parent = bg
			local nameLabel = Instance.new("TextLabel")
			nameLabel.Size = UDim2.new(1, -8, 0.5, 0)
			nameLabel.Position = UDim2.new(0, 4, 0, 2)
			nameLabel.BackgroundTransparency = 1
			nameLabel.Font = Enum.Font.FredokaOne
			nameLabel.TextScaled = true
			nameLabel.TextColor3 = Color3.fromRGB(70, 50, 40)
			nameLabel.Text = design.name
			nameLabel.Parent = bg
			local priceLabel = nameLabel:Clone()
			priceLabel.Name = "Price"
			priceLabel.Position = UDim2.new(0, 4, 0.5, 0)
			priceLabel.Size = UDim2.new(1, -8, 0.45, 0)
			priceLabel.TextColor3 = if stock > 0 then Color3.fromRGB(210, 140, 20) else Color3.fromRGB(120, 120, 120)
			priceLabel.Text = if stock > 0 then ("%d コイン（残り%d）"):format(shelf.price, stock) else "売り切れ"
			priceLabel.Parent = bg
			bg.Parent = billboard
			billboard.Parent = tag

			display.Parent = folder
		end
	end
end

local function craft(player: Player, designId: any, count: any): (boolean, string)
	if tooFast(player) then
		return false, "少し待ってからどうぞ"
	end
	local profile = DataService.Get(player)
	if not profile or type(designId) ~= "string" or not profile.designs[designId] then
		return false, "デザインが見つかりません"
	end
	if type(count) ~= "number" or count ~= count then
		return false, "個数が正しくありません"
	end
	if profile.designs[designId].boughtFrom then
		return false, "買ったアイテムは作れません"
	end
	count = math.clamp(math.floor(count), 1, ShopService.MaxStock)
	local current = profile.stock[designId] or 0
	count = math.min(count, ShopService.MaxStock - current)
	if count <= 0 then
		return false, ("在庫は%d個までです"):format(ShopService.MaxStock)
	end
	local cost = ItemBuilder.CraftCost(profile.designs[designId]) * count
	if not DataService.TrySpend(player, cost) then
		return false, ("コインが足りません（%d コイン必要）"):format(cost)
	end
	profile.stock[designId] = current + count
	DataService.Changed(player)
	ShopService.Render(player)
	return true, ("%d個作りました（-%d コイン）"):format(count, cost)
end

local function setShelf(player: Player, slot: any, designId: any, price: any): (boolean, string)
	if tooFast(player) then
		return false, "少し待ってからどうぞ"
	end
	local profile = DataService.Get(player)
	if not profile or type(slot) ~= "number" or slot ~= slot then
		return false, "棚が正しくありません"
	end
	slot = math.floor(slot)
	if slot < 1 or slot > math.min(ShopService.SlotCount, profile.shelfSlots) then
		return false, "棚が正しくありません"
	end
	local key = tostring(slot)
	if designId == nil then
		profile.shelves[key] = nil
		DataService.Changed(player)
		ShopService.Render(player)
		return true, "棚を片付けました"
	end
	if type(designId) ~= "string" or not profile.designs[designId] then
		return false, "デザインが見つかりません"
	end
	if profile.designs[designId].boughtFrom then
		return false, "買ったアイテムは売れません（自宅に飾れます）"
	end
	if type(price) ~= "number" or price ~= price then
		return false, "値段が正しくありません"
	end
	price = math.clamp(math.floor(price), 1, ShopService.MaxPrice)
	profile.shelves[key] = { designId = designId, price = price }
	DataService.Changed(player)
	ShopService.Render(player)
	return true, "棚に並べました！"
end

-- 他のプレイヤーの店の棚から買う。買ったアイテムは自宅に飾れる（作り直し・転売はできない）
ShopService.MaxBought = 30
local function buy(buyer: Player, ownerUserId: any, slot: any, seenPrice: any): (boolean, string)
	if tooFast(buyer) then
		return false, "少し待ってからどうぞ"
	end
	if type(ownerUserId) ~= "number" or type(slot) ~= "number" or slot ~= slot then
		return false, "お店が見つかりません"
	end
	slot = math.floor(slot)
	if slot < 1 or slot > ShopService.SlotCount then
		return false, "お店が見つかりません"
	end
	local seller = Players:GetPlayerByUserId(ownerUserId)
	if not seller or seller == buyer then
		return false, if seller == buyer then "自分のお店では買えません" else "お店が見つかりません"
	end
	local sellerProfile = DataService.Get(seller)
	local buyerProfile = DataService.Get(buyer)
	if not sellerProfile or not buyerProfile then
		return false, "データを読み込み中です"
	end
	if slot > sellerProfile.shelfSlots then
		return false, "この棚には何もありません"
	end
	local shelf = sellerProfile.shelves[tostring(slot)]
	local design = shelf and sellerProfile.designs[shelf.designId]
	if not shelf or not design then
		return false, "この棚には何もありません"
	end
	local stock = sellerProfile.stock[shelf.designId] or 0
	if stock <= 0 then
		return false, "売り切れです"
	end
	if seenPrice ~= shelf.price then
		return false, ("値段が変わりました（今は %d コイン）"):format(shelf.price)
	end
	-- 店の棚の近くにいるときだけ買える
	local plot = PlotService.Get(seller)
	local tablePart = plot and plot.model:FindFirstChild("ShelfTable" .. slot)
	local character = buyer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not tablePart or not root or ((root :: BasePart).Position - (tablePart :: BasePart).Position).Magnitude > 16 then
		return false, "棚に近づいてから買ってください"
	end
	-- 同じ店の同じ商品は1つのアイテムとしてまとめる
	local sourceKey = seller.UserId .. ":" .. shelf.designId
	local targetId: string? = nil
	local boughtCount = 0
	for id, d in buyerProfile.designs do
		if d.boughtFrom then
			boughtCount += 1
			if d.sourceKey == sourceKey then
				targetId = id
			end
		end
	end
	if not targetId and boughtCount >= ShopService.MaxBought then
		return false, ("買ったアイテムは%d種類までです"):format(ShopService.MaxBought)
	end
	local price = shelf.price
	if not DataService.TrySpend(buyer, price) then
		return false, ("コインが足りません（%d コイン必要）"):format(price)
	end
	sellerProfile.stock[shelf.designId] = stock - 1
	sellerProfile.stats.sold += 1
	sellerProfile.stats.earned += price
	DataService.AddCoins(seller, price)

	if not targetId then
		targetId = "d" .. buyerProfile.nextDesignId
		buyerProfile.nextDesignId += 1
		buyerProfile.designs[targetId] = {
			name = design.name,
			parts = HttpService:JSONDecode(HttpService:JSONEncode(design.parts)),
			boughtFrom = seller.DisplayName,
			sourceKey = sourceKey,
		}
	end
	local id = targetId :: string
	buyerProfile.stock[id] = (buyerProfile.stock[id] or 0) + 1
	DataService.Changed(buyer)
	ShopService.Render(seller)
	saleEvent:FireClient(seller, design.name, price, buyer.DisplayName)
	return true, ("「%s」を買いました！ 自宅に飾れます"):format(design.name)
end

local function buyShelfSlot(player: Player): (boolean, string)
	local profile = DataService.Get(player)
	if not profile then
		return false, "データを読み込み中です"
	end
	local price = ShopUpgrades.NextShelfPrice(profile.shelfSlots)
	if not price or profile.shelfSlots >= ShopService.SlotCount then
		return false, "これ以上は増やせません"
	end
	if not DataService.TrySpend(player, price) then
		return false, ("コインが足りません（%d コイン必要）"):format(price)
	end
	profile.shelfSlots += 1
	DataService.Changed(player)
	ShopService.Render(player)
	return true, "店頭に陳列台を増やしました！"
end

local function setInterior(player: Player, kind: any, id: any): (boolean, string)
	local profile = DataService.Get(player)
	if not profile then
		return false, "データを読み込み中です"
	end
	local list = if kind == "wall" then ShopUpgrades.WallById elseif kind == "floor" then ShopUpgrades.FloorById else nil
	local entry = list and type(id) == "string" and (list :: any)[id]
	if not entry then
		return false, "見つかりません"
	end
	local ownedKey = kind .. ":" .. id
	if entry.price > 0 and not profile.ownedInterior[ownedKey] then
		if not DataService.TrySpend(player, entry.price) then
			return false, ("コインが足りません（%d コイン必要）"):format(entry.price)
		end
		profile.ownedInterior[ownedKey] = true
	end
	(profile.interior :: any)[kind] = id
	DataService.Changed(player)
	ShopService.Render(player)
	return true, ("「%s」にしました"):format(entry.name)
end

local function wrap(name: string, fn: (...any) -> (boolean, string))
	Net.Function(name).OnServerInvoke = function(player, ...)
		local ok, a, b = pcall(fn, player, ...)
		if not ok then
			warn(("[ShopService] %s エラー: %s"):format(name, tostring(a)))
			return false, "エラーが起きました"
		end
		return a, b
	end
end

function ShopService.Start()
	wrap("CraftItem", craft)
	wrap("SetShelf", setShelf)
	wrap("BuyFromShelf", buy)
	wrap("BuyShelfSlot", buyShelfSlot)
	wrap("SetInterior", setInterior)

	-- 棚にプロンプトをつける（店主だけが使える。判定はクライアント表示とサーバー処理の両方）
	for _, plot in PlotService.All() do
		for slot = 1, ShopService.SlotCount do
			local tablePart = plot.model:FindFirstChild("ShelfTable" .. slot)
			if tablePart then
				local prompt = Instance.new("ProximityPrompt")
				prompt.Name = "ShelfPrompt"
				prompt.ActionText = "棚に並べる"
				prompt.ObjectText = "陳列台 " .. slot
				prompt.HoldDuration = 0
				prompt.MaxActivationDistance = 9
				prompt.RequiresLineOfSight = false
				prompt:SetAttribute("Slot", slot)
				prompt:SetAttribute("Locked", PlotService.IsOutdoorShelf(slot))
				prompt.Parent = tablePart
			end
		end
	end

	-- 区画とデータの両方がそろったら表示する
	PlotService.Assigned:Connect(function(player)
		ShopService.Render(player)
	end)
	DataService.OnLoaded(function(player)
		ShopService.Render(player)
	end)
	PlotService.Released:Connect(function(_, plot)
		clearDisplays(plot)
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastRequest[player] = nil
	end)
end

return ShopService
