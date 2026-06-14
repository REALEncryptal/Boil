--!strict
-- Registers UIShell's FrameProvider as a root provider, so the client entry wraps
-- the whole tree in frame open/close state WITHOUT naming UIShell. Discovered and
-- run before mount by init.client.luau's presentation loop (name ends "Presentation").
--
-- This is the seam that makes UIShell an optional feature: remove the UIShell
-- folder and no provider registers — the root still mounts, just without frame
-- state (and nothing left depends on useFrame). See docs/game/framework-boundary.md.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UIRegistry = require(ReplicatedStorage.Shared.Boil).UIRegistry
local UIShell = require(ReplicatedStorage.Features:WaitForChild("UIShell"))

UIRegistry.registerProvider(UIShell.FrameProvider)

return {}
