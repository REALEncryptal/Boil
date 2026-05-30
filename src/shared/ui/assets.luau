--!strict
-- Asset IDs and palettes shared by the gem-style UI primitives.
-- Sourced from the Studio template; bump these if the artwork is re-exported.

local Assets = {}

-- Tiled noise texture used as the gem background fill.
Assets.NOISE_TEXTURE = "rbxassetid://127211237265741"

-- Display font (bold/heavy sans-serif) used for all gem text.
Assets.DISPLAY_FONT_ID = "rbxassetid://12187373592"

local function seq(stops: { { time: number, r: number, g: number, b: number } }): ColorSequence
	local kps = {}
	for i, s in ipairs(stops) do
		kps[i] = ColorSequenceKeypoint.new(s.time, Color3.fromRGB(s.r, s.g, s.b))
	end
	return ColorSequence.new(kps)
end

-- Gem color variants. Each variant defines:
--   fill: outer gradient painted over the noise texture
--   glow: inner "glow" border stroke gradient (sits under the shine layer)
Assets.Variants = {
	red = {
		fill = seq({ { time = 0, r = 255, g = 0, b = 166 }, { time = 1, r = 255, g = 33, b = 33 } }),
		glow = seq({ { time = 0, r = 255, g = 108, b = 228 }, { time = 1, r = 255, g = 99, b = 99 } }),
	},
	blue = {
		fill = seq({ { time = 0, r = 0, g = 208, b = 255 }, { time = 1, r = 20, g = 114, b = 255 } }),
		glow = seq({ { time = 0, r = 79, g = 223, b = 255 }, { time = 1, r = 75, g = 162, b = 255 } }),
	},
	green = {
		fill = seq({ { time = 0, r = 0, g = 255, b = 213 }, { time = 1, r = 0, g = 255, b = 102 } }),
		glow = seq({ { time = 0, r = 70, g = 255, b = 249 }, { time = 1, r = 159, g = 255, b = 144 } }),
	},
	purple = {
		fill = seq({ { time = 0, r = 247, g = 0, b = 255 }, { time = 1, r = 162, g = 0, b = 255 } }),
		glow = seq({ { time = 0, r = 255, g = 83, b = 189 }, { time = 1, r = 214, g = 48, b = 255 } }),
	},
	yellow = {
		fill = seq({ { time = 0, r = 255, g = 255, b = 0 }, { time = 1, r = 255, g = 170, b = 0 } }),
		glow = seq({ { time = 0, r = 253, g = 255, b = 143 }, { time = 1, r = 255, g = 221, b = 140 } }),
	},
	white = {
		fill = seq({ { time = 0, r = 196, g = 255, b = 251 }, { time = 1, r = 150, g = 190, b = 226 } }),
		glow = seq({ { time = 0, r = 255, g = 255, b = 255 }, { time = 1, r = 188, g = 244, b = 255 } }),
	},
	rainbow = {
		fill = seq({
			{ time = 0,     r = 255, g = 0,   b = 0 },
			{ time = 0.125, r = 255, g = 127, b = 0 },
			{ time = 0.25,  r = 255, g = 255, b = 0 },
			{ time = 0.375, r = 0,   g = 255, b = 0 },
			{ time = 0.5,   r = 0,   g = 255, b = 255 },
			{ time = 0.625, r = 17,  g = 0,   b = 255 },
			{ time = 0.75,  r = 149, g = 0,   b = 255 },
			{ time = 0.875, r = 255, g = 0,   b = 255 },
			{ time = 1,     r = 255, g = 0,   b = 0 },
		}),
		glow = seq({
			{ time = 0,     r = 255, g = 93,  b = 93 },
			{ time = 0.125, r = 255, g = 178, b = 105 },
			{ time = 0.25,  r = 255, g = 255, b = 135 },
			{ time = 0.375, r = 135, g = 255, b = 135 },
			{ time = 0.5,   r = 105, g = 255, b = 255 },
			{ time = 0.625, r = 115, g = 105, b = 255 },
			{ time = 0.75,  r = 192, g = 105, b = 255 },
			{ time = 0.875, r = 255, g = 105, b = 255 },
			{ time = 1,     r = 255, g = 105, b = 105 },
		}),
	},
}

-- Badge-specific palettes. Badge's blue diverges from Button's blue in the
-- Studio template (slightly different fill stops and a brighter glow), so
-- the lookup is layered: Badge tries `BadgeVariants[key]` first and falls
-- back to `Variants[key]` when no badge-tuning exists.
Assets.BadgeVariants = {
	blue = {
		fill = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 208, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 132, 255)),
		}),
		glow = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(129, 242, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(73, 167, 255)),
		}),
	},
}

-- White diagonal highlight applied as the top stroke on every gem Button.
Assets.SHINE_TRANSPARENCY = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.3),
	NumberSequenceKeypoint.new(0.2, 1),
	NumberSequenceKeypoint.new(1, 1),
})

-- Slightly fading glow stroke used by Badge (faintly transparent at the bottom).
Assets.BADGE_GLOW_TRANSPARENCY = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.0375),
	NumberSequenceKeypoint.new(1, 0.575),
})

export type VariantKey = "red" | "blue" | "green" | "purple" | "yellow" | "white" | "rainbow"

-- Image asset registry. Add new icons here (in kebab/camelCase keys) rather
-- than pasting raw `rbxassetid://…` strings at call sites — keeping the lookup
-- centralized means a re-upload only needs one edit. Icons are referenced as
-- `ui.assets.Icons.<key>` and produce the full `rbxassetid://…` string.
Assets.Icons = {
	rebirth = "rbxassetid://93321219154443",
	bandOfCash = "rbxassetid://73079263760001",
	shoppingBasket = "rbxassetid://117006057996408",
	questionMark = "rbxassetid://120234519496461",
	friends = "rbxassetid://128905070355613",
	wheel = "rbxassetid://92211074359779",
	rocket = "rbxassetid://137349421699691",
	book = "rbxassetid://76948871632136",
}

-- Brainrot character image icons. Kept separate from `Icons` because they're
-- character art rather than UI symbols — different visual language, different
-- intended uses (cards, collectibles, banners), no overlap with the icon set.
Assets.Brainrots = {
	tungTungTungSahur = "rbxassetid://96425337367679",
	liriliLarila = "rbxassetid://104842983573914",
	trippiTroppi = "rbxassetid://108224067442222",
	tralaleroTralala = "rbxassetid://98753768070862",
}

export type IconKey =
	"rebirth" | "bandOfCash" | "shoppingBasket" | "questionMark"
	| "friends" | "wheel" | "rocket" | "book"

export type BrainrotKey =
	"tungTungTungSahur" | "liriliLarila" | "trippiTroppi" | "tralaleroTralala"

return Assets
