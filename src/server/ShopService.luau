--!strict
-- 製作（デザインから在庫を作る）と、店の棚への陳列・表示

local HttpService = game:GetService("HttpService")
local TextService = game:GetService("TextService")
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
local noticeEvent = Net.Event("Notice")
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
local function applyLayout(plot: PlotService.Plot, shelfSlots: number, wallId: string, floorId: string, awningId: string?, signId: string?)
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
	local awning = ShopUpgrades.AwningById[awningId or "Default"]
	local awningColor = (awning and awning.color) or plot.model:GetAttribute("DefaultAwning")
	if typeof(awningColor) == "Color3" then
		for _, part in plot.model:GetChildren() do
			if part.Name == "AwningColor" and part:IsA("BasePart") then
				part.Color = awningColor
			end
		end
	end
	local sign = ShopUpgrades.SignById[signId or "Default"] or ShopUpgrades.Signs[1]
	local signPart = plot.model:FindFirstChild("Sign")
	if signPart and signPart:IsA("BasePart") then
		signPart.Color = sign.color
		local gui = signPart:FindFirstChildOfClass("SurfaceGui")
		local label = gui and gui:FindFirstChild("Text")
		if label and label:IsA("TextLabel") then
			label.TextColor3 = ShopUpgrades.TextColorOn(sign.color)
		end
	end
end

local function clearDisplays(plot: PlotService.Plot)
	displayFolder(plot):ClearAllChildren()
	plot.model:SetAttribute("OnSale", nil)
	plot.model:SetAttribute("Stars", nil)
	for slot = 1, ShopService.SlotCount do
		setPromptText(plot, slot, nil)
	end
	applyLayout(plot, ShopUpgrades.BaseShelves, ShopUpgrades.Walls[1].id, ShopUpgrades.Floors[1].id)
end

-- デザインごとの売れた数を記録する
function ShopService.RecordSale(profile: any, designId: string, count: number)
	profile.designSales[designId] = (profile.designSales[designId] or 0) + count
end

-- 一番売れているデザイン（3個以上売れていれば）
local function bestSeller(profile: any): string?
	local bestId, bestCount = nil, 2
	for id, count in profile.designSales do
		if count > bestCount and profile.designs[id] then
			bestId, bestCount = id, count
		end
	end
	return bestId
end

-- お店の記録：最近のお客さんの反応（サーバーのメモリだけ。最新10件をクライアントへ送る）
ShopService.LogSize = 10
local logs: { [Player]: { string } } = {}
local logEvent = Net.Event("ShopLog")
function ShopService.Log(player: Player, text: string)
	local list = logs[player] or {}
	logs[player] = list
	local t = os.date("!*t", os.time() + 9 * 3600) :: any
	table.insert(list, 1, ("%02d:%02d %s"):format(t.hour, t.min, text))
	while #list > ShopService.LogSize do
		table.remove(list)
	end
	logEvent:FireClient(player, list)
end

-- 店の評判（0〜100）と星（1〜5）
function ShopService.Stars(player: Player): number
	local profile = DataService.Get(player)
	if not profile then
		return 1
	end
	return math.clamp(1 + math.floor(profile.reputation / 25), 1, 5)
end

local function starText(stars: number): string
	return string.rep("★", stars) .. string.rep("☆", 5 - stars)
end

local function updateSign(player: Player)
	local plot = PlotService.Get(player)
	if plot then
		plot.signLabel.Text = ("%s のお店 %s"):format(player.DisplayName, starText(ShopService.Stars(player)))
		plot.model:SetAttribute("Stars", ShopService.Stars(player)) -- お店めぐりの一覧で使う
		local profile = DataService.Get(player)
		plot.sloganLabel.Text = if profile then profile.slogan else ""
	end
end

function ShopService.AddReputation(player: Player, amount: number)
	local profile = DataService.Get(player)
	if not profile then
		return
	end
	local before = ShopService.Stars(player)
	profile.reputation = math.clamp(profile.reputation + amount, 0, 100)
	local after = ShopService.Stars(player)
	if after ~= before then
		updateSign(player)
		DataService.Changed(player)
		local text = if after > before then ("お店の評判が上がった！ %s"):format(starText(after)) else ("お店の評判が下がった… %s"):format(starText(after))
		noticeEvent:FireClient(player, text)
	end
end

-- 留守中の売上：前回から経った時間に応じて、陳列中の商品が少しずつ売れていたことにする
ShopService.OfflineSaleInterval = 600 -- 10分に1回、どれかの棚で売れる
ShopService.OfflineMaxSeconds = 8 * 3600 -- 8時間分まで
local offlineEvent = Net.Event("OfflineSales")

function ShopService.OfflineSales(player: Player, profile: any)
	local lastSeen = tonumber(profile.lastSeen) or 0
	if lastSeen <= 0 then
		return
	end
	local elapsed = math.clamp(os.time() - lastSeen, 0, ShopService.OfflineMaxSeconds)
	local chances = math.floor(elapsed / ShopService.OfflineSaleInterval)
	if chances <= 0 then
		return
	end
	local slots = {}
	for slot = 1, math.min(ShopService.SlotCount, profile.shelfSlots) do
		if profile.shelves[tostring(slot)] then
			table.insert(slots, slot)
		end
	end
	if #slots == 0 then
		return
	end
	local random = Random.new()
	local count, earned = 0, 0
	for i = 1, chances do
		local shelf = profile.shelves[tostring(slots[(i - 1) % #slots + 1])]
		local design = profile.designs[shelf.designId]
		local stock = profile.stock[shelf.designId] or 0
		if design and stock > 0 then
			-- 相場より高い商品は売れにくい（留守中はお客さんの好みは考えない）
			local value = ItemBuilder.Value(design)
			local chance = if shelf.price <= value then 0.8 elseif shelf.price <= value * 1.3 then 0.5 elseif shelf.price <= value * 1.6 then 0.2 else 0
			if random:NextNumber() < chance then
				profile.stock[shelf.designId] = stock - 1
				ShopService.RecordSale(profile, shelf.designId, 1)
				count += 1
				earned += shelf.price
			end
		end
	end
	if count == 0 then
		return
	end
	profile.stats.sold += count
	profile.stats.earned += earned
	DataService.AddToday(profile, count, earned, 0)
	DataService.AddCoins(player, earned)
	task.delay(5, function()
		if player.Parent then
			offlineEvent:FireClient(player, count, earned)
		end
	end)
end

ShopService.FeaturedSize = 6
ShopService.FeaturedOffset = CFrame.new(0, 14.5, 7) -- 屋根の上（看板の後ろ）。区画ローカル

-- 店主の棚の表示を作り直す
function ShopService.Render(player: Player)
	local plot = PlotService.Get(player)
	local profile = DataService.Get(player)
	if not plot or not profile then
		return
	end
	local folder = displayFolder(plot)
	folder:ClearAllChildren()
	-- お店めぐりの一覧用：在庫のある棚の数
	local onSale = 0
	for slot = 1, math.min(ShopService.SlotCount, profile.shelfSlots) do
		local shelf = profile.shelves[tostring(slot)]
		if shelf and profile.designs[shelf.designId] and (profile.stock[shelf.designId] or 0) > 0 then
			onSale += 1
		end
	end
	plot.model:SetAttribute("OnSale", onSale)
	applyLayout(plot, profile.shelfSlots, profile.interior.wall, profile.interior.floor, profile.interior.awning, profile.interior.sign)
	local best = bestSeller(profile)
	updateSign(player)
	-- 屋根の上の看板商品（クライアントの DecorFun がゆっくり回す）
	local featured = profile.designs[profile.featured]
	if featured and not featured.boughtFrom then
		local item = ItemBuilder.BuildFitted(featured, ShopService.FeaturedSize)
		item.Name = "Featured"
		item:PivotTo(plot.origin * ShopService.FeaturedOffset)
		item.Parent = folder
	end
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
			if shelf.designId == best then
				-- 一番売れている商品の札
				local badge = nameLabel:Clone()
				badge.Name = "BestSeller"
				badge.Size = UDim2.new(0, 90, 0, 22)
				badge.Position = UDim2.new(0.5, -45, 0, -24)
				badge.BackgroundTransparency = 0
				badge.BackgroundColor3 = Color3.fromRGB(240, 90, 80)
				badge.TextColor3 = Color3.new(1, 1, 1)
				badge.Text = "人気No.1"
				local badgeCorner = Instance.new("UICorner")
				badgeCorner.CornerRadius = UDim.new(0, 8)
				badgeCorner.Parent = badge
				badge.Parent = bg
				billboard.Size = UDim2.new(0, 150, 0, 54)
				billboard.ClipsDescendants = false
			end
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

-- 同じデザインでも形が変わっていたら別のアイテムとして扱うための目印（フィールド順を固定して作る）
local function partsFingerprint(parts: any): string
	local pieces = {}
	for _, part in parts do
		table.insert(pieces, table.concat({
			part.shape, part.color, part.material,
			table.concat(part.size, ","), table.concat(part.pos, ","), table.concat(part.rot, ","),
		}, "/"))
	end
	return table.concat(pieces, ";")
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
	local sourceKey = seller.UserId .. ":" .. shelf.designId .. ":" .. partsFingerprint(design.parts)
	local targetId: string? = nil
	local boughtCount = 0
	for id, d in buyerProfile.designs do
		if d.boughtFrom and not d.gift then -- プレゼントは別枠
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
	ShopService.RecordSale(sellerProfile, shelf.designId, 1)
	sellerProfile.stats.earned += price
	DataService.AddToday(sellerProfile, 1, price, 0)
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
	ShopService.Log(seller, ("%s さんが「%s」を %d で購入"):format(buyer.DisplayName, design.name, price))
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

local homeChanged = Instance.new("BindableEvent")
ShopService.HomeInteriorChanged = homeChanged.Event -- (player)

local function setInterior(player: Player, kind: any, id: any): (boolean, string)
	local profile = DataService.Get(player)
	if not profile then
		return false, "データを読み込み中です"
	end
	local lists = {
		wall = ShopUpgrades.WallById,
		floor = ShopUpgrades.FloorById,
		awning = ShopUpgrades.AwningById,
		sign = ShopUpgrades.SignById,
		homeWall = ShopUpgrades.HomeWallById,
		homeFloor = ShopUpgrades.HomeFloorById,
	} :: { [string]: any }
	local list = if type(kind) == "string" then lists[kind] else nil
	local entry = list and type(id) == "string" and list[id]
	if not entry then
		return false, "見つかりません"
	end
	-- 壁・床はお店と自宅で同じ記録を使う（一度買えば両方で使える）
	local ownedKey = ShopUpgrades.OwnedKind[kind] .. ":" .. id
	if entry.price > 0 and not profile.ownedInterior[ownedKey] then
		if not DataService.TrySpend(player, entry.price) then
			return false, ("コインが足りません（%d コイン必要）"):format(entry.price)
		end
		profile.ownedInterior[ownedKey] = true
	end
	(profile.interior :: any)[kind] = id
	DataService.Changed(player)
	ShopService.Render(player)
	if kind == "homeWall" or kind == "homeFloor" then
		homeChanged:Fire(player) -- 自宅の見た目は HomeService が描き直す（HomeService は ShopService を読み込むので逆向きはイベントで）
	end
	return true, ("「%s」にしました"):format(entry.name)
end

-- キャッチコピー（他の人にも見えるので Roblox のフィルターを通す）
ShopService.SloganMaxLength = 20
local lastSlogan: { [Player]: number } = {}
local function setSlogan(player: Player, text: any): (boolean, string)
	local now = os.clock()
	if lastSlogan[player] and now - lastSlogan[player] < 3 then
		return false, "少し待ってからどうぞ"
	end
	local profile = DataService.Get(player)
	if not profile or type(text) ~= "string" then
		return false, "設定できませんでした"
	end
	if #text > 200 then
		return false, ("%d文字までです"):format(ShopService.SloganMaxLength)
	end
	text = string.gsub(text, "[%c]", "")
	text = string.gsub(text, "^%s+", "")
	text = string.gsub(text, "%s+$", "")
	local length = utf8.len(text)
	if not length then
		return false, "使えない文字があります"
	end
	if length > ShopService.SloganMaxLength then
		return false, ("%d文字までです"):format(ShopService.SloganMaxLength)
	end
	lastSlogan[player] = now
	local filtered = ""
	if length > 0 then
		local ok, result = pcall(function()
			return TextService:FilterStringAsync(text, player.UserId):GetNonChatStringForBroadcastAsync()
		end)
		if not ok or type(result) ~= "string" then
			return false, "文字を確認できませんでした。もう一度どうぞ"
		end
		filtered = result
	end
	profile.slogan = filtered
	DataService.Changed(player)
	updateSign(player)
	return true, if filtered == "" then "キャッチコピーを消しました" else "キャッチコピーを出しました！"
end

-- チラシ：コインを払うと少しの間お客さんが増える
ShopService.FlyerPrice = 60
ShopService.FlyerSeconds = 180
local flyerUntil: { [Player]: number } = {}
local flyerEvent = Net.Event("FlyerUntil")

function ShopService.FlyerActive(player: Player): boolean
	return (flyerUntil[player] or 0) > os.clock()
end

local function buyFlyer(player: Player): (boolean, string)
	if ShopService.FlyerActive(player) then
		return false, "チラシの効果がまだ続いています"
	end
	-- 並べている商品がないとお客さんは来ないので、先に知らせる
	local profile = DataService.Get(player)
	local hasStocked = false
	if profile and PlotService.Get(player) then
		for key, shelf in profile.shelves do
			if (tonumber(key) or 99) <= profile.shelfSlots and profile.designs[shelf.designId] and (profile.stock[shelf.designId] or 0) > 0 then
				hasStocked = true
			end
		end
	end
	if not hasStocked then
		return false, "先に商品を棚に並べよう（並べていないとお客さんは来ません）"
	end
	if not DataService.TrySpend(player, ShopService.FlyerPrice) then
		return false, ("コインが足りません（%d コイン必要）"):format(ShopService.FlyerPrice)
	end
	flyerUntil[player] = os.clock() + ShopService.FlyerSeconds
	flyerEvent:FireClient(player, ShopService.FlyerSeconds)
	return true, ("チラシを配りました！%d分間お客さんが増えます"):format(ShopService.FlyerSeconds // 60)
end

-- プレゼント：自分の在庫のアイテムを1つ、同じサーバーの人に贈る（受け取った人は自宅に飾れる）
local lastGift: { [Player]: number } = {}
local lastGiftTo: { [Player]: number } = {}
ShopService.MaxGifts = 30
ShopService.MaxGiftKindsPerSender = 3
local giftEvent = Net.Event("GiftReceived")
local function gift(sender: Player, targetUserId: any, designId: any): (boolean, string)
	local now = os.clock()
	if lastGift[sender] and now - lastGift[sender] < 2 then
		return false, "少し待ってからどうぞ"
	end
	if type(targetUserId) ~= "number" or type(designId) ~= "string" then
		return false, "贈り先が正しくありません"
	end
	local target = Players:GetPlayerByUserId(targetUserId)
	if not target or target == sender then
		return false, "贈り先が見つかりません"
	end
	local senderProfile = DataService.Get(sender)
	local targetProfile = DataService.Get(target)
	if not senderProfile or not targetProfile then
		return false, "データを読み込み中です"
	end
	local design = senderProfile.designs[designId]
	if not design or design.boughtFrom then
		return false, "自分で作ったアイテムだけ贈れます"
	end
	local stock = senderProfile.stock[designId] or 0
	if stock <= 0 then
		return false, "在庫がありません。工房で作りましょう"
	end
	-- 受け取る側の迷惑にならないよう：プレゼントは別枠で30種類まで、同じ人からは3種類まで、受け取りは2秒に1回まで
	if lastGiftTo[target] and now - lastGiftTo[target] < 2 then
		return false, "相手が受け取り中です。少し待ってからどうぞ"
	end
	local senderPrefix = sender.UserId .. ":"
	local sourceKey = senderPrefix .. designId .. ":" .. partsFingerprint(design.parts)
	local targetId: string? = nil
	local giftCount, fromSender = 0, 0
	for id, d in targetProfile.designs do
		if d.gift then
			giftCount += 1
			if type(d.sourceKey) == "string" and string.sub(d.sourceKey, 1, #senderPrefix) == senderPrefix then
				fromSender += 1
			end
			if d.sourceKey == sourceKey then
				targetId = id
			end
		end
	end
	if not targetId and (giftCount >= ShopService.MaxGifts or fromSender >= ShopService.MaxGiftKindsPerSender) then
		return false, "これ以上この人には新しい種類を贈れません"
	end
	lastGift[sender] = now
	lastGiftTo[target] = now
	senderProfile.stock[designId] = stock - 1
	if not targetId then
		targetId = "d" .. targetProfile.nextDesignId
		targetProfile.nextDesignId += 1
		targetProfile.designs[targetId] = {
			name = design.name,
			parts = HttpService:JSONDecode(HttpService:JSONEncode(design.parts)),
			boughtFrom = sender.DisplayName,
			sourceKey = sourceKey,
			gift = true,
		}
	end
	local id = targetId :: string
	targetProfile.stock[id] = (targetProfile.stock[id] or 0) + 1
	DataService.Changed(sender)
	DataService.Changed(target)
	ShopService.Render(sender)
	giftEvent:FireClient(target, sender.DisplayName, design.name)
	return true, ("%s さんに「%s」を贈りました！"):format(target.DisplayName, design.name)
end

-- 屋根の上の看板商品を選ぶ（designId = "" で外す）。自分で作ったデザインだけ
local lastFeatured: { [Player]: number } = {}
local function setFeatured(player: Player, designId: any): (boolean, string)
	local now = os.clock()
	if lastFeatured[player] and now - lastFeatured[player] < 1 then
		return false, "少し待ってからどうぞ"
	end
	lastFeatured[player] = now
	local profile = DataService.Get(player)
	if not profile or type(designId) ~= "string" then
		return false, "設定できませんでした"
	end
	if designId == "" then
		profile.featured = ""
		DataService.Changed(player)
		ShopService.Render(player)
		return true, "看板商品を外しました"
	end
	local design = profile.designs[designId]
	if not design or design.boughtFrom then
		return false, "自分で作ったデザインだけ飾れます"
	end
	profile.featured = designId
	DataService.Changed(player)
	ShopService.Render(player)
	return true, ("「%s」を屋根の上に飾りました！"):format(design.name)
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
	wrap("SetSlogan", setSlogan)
	wrap("BuyFlyer", buyFlyer)
	wrap("SendGift", gift)
	wrap("SetFeatured", setFeatured)
	game:GetService("Players").PlayerRemoving:Connect(function(player)
		lastFeatured[player] = nil
	end)

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
	DataService.OnLoaded(function(player, profile)
		ShopService.OfflineSales(player, profile)
		ShopService.Render(player)
	end)
	PlotService.Released:Connect(function(_, plot)
		clearDisplays(plot)
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastRequest[player] = nil
		lastSlogan[player] = nil
		flyerUntil[player] = nil
		lastGift[player] = nil
		lastGiftTo[player] = nil
		logs[player] = nil
	end)
end

return ShopService
