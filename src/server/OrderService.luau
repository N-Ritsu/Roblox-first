--!strict
-- お客さんの注文：ときどき「『赤』のものがほしい」という注文が届き、
-- 期限内に条件に合う商品がお客さんに売れると、ボーナスのコインがもらえる
-- 注文はサーバーのメモリだけで管理する（抜けると消える。セーブはしない）

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Catalog = require(Shared:WaitForChild("Catalog"))
local Net = require(Shared:WaitForChild("Net"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local PlotService = require(script.Parent:WaitForChild("PlotService"))
local ShopService = require(script.Parent:WaitForChild("ShopService"))

local OrderService = {}

OrderService.Duration = 8 * 60 -- 注文の期限（秒）
OrderService.FirstDelay = { 90, 150 } -- 入ってから最初の注文まで（秒）
OrderService.Cooldown = { 180, 360 } -- 注文が終わってから次の注文まで（秒）
OrderService.BonusBase = 30
OrderService.BonusPerStar = 10
OrderService.CustomerChance = 0.5 -- 注文中、来店するお客さんが注文した本人である確率

export type Order = {
	field: string, -- "color" / "shape" / "material"
	id: string,
	label: string, -- 「赤」のもの など
	bonus: number,
	expires: number, -- os.time()
}

local orders: { [Player]: Order } = {}
local nextOrderAt: { [Player]: number } = {}
local random = Random.new()
local orderEvent = Net.Event("Order")
local noticeEvent = Net.Event("Notice")

local function send(player: Player)
	local order = orders[player]
	if order then
		orderEvent:FireClient(player, { label = order.label, bonus = order.bonus, expires = order.expires })
	else
		orderEvent:FireClient(player, nil)
	end
end

local function schedule(player: Player, range: { number })
	nextOrderAt[player] = os.time() + random:NextInteger(range[1], range[2])
end

-- その人がもう解放している部品から注文を選ぶ（すぐに作れる注文だけにする）
local function pick(profile: any): (string?, string?, string?)
	local options = {}
	for _, entry in Catalog.Colors do
		if profile.unlocks.colors[entry.id] then
			table.insert(options, { "color", entry.id, ("「%s」のもの"):format(entry.name) })
		end
	end
	for _, entry in Catalog.Shapes do
		if profile.unlocks.shapes[entry.id] then
			table.insert(options, { "shape", entry.id, ("「%s」の入ったもの"):format(entry.name) })
		end
	end
	for _, entry in Catalog.Materials do
		if profile.unlocks.materials[entry.id] then
			table.insert(options, { "material", entry.id, ("「%s」のもの"):format(entry.name) })
		end
	end
	if #options == 0 then
		return nil, nil, nil
	end
	-- 今の棚の商品でそのまま達成できる注文はなるべく避ける（新しく作る理由にする）
	local onShelf: { [string]: boolean } = {}
	for _, shelf in profile.shelves do
		local design = profile.designs[shelf.designId]
		if design and (profile.stock[shelf.designId] or 0) > 0 then
			for _, part in design.parts do
				onShelf["color:" .. part.color] = true
				onShelf["shape:" .. part.shape] = true
				onShelf["material:" .. part.material] = true
			end
		end
	end
	local fresh = {}
	for _, option in options do
		if not onShelf[option[1] .. ":" .. option[2]] then
			table.insert(fresh, option)
		end
	end
	if #fresh > 0 and random:NextNumber() < 0.8 then
		options = fresh
	end
	local choice = options[random:NextInteger(1, #options)]
	return choice[1], choice[2], choice[3]
end

local function tick()
	local now = os.time()
	for _, player in Players:GetPlayers() do
		local profile = DataService.Get(player)
		if profile and PlotService.Get(player) then
			local order = orders[player]
			if order and now >= order.expires then
				orders[player] = nil
				schedule(player, OrderService.Cooldown)
				noticeEvent:FireClient(player, "注文の期限が過ぎました。また次の注文を待とう")
				send(player)
			elseif not order then
				if not nextOrderAt[player] then
					schedule(player, OrderService.FirstDelay)
				elseif now >= nextOrderAt[player] and profile.stats.sold >= 1 then
					-- はじめての売上までは、操作を覚えるのを優先して注文を出さない
					local field, id, label = pick(profile)
					if field and id and label then
						orders[player] = {
							field = field,
							id = id,
							label = label,
							bonus = OrderService.BonusBase + OrderService.BonusPerStar * ShopService.Stars(player),
							expires = now + OrderService.Duration,
						}
						noticeEvent:FireClient(player, ("注文が届いた！ %sを売るとボーナス +%d"):format(label, orders[player].bonus))
						send(player)
					end
				end
			end
		end
	end
end

local function matches(design: any, order: Order): boolean
	for _, part in design.parts do
		if part[order.field] == order.id then
			return true
		end
	end
	return false
end

-- お客さんに商品が売れたときに呼ぶ。注文に合えばボーナスを渡して true
function OrderService.OnSale(owner: Player, design: any): boolean
	local order = orders[owner]
	if not order or os.time() >= order.expires or not matches(design, order) then
		return false
	end
	orders[owner] = nil
	schedule(owner, OrderService.Cooldown)
	DataService.AddCoins(owner, order.bonus)
	local profile = DataService.Get(owner)
	if profile then
		profile.ordersDone += 1
		DataService.AddToday(profile, 0, 0, 1)
		DataService.Changed(owner)
	end
	noticeEvent:FireClient(owner, ("注文達成！ 「%s」でボーナス +%d コイン"):format(design.name, order.bonus))
	send(owner)
	return true
end

-- 注文中なら、来店するお客さんの好みとして使う（なければ nil）
function OrderService.PreferenceFor(owner: Player): { field: string, id: string, text: string }?
	local order = orders[owner]
	if not order or random:NextNumber() > OrderService.CustomerChance then
		return nil
	end
	return { field = order.field, id = order.id, text = ("注文した%sを取りに来たよ"):format(order.label) }
end

function OrderService.Start()
	Net.Event("RequestOrder").OnServerEvent:Connect(send)
	Players.PlayerRemoving:Connect(function(player)
		orders[player] = nil
		nextOrderAt[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(5)
			local ok, err = pcall(tick)
			if not ok then
				warn("[OrderService] エラー:", err)
			end
		end
	end)
end

return OrderService
