--!strict
-- Internal building blocks shared by the Slop components.
--
-- Every surface in this skin is the same short stack of strokes, so they live
-- here once instead of being re-typed in eleven files:
--
--   innerGlow  — soft white bevel just inside the edge
--   outline    — the heavy dark border on a glass surface
--   gemOutline — the same border tinted by a variant gradient
--   fill       — the variant gradient that paints a gem surface
--   textStroke — the dark outline drawn on text glyphs
--
-- Not part of the skin contract; nothing outside this folder requires it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local theme = require(script.Parent.theme)

local parts = {}

-- Soft white glow hugging the inside edge. Drawn below the outline (ZIndex 1)
-- so the dark border always reads on top of it.
function parts.innerGlow(thickness: number?): any
	return React.createElement("UIStroke", {
		Thickness = thickness or theme.innerGlowThickness,
		Transparency = theme.innerGlowTransparency,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		BorderStrokePosition = Enum.BorderStrokePosition.Inner,
		ZIndex = 1,
	})
end

-- The plain dark border on a glass surface (Panel, Badge, TextField, …).
function parts.outline(thickness: number?): any
	return React.createElement("UIStroke", {
		Thickness = thickness or theme.strokeThickness,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		BorderStrokePosition = Enum.BorderStrokePosition.Inner,
		ZIndex = 2,
	})
end

-- The border on a gem surface: a dark stroke with the variant gradient laid
-- over it, so the edge reads as a darkened shade of the fill rather than black.
--
-- Also used on glass surfaces when the caller passes an explicit `variant` —
-- that's how a variant stays visible on primitives whose body is glass.
function parts.gemOutline(variant: theme.Variant, thickness: number?): any
	return React.createElement("UIStroke", {
		Color = theme.outlineColor,
		Thickness = thickness or theme.strokeThickness,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		BorderStrokePosition = Enum.BorderStrokePosition.Inner,
		ZIndex = 2,
	}, {
		UIGradient = React.createElement("UIGradient", {
			Color = variant.color,
			Rotation = variant.rotation,
		}),
	})
end

-- The variant gradient that paints a gem surface. Pair it with a white
-- BackgroundColor3 so the gradient's own colors come through unmodulated.
function parts.fill(variant: theme.Variant): any
	return React.createElement("UIGradient", {
		Color = variant.color,
		Rotation = variant.rotation,
	})
end

-- Outline on text glyphs. `variant` tints it to match a gem surface the text
-- sits on; omit it for the plain dark outline used on glass.
function parts.textStroke(thickness: number?, variant: theme.Variant?): any
	local props: { [string]: any } = {
		Thickness = thickness or theme.textStrokeThickness,
		BorderStrokePosition = Enum.BorderStrokePosition.Inner,
		ZIndex = 2,
	}
	if variant then
		props.Color = theme.outlineColor
		return React.createElement("UIStroke", props, {
			UIGradient = React.createElement("UIGradient", {
				Color = variant.color,
				Rotation = variant.rotation,
			}),
		})
	end
	return React.createElement("UIStroke", props)
end

-- Every label in this skin is TextScaled — text fills its box, which is what
-- gives the skin its chunky look. So this is **opt-in**: it's mounted only when
-- a caller passes an explicit `textSize`, which the contract defines as a size
-- request and this skin honors as a ceiling on the scale-up.
--
-- Do not mount it with a default. A cap on every label silently shrinks the
-- whole skin back to small text.
-- Resolve a role name (or a raw number) to a pixel ceiling on the scale-up,
-- expressed in REAL screen pixels for the given viewport scale.
--
-- That multiplication is the whole point. `UITextSizeConstraint.MaxTextSize` is
-- enforced in absolute pixels and `UIScale` does NOT scale it — measured: at
-- scale 1.0 a capped label filled 98% of its box, at scale 1.5 the box grew to
-- 64px and the text stayed pinned at 42, filling 65%. So a reference-space cap
-- silently shrinks the type as the viewport grows, which reads as "the labels
-- are too small on desktop".
--
-- Multiplying by the scale makes the cap mean "this many REFERENCE pixels of
-- rendered text", matching how every other size in the kit behaves.
function parts.capFor(role: (string | number)?, fallbackRole: string, scale: number?): number
	local reference: number
	if type(role) == "number" then
		reference = role
	else
		local key = if type(role) == "string" then role else fallbackRole
		reference = theme.type[key] or theme.type.body
	end
	return reference * (if scale and scale > 0 then scale else 1)
end

function parts.textSizeCap(maxTextSize: number?): any
	if not maxTextSize then
		return nil
	end
	return React.createElement("UITextSizeConstraint", {
		MaxTextSize = maxTextSize,
	})
end

return parts
