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

-- 読み込み済みなら即、以後も変化のたびに呼ぶ
function State.Observe(callback: (any) -> ())
	if State.profile then
		task.spawn(callback, State.profile)
	end
	State.Changed:Connect(callback)
end

return State
