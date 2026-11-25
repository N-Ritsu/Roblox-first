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
	home: { [string]: any }, -- 自宅のマス "x_z" → { designId, rot }
	shelfSlots: number, -- 使える陳列台の数
	interior: { wall: string, floor: string },
	ownedInterior: { [string]: boolean }, -- 買った内装（"wall:Mint" など）
	lastDaily: number,
	dailyStreak: number,
	tutorialDone: boolean,
	stats: { sold: number, earned: number },
	lockJobId: string?,
	lockTime: number?,
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
		home = {},
		shelfSlots = 4,
		interior = { wall = "Cream", floor = "Wood" },
		ownedInterior = {},
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

-- 同じプレイヤーが別サーバーに素早く移ったときに古いデータで上書きしないよう、
-- データに「どのサーバーが使っているか」の印（lockJobId）をつける簡易ロック
local LOCK_STALE_SECONDS = 300 -- これより古い印は、落ちたサーバーの残りとみなす
local LOCK_WAIT_TRIES = 5 -- 他のサーバーが使用中なら、3秒おきにこの回数まで待つ

local function load(player: Player): (Profile, boolean)
	if not store then
		return defaultProfile(), false
	end
	local lockWaits = 0
	local failures = 0
	while failures < 3 do
		local lockedByOther = false
		local loaded: any = nil
		local ok, err = pcall(function()
			(store :: DataStore):UpdateAsync(key(player), function(old: any)
				local data = if type(old) == "table" then old else defaultProfile()
				local lockJob = data.lockJobId
				local lockAge = os.time() - (tonumber(data.lockTime) or 0)
				if lockJob and lockJob ~= game.JobId and lockAge < LOCK_STALE_SECONDS and lockWaits < LOCK_WAIT_TRIES then
					lockedByOther = true
					return nil -- 書き込まずに中止
				end
				lockedByOther = false
				data.lockJobId = game.JobId
				data.lockTime = os.time()
				loaded = data
				return data
			end)
		end)
		if not ok then
			failures += 1
			warn(("[DataService] 読み込み失敗 (%d/3): %s"):format(failures, tostring(err)))
			if failures < 3 then
				task.wait(failures * 2)
			end
		elseif lockedByOther then
			lockWaits += 1
			task.wait(3)
		elseif loaded then
			reconcile(loaded, defaultProfile())
			-- 初期解放分はデータが古くても常に使えるようにする
			reconcile(loaded.unlocks, Catalog.DefaultUnlocks())
			return loaded :: Profile, true
		else
			failures += 1
		end
		if not player.Parent then
			break
		end
	end
	return defaultProfile(), false
end

-- release = true のときはロックの印を外す（退出・サーバー終了時）
local function save(player: Player, release: boolean?)
	local profile = profiles[player]
	if not store or not profile or not canSave[player] then
		return
	end
	local ok, err = pcall(function()
		(store :: DataStore):UpdateAsync(key(player), function(old: any)
			if type(old) == "table" and old.lockJobId and old.lockJobId ~= game.JobId then
				-- 別のサーバーがすでにこのデータを使っている。古いデータで上書きしない
				warn("[DataService] 他のサーバーが使用中のため保存を見送りました:", player.UserId)
				return nil
			end
			local data = profile :: any
			data.lockJobId = if release then nil else game.JobId
			data.lockTime = os.time()
			return data
		end)
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
	local sold = Instance.new("IntValue")
	sold.Name = "売った数"
	sold.Value = profile.stats.sold
	sold.Parent = leaderstats
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
	local sold = leaderstats and leaderstats:FindFirstChild("売った数")
	if sold and sold:IsA("IntValue") then
		sold.Value = profile.stats.sold
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

local leaving: { [Player]: boolean } = {}

local function onPlayerRemoving(player: Player)
	if leaving[player] then
		return
	end
	leaving[player] = true
	save(player, true)
	profiles[player] = nil
	canSave[player] = nil
	leaving[player] = nil
end

local function onPlayerAdded(player: Player)
	local profile, ok = load(player)
	profiles[player] = profile
	canSave[player] = ok
	if not player.Parent then
		-- 読み込み中に抜けた：ロックの印を外して終わる
		onPlayerRemoving(player)
		return
	end
	setupLeaderstats(player, profile)
	DataService.Changed(player)
	loadedEvent:Fire(player, profile)
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
				if not leaving[player] then
					task.spawn(save, player)
				end
			end
		end
	end)

	game:BindToClose(function()
		-- 退出処理中でないプレイヤーも保存し、すべて終わるまで待つ
		for player in profiles do
			task.spawn(onPlayerRemoving, player)
		end
		local started = os.clock()
		while next(profiles) ~= nil and os.clock() - started < 25 do
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
