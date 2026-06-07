--!strict
-- Skin #2: "flat" — a debug skin of plain gray boxes with accent borders. Same
-- contract, same slots as gem; no gradients/noise/shine. Its purpose is to prove
-- the swap works and to give a skin that's verifiable by eye on plain shapes
-- (so a skin change can be checked without judging gem artwork).

local contract = require(script.Parent.Parent.contract)

local skin: contract.Skin = {
	name = "flat",
	theme = require(script.theme),
	components = {
		Button = require(script.Button),
		IconButton = require(script.IconButton),
		Badge = require(script.Badge),
		Panel = require(script.Panel),
		Text = require(script.Text),
		TextField = require(script.TextField),
		Checkbox = require(script.Checkbox),
		ProgressBar = require(script.ProgressBar),
		ScrollList = require(script.ScrollList),
		Window = require(script.Window),
		GemBackground = require(script.GemBackground),
	},
}

return skin
