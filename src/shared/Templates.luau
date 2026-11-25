--!strict
-- 工房の見本デザイン（needs がないものは最初から使える部品だけで作ってある）
-- needs = 保存に解放が必要な部品 { shapes = {...}, colors = {...} }（部品ショップで解放する動機づけ）
-- season = その季節の間だけ見せる（解放済みなら季節外でも見せる）
-- くさびは高い面が奥（+Z）で、手前に向かって下る。よこ回転4（180°）で向きが逆になる
-- 円柱は横向き（X方向）が基本なので、rot = {2, 2}（たて90°・よこ90°）で縦向きになる

local function p(shape: string, color: string, material: string, size: { number }, pos: { number }, rot: { number }?)
	return { shape = shape, color = color, material = material, size = size, pos = pos, rot = rot or { 0, 0 } }
end

local UP = { 2, 2 } -- 円柱を縦にする向き
local ALONG_Z = { 0, 2 } -- 円柱を前後方向にする向き

local Templates = {
	{
		name = "いす",
		parts = {
			p("Block", "Brown", "Wood", { 3, 0.5, 3 }, { 0, 1.5, 0 }),
			p("Block", "Brown", "Wood", { 3, 3, 0.5 }, { 0, 3, 1.5 }),
			p("Block", "Brown", "Wood", { 0.5, 1.5, 0.5 }, { -1, 0.5, -1 }),
			p("Block", "Brown", "Wood", { 0.5, 1.5, 0.5 }, { 1, 0.5, -1 }),
			p("Block", "Brown", "Wood", { 0.5, 1.5, 0.5 }, { -1, 0.5, 1 }),
			p("Block", "Brown", "Wood", { 0.5, 1.5, 0.5 }, { 1, 0.5, 1 }),
		},
	},
	{
		name = "つくえ",
		parts = {
			p("Block", "Brown", "Wood", { 4, 0.5, 3 }, { 0, 2.5, 0 }),
			p("Block", "Brown", "Wood", { 0.5, 2.5, 0.5 }, { -1.5, 1, -1 }),
			p("Block", "Brown", "Wood", { 0.5, 2.5, 0.5 }, { 1.5, 1, -1 }),
			p("Block", "Brown", "Wood", { 0.5, 2.5, 0.5 }, { -1.5, 1, 1 }),
			p("Block", "Brown", "Wood", { 0.5, 2.5, 0.5 }, { 1.5, 1, 1 }),
		},
	},
	{
		name = "木",
		parts = {
			p("Cylinder", "Brown", "Wood", { 2.5, 1, 1 }, { 0, 0, 0 }, UP),
			p("Ball", "Green", "Plastic", { 3, 3, 3 }, { 0, 2.5, 0 }),
			p("Ball", "Green", "Plastic", { 2, 2, 2 }, { 0.5, 3, 0.5 }),
		},
	},
	{
		name = "ランプ",
		parts = {
			p("Cylinder", "Black", "SmoothPlastic", { 0.5, 2, 2 }, { 0, 0, 0 }, UP),
			p("Cylinder", "Black", "SmoothPlastic", { 3, 0.5, 0.5 }, { 0, 1.5, 0 }, UP),
			p("Ball", "Yellow", "SmoothPlastic", { 2, 2, 2 }, { 0, 3, 0 }),
		},
	},
	{
		name = "くるま",
		parts = {
			p("Block", "Red", "SmoothPlastic", { 4, 1.5, 2 }, { 0, 1, 0 }),
			p("Block", "White", "SmoothPlastic", { 2, 1, 1.5 }, { -0.5, 2, 0 }),
			p("Cylinder", "Black", "Plastic", { 0.5, 1.5, 1.5 }, { -1.5, 0.5, -1 }, ALONG_Z),
			p("Cylinder", "Black", "Plastic", { 0.5, 1.5, 1.5 }, { 1.5, 0.5, -1 }, ALONG_Z),
			p("Cylinder", "Black", "Plastic", { 0.5, 1.5, 1.5 }, { -1.5, 0.5, 1 }, ALONG_Z),
			p("Cylinder", "Black", "Plastic", { 0.5, 1.5, 1.5 }, { 1.5, 0.5, 1 }, ALONG_Z),
		},
	},
	{
		name = "ゆきだるま",
		parts = {
			p("Ball", "White", "SmoothPlastic", { 3, 3, 3 }, { 0, 0, 0 }),
			p("Ball", "White", "SmoothPlastic", { 2, 2, 2 }, { 0, 2.5, 0 }),
			p("Cylinder", "Black", "SmoothPlastic", { 1, 1.5, 1.5 }, { 0, 3.5, 0 }, UP),
		},
	},
	{
		name = "おうち",
		needs = { shapes = { "Wedge" } },
		parts = {
			p("Block", "White", "Plastic", { 4, 3, 4 }, { 0, 0, 0 }),
			p("Wedge", "Red", "Plastic", { 4, 2, 2 }, { 0, 2.5, -1 }),
			p("Wedge", "Red", "Plastic", { 4, 2, 2 }, { 0, 2.5, 1 }, { 0, 4 }),
			p("Block", "Brown", "Wood", { 1, 2, 0.5 }, { 0, -0.5, -2 }),
			p("Block", "Yellow", "SmoothPlastic", { 1, 1, 0.5 }, { -1.5, 0.5, -2 }),
			p("Block", "Yellow", "SmoothPlastic", { 1, 1, 0.5 }, { 1.5, 0.5, -2 }),
		},
	},
	{
		name = "すべり台",
		needs = { shapes = { "Wedge" } },
		parts = {
			p("Block", "Blue", "SmoothPlastic", { 2, 3, 2 }, { 0, 0, 1 }),
			p("Wedge", "Yellow", "SmoothPlastic", { 2, 3, 3 }, { 0, 0, -1.5 }),
			p("Block", "Red", "SmoothPlastic", { 0.5, 1, 2 }, { -1, 2, 1 }),
			p("Block", "Red", "SmoothPlastic", { 0.5, 1, 2 }, { 1, 2, 1 }),
		},
	},
	{
		name = "クリスマスツリー",
		needs = { colors = { "Holly", "Berry" } },
		season = "winter",
		parts = {
			p("Cylinder", "Brown", "Wood", { 1.5, 1, 1 }, { 0, -3, 0 }, UP),
			p("Ball", "Holly", "Plastic", { 3.5, 3.5, 3.5 }, { 0, -1.5, 0 }),
			p("Ball", "Holly", "Plastic", { 2.5, 2.5, 2.5 }, { 0, 0.5, 0 }),
			p("Ball", "Holly", "Plastic", { 1.5, 1.5, 1.5 }, { 0, 2, 0 }),
			p("Ball", "Yellow", "SmoothPlastic", { 1, 1, 1 }, { 0, 3, 0 }),
			p("Ball", "Berry", "SmoothPlastic", { 0.5, 0.5, 0.5 }, { 1.5, -1.5, -1 }),
		},
	},
	{
		name = "プレゼント箱",
		needs = { colors = { "Berry", "SnowWhite" } },
		season = "winter",
		parts = {
			p("Block", "Berry", "SmoothPlastic", { 3, 2.5, 3 }, { 0, 0, 0 }),
			p("Block", "SnowWhite", "SmoothPlastic", { 0.5, 3, 3.5 }, { 0, 0, 0 }),
			p("Block", "SnowWhite", "SmoothPlastic", { 3.5, 3, 0.5 }, { 0, 0, 0 }),
			p("Ball", "SnowWhite", "SmoothPlastic", { 1, 1, 1 }, { -0.5, 1.5, 0 }),
			p("Ball", "SnowWhite", "SmoothPlastic", { 1, 1, 1 }, { 0.5, 1.5, 0 }),
		},
	},
	{
		name = "そり",
		needs = { colors = { "Berry" } },
		season = "winter",
		parts = {
			p("Block", "Berry", "Wood", { 3, 0.5, 2 }, { 0.5, 1, 0 }),
			p("Block", "Berry", "Wood", { 0.5, 1.5, 2 }, { 2, 1.5, 0 }),
			p("Block", "Yellow", "SmoothPlastic", { 4, 0.5, 0.5 }, { 0, 0, -1 }),
			p("Block", "Yellow", "SmoothPlastic", { 4, 0.5, 0.5 }, { 0, 0, 1 }),
			p("Cylinder", "Yellow", "SmoothPlastic", { 2.5, 1, 1 }, { -2, 0.5, 0 }, ALONG_Z),
			p("Block", "Green", "SmoothPlastic", { 1, 1, 1 }, { 0.5, 1.5, 0 }),
		},
	},
	{
		name = "かまくら",
		needs = { colors = { "SnowWhite" } },
		season = "winter",
		parts = {
			p("Cylinder", "SnowWhite", "Plastic", { 0.5, 4, 4 }, { 0, -1.5, 0 }, UP),
			p("Ball", "SnowWhite", "Plastic", { 4, 4, 4 }, { 0, -0.5, 0 }),
			p("Block", "Black", "Plastic", { 1.5, 1.5, 0.5 }, { 0, -0.5, -1.8 }),
			p("Ball", "Yellow", "SmoothPlastic", { 0.5, 0.5, 0.5 }, { 0, -1, -2 }),
		},
	},
}

return Templates
