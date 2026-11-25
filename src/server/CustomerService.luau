--!strict
-- お客さんNPC：店に来て棚を見て、値段が「払ってもいい額」以下なら買っていく

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ItemBuilder = require(Shared:WaitForChild("ItemBuilder"))
local Net = require(Shared:WaitForChild("Net"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local PlotService = require(script.Parent:WaitForChild("PlotService"))
local ShopService = require(script.Parent:WaitForChild("ShopService"))
local Build = require(script.Parent:WaitForChild("Build"))

local CustomerService = {}

CustomerService.MaxPerPlot = 3
CustomerService.SpawnInterval = { 7, 13 } -- 秒（ランダム）
CustomerService.WalkSpeed = 9
CustomerService.WillingnessRange = { 0.8, 1.6 } -- 価値に対して払ってもいい額の倍率

local saleEvent = Net.Event("Sale")
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

local function makeCustomer(position: Vector3): Customer
	local model = Instance.new("Model")
	model.Name = "Customer"
	local base = CFrame.new(position)
	local body = Build.Part(model, {
		Name = "Body",
		Size = Vector3.new(2.6, 1.9, 1.9),
		CFrame = base * CFrame.new(0, 1.4, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = SHIRTS[random:NextInteger(1, #SHIRTS)],
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
	if random:NextNumber() < 0.5 then
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
	billboard.Size = UDim2.new(0, 120, 0, 36)
	billboard.StudsOffset = Vector3.new(0, 2, 0)
	billboard.MaxDistance = 60
	billboard.LightInfluence = 0
	local bubble = Instance.new("TextLabel")
	bubble.Size = UDim2.fromScale(1, 1)
	bubble.BackgroundColor3 = Color3.new(1, 1, 1)
	bubble.TextColor3 = Color3.fromRGB(70, 50, 40)
	bubble.Font = Enum.Font.FredokaOne
	bubble.TextScaled = true
	bubble.Text = ""
	bubble.Visible = false
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = bubble
	bubble.Parent = billboard
	billboard.Parent = head

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

-- 棚の前（お客さんが立つ位置、ローカル座標）
local function shelfStandOffset(slot: number): Vector3
	local offset = PlotService.ShelfOffsets[slot].Position
	local x = if offset.X < 0 then offset.X + 3.6 else offset.X - 3.6
	return Vector3.new(x, 0.9, offset.Z)
end

local function visit(plot: PlotService.Plot, owner: Player)
	local isValid = function()
		return plot.owner == owner and owner.Parent ~= nil
	end
	local origin = plot.origin
	local function world(v: Vector3): Vector3
		return origin:PointToWorldSpace(v)
	end

	local side = if random:NextNumber() < 0.5 then -1 else 1
	local start = world(Vector3.new(side * 16, 0.6, -11))
	local customer = makeCustomer(start)
	local function finish()
		customer.model:Destroy()
		active[plot.index] = math.max(0, (active[plot.index] or 1) - 1)
	end

	-- 店の前を通って入口へ
	if not walkTo(customer, world(Vector3.new(side * 2, 0.6, -10)), isValid) then
		return finish()
	end
	if not walkTo(customer, world(Vector3.new(random:NextNumber(-1.5, 1.5), 0.9, -2)), isValid) then
		return finish()
	end

	-- 在庫のある棚を選んで見に行く
	local profile = DataService.Get(owner)
	if not profile then
		return finish()
	end
	local candidates = {}
	for slot = 1, ShopService.SlotCount do
		local shelf = profile.shelves[tostring(slot)]
		if shelf and profile.designs[shelf.designId] and (profile.stock[shelf.designId] or 0) > 0 then
			table.insert(candidates, slot)
		end
	end
	local bought = false
	if #candidates > 0 then
		local slot = candidates[random:NextInteger(1, #candidates)]
		local stand = shelfStandOffset(slot)
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
			local value = ItemBuilder.Value(design)
			local range = CustomerService.WillingnessRange
			local willing = value * random:NextNumber(range[1], range[2])
			if shelf.price <= willing then
				bought = true
				profile.stock[shelf.designId] = stock - 1
				profile.stats.sold += 1
				profile.stats.earned += shelf.price
				DataService.AddCoins(owner, shelf.price)
				ShopService.Render(owner)
				saleEvent:FireClient(owner, design.name, shelf.price)
				coinBurst(world(PlotService.ShelfOffsets[slot].Position) + Vector3.new(0, 2, 0))
				say(customer, if shelf.price <= value * 0.9 then "安い！買う！" else "これください！")
			else
				say(customer, if shelf.price > value * 2 then "高すぎる…" else "うーん、高いなぁ")
			end
		else
			say(customer, "売り切れか…")
		end
		if not pause(1.2, isValid) then
			return finish()
		end
		say(customer, nil)
	else
		say(customer, "何もないなぁ")
		if not pause(1.5, isValid) then
			return finish()
		end
		say(customer, nil)
	end

	if bought then
		-- レジに寄ってから帰る（棚にぶつからないよう真ん中の通路を通る）
		if not walkTo(customer, world(Vector3.new(2, 0.9, 11)), isValid) then
			return finish()
		end
		if not walkTo(customer, world(Vector3.new(8, 0.9, 11)), isValid) then
			return finish()
		end
		say(customer, "ありがとう！")
		if not pause(0.8, isValid) then
			return finish()
		end
		say(customer, nil)
		if not walkTo(customer, world(Vector3.new(2, 0.9, 11)), isValid) then
			return finish()
		end
	end
	if not walkTo(customer, world(Vector3.new(0, 0.9, -2)), isValid) then
		return finish()
	end
	local exitSide = if random:NextNumber() < 0.5 then -1 else 1
	if walkTo(customer, world(Vector3.new(exitSide * 2, 0.6, -10)), isValid) then
		walkTo(customer, world(Vector3.new(exitSide * 18, 0.6, -11)), isValid)
	end
	finish()
end

-- 陳列している商品がある店ほど、お客さんが来やすい
local function hasStockedShelf(owner: Player): boolean
	local profile = DataService.Get(owner)
	if not profile then
		return false
	end
	for _, shelf in profile.shelves do
		if profile.designs[shelf.designId] and (profile.stock[shelf.designId] or 0) > 0 then
			return true
		end
	end
	return false
end

function CustomerService.Start()
	folder = Instance.new("Folder")
	folder.Name = "Customers"
	folder.Parent = workspace

	local nextSpawn: { [number]: number } = {}
	task.spawn(function()
		while true do
			task.wait(1)
			local now = os.clock()
			for _, plot in PlotService.All() do
				local owner = plot.owner
				if owner and hasStockedShelf(owner) then
					if not nextSpawn[plot.index] then
						nextSpawn[plot.index] = now + 3
					elseif now >= nextSpawn[plot.index] and (active[plot.index] or 0) < CustomerService.MaxPerPlot then
						local interval = CustomerService.SpawnInterval
						nextSpawn[plot.index] = now + random:NextNumber(interval[1], interval[2])
						active[plot.index] = (active[plot.index] or 0) + 1
						task.spawn(function()
							local ok, err = pcall(visit, plot, owner)
							if not ok then
								warn("[CustomerService] エラー:", err)
								active[plot.index] = math.max(0, (active[plot.index] or 1) - 1)
							end
						end)
					end
				else
					nextSpawn[plot.index] = nil
				end
			end
		end
	end)
	-- 店主が抜けたときのお客さんは walkTo / pause の isValid で自然に消える
end

return CustomerService
