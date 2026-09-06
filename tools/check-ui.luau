--!strict
-- Verifies that feature UI is built from the shared kit, on the shared scales.
--
-- Run: `lune run tools/check-ui`   (exits non-zero on a violation)
--
-- The existing lints check the seams that were already understood: check-views
-- catches logic leaking into a view, check-framework-boundary catches a feature
-- reaching past `Shared.Boil`, check-skins catches an incomplete skin. None of
-- them could see the problem that actually made the UI inconsistent — a feature
-- quietly not using the kit at all. A raw `TextLabel` with its own font, colour
-- and `TextSize = 16` passed every check and looked like nothing else on screen.
--
-- Three checks, all scoped to feature UI (`src/features/**/*.ui.luau` and any
-- `*View*.luau`). Framework files under `src/shared/ui/` are exempt: raw Roblox
-- instances are exactly what a skin implementation is *for*.
--
--   1. RAW SURFACES   — TextLabel / TextButton / TextBox / ImageLabel /
--                       ImageButton / ScrollingFrame have kit equivalents
--                       (ui.Text, ui.Button, ui.TextField, ui.IconButton,
--                       ui.ScrollList). Plain `Frame` is allowed: it's the
--                       structural primitive, and Stack/Slot are built on it.
--   2. LITERAL TYPE   — `textSize = 32` pins a size the theme can't move. Name a
--                       role instead: `role = "body"`.
--   3. STORY COVERAGE — every component gets a sibling `<Name>.story.luau`.
--                       Visuals are iterated in UI Labs, so a UI without a story
--                       can't be reviewed.
--   4. PRIVATE TOKENS  — feature code may read only the theme members the
--                       contract guarantees (`type`, `space`, `motion`, `roles`,
--                       `textColor`, `mutedText`, `resolveVariant`). Everything
--                       else is that skin's business.
--
-- Check 4 exists because of a real crash: SettingsUI read `theme.checkboxSize`,
-- which gem spells as a number and slop spells as a UDim2, so
-- `theme.checkboxSize + theme.space.md` threw "UDim2 expected, got number" the
-- moment the default skin changed. Slop has no `rowHeight` at all. Nothing
-- caught it — the code was correct against one skin and unportable against the
-- next, which is exactly the failure a contract is supposed to prevent.
--
-- Two escape hatches, both requiring the author to say something:
--
--   `-- boil-allow-raw: <reason>` on the line before a genuinely justified raw
--   instance (a bespoke FX layer, an icon button with a custom rotation rig).
--
--   `-- covers: Sidebar, Frame` inside a story, naming components it already
--   exercises. Read PROJECT-WIDE, not per folder: the HUD story renders the real
--   app, so it genuinely covers the sidebar and UIShell's frame system, which
--   live in other features. Splitting those back out would put plumbing views in
--   the Story Explorer that have no design decision to review.
--
-- Both leave the exception on the record instead of letting the rule quietly rot.
--
-- Context providers (`*Provider*`) are exempt from story coverage: they render no
-- visuals, so there is nothing to look at.

local fs = require("@lune/fs")
local process = require("@lune/process")

local FEATURES = "src/features"
local SHARED_UI = "src/shared/ui"
local CONTRACT = "src/shared/ui/contract.luau"

-- Roblox classes that duplicate something the kit already ships.
local RAW_SURFACES = {
	TextLabel = "ui.Text",
	TextButton = "ui.Button",
	TextBox = "ui.TextField",
	ImageLabel = "ui.Badge / ui.IconButton",
	ImageButton = "ui.IconButton",
	ScrollingFrame = "ui.ScrollList",
}

local ALLOW_COMMENT = "boil%-allow%-raw:"

-- The theme members feature code may read, taken from the contract itself so the
-- lint and the runtime can't disagree about the list.
local function contractThemeKeys(): { [string]: boolean }
	local allowed: { [string]: boolean } = {}
	if not fs.isFile(CONTRACT) then
		return allowed
	end
	local block = string.match(fs.readFile(CONTRACT), "local CONTRACT_THEME_KEYS = (%b{})")
	if block == nil then
		return allowed
	end
	for key in string.gmatch(block, '"([%w_]+)"') do
		allowed[key] = true
	end
	return allowed
end

local ALLOWED_THEME_KEYS = contractThemeKeys()
local COVERS_COMMENT = "%-%-%s*covers:%s*([^\n]+)"

local problems = 0

local function fail(path: string, line: number, message: string, hint: string?)
	problems += 1
	print(`[check-ui] {path}:{line}`)
	print(`    {message}`)
	if hint then
		print(`    {hint}`)
	end
end

local function lines(source: string): { string }
	local out: { string } = {}
	for line in string.gmatch(source .. "\n", "(.-)\n") do
		table.insert(out, line)
	end
	return out
end

-- Every .luau under a feature folder, plus the folder name, so messages can name
-- the feature. The splitter only reads a feature's top level, so this does too.
type File = { path: string, name: string, feature: string, source: string }

local function featureFiles(): { File }
	local out: { File } = {}
	if not fs.isDir(FEATURES) then
		return out
	end
	for _, feature in fs.readDir(FEATURES) do
		local dir = `{FEATURES}/{feature}`
		if not fs.isDir(dir) then
			continue
		end
		for _, entry in fs.readDir(dir) do
			local path = `{dir}/{entry}`
			if fs.isFile(path) and string.match(entry, "%.luau$") then
				table.insert(out, { path = path, name = entry, feature = feature, source = fs.readFile(path) })
			end
		end
	end
	return out
end

-- A UI file: renders something. Stories are excluded — a story's whole job is to
-- fake surrounding context, and it is never shipped as a screen.
local function isUIFile(name: string): boolean
	if string.match(name, "%.story%.luau$") then
		return false
	end
	return string.match(name, "%.ui%.luau$") ~= nil or string.match(name, "View") ~= nil
end

------------------------------------------------------------------------------
-- 1 + 2: raw surfaces and literal type sizes
------------------------------------------------------------------------------
local uiFileCount = 0

for _, file in featureFiles() do
	if not isUIFile(file.name) then
		continue
	end
	uiFileCount += 1

	local source = lines(file.source)
	for index, line in source do
		-- Comments are documentation, not code; a doc block naming TextLabel
		-- shouldn't fail the build.
		if string.match(line, "^%s*%-%-") then
			continue
		end

		-- Scan back through the contiguous comment block above this line, not just
		-- the single line before it: a reason worth writing is usually longer than
		-- one line, and the marker sits at the top of it.
		local allowed = false
		local back = index - 1
		while back >= 1 and string.match(source[back], "^%s*%-%-") do
			if string.match(source[back], ALLOW_COMMENT) then
				allowed = true
				break
			end
			back -= 1
		end

		if not allowed then
			for class, replacement in RAW_SURFACES do
				if string.match(line, `createElement%("{class}"`) then
					fail(
						file.path,
						index,
						`raw {class} in feature UI — use {replacement}`,
						`If it's genuinely bespoke, put "-- boil-allow-raw: <reason>" on the line above.`
					)
					break
				end
			end
		end

		-- A theme member the contract doesn't guarantee. Correct against the skin
		-- it was written for, broken or absent in the next one.
		for key in string.gmatch(line, "theme%.([%w_]+)") do
			if not ALLOWED_THEME_KEYS[key] then
				fail(
					file.path,
					index,
					`theme.{key} is not part of the contract — it is skin-private`,
					"Features read only theme.type / space / motion / roles / textColor / "
						.. "mutedText / resolveVariant. Derive the value, or add it to the contract."
				)
			end
		end

		-- `textSize = 32` / `TextSize = 32`: a number the theme can't move.
		-- A reference to a token (`theme.type.body`) is fine — only literals fail.
		if not allowed then
			local literal = string.match(line, "[tT]extSize%s*=%s*(%d+)")
			if literal then
				fail(
					file.path,
					index,
					`literal text size {literal} — name a role instead (role = "body")`,
					"Roles resolve per skin; a literal pins one skin's number into the call site."
				)
			end
		end
	end
end

------------------------------------------------------------------------------
-- 3: story coverage
------------------------------------------------------------------------------
-- Every component name declared covered by any story in `dirs`, via
-- `-- covers: A, B`. Collected across the whole project so a story may cover a
-- component from another feature — which the HUD story, rendering the real app,
-- legitimately does.
local function coveredAcross(dirs: { string }): { [string]: boolean }
	local covered: { [string]: boolean } = {}
	for _, dir in dirs do
		if not fs.isDir(dir) then
			continue
		end
		for _, entry in fs.readDir(dir) do
			local path = `{dir}/{entry}`
			if not fs.isFile(path) or not string.match(entry, "%.story%.luau$") then
				continue
			end
			local list = string.match(fs.readFile(path), COVERS_COMMENT)
			if list == nil then
				continue
			end
			for name in string.gmatch(list, "([%w_]+)") do
				covered[name] = true
			end
		end
	end
	return covered
end

local storyDirs: { string } = { SHARED_UI }
if fs.isDir(FEATURES) then
	for _, feature in fs.readDir(FEATURES) do
		if fs.isDir(`{FEATURES}/{feature}`) then
			table.insert(storyDirs, `{FEATURES}/{feature}`)
		end
	end
end
local covered = coveredAcross(storyDirs)

-- Feature UI.
for _, file in featureFiles() do
	local base = string.match(file.name, "^(.-)%.ui%.luau$")
	if base == nil then
		continue
	end
	-- A provider renders nothing; there is no visual to review.
	if string.match(base, "Provider") then
		continue
	end
	if covered[base] then
		continue
	end
	if not fs.isFile(`{FEATURES}/{file.feature}/{base}.story.luau`) then
		fail(
			file.path,
			1,
			`no sibling {base}.story.luau`,
			"Visuals are iterated in UI Labs; a component without a story can't be reviewed."
		)
	end
end

-- Shared primitives. Hooks, token tables and the skin plumbing aren't components,
-- so they're exempt by name.
local NOT_COMPONENTS = {
	init = true,
	contract = true,
	assets = true,
	theme = true,
	tokens = true,
	viewport = true,
	skins = true,
}

if fs.isDir(SHARED_UI) then
	for _, entry in fs.readDir(SHARED_UI) do
		local path = `{SHARED_UI}/{entry}`
		if not fs.isFile(path) or not string.match(entry, "%.luau$") then
			continue
		end
		local base = (string.gsub(entry, "%.luau$", ""))
		if string.match(base, "%.story$") or NOT_COMPONENTS[base] or string.match(base, "^use") then
			continue
		end
		if covered[base] then
			continue
		end
		if not fs.isFile(`{SHARED_UI}/{base}.story.luau`) then
			fail(path, 1, `no sibling {base}.story.luau`, "Every shared primitive ships a story.")
		end
	end
end

if problems > 0 then
	print(`\n[check-ui] FAILED — {problems} problem(s) across {uiFileCount} feature UI file(s).`)
	print("Compose the shared kit and name roles; see CLAUDE.md and docs/game/skin-contract.md.")
	process.exit(1)
end

print(`[check-ui] ok — {uiFileCount} feature UI file(s) on the kit, stories present.`)
