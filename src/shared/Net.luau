--!strict
-- RemoteEvent / RemoteFunction の受け渡し
-- サーバーでは作成、クライアントでは出来上がるのを待って取得する

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = {}

local IS_SERVER = RunService:IsServer()
local folder: Instance? = nil

local function getFolder(): Instance
	if folder then
		return folder
	end
	if IS_SERVER then
		local f = ReplicatedStorage:FindFirstChild("Remotes")
		if not f then
			f = Instance.new("Folder")
			f.Name = "Remotes"
			f.Parent = ReplicatedStorage
		end
		folder = f
	else
		folder = ReplicatedStorage:WaitForChild("Remotes")
	end
	return folder :: Instance
end

local function get(className: string, name: string): Instance
	local f = getFolder()
	if IS_SERVER then
		local existing = f:FindFirstChild(name)
		if existing then
			return existing
		end
		local remote = Instance.new(className)
		remote.Name = name
		remote.Parent = f
		return remote
	end
	return f:WaitForChild(name)
end

function Net.Event(name: string): RemoteEvent
	return get("RemoteEvent", name) :: RemoteEvent
end

function Net.Function(name: string): RemoteFunction
	return get("RemoteFunction", name) :: RemoteFunction
end

return Net
