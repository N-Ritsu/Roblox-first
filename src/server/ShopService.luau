--!strict
-- 製作（デザインから在庫を作る）と、店の棚への陳列・表示

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ItemBuilder = require(Shared:WaitForChild("ItemBuilder"))
local Net = require(Shared:WaitForChild("Net"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local PlotService = require(script.Parent:WaitForChild("PlotService"))
local Build = require(script.Parent:WaitForChild("Build"))

local ShopService = {}

ShopService.MaxStock = 99
ShopService.MaxPrice = 9999
ShopService.SlotCount = #PlotService.ShelfOffsets

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

local function clearDisplays(plot: PlotService.Plot)
	displayFolder(plot):ClearAllChildren()
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
	for slot = 1, ShopService.SlotCount do
		local shelf = profile.shelves[tostring(slot)]
		local design = shelf and profile.designs[shelf.designId]
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
	if slot < 1 or slot > ShopService.SlotCount then
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
	if type(price) ~= "number" or price ~= price then
		return false, "値段が正しくありません"
	end
	price = math.clamp(math.floor(price), 1, ShopService.MaxPrice)
	profile.shelves[key] = { designId = designId, price = price }
	DataService.Changed(player)
	ShopService.Render(player)
	return true, "棚に並べました！"
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
	game:GetService("Players").PlayerRemoving:Connect(function(player)
		lastRequest[player] = nil
	end)
end

return ShopService
