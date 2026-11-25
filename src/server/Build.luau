--!strict
-- パーツをまとめて作るための小さな補助

local Build = {}

export type PartProps = {
	Name: string?,
	Size: Vector3,
	CFrame: CFrame,
	Color: Color3?,
	Material: Enum.Material?,
	Transparency: number?,
	CanCollide: boolean?,
	Shape: Enum.PartType?,
	CastShadow: boolean?,
}

function Build.Part(parent: Instance, props: PartProps, className: string?): BasePart
	local part = Instance.new((className or "Part") :: any) :: BasePart
	part.Name = props.Name or "Part"
	part.Anchored = true
	part.Size = props.Size
	part.CFrame = props.CFrame
	part.Color = props.Color or Color3.fromRGB(200, 200, 200)
	part.Material = props.Material or Enum.Material.SmoothPlastic
	part.Transparency = props.Transparency or 0
	if props.CanCollide ~= nil then
		part.CanCollide = props.CanCollide
	end
	if props.CastShadow ~= nil then
		part.CastShadow = props.CastShadow
	end
	if props.Shape and part:IsA("Part") then
		part.Shape = props.Shape
	end
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

-- 板の正面に文字を出す
function Build.Sign(part: BasePart, text: string, face: Enum.NormalId?, textColor: Color3?): TextLabel
	local gui = Instance.new("SurfaceGui")
	gui.Face = face or Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = textColor or Color3.new(1, 1, 1)
	label.Text = text
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0.04, 0)
	padding.PaddingRight = UDim.new(0.04, 0)
	padding.PaddingTop = UDim.new(0.1, 0)
	padding.PaddingBottom = UDim.new(0.1, 0)
	padding.Parent = label
	label.Parent = gui
	gui.Parent = part
	return label
end

return Build
