--!strict
-- 工房の見本デザイン（最初から使える部品だけで作ってある）
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
}

return Templates
