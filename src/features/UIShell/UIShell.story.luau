--!nonstrict
-- UI Labs story for the frame system. Two demo frames (A red, B blue), a
-- toolbar to open/swap/close them, and a side bar that slides off when any
-- frame is open.
--
-- Controls let you tweak the enter/exit timing without rebuilding the story.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local UILabs = require(ReplicatedStorage.Packages.UILabs)
local ui = require(ReplicatedStorage.Shared.Boil).ui
local UIShell = require(ReplicatedStorage.Features.UIShell)

-- useFrame() needs a provider ancestor, so the demo body lives in a
-- separate component rendered as the FrameProvider's child.
local function Demo(props)
	local frames = UIShell.useFrame()

	local enterTweenInfo = TweenInfo.new(
		props.enterDuration,
		Enum.EasingStyle.Elastic,
		Enum.EasingDirection.Out
	)
	local exitTweenInfo = TweenInfo.new(
		props.exitDuration,
		Enum.EasingStyle.Quad,
		Enum.EasingDirection.Out
	)

	return React.createElement("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, {
		Toolbar = React.createElement("Frame", {
			Size = UDim2.fromOffset(440, 70),
			Position = UDim2.fromScale(0.5, 0.05),
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundTransparency = 1,
		}, {
			Layout = React.createElement("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				Padding = UDim.new(0, 10),
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			OpenA = React.createElement(ui.Button, {
				variant = "red",
				text = "Open A",
				textSize = 28,
				size = UDim2.fromOffset(130, 60),
				layoutOrder = 1,
				onClick = function()
					frames.open("A")
				end,
			}),
			OpenB = React.createElement(ui.Button, {
				variant = "blue",
				text = "Open B",
				textSize = 28,
				size = UDim2.fromOffset(130, 60),
				layoutOrder = 2,
				onClick = function()
					frames.open("B")
				end,
			}),
			Close = React.createElement(ui.Button, {
				variant = "white",
				text = "Close",
				textSize = 28,
				size = UDim2.fromOffset(130, 60),
				layoutOrder = 3,
				onClick = frames.close,
			}),
		}),

		SideBar = React.createElement(UIShell.HideWhenFrameOpen, {
			direction = props.sideBarDirection,
			basePosition = UDim2.new(0, 20, 0.5, 0),
			anchorPoint = Vector2.new(0, 0.5),
			size = UDim2.fromOffset(180, 320),
		}, {
			Panel = React.createElement(ui.Panel, {
				size = UDim2.fromScale(1, 1),
				position = UDim2.fromScale(0.5, 0.5),
				anchorPoint = Vector2.new(0.5, 0.5),
			}, {
				Label = React.createElement("TextLabel", {
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
					Text = `Side bar\n(slides {props.sideBarDirection})`,
					TextColor3 = Color3.fromRGB(255, 255, 255),
					TextSize = 22,
					TextWrapped = true,
				}),
			}),
		}),

		FrameA = React.createElement(UIShell.Frame, {
			id = "A",
			enterTweenInfo = enterTweenInfo,
			exitTweenInfo = exitTweenInfo,
		}, {
			Window = React.createElement(ui.Window, {
				title = "Frame A",
				titleVariant = "red",
				closeVariant = "red",
				onClose = frames.close,
			}, {
				Note = React.createElement("TextLabel", {
					Size = UDim2.new(1, 0, 0, 80),
					BackgroundTransparency = 1,
					Text = "Click 'Open B' to swap. Watch A tween out as B tweens in.",
					TextColor3 = Color3.fromRGB(255, 255, 255),
					TextSize = 22,
					TextWrapped = true,
					LayoutOrder = 0,
				}),
			}),
		}),

		FrameB = React.createElement(UIShell.Frame, {
			id = "B",
			enterTweenInfo = enterTweenInfo,
			exitTweenInfo = exitTweenInfo,
		}, {
			Window = React.createElement(ui.Window, {
				title = "Frame B",
				titleVariant = "blue",
				closeVariant = "blue",
				onClose = frames.close,
			}, {
				Note = React.createElement("TextLabel", {
					Size = UDim2.new(1, 0, 0, 80),
					BackgroundTransparency = 1,
					Text = "Click 'Open A' to swap back, or 'Close' to dismiss.",
					TextColor3 = Color3.fromRGB(255, 255, 255),
					TextSize = 22,
					TextWrapped = true,
					LayoutOrder = 0,
				}),
			}),
		}),
	})
end

return {
	summary = "Frame system. Open A / Open B swap with UIScale enter+exit tweens; the side bar slides off-screen while any frame is open.",
	react = React,
	reactRoblox = ReactRoblox,

	controls = {
		enterDuration = UILabs.Slider(0.8, 0.05, 1.5, 0.05),
		exitDuration = UILabs.Slider(0.1, 0.05, 1, 0.05),
		sideBarDirection = UILabs.Choose({ "left", "right", "top", "bottom" }),
	},

	story = function(props)
		return React.createElement(UIShell.FrameProvider, {}, {
			Demo = React.createElement(Demo, {
				enterDuration = props.controls.enterDuration,
				exitDuration = props.controls.exitDuration,
				sideBarDirection = props.controls.sideBarDirection,
			}),
		})
	end,
}
