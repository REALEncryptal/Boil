--!strict
-- Slop — translucent black glass, heavy dark outlines, soft inner glow, square
-- corners, FredokaOne, and per-variant gradient fills on the gem surfaces.
--
-- Extracted from a Studio template; see docs/game/slop-skin.md for what each
-- primitive maps to and which contract props this skin ignores.
--
-- The registry discovers this folder from ReplicatedStorage.Skins on first use,
-- so there's no registration step. Activate it with:
--
--   React.createElement(ui.SkinProvider, { skin = "slop" }, children)
--
-- This skin also claims `default = true`, so it is what an unparameterised
-- <SkinProvider> and every UI Labs story render in. Remove that line to fall
-- back to gem.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Boil = require(ReplicatedStorage.Shared.Boil)

local skin: Boil.Skin = {
	name = "slop",
	default = true,
	theme = require(script.theme),
	components = {
		Button = require(script.Button),
		IconButton = require(script.IconButton),
		Badge = require(script.Badge),
		Panel = require(script.Panel),
		Text = require(script.Text),
		Icon = require(script.Icon),
		TextField = require(script.TextField),
		Checkbox = require(script.Checkbox),
		ProgressBar = require(script.ProgressBar),
		ScrollList = require(script.ScrollList),
		Window = require(script.Window),
		GemBackground = require(script.GemBackground),
	},
}

return skin
