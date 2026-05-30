-- UIShell — global frame system.
--
-- One frame on screen at a time (open another → previous tweens out).
-- HUD / side bar content can subscribe via <HideWhenFrameOpen> to slide
-- off-screen while any frame is open.
--
-- See docs/game/UIShell.md for the full API.

local UIShell = {}

UIShell.Constants = require(script.Constants)
UIShell.Types = require(script.Types)

local FrameProvider = require(script.FrameProvider)
UIShell.FrameProvider = FrameProvider.FrameProvider
UIShell.useFrame = FrameProvider.useFrame

UIShell.Frame = require(script.Frame)
UIShell.HideWhenFrameOpen = require(script.HideWhenFrameOpen)

return UIShell
