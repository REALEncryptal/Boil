--!strict
-- Animation defaults for the frame system. Override at the call site via
-- props when a specific frame or side bar wants different timing.

return {
	-- Frame enter tween: Back.Out — snappy with a single small overshoot.
	ENTER_TWEEN_INFO = TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out),

	-- Frame exit tween: Quad.In — accelerates as the window shrinks away.
	EXIT_TWEEN_INFO = TweenInfo.new(0.05, Enum.EasingStyle.Quad, Enum.EasingDirection.In),

	-- UIScale start value: window grows from this scale to 1 on open, then
	-- shrinks back to this on close.
	ENTER_SCALE_FROM = 0.8,

	-- HideWhenFrameOpen: how far off-screen (in parent scale units) the
	-- hidden element slides. 1.0 = one full parent-width/height, which
	-- guarantees off-screen for any element narrower than its parent.
	HIDE_OFFSCREEN_OFFSET = 1.0,

	-- HideWhenFrameOpen tweens. Hide uses In so the slow part of the motion
	-- happens on-screen — otherwise the side bar looks like it just vanishes
	-- because Quad.Out's fast-start has it off-screen in ~1 frame. Show uses
	-- Out for the symmetric gentle on-screen landing.
	HIDE_HIDE_TWEEN_INFO = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
	HIDE_SHOW_TWEEN_INFO = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
}
