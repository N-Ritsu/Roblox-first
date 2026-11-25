--!strict
-- 広場の「人気のお店」ランキング掲示板（このサーバーにいる人の、売った数の多い順）

local Players = game:GetService("Players")

local DataService = require(script.Parent:WaitForChild("DataService"))
local Build = require(script.Parent:WaitForChild("Build"))
local WorldService = require(script.Parent:WaitForChild("WorldService"))

local RankingService = {}

RankingService.Shown = 6

function RankingService.Start()
	local board = Build.Part(workspace:WaitForChild("Plaza"), {
		Name = "RankingBoard",
		Size = Vector3.new(14, 10, 0.6),
		-- 広場の外周（店への道を避けた場所）に、噴水の方を向けて立てる
		CFrame = CFrame.lookAt(WorldService.SpotPosition(WorldService.RankingSpot, 22) + Vector3.new(0, 7, 0), Vector3.new(0, 7, 0)),
		Color = Color3.fromRGB(120, 80, 55),
		Material = Enum.Material.Wood,
	})
	for _, x in { -6, 6 } do
		Build.Part(workspace.Plaza, {
			Name = "BoardLeg",
			Size = Vector3.new(0.6, 3, 0.6),
			CFrame = board.CFrame * CFrame.new(x, -6.5, 0),
			Color = Color3.fromRGB(90, 60, 40),
			Material = Enum.Material.Wood,
		})
	end
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.LightInfluence = 0
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0, 4)
	layout.Parent = gui
	local function line(order: number, text: string, color: Color3, height: number): TextLabel
		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(0.92, 0, 0, height)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.TextColor3 = color
		label.Text = text
		label.LayoutOrder = order
		label.Parent = gui
		return label
	end
	line(0, "人気のお店ランキング", Color3.fromRGB(255, 220, 90), 56)
	local rows = {}
	for i = 1, RankingService.Shown do
		rows[i] = line(i, "", Color3.new(1, 1, 1), 36)
	end
	gui.Parent = board

	task.spawn(function()
		while true do
			local entries = {}
			for _, player in Players:GetPlayers() do
				local profile = DataService.Get(player)
				if profile then
					table.insert(entries, { name = player.DisplayName, sold = profile.stats.sold })
				end
			end
			table.sort(entries, function(a, b)
				return a.sold > b.sold
			end)
			for i, row in rows do
				local entry = entries[i]
				row.Text = if entry then ("%d位　%s のお店　%d個"):format(i, entry.name, entry.sold) else ""
			end
			if #entries == 0 then
				rows[1].Text = "まだだれもいません"
			end
			task.wait(10)
		end
	end)
end

return RankingService
