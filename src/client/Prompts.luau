--!strict
-- 店のプロンプトの見え方を、自分の店か他の人の店かで切り替える（この画面の中だけの変更）
-- 自分の店：工房・棚に並べる・自宅  ／  他の人の店：棚から「買う」だけ

local Players = game:GetService("Players")

local Prompts = {}

local player = Players.LocalPlayer

local function apply(prompt: ProximityPrompt, mine: boolean, occupied: boolean)
	if prompt.Name == "ShelfPrompt" then
		-- まだ増やしていない陳列台（Locked）は誰にも出さない
		prompt.Enabled = (mine or occupied) and not prompt:GetAttribute("Locked")
		prompt.ActionText = if mine then "棚に並べる" else "買う"
		prompt.HoldDuration = if mine then 0 else 0.4 -- 間違って買わないよう少し長押し
	elseif prompt.Name == "WorkbenchPrompt" or prompt.Name == "HomeDecorPrompt" then
		prompt.Enabled = mine
	elseif prompt.Name == "HomeEnterPrompt" then
		-- 他の人の自宅は、公開されていれば入れる
		local plot = prompt:FindFirstAncestor("Plots")
		local plotModel = prompt.Parent and prompt.Parent.Parent
		prompt.Enabled = mine or (plot ~= nil and plotModel ~= nil and plotModel:GetAttribute("HomePublic") == true)
		prompt.ActionText = if mine then "自宅に入る" else "おじゃまする"
	elseif prompt.Name == "HomeLikePrompt" then
		prompt.Enabled = occupied and not mine
	end
end

local watched: { [ProximityPrompt]: boolean } = {}

local function watchPlot(plot: Instance)
	local function refresh()
		local owner = plot:GetAttribute("OwnerUserId")
		local mine = owner == player.UserId
		for _, descendant in plot:GetDescendants() do
			if descendant:IsA("ProximityPrompt") then
				apply(descendant, mine, owner ~= nil)
			end
		end
	end
	plot:GetAttributeChangedSignal("OwnerUserId"):Connect(refresh)
	plot:GetAttributeChangedSignal("HomePublic"):Connect(refresh)
	local function watchLock(prompt: ProximityPrompt)
		if prompt.Name ~= "ShelfPrompt" or watched[prompt] then
			return
		end
		watched[prompt] = true
		prompt:GetAttributeChangedSignal("Locked"):Connect(function()
			local owner = plot:GetAttribute("OwnerUserId")
			apply(prompt, owner == player.UserId, owner ~= nil)
		end)
		prompt.Destroying:Connect(function()
			watched[prompt] = nil
		end)
	end
	for _, descendant in plot:GetDescendants() do
		if descendant:IsA("ProximityPrompt") then
			watchLock(descendant)
		end
	end
	-- StreamingEnabled で後から届くプロンプトにも反映する
	plot.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("ProximityPrompt") then
			watchLock(descendant)
			local owner = plot:GetAttribute("OwnerUserId")
			apply(descendant, owner == player.UserId, owner ~= nil)
		end
	end)
	refresh()
end

function Prompts.Start()
	local plots = workspace:WaitForChild("Plots")
	for _, plot in plots:GetChildren() do
		watchPlot(plot)
	end
	plots.ChildAdded:Connect(watchPlot)
end

return Prompts
