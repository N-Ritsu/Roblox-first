--!strict
-- 自宅で遊べる：飾ったアイテムに近づくと、ぴょんと跳ねて光る（見た目だけ。自分の画面の中だけで動く）

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Sounds = require(script.Parent:WaitForChild("Sounds"))

local DecorFun = {}

local TOUCH_RANGE = 3.5 -- この距離まで近づくと反応する
local COOLDOWN = 1.5 -- 同じアイテムが続けて反応しない時間
local BOUNCE_TIME = 0.45
local BOUNCE_HEIGHT = 1.2

local lastBounce: { [Model]: number } = {}
local bouncing: { [Model]: boolean } = {}
local wasNear: { [Model]: boolean } = {} -- 近づいた瞬間だけ反応させる（そばに立ち続けても跳ね続けない）

local function sparkle(model: Model)
	local _, size = model:GetBoundingBox()
	local holder = Instance.new("Part")
	holder.Name = "DecorSparkle"
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.Transparency = 1
	holder.Size = Vector3.new(1, 1, 1)
	holder.CFrame = model:GetPivot() * CFrame.new(0, size.Y / 2, 0)
	local light = Instance.new("PointLight")
	light.Range = 8
	light.Brightness = 2
	light.Color = Color3.fromRGB(255, 230, 150)
	light.Parent = holder
	local particles = Instance.new("ParticleEmitter")
	particles.Rate = 0
	particles.Lifetime = NumberRange.new(0.5, 0.9)
	particles.Speed = NumberRange.new(3, 6)
	particles.SpreadAngle = Vector2.new(180, 180)
	particles.Size = NumberSequence.new(0.35, 0)
	particles.Color = ColorSequence.new(Color3.fromRGB(255, 240, 160), Color3.fromRGB(255, 180, 220))
	particles.LightEmission = 1
	particles.Parent = holder
	holder.Parent = workspace
	particles:Emit(14)
	task.delay(1, function()
		holder:Destroy()
	end)
end

local function bounce(model: Model)
	if bouncing[model] then
		return
	end
	bouncing[model] = true
	lastBounce[model] = os.clock()
	local base = model:GetPivot()
	sparkle(model)
	Sounds.Play("click")
	local started = os.clock()
	local connection: RBXScriptConnection? = nil
	connection = RunService.RenderStepped:Connect(function()
		local t = (os.clock() - started) / BOUNCE_TIME
		if t >= 1 or not model.Parent then
			if model.Parent then
				model:PivotTo(base)
			end
			bouncing[model] = nil
			if connection then
				connection:Disconnect()
			end
			return
		end
		-- 上に跳ねて、少しだけ回る
		local height = math.sin(t * math.pi) * BOUNCE_HEIGHT
		model:PivotTo(base * CFrame.new(0, height, 0) * CFrame.Angles(0, math.sin(t * math.pi) * 0.4, 0))
	end)
end

-- 屋根の上の看板商品をゆっくり回す（見た目だけ）
local function spinFeatured(plots: Instance)
	local base: { [Model]: CFrame } = {}
	local angle = 0
	RunService.RenderStepped:Connect(function(dt)
		angle = (angle + dt * 0.8) % (2 * math.pi)
		for _, plot in plots:GetChildren() do
			local displays = plot:FindFirstChild("Displays")
			local item = displays and displays:FindFirstChild("Featured")
			if item and item:IsA("Model") then
				if not base[item] then
					base[item] = item:GetPivot()
				end
				item:PivotTo(base[item] * CFrame.new(0, math.sin(angle * 2) * 0.3, 0) * CFrame.Angles(0, angle, 0))
			end
		end
		for item in base do
			if not item.Parent then
				base[item] = nil
			end
		end
	end)
end

-- 自宅の灯りが「パーティー」なら、灯りの色をゆっくり虹色に変える（見た目だけ）
local function partyLights(plots: Instance)
	task.spawn(function()
		while true do
			task.wait(0.1)
			local hue = (os.clock() * 0.15) % 1
			for _, plot in plots:GetChildren() do
				local home = plot:FindFirstChild("Home")
				if home and home:GetAttribute("LightMode") == "party" then
					local color = Color3.fromHSV(hue, 0.45, 1)
					for _, lamp in home:GetChildren() do
						if lamp.Name == "Lamp" and lamp:IsA("BasePart") then
							lamp.Color = color
							local light = lamp:FindFirstChildOfClass("PointLight")
							if light then
								light.Color = color
							end
						end
					end
				end
			end
		end
	end)
end

function DecorFun.Start()
	local player = Players.LocalPlayer
	local plots = workspace:WaitForChild("Plots")
	spinFeatured(plots)
	partyLights(plots)
	while true do
		task.wait(0.15)
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			local position = root.Position
			for _, plot in plots:GetChildren() do
				local home = plot:FindFirstChild("Home")
				local decor = home and home:FindFirstChild("Decor")
				if decor then
					for _, item in decor:GetChildren() do
						if item:IsA("Model") and not bouncing[item] then
							local pivot = item:GetPivot().Position
							local flat = Vector3.new(pivot.X - position.X, 0, pivot.Z - position.Z).Magnitude
							local near = flat < TOUCH_RANGE and math.abs(pivot.Y - position.Y) < 6
							if near and not wasNear[item] and os.clock() - (lastBounce[item] or 0) > COOLDOWN then
								bounce(item)
							end
							wasNear[item] = near or nil
						end
					end
				end
			end
			-- 消えたアイテムの記録を片付ける
			for item in lastBounce do
				if not item.Parent then
					lastBounce[item] = nil
				end
			end
			for item in wasNear do
				if not item.Parent then
					wasNear[item] = nil
				end
			end
		end
	end
end

return DecorFun
