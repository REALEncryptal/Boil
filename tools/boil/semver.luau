--!strict
-- The smallest semver that covers what package manifests actually use:
-- exact ("1.2.3"), caret ("^1.2"), tilde ("~1.2.3"), comparators (">=1.0"),
-- and any ("*" / "").
--
-- Deliberately not a full node-semver: no ranges with spaces, no pre-release
-- ordering rules beyond "a pre-release sorts below its release". If a manifest
-- needs more than this, it's a sign the version scheme is too clever.

local util = require("./util")

local semver = {}

export type Version = { major: number, minor: number, patch: number, pre: string? }

function semver.parse(text: string): Version?
	local cleaned = string.gsub(text, "^v", "")
	local major, minor, patch, pre = string.match(cleaned, "^(%d+)%.(%d+)%.(%d+)%-?([%w%.%-]*)$")
	if not major then
		major, minor = string.match(cleaned, "^(%d+)%.(%d+)$")
		patch = "0"
	end
	if not major then
		major = string.match(cleaned, "^(%d+)$")
		minor, patch = "0", "0"
	end
	if not major then
		return nil
	end
	return {
		major = tonumber(major) :: number,
		minor = tonumber(minor) :: number,
		patch = tonumber(patch) :: number,
		pre = if pre and pre ~= "" then pre else nil,
	}
end

function semver.toString(v: Version): string
	local base = `{v.major}.{v.minor}.{v.patch}`
	return if v.pre then `{base}-{v.pre}` else base
end

-- -1 / 0 / 1
function semver.compare(a: Version, b: Version): number
	for _, key in { "major", "minor", "patch" } do
		local av, bv = (a :: any)[key], (b :: any)[key]
		if av ~= bv then
			return if av < bv then -1 else 1
		end
	end
	if a.pre == b.pre then
		return 0
	end
	if a.pre and not b.pre then
		return -1
	end
	if b.pre and not a.pre then
		return 1
	end
	return if (a.pre :: string) < (b.pre :: string) then -1 else 1
end

local function caretCeiling(v: Version): Version
	if v.major > 0 then
		return { major = v.major + 1, minor = 0, patch = 0 }
	end
	if v.minor > 0 then
		return { major = 0, minor = v.minor + 1, patch = 0 }
	end
	return { major = 0, minor = 0, patch = v.patch + 1 }
end

-- Does `version` satisfy `range`? Unparseable input is a miss, never an error —
-- a malformed range in someone else's manifest shouldn't crash the CLI.
function semver.satisfies(version: string, range: string?): boolean
	if not range or range == "" or range == "*" then
		return true
	end

	local v = semver.parse(version)
	if not v then
		return false
	end

	local operator, rest = string.match(util.trim(range), "^([%^~>=<]*)%s*(.+)$")
	local target = semver.parse(rest or "")
	if not target then
		return false
	end

	if operator == "" or operator == "=" then
		return semver.compare(v, target) == 0
	end
	if operator == "^" then
		return semver.compare(v, target) >= 0 and semver.compare(v, caretCeiling(target)) < 0
	end
	if operator == "~" then
		local ceiling = { major = target.major, minor = target.minor + 1, patch = 0 }
		return semver.compare(v, target) >= 0 and semver.compare(v, ceiling) < 0
	end
	if operator == ">=" then
		return semver.compare(v, target) >= 0
	end
	if operator == ">" then
		return semver.compare(v, target) > 0
	end
	if operator == "<=" then
		return semver.compare(v, target) <= 0
	end
	if operator == "<" then
		return semver.compare(v, target) < 0
	end
	return false
end

-- Highest version in `versions` satisfying `range`, or nil.
function semver.maxSatisfying(versions: { string }, range: string?): string?
	local best: string? = nil
	local bestParsed: Version? = nil
	for _, candidate in versions do
		if not semver.satisfies(candidate, range) then
			continue
		end
		local parsed = semver.parse(candidate)
		if not parsed then
			continue
		end
		if not bestParsed or semver.compare(parsed, bestParsed) > 0 then
			best, bestParsed = candidate, parsed
		end
	end
	return best
end

return semver
