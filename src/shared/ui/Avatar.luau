--!strict
-- Avatar — a player's headshot in a rounded frame with an outline.
--
-- Content, not a surface, so like Icon it is NOT skin-resolved: a profile
-- picture is the same picture under every skin, and the ring around it is a
-- border the caller colours — black by default, the game's accent for "this is
-- you". What a skin DOES supply is the ring's weight: `theme.strokeThickness`,
-- read through useSkin so the ring matches every other outline in the kit.
-- Safe from the skin cycle for the same reason Counter is: no skin lists
-- Avatar, so nothing under skins/ requires this file.
--
--   React.createElement(ui.Avatar, {
--       userId = player.UserId,
--       size = UDim2.fromOffset(96, 96),
--       strokeColor = Color3.fromRGB(0, 0, 0),
--   })
--
-- The image is Roblox's own `rbxthumb://` headshot, which loads without a yield
-- and works in edit mode, so a story shows a real face. It is always square: the
-- box you give it is a MAXIMUM and a square is fitted inside it, centred on the
-- anchor. So inside a proportional container give it the full width and the
-- height you want — `UDim2.fromScale(1, 0.6)` — never a zero width: a zero-wide
-- box fits a zero-wide square, which reads as the avatar simply not rendering.
--
-- Sizes are REFERENCE pixels inside a Surface, like everything else — or scale
-- inside a BillboardGui sized in studs, where the ring's pixel thickness stays
-- put while the picture shrinks with distance.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local SkinProvider = require(script.Parent.SkinProvider)

export type AvatarProps = {
	userId: number,
	size: UDim2?,
	position: UDim2?,
	anchorPoint: Vector2?,
	layoutOrder: number?,
	zIndex: number?,
	-- The ring. Colour defaults to black; thickness to the skin's outline weight.
	strokeColor: Color3?,
	strokeThickness: number?,
	-- Corner rounding. Defaults to a full circle.
	cornerRadius: UDim?,
	-- The disc behind the picture. Headshots ship with a transparent
	-- background, so this is what shows around the head.
	backgroundColor: Color3?,
	backgroundTransparency: number?,
	-- Resolution Roblox renders the thumbnail at: 48, 60, 100, 150, 180, 352
	-- or 420. Any other number returns nothing.
	thumbnailSize: number?,
}

local DEFAULT_STROKE = Color3.fromRGB(0, 0, 0)
local DEFAULT_BACKGROUND = Color3.fromRGB(38, 40, 48)
local DEFAULT_THUMBNAIL = 180
-- Only reached under a skin that declares no outline weight of its own.
local FALLBACK_THICKNESS = 2

local function headshot(userId: number, size: number): string
	return `rbxthumb://type=AvatarHeadShot&id={userId}&w={size}&h={size}`
end
return function(props: AvatarProps)
	local skin = SkinProvider.useSkin()
	local thickness = props.strokeThickness or skin.theme.strokeThickness or FALLBACK_THICKNESS

	return React.createElement("ImageLabel", {
		Image = headshot(props.userId, props.thumbnailSize or DEFAULT_THUMBNAIL),
		ScaleType = Enum.ScaleType.Fit,
		Size = props.size or UDim2.fromScale(1, 1),
		Position = props.position,
		AnchorPoint = props.anchorPoint,
		LayoutOrder = props.layoutOrder,
		ZIndex = props.zIndex,
		BackgroundColor3 = props.backgroundColor or DEFAULT_BACKGROUND,
		BackgroundTransparency = props.backgroundTransparency or 0,
		BorderSizePixel = 0,
	}, {
		-- Default AspectType (FitWithinMaxSize): `size` is the ceiling and the
		-- square fits inside it.
		Aspect = React.createElement("UIAspectRatioConstraint", {
			AspectRatio = 1,
		}),
		Corner = React.createElement("UICorner", {
			CornerRadius = props.cornerRadius or UDim.new(0.5, 0),
		}),
		Ring = React.createElement("UIStroke", {
			Color = props.strokeColor or DEFAULT_STROKE,
			Thickness = thickness,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
	})
end
