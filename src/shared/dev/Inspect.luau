--!strict
-- Studio property dumper for shared/ui scaffolding.
--
-- Usage from the command bar (after selecting one or more instances in
-- Explorer):
--
--   require(game.ReplicatedStorage.Shared.dev.Inspect)()
--
-- Walks each selected instance recursively, records non-default properties
-- for every known GUI / UI-effect class, formats them in Luau-readable
-- syntax, prints to Output, and copies the dump to the clipboard for
-- pasting back to Claude.
--
-- You can also pass an explicit target:
--   require(game.ReplicatedStorage.Shared.dev.Inspect)(workspace.SomeGui.Frame)

local Selection = game:GetService("Selection")

local frameProps = {
	"Size", "Position", "AnchorPoint",
	"BackgroundColor3", "BackgroundTransparency",
	"BorderSizePixel", "ZIndex", "LayoutOrder",
	"ClipsDescendants", "AutomaticSize",
	"Rotation", "Visible",
}
local textProps = {
	"Text", "TextColor3", "TextSize", "FontFace",
	"TextScaled", "TextWrapped", "TextTransparency",
	"TextStrokeTransparency", "TextStrokeColor3",
	"TextXAlignment", "TextYAlignment", "RichText",
	"LineHeight", "TextTruncate", "MaxVisibleGraphemes",
}
local imgProps = {
	"Image", "ImageColor3", "ImageTransparency",
	"ImageRectOffset", "ImageRectSize", "ScaleType",
	"SliceCenter", "SliceScale", "TileSize", "ResampleMode",
}
local btnProps = { "AutoButtonColor", "Modal" }

local function merge(...): { string }
	local out = {}
	for _, list in ipairs({ ... }) do
		for _, v in ipairs(list) do
			table.insert(out, v)
		end
	end
	return out
end

local PROPS: { [string]: { string } } = {
	ScreenGui = {
		"DisplayOrder", "Enabled", "IgnoreGuiInset",
		"ResetOnSpawn", "ZIndexBehavior",
	},
	Frame = frameProps,
	TextLabel = merge(frameProps, textProps),
	TextButton = merge(frameProps, textProps, btnProps),
	TextBox = merge(frameProps, textProps),
	ImageLabel = merge(frameProps, imgProps),
	ImageButton = merge(frameProps, imgProps, btnProps),
	ScrollingFrame = merge(frameProps, {
		"CanvasSize", "CanvasPosition", "ScrollingDirection",
		"ScrollBarThickness", "ScrollBarImageColor3",
		"VerticalScrollBarInset", "HorizontalScrollBarInset",
		"TopImage", "MidImage", "BottomImage",
		"ElasticBehavior", "ScrollingEnabled",
	}),
	UIStroke = {
		"Color", "Thickness", "Transparency",
		"ApplyStrokeMode", "LineJoinMode", "Enabled",
		"ZIndex", "StrokeSizingMode",
		"BorderOffset", "BorderStrokePosition",
	},
	UIGradient = {
		"Color", "Transparency",
		"Offset", "Rotation", "Enabled",
	},
	UIListLayout = {
		"FillDirection", "Padding", "SortOrder",
		"HorizontalAlignment", "VerticalAlignment",
		"HorizontalFlex", "VerticalFlex",
		"Wraps", "ItemLineAlignment",
	},
	UIGridLayout = {
		"CellSize", "CellPadding", "FillDirection",
		"FillDirectionMaxCells", "SortOrder", "StartCorner",
		"HorizontalAlignment", "VerticalAlignment",
	},
	UIPadding = {
		"PaddingTop", "PaddingBottom",
		"PaddingLeft", "PaddingRight",
	},
	UIAspectRatioConstraint = {
		"AspectRatio", "AspectType", "DominantAxis",
	},
	UICorner = { "CornerRadius" },
	UIScale = { "Scale" },
	UIFlexItem = {
		"FlexMode", "GrowRatio", "ShrinkRatio",
		"ItemLineAlignment",
	},
	UISizeConstraint = { "MinSize", "MaxSize" },
	UITextSizeConstraint = { "MinTextSize", "MaxTextSize" },
}

local function rgb(c: Color3): (number, number, number)
	return math.floor(c.R * 255 + 0.5),
		math.floor(c.G * 255 + 0.5),
		math.floor(c.B * 255 + 0.5)
end

local function fmt(v: any): string
	if v == nil then
		return "<unset>"
	end
	local t = typeof(v)
	if t == "UDim2" then
		return string.format(
			"UDim2.new(%g, %g, %g, %g)",
			v.X.Scale, v.X.Offset, v.Y.Scale, v.Y.Offset
		)
	elseif t == "UDim" then
		return string.format("UDim.new(%g, %g)", v.Scale, v.Offset)
	elseif t == "Vector2" then
		return string.format("Vector2.new(%g, %g)", v.X, v.Y)
	elseif t == "Color3" then
		local r, g, b = rgb(v)
		return string.format("Color3.fromRGB(%d, %d, %d)", r, g, b)
	elseif t == "Rect" then
		return string.format(
			"Rect.new(%g, %g, %g, %g)",
			v.Min.X, v.Min.Y, v.Max.X, v.Max.Y
		)
	elseif t == "ColorSequence" then
		local p = {}
		for _, k in ipairs(v.Keypoints) do
			local r, g, b = rgb(k.Value)
			table.insert(p, string.format(
				"%g=rgb(%d,%d,%d)", k.Time, r, g, b
			))
		end
		return "ColorSequence[" .. table.concat(p, " | ") .. "]"
	elseif t == "NumberSequence" then
		local p = {}
		for _, k in ipairs(v.Keypoints) do
			table.insert(p, string.format("%g=%g", k.Time, k.Value))
		end
		return "NumberSequence[" .. table.concat(p, " | ") .. "]"
	elseif t == "EnumItem" then
		return tostring(v)
	elseif t == "Font" then
		return string.format(
			"Font(%s | w=%s | s=%s)",
			tostring(v.Family),
			tostring(v.Weight.Name),
			tostring(v.Style.Name)
		)
	elseif t == "string" then
		return string.format("%q", v)
	else
		return tostring(v)
	end
end

local function eq(a: any, b: any): boolean
	if typeof(a) ~= typeof(b) then
		return false
	end
	local t = typeof(a)
	if t == "ColorSequence" or t == "NumberSequence" or t == "Font" then
		return fmt(a) == fmt(b)
	end
	return a == b
end

local defaults: { [string]: any } = {}
local function getDefault(cn: string): Instance?
	if defaults[cn] == nil then
		local ok, i = pcall(Instance.new, cn)
		defaults[cn] = if ok then i else false
	end
	local d = defaults[cn]
	if d == false then
		return nil
	end
	return d
end

local function walk(inst: Instance, depth: number, lines: { string })
	local indent = string.rep("  ", depth)
	table.insert(lines, string.format(
		"%s%s <%s>", indent, inst.Name, inst.ClassName
	))
	local plist = PROPS[inst.ClassName]
	if plist then
		local d = getDefault(inst.ClassName)
		for _, prop in ipairs(plist) do
			local ok, val = pcall(function()
				return (inst :: any)[prop]
			end)
			if ok then
				local skip = false
				if d then
					local ok2, dv = pcall(function()
						return (d :: any)[prop]
					end)
					if ok2 and eq(val, dv) then
						skip = true
					end
				end
				if not skip then
					table.insert(lines, string.format(
						"%s  %s = %s",
						indent, prop, fmt(val)
					))
				end
			end
		end
	end
	for _, c in ipairs(inst:GetChildren()) do
		walk(c, depth + 1, lines)
	end
end

return function(target: Instance?)
	local roots: { Instance }
	if target then
		roots = { target }
	else
		roots = Selection:Get()
		if #roots == 0 then
			warn("[Inspect] Select one or more instances in the Explorer first.")
			return
		end
	end

	local lines: { string } = {}
	for _, root in ipairs(roots) do
		walk(root, 0, lines)
		table.insert(lines, "---")
	end

	local result = table.concat(lines, "\n")
	if setclipboard then
		(setclipboard :: any)(result)
		print(string.format(
			"[Inspect] Copied %d lines to clipboard. Paste into Claude.",
			#lines
		))
	else
		print(result)
	end
end
