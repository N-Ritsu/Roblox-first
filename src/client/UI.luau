--!strict
-- UI 部品を同じ見た目で作るための補助

local UI = {}

UI.Colors = {
	Panel = Color3.fromRGB(255, 248, 235),
	PanelDark = Color3.fromRGB(240, 228, 205),
	Text = Color3.fromRGB(70, 50, 40),
	Accent = Color3.fromRGB(240, 120, 80),
	Good = Color3.fromRGB(90, 185, 110),
	Muted = Color3.fromRGB(170, 160, 150),
	Coin = Color3.fromRGB(250, 200, 60),
}
UI.Font = Enum.Font.FredokaOne

function UI.Corner(parent: Instance, radius: number?)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or 12)
	corner.Parent = parent
end

function UI.Stroke(parent: Instance, color: Color3?, thickness: number?)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color or Color3.fromRGB(120, 85, 60)
	stroke.Thickness = thickness or 2
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = parent
end

function UI.Frame(parent: Instance, props: { [string]: any }?): Frame
	local frame = Instance.new("Frame")
	frame.BackgroundColor3 = UI.Colors.Panel
	frame.BorderSizePixel = 0
	for k, v in props or {} do
		(frame :: any)[k] = v
	end
	frame.Parent = parent
	return frame
end

function UI.Label(parent: Instance, text: string, props: { [string]: any }?): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Font = UI.Font
	label.TextColor3 = UI.Colors.Text
	label.TextScaled = true
	label.Text = text
	for k, v in props or {} do
		(label :: any)[k] = v
	end
	label.Parent = parent
	return label
end

function UI.Button(parent: Instance, text: string, color: Color3?, props: { [string]: any }?): TextButton
	local button = Instance.new("TextButton")
	button.BackgroundColor3 = color or UI.Colors.Accent
	button.BorderSizePixel = 0
	button.AutoButtonColor = true
	button.Font = UI.Font
	button.TextColor3 = Color3.new(1, 1, 1)
	button.TextScaled = true
	button.Text = text
	UI.Corner(button, 10)
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 4)
	padding.PaddingBottom = UDim.new(0, 4)
	padding.PaddingLeft = UDim.new(0, 6)
	padding.PaddingRight = UDim.new(0, 6)
	padding.Parent = button
	for k, v in props or {} do
		(button :: any)[k] = v
	end
	button.Parent = parent
	return button
end

-- 画面上部に短いお知らせを出す
local toastGui: ScreenGui? = nil
function UI.Toast(playerGui: Instance, text: string, color: Color3?)
	if not toastGui or not toastGui.Parent then
		local gui = Instance.new("ScreenGui")
		gui.Name = "Toasts"
		gui.ResetOnSpawn = false
		gui.DisplayOrder = 50
		local list = Instance.new("UIListLayout")
		list.HorizontalAlignment = Enum.HorizontalAlignment.Center
		list.Padding = UDim.new(0, 6)
		list.SortOrder = Enum.SortOrder.LayoutOrder
		local holder = Instance.new("Frame")
		holder.Name = "Holder"
		holder.BackgroundTransparency = 1
		holder.Size = UDim2.new(0, 360, 0, 300)
		holder.Position = UDim2.new(0.5, -180, 0, 70)
		list.Parent = holder
		holder.Parent = gui
		gui.Parent = playerGui
		toastGui = gui
	end
	local holder = (toastGui :: ScreenGui):FindFirstChild("Holder") :: Frame
	local toast = UI.Label(holder, text, {
		Size = UDim2.new(1, 0, 0, 36),
		BackgroundTransparency = 0.05,
		BackgroundColor3 = color or UI.Colors.Text,
		TextColor3 = Color3.new(1, 1, 1),
		LayoutOrder = math.floor(os.clock() * 1000),
	})
	UI.Corner(toast, 10)
	task.delay(3, function()
		toast:Destroy()
	end)
end

return UI
