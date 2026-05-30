--!strict
-- Bezier curve math + easings used by the per-frame Overlay loop.
-- Kept tiny and stateless so it's easy to test and reuse.

local bezier = {}

-- Quadratic bezier: B(t) = (1-t)²·p0 + 2(1-t)t·p1 + t²·p2
function bezier.quadratic(p0: Vector2, p1: Vector2, p2: Vector2, t: number): Vector2
	local u = 1 - t
	return p0 * (u * u) + p1 * (2 * u * t) + p2 * (t * t)
end

-- 2D perpendicular of a vector, normalized. Returns zero for the zero vector.
function bezier.perpendicular(v: Vector2): Vector2
	local len = v.Magnitude
	if len == 0 then
		return Vector2.zero
	end
	return Vector2.new(-v.Y, v.X) / len
end

-- Quadratic in/out — smooth start, fast middle, smooth stop.
function bezier.easeQuadInOut(t: number): number
	if t < 0.5 then
		return 2 * t * t
	end
	local u = -2 * t + 2
	return 1 - (u * u) / 2
end

-- Back-out (overshoots past 1, then settles). Used for the pop-in scale.
function bezier.easeBackOut(t: number, overshoot: number?): number
	local c1 = overshoot or 1.70158
	local c3 = c1 + 1
	local u = t - 1
	return 1 + c3 * (u * u * u) + c1 * (u * u)
end

return bezier
