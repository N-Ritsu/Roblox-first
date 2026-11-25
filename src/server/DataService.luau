--!strict
-- プレイヤーのセーブデータ管理
-- DataStore の呼び出しはすべて pcall で包み、失敗してもゲームは止めない。
-- 読み込みに失敗したプレイヤーのデータは、上書き事故を防ぐため保存しない。

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Catalog = require(Shared:WaitForChild("Catalog"))
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))

export type Profile = {
	version: number,
	coins: number,
	designs: { [string]: any }, -- デザインID → デザイン
	nextDesignId: number,
	stock: { [string]: number }, -- デザインID → 在庫数
	unlocks: { shapes: { [string]: boolean }, colors: { [string]: boolean }, materials: { [string]: boolean } },
	shelves: { [string]: any }, -- 棚番号（文字列）→ { designId, price }
	lastDaily: number,
	dailyStreak: number,
	tutorialDone: boolean,
	stats: { sold: number, earned: number },
}

local DataService = {}

local profileUpdated = Net.Event("ProfileUpdated")
local requestProfile = Net.Event("RequestProfile")

local profiles: { [Player]: Profile } = {}
local canSave: { [Player]: boolean } = {}
local loadedEvent = Instance.new("BindableEvent")
DataService.Loaded = loadedEvent.Event -- (player, profile)

local store: DataStore? = nil
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(Config.DataStoreName)
	end)
	if ok then
		store = result
	else
		warn("[DataService] DataStore を使えません。今回はセーブされません:", result)
	end
end

local function defaultProfile(): Profile
	return {
		version = 1,
		coins = Config.StartingCoins,
		designs = {},
		nextDesignId = 1,
		stock = {},
		unlocks = Catalog.DefaultUnlocks(),
		shelves = {},
		lastDaily = 0,
		dailyStreak = 0,
		tutorialDone = false,
		stats = { sold = 0, earned = 0 },
	}
end

-- 保存データに足りない項目を既定値で埋める（項目を追加したときの互換性のため）
local function reconcile(data: any, template: any)
	for key, value in template do
		if data[key] == nil then
			if type(value) == "table" then
				data[key] = HttpService:JSONDecode(HttpService:JSONEncode(value))
			else
				data[key] = value
			end
		elseif type(value) == "table" and type(data[key]) == "table" then
			reconcile(data[key], value)
		end
	end
end

local function key(player: Player): string
	return "u_" .. player.UserId
end

local function load(player: Player): (Profile, boolean)
	if not store then
		return defaultProfile(), false
	end
	for attempt = 1, 3 do
		local ok, result = pcall(function()
			return (store :: DataStore):GetAsync(key(player))
		end)
		if ok then
			local profile = defaultProfile()
			if type(result) == "table" then
				reconcile(result, profile)
				-- 初期解放分はデータが古くても常に使えるようにする
				reconcile(result.unlocks, Catalog.DefaultUnlocks())
				return result :: any, true
			end
			return profile, true
		end
		warn(("[DataService] 読み込み失敗 (%d/3): %s"):format(attempt, tostring(result)))
		task.wait(attempt * 2)
	end
	return defaultProfile(), false
end

local function save(player: Player)
	local profile = profiles[player]
	if not store or not profile or not canSave[player] then
		return
	end
	local ok, err = pcall(function()
		(store :: DataStore):SetAsync(key(player), profile)
	end)
	if not ok then
		warn("[DataService] 保存失敗:", err)
	end
end

local function setupLeaderstats(player: Player, profile: Profile)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	local coins = Instance.new("IntValue")
	coins.Name = "コイン"
	coins.Value = profile.coins
	coins.Parent = leaderstats
	leaderstats.Parent = player
end

function DataService.Get(player: Player): Profile?
	return profiles[player]
end

-- データを書き換えたら呼ぶ。クライアントへ最新の状態を送る
function DataService.Changed(player: Player)
	local profile = profiles[player]
	if not profile then
		return
	end
	local leaderstats = player:FindFirstChild("leaderstats")
	local coins = leaderstats and leaderstats:FindFirstChild("コイン")
	if coins and coins:IsA("IntValue") then
		coins.Value = profile.coins
	end
	profileUpdated:FireClient(player, profile)
end

function DataService.AddCoins(player: Player, amount: number)
	local profile = profiles[player]
	if not profile then
		return
	end
	profile.coins = math.max(0, math.floor(profile.coins + amount))
	DataService.Changed(player)
end

-- 足りていれば払って true を返す
function DataService.TrySpend(player: Player, amount: number): boolean
	local profile = profiles[player]
	if not profile or amount < 0 or profile.coins < amount then
		return false
	end
	profile.coins -= math.floor(amount)
	DataService.Changed(player)
	return true
end

local function onPlayerAdded(player: Player)
	local profile, ok = load(player)
	if not player.Parent then
		return
	end
	profiles[player] = profile
	canSave[player] = ok
	setupLeaderstats(player, profile)
	DataService.Changed(player)
	loadedEvent:Fire(player, profile)
end

local function onPlayerRemoving(player: Player)
	save(player)
	profiles[player] = nil
	canSave[player] = nil
end

function DataService.Start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	requestProfile.OnServerEvent:Connect(function(player)
		DataService.Changed(player)
	end)

	task.spawn(function()
		while true do
			task.wait(Config.AutosaveInterval)
			for player in profiles do
				task.spawn(save, player)
			end
		end
	end)

	game:BindToClose(function()
		local pending = 0
		for player in profiles do
			pending += 1
			task.spawn(function()
				save(player)
				pending -= 1
			end)
		end
		local started = os.clock()
		while pending > 0 and os.clock() - started < 25 do
			task.wait(0.1)
		end
	end)
end

-- 他のサービス用：読み込み済みなら即、まだなら読み込みを待って呼ぶ
function DataService.OnLoaded(callback: (Player, Profile) -> ())
	DataService.Loaded:Connect(callback)
	for player, profile in profiles do
		task.spawn(callback, player, profile)
	end
end

return DataService
