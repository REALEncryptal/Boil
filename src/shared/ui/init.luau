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
-- Available skins live in `ui.skins` ({ gem, flat }). Wrap a subtree to swap:
--   React.createElement(ui.SkinProvider, { skin = "flat" }, children)
--
-- `ui.theme` exposes the default (gem) token table — the single source of design
-- tokens the UI Labs Theme story tunes live. For skin-aware token reads inside a
-- component, use `ui.useSkin().theme`.
--
-- Text and GemBackground are exported (also skin-resolved) so features can
-- compose new surfaces without rebuilding the visual stack from scratch.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)

local SkinProvider = require(script.SkinProvider)

-- Build a semantic component for `key`: render the active skin's implementation.
local function semantic(key: string)
	return function(props)
		local skin = SkinProvider.useSkin()
		return React.createElement((skin.components :: any)[key], props)
	end
end

local ui = {}

-- Skin seam.
ui.SkinProvider = SkinProvider.SkinProvider
ui.useSkin = SkinProvider.useSkin
ui.skins = SkinProvider.skins
ui.contract = require(script.contract)

-- Tokens + asset registry.
ui.assets = require(script.assets)
ui.theme = require(script.theme)

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
