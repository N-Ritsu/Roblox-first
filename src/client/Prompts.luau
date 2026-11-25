--!strict
-- 店のプロンプトの見え方を、自分の店か他の人の店かで切り替える（この画面の中だけの変更）
-- 自分の店：工房・棚に並べる・自宅  ／  他の人の店：棚から「買う」だけ

local Players = game:GetService("Players")

local Prompts = {}

local player = Players.LocalPlayer

local function apply(prompt: ProximityPrompt, mine: boolean, occupied: boolean)
	if prompt.Name == "ShelfPrompt" then
		prompt.Enabled = mine or occupied
		prompt.ActionText = if mine then "棚に並べる" else "買う"
		prompt.HoldDuration = if mine then 0 else 0.4 -- 間違って買わないよう少し長押し
	elseif prompt.Name == "WorkbenchPrompt" or prompt.Name == "HomeEnterPrompt" then
		prompt.Enabled = mine
	end
end

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
	-- StreamingEnabled で後から届くプロンプトにも反映する
	plot.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("ProximityPrompt") then
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
