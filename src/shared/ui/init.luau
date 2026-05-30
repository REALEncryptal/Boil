-- Shared UI primitives. Consume from features as:
--
--   local ui = require(ReplicatedStorage.Shared.ui)
--   React.createElement(ui.Button, { variant = "red", text = "X", onClick = … })
--
-- Variant keys live in `ui.assets.Variants` (Button) and `ui.assets.BadgeVariants`
-- (Badge). Add new palettes there rather than passing raw ColorSequences at
-- the call site.
--
-- Text and GemBackground are exported so features can compose new gem-styled
-- surfaces without rebuilding the visual stack from scratch. Set `shadow = true`
-- on Text to get the gem-style drop-shadow used by Button/Badge.
--
-- `ui.theme` is the single source of design tokens (stroke, padding,
-- transparency, text sizes, hover scale). Every primitive reads its defaults
-- from there — change a token and it flows through the entire UI.

local ui = {}

ui.assets = require(script.assets)
ui.theme = require(script.theme)
ui.Button = require(script.Button)
ui.IconButton = require(script.IconButton)
ui.Badge = require(script.Badge)
ui.Panel = require(script.Panel)
ui.TextField = require(script.TextField)
ui.Checkbox = require(script.Checkbox)
ui.ProgressBar = require(script.ProgressBar)
ui.ScrollList = require(script.ScrollList)
ui.Window = require(script.Window)
ui.Text = require(script.Text)
ui.GemBackground = require(script.GemBackground)
ui.useHoverScale = require(script.useHoverScale)
ui.useTweenedScale = require(script.useTweenedScale)
ui.useTweenedUDim2 = require(script.useTweenedUDim2)
ui.useTweenedRotation = require(script.useTweenedRotation)

return ui
