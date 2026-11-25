--!strict
-- サーバーから送られてくる自分のセーブデータの写し

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"))

local State = {}

State.profile = nil :: any
local changed = Instance.new("BindableEvent")
State.Changed = changed.Event

Net.Event("ProfileUpdated").OnClientEvent:Connect(function(profile)
	State.profile = profile
	changed:Fire(profile)
end)
-- 読み込みより先にサーバーが送っていた場合に備えて、改めて要求する
Net.Event("RequestProfile"):FireServer()

-- 今のお客さんの注文（なければ nil）。{ label, bonus, expires, field, id }
State.order = nil :: any
Net.Event("Order").OnClientEvent:Connect(function(order)
	State.order = order
end)

-- 今の注文に合うデザインか
function State.MatchesOrder(design: any): boolean
	local order = State.order
	if type(order) ~= "table" or type(order.field) ~= "string" or (tonumber(order.expires) or 0) <= workspace:GetServerTimeNow() then
		return false
	end
	for _, part in design.parts do
		if part[order.field] == order.id then
			return true
		end
	end
	return false
end

-- 読み込み済みなら即、以後も変化のたびに呼ぶ
function State.Observe(callback: (any) -> ())
	if State.profile then
		task.spawn(callback, State.profile)
	end
	State.Changed:Connect(callback)
end

return State
