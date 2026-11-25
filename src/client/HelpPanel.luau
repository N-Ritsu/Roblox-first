--!strict
-- 遊び方ヘルプ：コイン表示の右の「？」ボタンで開く

local Players = game:GetService("Players")

local UI = require(script.Parent:WaitForChild("UI"))

local HelpPanel = {}

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local TOPICS = {
	{ "アイテムを作る", "左の「工房」で、形・色・素材・大きさ・位置・向きを選んで保存。見本から始めてもOK。「左右反転」で左右対称に、色の🎲でおまかせ配色。プレビューはドラッグで回せる" },
	{ "売る", "工房の「1個」「5個」で在庫を作り、お店の陳列台に近づいて商品と値段を決める。お客さんが買うとコインがもらえる" },
	{ "値段のコツ", "相場（価値）くらいが一番もうかる。安めだと評判（★）が上がり、お客さんが増える。高すぎると帰ってしまう" },
	{ "高く売れるとき", "お客さんの好み・今週のお題（画面下）に合う商品は高く売れる。お金持ち・子ども・コレクターのお客さんもいる。ときどき届く「注文」（画面下）に合う商品が売れるとボーナス" },
	{ "コインの使い道", "「部品」で新しい形・色・素材や部品の数を解放。「お店」で陳列台・内装・ひさし・看板・自宅の壁と床・キャッチコピー・屋根の上の看板商品・チラシ" },
	{ "自宅", "お店の左の壁の「自宅」ドアから。作ったものや買ったもの・もらったものを床と壁に飾れる。飾ったものに近づくとぴょんと跳ねる。友だちを呼ぶとパーティーボーナス" },
	{ "みんなと遊ぶ", "「めぐる」で他の人のお店へ行って買い物（長押しで購入）。プレゼントやフレンド招待もここから" },
	{ "毎日のおたのしみ", "ログインボーナス、留守中の売上、「目標」の報酬、全サーバーランキング（広場の掲示板の裏）" },
}

local panel: Frame

function HelpPanel.Open()
	UI.CloseOtherPanels(HelpPanel.Close)
	panel.Visible = true
end

function HelpPanel.Close()
	panel.Visible = false
end

function HelpPanel.Start()
	UI.RegisterPanel(HelpPanel.Close)
	local gui = Instance.new("ScreenGui")
	gui.Name = "HelpPanel"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 12
	gui.Parent = playerGui

	panel = UI.Frame(gui, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromScale(0.9, 0.8),
		Visible = false,
	})
	UI.Corner(panel, 16)
	UI.Stroke(panel, nil, 3)
	local constraint = Instance.new("UISizeConstraint")
	constraint.MaxSize = Vector2.new(560, 540)
	constraint.Parent = panel
	UI.Label(panel, "遊び方", {
		Size = UDim2.new(1, -80, 0, 34),
		Position = UDim2.new(0, 16, 0, 8),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	local close = UI.Button(panel, "×", UI.Colors.Accent, { Size = UDim2.new(0, 40, 0, 40), Position = UDim2.new(1, -50, 0, 6) })
	close.Activated:Connect(HelpPanel.Close)

	local list = Instance.new("ScrollingFrame")
	list.Size = UDim2.new(1, -24, 1, -62)
	list.Position = UDim2.new(0, 12, 0, 50)
	list.BackgroundColor3 = UI.Colors.PanelDark
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 6
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	UI.Corner(list, 12)
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 6)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Parent = list
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 8)
	padding.PaddingBottom = UDim.new(0, 8)
	padding.Parent = list
	list.Parent = panel

	for i, topic in TOPICS do
		local card = UI.Frame(list, {
			Size = UDim2.new(1, -16, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = Color3.new(1, 1, 1),
			LayoutOrder = i,
		})
		UI.Corner(card, 10)
		local cardLayout = Instance.new("UIListLayout")
		cardLayout.SortOrder = Enum.SortOrder.LayoutOrder
		cardLayout.Padding = UDim.new(0, 2)
		cardLayout.Parent = card
		local cardPadding = Instance.new("UIPadding")
		cardPadding.PaddingTop = UDim.new(0, 6)
		cardPadding.PaddingBottom = UDim.new(0, 8)
		cardPadding.PaddingLeft = UDim.new(0, 10)
		cardPadding.PaddingRight = UDim.new(0, 10)
		cardPadding.Parent = card
		UI.Label(card, topic[1], {
			Size = UDim2.new(1, 0, 0, 24),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = UI.Colors.Accent,
			LayoutOrder = 1,
		})
		-- 本文は折り返して高さを自動で合わせる（TextScaled だと小さくなりすぎるため固定サイズ）
		UI.Label(card, topic[2], {
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			TextScaled = false,
			TextSize = 16,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = 2,
		})
	end

	-- コイン表示の右の「？」ボタン
	local helpGui = Instance.new("ScreenGui")
	helpGui.Name = "HelpButton"
	helpGui.ResetOnSpawn = false
	helpGui.DisplayOrder = 5
	helpGui.Parent = playerGui
	local button = UI.Button(helpGui, "？", Color3.fromRGB(90, 170, 240), {
		Name = "OpenHelp",
		Size = UDim2.new(0, 48, 0, 48),
		Position = UDim2.new(0, 214, 0, 64),
	})
	UI.Stroke(button, Color3.fromRGB(40, 100, 170), 2)
	button.Activated:Connect(function()
		if panel.Visible then
			HelpPanel.Close()
		else
			HelpPanel.Open()
		end
	end)
end

return HelpPanel
