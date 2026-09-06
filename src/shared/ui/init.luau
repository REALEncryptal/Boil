-- Shared UI primitives. Consume from features as:
--
--   local ui = require(ReplicatedStorage.Shared.ui)
--   React.createElement(ui.Button, { variant = "red", text = "X", onClick = … })
--
-- Each `ui.X` is a *semantic* component: at render it resolves the active skin
-- from React context (see SkinProvider) and renders that skin's implementation,
-- passing props (including the named-children slot) straight through. With no
-- <SkinProvider> mounted it falls back to the "gem" skin, so call sites and UI
-- Labs stories work unchanged.
--
-- The prop shapes every primitive speaks are the *contract* (`ui.contract`) —
-- the keystone. Skins implement those shapes; `variant` and tokens are per-skin.
--
-- Available skins live in `ui.skins` — the built-in gem and flat plus anything
-- installed under src/skins/ (`ui.skins.names()`). Wrap a subtree to swap:
--   React.createElement(ui.SkinProvider, { skin = "flat" }, children)
--
-- `ui.theme` exposes the default (gem) token table. For skin-aware token reads
-- inside a component, use `ui.useSkin().theme` — that is the correct one in a
-- subtree that swapped skins.
--
-- Sizes are named, not numbered. `ui.tokens` holds the two scales every skin
-- speaks: `theme.type.<display|title|heading|body|label|caption>` and
-- `theme.space.<xs|sm|md|lg|xl|xxl>`. Call sites pass roles — `role = "body"`,
-- `gap = "md"` — so a screen re-pitches from one edit instead of a hunt through
-- literals.
--
-- Everything is authored in REFERENCE pixels (1280x720) and scaled to the real
-- viewport by `ui.Surface`, which mounts the one UIScale that does it. Wrap a
-- feature UI in a Surface and it is correct on a phone and a 4K monitor with no
-- breakpoint. `ui.useViewport` / `useScale` / `useDevice` are there for the
-- cases where the layout has to *change* rather than just shrink.
--
-- Text and GemBackground are exported (also skin-resolved) so features can
-- compose new surfaces without rebuilding the visual stack from scratch.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)

local SkinProvider = require(script.SkinProvider)

-- Build a semantic component for `key`: render the active skin's implementation,
-- falling back to gem's when the active skin doesn't implement the key (see
-- skins.resolve — that's what keeps installed skins working across a contract
-- addition instead of erroring on the first render).
local function semantic(key: string)
	return function(props)
		local skin = SkinProvider.useSkin()
		return React.createElement(SkinProvider.skins.resolve(skin, key), props)
	end
end

local ui = {}

-- Skin seam.
ui.SkinProvider = SkinProvider.SkinProvider
ui.useSkin = SkinProvider.useSkin
ui.skins = SkinProvider.skins
ui.registerSkin = SkinProvider.skins.register
ui.contract = require(script.contract)

-- Tokens + asset registry.
ui.assets = require(script.assets)
ui.theme = require(script.theme)
ui.tokens = require(script.tokens)

-- Semantic primitives (skin-resolved).
ui.Button = semantic("Button")
ui.IconButton = semantic("IconButton")
ui.Badge = semantic("Badge")
ui.Panel = semantic("Panel")
ui.TextField = semantic("TextField")
ui.Checkbox = semantic("Checkbox")
ui.ProgressBar = semantic("ProgressBar")
ui.ScrollList = semantic("ScrollList")
ui.Window = semantic("Window")
ui.Text = semantic("Text")
ui.GemBackground = semantic("GemBackground")

-- Responsive seam (seam #5): Surface mounts the viewport UIScale, so a feature
-- authored once at the reference resolution is correct on every device. The
-- hooks expose the raw numbers for the rarer case where a layout has to *change*
-- rather than just shrink.
ui.Surface = require(script.Surface)
-- Fixed art, deliberately NOT skin-resolved — see CloseButton.luau.
ui.CloseButton = require(script.CloseButton)
ui.viewport = require(script.viewport)
ui.ViewportProvider = require(script.useViewport).ViewportProvider
ui.useViewport = require(script.useViewport).useViewport
ui.useScale = require(script.useViewport).useScale
ui.useDevice = require(script.useViewport).useDevice

-- Layout primitives (seam #2): transparent, structure-only. Not skin-resolved —
-- they have no visuals, just UI*Layout / padding / sizing. Compose screens with
-- these; put skinned primitives inside them.
ui.Stack = require(script.Stack)
ui.Row = require(script.Row)
ui.Grid = require(script.Grid)
ui.Slot = require(script.Slot)

-- Skin-agnostic behavior hooks.
ui.useHoverScale = require(script.useHoverScale)
ui.useTweenedScale = require(script.useTweenedScale)
ui.useTweenedUDim2 = require(script.useTweenedUDim2)
ui.useTweenedRotation = require(script.useTweenedRotation)

return ui
