--!strict
-- Skin #1: "gem" — the original gem-styled look.
--
-- The primitive implementations still live in src/shared/ui/ (unchanged); this
-- table just gathers them so the SkinProvider can swap the whole set at once.
-- Those files compose each other directly (Button → Text → GemBackground) via
-- relative requires, so the gem look is internally consistent regardless of the
-- active skin in context.
--
-- `theme` is the canonical token module — the same instance `ui.theme` exposes —
-- so the UI Labs Theme story tunes the gem skin live.

local ui = script.Parent.Parent
local contract = require(ui.contract)

local skin: contract.Skin = {
	name = "gem",
	theme = require(ui.theme),
	components = {
		Button = require(ui.Button),
		IconButton = require(ui.IconButton),
		Badge = require(ui.Badge),
		Panel = require(ui.Panel),
		Text = require(ui.Text),
		TextField = require(ui.TextField),
		Checkbox = require(ui.Checkbox),
		ProgressBar = require(ui.ProgressBar),
		ScrollList = require(ui.ScrollList),
		Window = require(ui.Window),
		GemBackground = require(ui.GemBackground),
	},
}

return skin
