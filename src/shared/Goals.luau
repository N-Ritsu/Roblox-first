--!strict
-- 目標（実績）の一覧。達成すると報酬コインを受け取れる
-- progress はセーブデータから今の進み具合を数える（サーバーとクライアントの両方で使う）

local Catalog = require(script.Parent:WaitForChild("Catalog"))

export type Goal = { id: string, text: string, target: number, reward: number, progress: (any) -> number }

local function ownDesigns(profile: any): number
	local n = 0
	for _, design in profile.designs do
		if not design.boughtFrom then
			n += 1
		end
	end
	return n
end

local function paidUnlocks(profile: any): number
	local n = 0
	for kind, list in Catalog.Kinds do
		for _, entry in list do
			if entry.unlockPrice > 0 and profile.unlocks[kind] and profile.unlocks[kind][entry.id] then
				n += 1
			end
		end
	end
	return n
end

local function homeItems(profile: any): number
	local n = 0
	for _ in profile.home do
		n += 1
	end
	return n
end

local function sold(profile: any): number
	return profile.stats.sold
end
local function earned(profile: any): number
	return profile.stats.earned
end
local function streak(profile: any): number
	return profile.dailyStreak
end

local Goals = {}

Goals.List = {
	{ id = "design1", text = "アイテムをデザインする", target = 1, reward = 20, progress = ownDesigns },
	{ id = "sold1", text = "初めて商品を売る", target = 1, reward = 30, progress = sold },
	{ id = "sold10", text = "商品を10個売る", target = 10, reward = 60, progress = sold },
	{ id = "designs5", text = "デザインを5つ作る", target = 5, reward = 80, progress = ownDesigns },
	{ id = "unlock5", text = "部品を5つ解放する", target = 5, reward = 100, progress = paidUnlocks },
	{ id = "home5", text = "自宅にアイテムを5つ飾る", target = 5, reward = 80, progress = homeItems },
	{ id = "earned500", text = "売上を合計500コインにする", target = 500, reward = 100, progress = earned },
	{ id = "streak3", text = "3日連続でログインする", target = 3, reward = 100, progress = streak },
	{ id = "sold50", text = "商品を50個売る", target = 50, reward = 150, progress = sold },
	{ id = "shelves6", text = "陳列台を6台にする", target = 6, reward = 150, progress = function(p)
		return p.shelfSlots
	end },
	{ id = "unlock15", text = "部品を15個解放する", target = 15, reward = 300, progress = paidUnlocks },
	{ id = "streak7", text = "7日連続でログインする", target = 7, reward = 300, progress = streak },
	{ id = "sold200", text = "商品を200個売る", target = 200, reward = 400, progress = sold },
	{ id = "earned5000", text = "売上を合計5000コインにする", target = 5000, reward = 500, progress = earned },
} :: { Goal }

Goals.ById = {} :: { [string]: Goal }
for _, goal in Goals.List do
	Goals.ById[goal.id] = goal
end

function Goals.IsDone(goal: Goal, profile: any): boolean
	return goal.progress(profile) >= goal.target
end

-- 受け取れる報酬の数
function Goals.ClaimableCount(profile: any): number
	local n = 0
	for _, goal in Goals.List do
		if not profile.goalsClaimed[goal.id] and Goals.IsDone(goal, profile) then
			n += 1
		end
	end
	return n
end

return Goals
