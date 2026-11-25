--!strict
-- 季節イベントの期間（日本時間の日付で自動的に切り替わる）

local Season = {}

-- 日本時間の今日の月・日
function Season.TodayJST(): (number, number)
	local t = os.date("!*t", math.floor(workspace:GetServerTimeNow()) + 9 * 3600) :: any
	return t.month, t.day
end

-- 冬のイベント：12月1日〜1月7日
function Season.IsActive(season: string?): boolean
	if season == nil then
		return true
	end
	if season == "winter" then
		local month, day = Season.TodayJST()
		return month == 12 or (month == 1 and day <= 7)
	end
	return false
end

return Season
