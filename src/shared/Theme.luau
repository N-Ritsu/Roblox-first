--!strict
-- 今週のお題：週ごと（日本時間の月曜はじまり）に変わるテーマ。合う商品はお客さんが高く買う

local Catalog = require(script.Parent:WaitForChild("Catalog"))

local Theme = {}

export type ThemeEntry = { field: string, id: string }

Theme.List = {
	{ field = "color", id = "Blue" },
	{ field = "shape", id = "Ball" },
	{ field = "material", id = "Wood" },
	{ field = "color", id = "Red" },
	{ field = "shape", id = "Cylinder" },
	{ field = "color", id = "Yellow" },
	{ field = "material", id = "Metal" },
	{ field = "color", id = "Green" },
	{ field = "material", id = "Glass" },
	{ field = "color", id = "Pink" },
	{ field = "shape", id = "Wedge" },
	{ field = "material", id = "Neon" },
} :: { ThemeEntry }

Theme.Bonus = 1.3 -- お題に合う商品の、払ってもいい額の倍率

-- 1970/1/1 は木曜なので、月曜はじまりにするため3日ずらす
local function weekIndex(): number
	-- クライアントの時計がずれていてもサーバーと同じ週になるよう、サーバー時刻を使う
	local jst = math.floor(workspace:GetServerTimeNow()) + 9 * 3600
	return math.floor((jst + 3 * 86400) / (7 * 86400))
end

function Theme.Current(): ThemeEntry
	return Theme.List[weekIndex() % #Theme.List + 1]
end

function Theme.Text(theme: ThemeEntry): string
	local name = "?"
	if theme.field == "color" then
		local e = Catalog.ColorById[theme.id]
		name = if e then ("「%s」を使ったもの"):format(e.name) else name
	elseif theme.field == "shape" then
		local e = Catalog.ShapeById[theme.id]
		name = if e then ("「%s」が入ったもの"):format(e.name) else name
	else
		local e = Catalog.MaterialById[theme.id]
		name = if e then ("「%s」でできたもの"):format(e.name) else name
	end
	return name
end

function Theme.Matches(design: any, theme: ThemeEntry): boolean
	for _, part in design.parts do
		if part[theme.field] == theme.id then
			return true
		end
	end
	return false
end

return Theme
