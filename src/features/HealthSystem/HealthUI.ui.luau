local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local Constants = require(script.Parent.Constants)

return function(props)
	return React.createElement("TextLabel", {
		Size = UDim2.fromOffset(160, 36),
		Position = UDim2.fromOffset(16, 16),
		BackgroundColor3 = Color3.fromRGB(20, 20, 26),
		BorderSizePixel = 0,
		TextColor3 = Color3.fromRGB(255, 95, 95),
		Font = Enum.Font.GothamBold,
		TextSize = 16,
		Text = `HP: {props.hp or Constants.MAX_HP}`,
	}, {
		Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 6) }),
	})
end
