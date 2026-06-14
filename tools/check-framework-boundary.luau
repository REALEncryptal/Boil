--!strict
-- Enforces the framework/feature boundary in BOTH directions:
--
--   1. Framework code must never name a specific feature. The dependency arrow
--      points one way, so the framework stays agnostic to every feature and ships
--      empty.
--   2. Features must consume the framework only through its single public surface,
--      `require(ReplicatedStorage.Shared.Boil)` — never a deep `Shared.*` path. That
--      keeps the contract narrow, so updating the framework's internals never
--      touches feature code.
--
-- Run: `lune run tools/check-framework-boundary`  (exits non-zero on any leak)
--
-- Direction 1 — allowed: touching the `Features` container generically (iterating,
-- `LoadDescendants(Features, …)`, `Features:GetChildren()`). Violation: reaching a
-- *named* child (`Features:WaitForChild("UIShell")`, `Features.Notes`). If the
-- framework needs that, the seam is backwards — the feature should register INTO
-- the framework, not the reverse.
--
-- Direction 2 — allowed: `require(ReplicatedStorage.Shared.Boil)` (and a feature
-- requiring its own modules under `ReplicatedStorage.Features.<Self>`). Violation:
-- `require(ReplicatedStorage.Shared.ui)`, `…Shared.utils.UIRegistry`, etc. — route
-- it through `Boil`, adding to that surface if it's genuinely missing.
--
-- Scope: direction 1 scans the runtime framework realms (Shared / client / server);
-- direction 2 scans src/features. The build tools under tools/ are generic Lune
-- scripts that operate on the features directory by design, so they're out of scope.
-- See docs/game/framework-boundary.md.

local fs = require("@lune/fs")
local process = require("@lune/process")

local FRAMEWORK_DIRS = { "src/shared", "src/client", "src/server" }
local FEATURE_DIR = "src/features"

-- The one Shared.* member features may require directly.
local PUBLIC_SURFACE = "Boil"

-- Direction 1 rules. Every container variable in the entries ends in "Features"
-- (Features / ServerFeatures / ClientFeatures), so matching the bare token covers
-- all three.
local NAME_RULES: { { pattern: string, why: string } } = {
	{ pattern = 'Features:WaitForChild%(%s*["\']([%w_]+)["\']', why = "WaitForChild a named feature" },
	{ pattern = 'Features:FindFirstChild%(%s*["\']([%w_]+)["\']', why = "FindFirstChild a named feature" },
	{ pattern = 'Features%[%s*["\']([%w_]+)["\']%s*%]', why = "index a named feature" },
	{ pattern = "Features%.([%a_][%w_]*)", why = "dot-access a named feature" },
}

-- `Features.<X>` accesses that are Instance members, not feature children.
local INSTANCE_MEMBERS: { [string]: boolean } = {
	Name = true,
	Parent = true,
	ClassName = true,
	Archivable = true,
}

local violations = 0
local scanned = 0

-- True for comment-only lines, so prose mentioning a path can't trip a rule.
local function isComment(line: string): boolean
	local trimmed = string.gsub(line, "^%s*", "")
	return string.sub(trimmed, 1, 2) == "--"
end

local function report(path: string, lineNo: number, line: string, message: string)
	violations += 1
	print(`[check-framework-boundary] {path}:{lineNo}`)
	print(`    {message}`)
	print(`    > {(string.gsub(line, "^%s*", ""))}`)
end

-- Direction 1: framework code naming a feature.
local function scanFrameworkFile(path: string)
	scanned += 1
	for lineNo, line in ipairs(string.split(fs.readFile(path), "\n")) do
		if isComment(line) then
			continue
		end
		for _, rule in NAME_RULES do
			local name = string.match(line, rule.pattern)
			if name and not INSTANCE_MEMBERS[name] then
				report(path, lineNo, line, `framework names feature "{name}" ({rule.why})`)
			end
		end
	end
end

-- Direction 2: a feature reaching a non-Boil Shared.* path.
local function scanFeatureFile(path: string)
	scanned += 1
	for lineNo, line in ipairs(string.split(fs.readFile(path), "\n")) do
		if isComment(line) then
			continue
		end
		local member = string.match(line, "ReplicatedStorage%.Shared%.([%w_]+)")
		if member and member ~= PUBLIC_SURFACE then
			report(path, lineNo, line, `feature reaches framework internal "Shared.{member}" — require Shared.{PUBLIC_SURFACE} instead`)
		end
	end
end

local function walk(dir: string, scan: (string) -> ())
	if not fs.isDir(dir) then
		return
	end
	for _, name in fs.readDir(dir) do
		local path = dir .. "/" .. name
		if fs.isDir(path) then
			walk(path, scan)
		elseif string.match(name, "%.luau$") then
			scan(path)
		end
	end
end

for _, dir in FRAMEWORK_DIRS do
	walk(dir, scanFrameworkFile)
end
walk(FEATURE_DIR, scanFeatureFile)

if violations > 0 then
	print(`\n[check-framework-boundary] FAILED — {violations} boundary violation(s).`)
	print("Framework code must not name a feature; features must reach the framework only via Shared.Boil.")
	print("Invert the seam (register into the framework) or route the require through Boil.")
	process.exit(1)
end

print(`[check-framework-boundary] ok — {scanned} file(s), boundary intact both ways.`)
