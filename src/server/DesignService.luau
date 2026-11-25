--!strict
-- アイテムのデザインの保存・削除（工房UIから呼ばれる）

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ItemBuilder = require(Shared:WaitForChild("ItemBuilder"))
local Net = require(Shared:WaitForChild("Net"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local ShopService = require(script.Parent:WaitForChild("ShopService"))
local HomeService = require(script.Parent:WaitForChild("HomeService"))

local DesignService = {}

DesignService.MaxDesigns = 30

local lastRequest: { [Player]: number } = {}

local function tooFast(player: Player): boolean
	local now = os.clock()
	if lastRequest[player] and now - lastRequest[player] < 0.5 then
		return true
	end
	lastRequest[player] = now
	return false
end

-- 他の人にも見える文字なので、Roblox のフィルターを通す。失敗したら保存しない
local function filterName(player: Player, name: string): string?
	local ok, result = pcall(function()
		local filtered = TextService:FilterStringAsync(name, player.UserId)
		return filtered:GetNonChatStringForBroadcastAsync()
	end)
	if ok and type(result) == "string" then
		return result
	end
	warn("[DesignService] 名前のフィルターに失敗:", result)
	return nil
end

local function sameParts(a: any, b: any): boolean
	if #a ~= #b then
		return false
	end
	for i = 1, #a do
		local p, q = a[i], b[i]
		if p.shape ~= q.shape or p.color ~= q.color or p.material ~= q.material then
			return false
		end
		for _, field in { "size", "pos", "rot" } do
			for j = 1, #p[field] do
				if p[field][j] ~= q[field][j] then
					return false
				end
			end
		end
	end
	return true
end

local function isInUse(profile: any, id: string): boolean
	if (profile.stock[id] or 0) > 0 then
		return true
	end
	for _, shelf in profile.shelves do
		if shelf.designId == id then
			return true
		end
	end
	for _, placed in profile.home do
		if placed.designId == id then
			return true
		end
	end
	return false
end

local function countDesigns(profile: any): number
	local n = 0
	for _, design in profile.designs do
		if not design.boughtFrom then
			n += 1
		end
	end
	return n
end

local function saveDesign(player: Player, raw: any, editId: any): (boolean, string)
	if tooFast(player) then
		return false, "少し待ってからもう一度どうぞ"
	end
	local profile = DataService.Get(player)
	if not profile then
		return false, "データを読み込み中です"
	end
	local design, err = ItemBuilder.Validate(raw, profile.unlocks)
	if not design then
		return false, err or "保存できませんでした"
	end
	local name = filterName(player, design.name)
	if not name then
		return false, "名前を確認できませんでした。もう一度どうぞ"
	end
	design.name = name

	local id: string
	if type(editId) == "string" and profile.designs[editId] and profile.designs[editId].boughtFrom then
		return false, "買ったアイテムは編集できません"
	end
	-- 作り済みの在庫があるデザインは、形を変えると安く作って高く売れてしまうので名前の変更だけにする
	if type(editId) == "string" and profile.designs[editId] and not sameParts(profile.designs[editId].parts, design.parts) then
		if isInUse(profile, editId) then
			return false, "在庫・棚・自宅にあるデザインは形を変えられません。「新しく作る」で別に保存してください"
		end
	end
	if type(editId) == "string" and profile.designs[editId] then
		id = editId
	else
		if countDesigns(profile) >= DesignService.MaxDesigns then
			return false, ("デザインは%d個までです。いらないものを消してください"):format(DesignService.MaxDesigns)
		end
		id = "d" .. profile.nextDesignId
		profile.nextDesignId += 1
		profile.stock[id] = 0
	end
	profile.designs[id] = design
	DataService.Changed(player)
	ShopService.Render(player)
	HomeService.Render(player)
	return true, id
end

local function deleteDesign(player: Player, id: any): (boolean, string)
	local profile = DataService.Get(player)
	if not profile or type(id) ~= "string" or not profile.designs[id] then
		return false, "見つかりません"
	end
	profile.designs[id] = nil
	profile.stock[id] = nil
	profile.designSales[id] = nil
	-- 棚に並べていたら外す
	for slot, shelf in profile.shelves do
		if shelf.designId == id then
			profile.shelves[slot] = nil
		end
	end
	-- 自宅に飾っていたら外す
	for cell, placed in profile.home do
		if placed.designId == id then
			profile.home[cell] = nil
		end
	end
	DataService.Changed(player)
	ShopService.Render(player)
	HomeService.Render(player)
	return true, id
end

function DesignService.Start()
	Net.Function("SaveDesign").OnServerInvoke = function(player, raw, editId)
		local ok, a, b = pcall(saveDesign, player, raw, editId)
		if not ok then
			warn("[DesignService] SaveDesign エラー:", a)
			return false, "エラーが起きました"
		end
		return a, b
	end
	Net.Function("DeleteDesign").OnServerInvoke = function(player, id)
		local ok, a, b = pcall(deleteDesign, player, id)
		if not ok then
			warn("[DesignService] DeleteDesign エラー:", a)
			return false, "エラーが起きました"
		end
		return a, b
	end
	game:GetService("Players").PlayerRemoving:Connect(function(player)
		lastRequest[player] = nil
	end)
end

return DesignService
