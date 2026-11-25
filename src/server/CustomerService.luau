--!strict
-- お客さんNPC：店に来て棚を見て、値段が「払ってもいい額」以下なら買っていく

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Catalog = require(Shared:WaitForChild("Catalog"))
local Theme = require(Shared:WaitForChild("Theme"))
local Season = require(Shared:WaitForChild("Season"))
local ItemBuilder = require(Shared:WaitForChild("ItemBuilder"))
local Net = require(Shared:WaitForChild("Net"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local PlotService = require(script.Parent:WaitForChild("PlotService"))
local ShopService = require(script.Parent:WaitForChild("ShopService"))
local OrderService = require(script.Parent:WaitForChild("OrderService"))
local Build = require(script.Parent:WaitForChild("Build"))

local CustomerService = {}

CustomerService.MaxPerPlot = 3
CustomerService.SpawnInterval = { 7, 13 } -- 秒（ランダム）
CustomerService.WalkSpeed = 9
CustomerService.WillingnessRange = { 0.8, 1.6 } -- 価値に対して払ってもいい額の倍率

local saleEvent = Net.Event("Sale")
local noticeEvent = Net.Event("Notice")
local folder: Folder
local random = Random.new()

local SHIRTS = {
	Color3.fromRGB(240, 110, 100),
	Color3.fromRGB(100, 160, 240),
	Color3.fromRGB(120, 200, 120),
	Color3.fromRGB(250, 200, 80),
	Color3.fromRGB(190, 130, 230),
	Color3.fromRGB(250, 160, 200),
	Color3.fromRGB(90, 200, 200),
}
local SKINS = {
	Color3.fromRGB(255, 220, 190),
	Color3.fromRGB(240, 195, 150),
	Color3.fromRGB(200, 150, 110),
	Color3.fromRGB(140, 95, 65),
}

type Customer = {
	model: Model,
	bubble: TextLabel,
	position: Vector3,
	facing: Vector3,
}

local active: { [number]: number } = {} -- 区画番号 → 店内にいるお客さんの数

local function makeCustomer(position: Vector3, rich: boolean, scale: number?, style: string?): Customer
	local model = Instance.new("Model")
	model.Name = "Customer"
	local base = CFrame.new(position)
	local body = Build.Part(model, {
		Name = "Body",
		Size = Vector3.new(2.6, 1.9, 1.9),
		CFrame = base * CFrame.new(0, 1.4, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = if style == "santa" then Color3.fromRGB(200, 30, 40) else SHIRTS[random:NextInteger(1, #SHIRTS)],
		Shape = Enum.PartType.Cylinder,
		CanCollide = false,
	})
	local skin = SKINS[random:NextInteger(1, #SKINS)]
	local head = Build.Part(model, {
		Name = "Head",
		Size = Vector3.new(1.8, 1.8, 1.8),
		CFrame = base * CFrame.new(0, 3.4, 0),
		Color = skin,
		Shape = Enum.PartType.Ball,
		CanCollide = false,
	})
	for _, x in { -0.35, 0.35 } do
		Build.Part(model, {
			Name = "Eye",
			Size = Vector3.new(0.25, 0.35, 0.1),
			CFrame = base * CFrame.new(x, 3.55, -0.85),
			Color = Color3.fromRGB(30, 30, 35),
			CanCollide = false,
		})
	end
	if style == "santa" then
		-- サンタさん：白いひげと、白いふちの赤い帽子（パーツだけで作る）
		Build.Part(model, {
			Name = "Beard",
			Size = Vector3.new(1.5, 1.5, 1.5),
			CFrame = base * CFrame.new(0, 2.85, -0.55),
			Color = Color3.fromRGB(250, 250, 250),
			Shape = Enum.PartType.Ball,
			CanCollide = false,
		})
		Build.Part(model, {
			Name = "HatBrim",
			Size = Vector3.new(0.5, 2, 2),
			CFrame = base * CFrame.new(0, 4.15, 0) * CFrame.Angles(0, 0, math.rad(90)),
			Color = Color3.fromRGB(250, 250, 250),
			Material = Enum.Material.Fabric,
			Shape = Enum.PartType.Cylinder,
			CanCollide = false,
		})
		Build.Part(model, {
			Name = "Hat",
			Size = Vector3.new(1.2, 1.5, 1.5),
			CFrame = base * CFrame.new(0, 4.9, 0) * CFrame.Angles(0, 0, math.rad(90)),
			Color = Color3.fromRGB(200, 30, 40),
			Material = Enum.Material.Fabric,
			Shape = Enum.PartType.Cylinder,
			CanCollide = false,
		})
		Build.Part(model, {
			Name = "HatBall",
			Size = Vector3.new(0.7, 0.7, 0.7),
			CFrame = base * CFrame.new(0, 5.7, 0),
			Color = Color3.fromRGB(250, 250, 250),
			Shape = Enum.PartType.Ball,
			CanCollide = false,
		})
	elseif rich then
		-- お金持ち：金色のシルクハットと、きらきら
		Build.Part(model, {
			Name = "HatBrim",
			Size = Vector3.new(0.2, 2.6, 2.6),
			CFrame = base * CFrame.new(0, 4.15, 0) * CFrame.Angles(0, 0, math.rad(90)),
			Color = Color3.fromRGB(240, 190, 60),
			Material = Enum.Material.Metal,
			Shape = Enum.PartType.Cylinder,
			CanCollide = false,
		})
		local hat = Build.Part(model, {
			Name = "Hat",
			Size = Vector3.new(1.6, 1.7, 1.7),
			CFrame = base * CFrame.new(0, 5, 0) * CFrame.Angles(0, 0, math.rad(90)),
			Color = Color3.fromRGB(250, 205, 70),
			Material = Enum.Material.Neon,
			Shape = Enum.PartType.Cylinder,
			CanCollide = false,
		})
		local sparkle = Instance.new("Sparkles")
		sparkle.SparkleColor = Color3.fromRGB(255, 230, 120)
		sparkle.Parent = hat
	elseif random:NextNumber() < 0.5 then
		-- 帽子
		Build.Part(model, {
			Name = "Hat",
			Size = Vector3.new(0.5, 2, 2),
			CFrame = base * CFrame.new(0, 4.3, 0) * CFrame.Angles(0, 0, math.rad(90)),
			Color = SHIRTS[random:NextInteger(1, #SHIRTS)],
			Shape = Enum.PartType.Cylinder,
			CanCollide = false,
		})
	end
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.CanQuery = false
			part.CanTouch = false
		end
	end
	-- PrimaryPart は設定しない（設定すると横倒しの胴体の向きが基準になってしまう）
	model.WorldPivot = base
	local _ = body

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.new(0, 190, 0, 44)
	billboard.StudsOffset = Vector3.new(0, if rich or style == "santa" then 3.6 else 2, 0) -- お金持ちは帽子が高いので上に
	billboard.MaxDistance = 60
	billboard.LightInfluence = 0
	local bubble = Instance.new("TextLabel")
	bubble.Size = UDim2.fromScale(1, 1)
	bubble.BackgroundColor3 = Color3.new(1, 1, 1)
	bubble.TextColor3 = Color3.fromRGB(70, 50, 40)
	bubble.Font = Enum.Font.FredokaOne
	bubble.TextScaled = true
	bubble.Text = ""
	bubble.TextWrapped = true
	bubble.Visible = false
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = bubble
	bubble.Parent = billboard
	billboard.Parent = head

	if scale and scale ~= 1 then
		model:ScaleTo(scale) -- 子どもは小さく（足元を基準に縮む）
	end
	model.Parent = folder
	return { model = model, bubble = bubble, position = position, facing = Vector3.new(0, 0, -1) }
end

local function say(customer: Customer, text: string?)
	if text then
		customer.bubble.Text = text
		customer.bubble.Visible = true
	else
		customer.bubble.Visible = false
	end
end

local function place(customer: Customer, bob: number)
	local look = Vector3.new(customer.facing.X, 0, customer.facing.Z)
	if look.Magnitude < 0.01 then
		look = Vector3.new(0, 0, -1)
	end
	local cf = CFrame.lookAt(customer.position, customer.position + look) * CFrame.new(0, bob, 0)
	customer.model:PivotTo(cf)
end

-- 目的地まで歩く。途中で店主がいなくなったら false
local function walkTo(customer: Customer, target: Vector3, isValid: () -> boolean): boolean
	local t = random:NextNumber() * 10
	while true do
		if not isValid() then
			return false
		end
		local dt = RunService.Heartbeat:Wait()
		t += dt
		local delta = target - customer.position
		local distance = delta.Magnitude
		if distance < 0.2 then
			customer.position = target
			place(customer, 0)
			return true
		end
		local stepLength = math.min(distance, CustomerService.WalkSpeed * dt)
		customer.facing = delta.Unit
		customer.position += delta.Unit * stepLength
		place(customer, math.abs(math.sin(t * 9)) * 0.35)
	end
end

local function pause(seconds: number, isValid: () -> boolean): boolean
	local finish = os.clock() + seconds
	while os.clock() < finish do
		if not isValid() then
			return false
		end
		task.wait(0.2)
	end
	return isValid()
end

local function coinBurst(position: Vector3)
	local part = Build.Part(folder, {
		Name = "CoinBurst",
		Size = Vector3.new(0.2, 0.2, 0.2),
		CFrame = CFrame.new(position),
		Transparency = 1,
		CanCollide = false,
	})
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(Color3.fromRGB(255, 210, 60))
	emitter.LightEmission = 0.6
	emitter.Size = NumberSequence.new(0.6, 0)
	emitter.Speed = NumberRange.new(6, 10)
	emitter.SpreadAngle = Vector2.new(40, 40)
	emitter.Acceleration = Vector3.new(0, -20, 0)
	emitter.Lifetime = NumberRange.new(0.6, 0.9)
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.Rate = 0
	emitter.Parent = part
	-- 作った直後はまだクライアントに届いていないので、少し待ってから出す
	task.delay(0.15, function()
		emitter:Emit(18)
	end)
	task.delay(2, function()
		part:Destroy()
	end)
end

-- お客さんの好み（なければ nil）。好みに合う商品には多めに払ってくれる
CustomerService.PreferenceChance = 0.6
CustomerService.PreferenceBonus = 1.5
type Preference = { field: string, id: string, text: string }

local function pickPreference(): Preference?
	if random:NextNumber() > CustomerService.PreferenceChance then
		return nil
	end
	local roll = random:NextNumber()
	if roll < 0.5 then
		local entry = Catalog.Colors[random:NextInteger(1, #Catalog.Colors)]
		if entry.season and not Season.IsActive(entry.season) then
			return nil -- 期間外の限定色は好みに出さない
		end
		return { field = "color", id = entry.id, text = ("「%s」のものがほしいな"):format(entry.name) }
	elseif roll < 0.8 then
		local entry = Catalog.Shapes[random:NextInteger(1, #Catalog.Shapes)]
		return { field = "shape", id = entry.id, text = ("「%s」の入ったものがほしいな"):format(entry.name) }
	end
	local entry = Catalog.Materials[random:NextInteger(1, #Catalog.Materials)]
	return { field = "material", id = entry.id, text = ("「%s」のものがほしいな"):format(entry.name) }
end

local function matches(design: any, preference: Preference?): boolean
	if not preference then
		return false
	end
	for _, part in design.parts do
		if part[preference.field] == preference.id then
			return true
		end
	end
	return false
end

-- 商品を見て、買うかどうかと一言を決める
CustomerService.RichChance = 0.08
CustomerService.RichWillingnessRange = { 1.3, 2.1 }

-- お客さんの種類：rich（お金持ち）／child（子ども：安いもの好き）／collector（コレクター：部品の多いもの好き）
CustomerService.ChildChance = 0.12
CustomerService.CollectorChance = 0.1
CustomerService.ChildCheapPrice = 25 -- 子どもはこれ以下の値段だと喜んで買う
CustomerService.CollectorMinParts = 5 -- コレクターはこれ以上の部品のアイテムが好き

-- 冬のお客さん：サンタさん（冬の期間だけ）。冬の限定色を使った品が大好き
CustomerService.SantaChance = 0.05
CustomerService.SantaBonus = 2
CustomerService.WinterLineChance = 0.35
local WINTER_LINES = { "今日は寒いね〜", "雪がきれいだね！", "プレゼントを探しに来たよ", "もうすぐクリスマスだね", "あったかい物あるかな？" }

local function usesWinterColor(design: any): boolean
	for _, part in design.parts do
		local color = Catalog.ColorById[part.color]
		if color and color.season == "winter" then
			return true
		end
	end
	return false
end

local function decide(design: any, price: number, preference: Preference?, rich: boolean, kind: string?): (boolean, string)
	local value = ItemBuilder.Value(design)
	local range = if rich then CustomerService.RichWillingnessRange else CustomerService.WillingnessRange
	local willing = value * random:NextNumber(range[1], range[2])
	if kind == "child" then
		if price <= CustomerService.ChildCheapPrice then
			willing *= 1.5
		else
			willing *= 0.7 -- おこづかいが少ない
		end
	elseif kind == "santa" and usesWinterColor(design) then
		willing *= CustomerService.SantaBonus
		if price <= willing then
			return true, "ホッホッホー！冬にぴったりの品だ！"
		end
	elseif kind == "collector" and #design.parts >= CustomerService.CollectorMinParts then
		willing *= 1.6
		if price <= willing then
			return true, "見事なつくりだ！コレクションに加えよう"
		end
	end
	local liked = matches(design, preference)
	if liked then
		willing *= CustomerService.PreferenceBonus
	end
	local themed = Theme.Matches(design, Theme.Current())
	if themed then
		willing *= Theme.Bonus
	end
	if price <= willing then
		if rich then
			return true, "気に入った！いただこう"
		end
		if liked then
			return true, "これこれ！ほしかったの！"
		end
		if themed then
			return true, "今週のお題にぴったり！"
		end
		return true, if price <= value * 0.9 then "安い！買う！" else "これください！"
	end
	return false, if price > value * 2 then "高すぎる…" else "うーん、高いなぁ"
end

local function visit(plot: PlotService.Plot, owner: Player, ctx: { model: Model? })
	local isValid = function()
		return plot.owner == owner and owner.Parent ~= nil
	end
	local origin = plot.origin
	local function world(v: Vector3): Vector3
		return origin:PointToWorldSpace(v)
	end

	local side = if random:NextNumber() < 0.5 then -1 else 1
	local start = world(Vector3.new(side * 16, 0.6, -11))
	local roll = random:NextNumber()
	local rich = roll < CustomerService.RichChance
	local kind: string? = if rich then "rich"
		elseif roll < CustomerService.RichChance + CustomerService.ChildChance then "child"
		elseif roll < CustomerService.RichChance + CustomerService.ChildChance + CustomerService.CollectorChance then "collector"
		else nil
	if not kind and Season.IsActive("winter") and random:NextNumber() < CustomerService.SantaChance then
		kind = "santa"
	end
	local customer = makeCustomer(start, rich, if kind == "child" then 0.7 else 1, kind)
	ctx.model = customer.model
	local function finish()
		customer.model:Destroy()
		active[plot.index] = math.max(0, (active[plot.index] or 1) - 1)
	end
	local function go(x: number, y: number, z: number): boolean
		return walkTo(customer, world(Vector3.new(x, y, z)), isValid)
	end

	-- 店の前まで来る。好みがあれば吹き出しで教えてくれる
	-- 注文中なら、注文したお客さん本人が来ることがある
	local preference = if kind then nil else (OrderService.PreferenceFor(owner) or pickPreference())
	if rich then
		say(customer, "いい品はあるかね？")
		noticeEvent:FireClient(owner, "お金持ちのお客さんが来た！")
	elseif kind == "child" then
		say(customer, ("%d コインくらいで買えるものある？"):format(CustomerService.ChildCheapPrice))
	elseif kind == "collector" then
		say(customer, ("部品が%d個以上の凝った品を探しています"):format(CustomerService.CollectorMinParts))
	elseif kind == "santa" then
		say(customer, "ホッホッホー！冬の色の品はあるかな？")
		noticeEvent:FireClient(owner, "サンタさんが来た！ 冬の限定色の品が大好き")
	elseif preference then
		say(customer, preference.text)
	elseif Season.IsActive("winter") and random:NextNumber() < CustomerService.WinterLineChance then
		-- 好みのないふつうのお客さんは、冬の間ときどき冬のひとこと（雰囲気づくりだけで、買い方は変わらない）
		say(customer, WINTER_LINES[random:NextInteger(1, #WINTER_LINES)])
	end
	if not go(side * 2, 0.6, -10) then
		return finish()
	end
	say(customer, nil)

	-- 在庫のある棚を選ぶ
	local profile = DataService.Get(owner)
	if not profile then
		return finish()
	end
	local candidates = {}
	for slot = 1, math.min(ShopService.SlotCount, profile.shelfSlots) do
		local shelf = profile.shelves[tostring(slot)]
		if shelf and profile.designs[shelf.designId] and (profile.stock[shelf.designId] or 0) > 0 then
			table.insert(candidates, slot)
		end
	end
	-- 好みに合う商品があれば、そちらを見に行きやすい
	local liked = {}
	for _, candidate in candidates do
		local shelf = profile.shelves[tostring(candidate)]
		if matches(profile.designs[shelf.designId], preference) then
			table.insert(liked, candidate)
		end
	end
	local pool = if #liked > 0 and random:NextNumber() < 0.8 then liked else candidates
	local slot = if #pool > 0 then pool[random:NextInteger(1, #pool)] else nil
	local indoor = slot == nil or not PlotService.IsOutdoorShelf(slot)
	if indoor and not go(random:NextNumber(-1.5, 1.5), 0.9, -2) then
		return finish()
	end

	local bought = false
	if slot then
		local stand = PlotService.ShelfStandOffsets[slot]
		if not walkTo(customer, world(stand), isValid) then
			return finish()
		end
		customer.facing = world(PlotService.ShelfOffsets[slot].Position) - customer.position
		place(customer, 0)
		say(customer, "…")
		if not pause(random:NextNumber(1.5, 3), isValid) then
			return finish()
		end

		-- 見ている間に状況が変わっているかもしれないので、もう一度確かめる
		local shelf = profile.shelves[tostring(slot)]
		local design = shelf and profile.designs[shelf.designId]
		local stock = shelf and profile.stock[shelf.designId] or 0
		if shelf and design and stock > 0 then
			local willBuy, line = decide(design, shelf.price, preference, rich, kind)
			-- 評判：納得の値段で買えると上がり、高すぎて買えないと下がる
			if willBuy then
				ShopService.AddReputation(owner, if rich then 3 elseif shelf.price <= ItemBuilder.Value(design) * 1.1 then 2 else 1)
			elseif shelf.price > ItemBuilder.Value(design) * 1.6 then
				ShopService.AddReputation(owner, -1)
			end
			if willBuy then
				ShopService.Log(owner, ("「%s」が %d で売れた%s"):format(design.name, shelf.price, if rich then "（お金持ち）" else ""))
			elseif shelf.price > ItemBuilder.Value(design) * 2 then
				ShopService.Log(owner, ("「%s」(%d) は高すぎると帰られた"):format(design.name, shelf.price))
			else
				ShopService.Log(owner, ("「%s」(%d) は高いと言われた"):format(design.name, shelf.price))
			end
			if willBuy then
				bought = true
				profile.stock[shelf.designId] = stock - 1
				profile.stats.sold += 1
				ShopService.RecordSale(profile, shelf.designId, 1)
				profile.stats.earned += shelf.price
				DataService.AddToday(profile, 1, shelf.price, 0)
				DataService.AddCoins(owner, shelf.price)
				ShopService.Render(owner)
				saleEvent:FireClient(owner, design.name, shelf.price)
				OrderService.OnSale(owner, design)
				coinBurst(world(PlotService.ShelfOffsets[slot].Position) + Vector3.new(0, 2, 0))
			end
			say(customer, line)
		else
			say(customer, "売り切れか…")
			ShopService.Log(owner, "売り切れの棚を見て帰られた")
			ShopService.AddReputation(owner, -0.5)
		end
		if not pause(1.2, isValid) then
			return finish()
		end
		say(customer, nil)
	else
		say(customer, "何もないなぁ")
		ShopService.AddReputation(owner, -0.5)
		if not pause(1.5, isValid) then
			return finish()
		end
		say(customer, nil)
	end

	local exitSide = if random:NextNumber() < 0.5 then -1 else 1
	if not indoor then
		-- 店頭の台：その場でお礼を言って帰る
		if bought then
			say(customer, "ありがとう！")
			if not pause(0.8, isValid) then
				return finish()
			end
			say(customer, nil)
		end
		go(exitSide * 18, 0.6, -11)
		return finish()
	end

	if bought then
		-- レジに寄ってから帰る（棚にぶつからないよう真ん中の通路を通る）
		if not go(2, 0.9, 11) or not go(8, 0.9, 11) then
			return finish()
		end
		say(customer, "ありがとう！")
		if not pause(0.8, isValid) then
			return finish()
		end
		say(customer, nil)
		if not go(2, 0.9, 11) then
			return finish()
		end
	end
	if go(0, 0.9, -2) and go(exitSide * 2, 0.6, -10) then
		go(exitSide * 18, 0.6, -11)
	end
	finish()
end

-- 広場をぶらぶら歩く通行人（お店には入らない。ワールドをにぎやかに見せるため）
CustomerService.Passersby = 4
local function randomPlazaPoint(): Vector3
	local angle = random:NextNumber() * math.pi * 2
	local radius = random:NextNumber(12, 17) -- 噴水（半径8）とベンチ・ツリー（半径17.5〜）の間
	return Vector3.new(math.sin(angle) * radius, 0.4, math.cos(angle) * radius)
end

local function passerby()
	local always = function()
		return true
	end
	local walker = makeCustomer(randomPlazaPoint(), false)
	while true do
		local target = randomPlazaPoint()
		-- 噴水を突っ切らないよう、円周に沿って45°ずつ歩く（どの区間も中心から約13以上離れる）
		local from = walker.position
		local a0 = math.atan2(from.X, from.Z)
		local a1 = math.atan2(target.X, target.Z)
		local d = (a1 - a0 + math.pi) % (2 * math.pi) - math.pi
		local steps = math.ceil(math.abs(d) / math.rad(45))
		for s = 1, steps - 1 do
			local a = a0 + d * s / steps
			walkTo(walker, Vector3.new(math.sin(a) * 14, 0.4, math.cos(a) * 14), always)
		end
		walkTo(walker, target, always)
		task.wait(random:NextNumber(2, 6))
	end
end

-- 陳列している商品がある店ほど、お客さんが来やすい
local function hasStockedShelf(owner: Player): boolean
	local profile = DataService.Get(owner)
	if not profile then
		return false
	end
	for key, shelf in profile.shelves do
		if (tonumber(key) or 99) <= profile.shelfSlots and profile.designs[shelf.designId] and (profile.stock[shelf.designId] or 0) > 0 then
			return true
		end
	end
	return false
end

function CustomerService.Start()
	folder = Instance.new("Folder")
	folder.Name = "Customers"
	folder.Parent = workspace

	for _ = 1, CustomerService.Passersby do
		task.spawn(function()
			local ok, err = pcall(passerby)
			if not ok then
				warn("[CustomerService] 通行人のエラー:", err)
			end
		end)
	end

	local nextSpawn: { [number]: number } = {}
	task.spawn(function()
		while true do
			task.wait(1)
			-- 1回のエラーでお客さんが二度と来なくなるのを防ぐ
			local okTick, tickErr = pcall(function()
				local now = os.clock()
				for _, plot in PlotService.All() do
					local owner = plot.owner
					if owner and hasStockedShelf(owner) then
						if not nextSpawn[plot.index] then
							nextSpawn[plot.index] = now + 3
						elseif now >= nextSpawn[plot.index] and (active[plot.index] or 0) < CustomerService.MaxPerPlot + (if ShopService.Stars(owner) >= 4 then 1 else 0) + (if ShopService.FlyerActive(owner) then 1 else 0) then
							-- 評判が高い店ほど、お客さんが来る間隔が短い（★5で約0.6倍）
							local interval = CustomerService.SpawnInterval
							local speed = (1 + 0.15 * (ShopService.Stars(owner) - 1)) * (if ShopService.FlyerActive(owner) then 1.8 else 1)
							nextSpawn[plot.index] = now + random:NextNumber(interval[1], interval[2]) / speed
							active[plot.index] = (active[plot.index] or 0) + 1
							task.spawn(function()
								local ctx: { model: Model? } = {}
								local ok, err = pcall(visit, plot, owner, ctx)
								if not ok then
									warn("[CustomerService] エラー:", err)
									if ctx.model then
										ctx.model:Destroy()
									end
									active[plot.index] = math.max(0, (active[plot.index] or 1) - 1)
								end
							end)
						end
					else
						nextSpawn[plot.index] = nil
					end
				end
			end)
			if not okTick then
				warn("[CustomerService] 来店処理のエラー:", tickErr)
			end
		end
	end)
	-- 店主が抜けたときのお客さんは walkTo / pause の isValid で自然に消える
end

return CustomerService
