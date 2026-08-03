--!strict
-- `boil setup` — get a checkout ready to install and publish packages.
--
-- Mostly this exists to remove the one manual step the registry used to need:
-- "go to GitHub, make an empty repo, add a packages/ directory, push". That's
-- now automated, with three ways to create the remote, tried in order:
--
--   1. the `gh` CLI, if it's installed and authenticated (handles orgs, no token)
--   2. the GitHub API with GITHUB_TOKEN / GH_TOKEN
--   3. printing the one command you have to run yourself
--
-- Every step is idempotent and additive: an index that already exists is left
-- alone apart from gaining a packages/ directory if it's missing, and nothing
-- here ever force-pushes or deletes.

local fs = require("@lune/fs")
local net = require("@lune/net")
local process = require("@lune/process")
local serde = require("@lune/serde")

local project = require("./project")
local registry = require("./registry")
local source = require("./source")
local term = require("./term")
local util = require("./util")

local setup = {}

export type Options = {
	index: string?, -- explicit index URL or local path
	localIndex: boolean?, -- scaffold a plain directory instead of a git repo
	private: boolean?,
	yes: boolean?,
	skipIndex: boolean?,
}

local README = [[
# boil-index

The package index for [Boil](https://github.com/REALEncryptal/Boil) features and
skins. One TOML file per package under `packages/<scope>/<name>.toml`, each
listing that package's published versions.

Managed by `lune run tools/boil -- publish`; you shouldn't need to edit it by
hand. Browse it with `lune run tools/boil -- explore`.
]]

function setup.parseRepoUrl(url: string): (string?, string?)
	local owner, name = string.match(url, "github%.com[:/]([^/]+)/([^/%.]+)")
	return owner, name
end

-- The owner of this checkout's origin, used to guess a default index URL.
local function originOwner(): string?
	local ok, output = source.git({ "remote", "get-url", "origin" })
	if not ok then
		return nil
	end
	local owner = setup.parseRepoUrl(util.trim(output))
	return owner
end

local function remoteExists(url: string): boolean
	local ok = source.git({ "ls-remote", "--exit-code", url, "HEAD" })
	if ok then
		return true
	end
	-- An existing but *empty* repo has no refs, so ls-remote exits non-zero with
	-- no error output. Distinguish that from "no such repo", which errors loudly.
	local reachable, output = source.git({ "ls-remote", url })
	return reachable and util.trim(output) == ""
end

local function hasGh(): boolean
	local result = process.spawn("gh", { "--version" })
	return result.ok
end

local function createWithGh(owner: string, name: string, private: boolean): (boolean, string)
	local visibility = if private then "--private" else "--public"
	local result = process.spawn("gh", {
		"repo",
		"create",
		`{owner}/{name}`,
		visibility,
		"--description",
		"Boil package index",
	})
	if result.ok then
		return true, "created with gh"
	end
	return false, util.trim(if result.stderr ~= "" then result.stderr else result.stdout)
end

local function createWithApi(owner: string, name: string, private: boolean): (boolean, string)
	local token = process.env.GITHUB_TOKEN or process.env.GH_TOKEN
	if not token then
		return false, "no gh CLI and no GITHUB_TOKEN / GH_TOKEN set"
	end

	-- Personal repos and org repos are different endpoints, and we can't know
	-- which the owner is without another call — try the org route first, since
	-- /user/repos ignores the owner entirely and would silently create the index
	-- under the wrong account.
	local attempts = {
		{ url = `https://api.github.com/orgs/{owner}/repos`, label = "org" },
		{ url = "https://api.github.com/user/repos", label = "user" },
	}

	local lastError = ""
	for _, attempt in attempts do
		local ok, response = pcall(net.request, {
			url = attempt.url,
			method = "POST",
			headers = {
				Authorization = `Bearer {token}`,
				["Content-Type"] = "application/json",
				["User-Agent"] = "boil-cli",
				Accept = "application/vnd.github+json",
			},
			body = serde.encode("json", { name = name, private = private, description = "Boil package index" }),
		})
		if not ok then
			lastError = tostring(response)
			continue
		end
		if (response :: any).ok then
			return true, `created via the GitHub API ({attempt.label})`
		end
		lastError = `{(response :: any).statusCode}: {util.trim((response :: any).body)}`
	end

	return false, lastError
end

-- Put a packages/ directory and a README in the index, if they aren't there.
local function seedIndex(url: string): boolean
	local work = util.tempDir("index-setup")
	util.removeDir(work)

	local ok, output = source.git({ "clone", "--quiet", url, work })
	if not ok then
		term.warn(`could not clone {url}:\n{util.trim(output)}`)
		return false
	end

	local changed = false
	if not fs.isDir(`{work}/packages`) then
		util.ensureDir(`{work}/packages`)
		fs.writeFile(`{work}/packages/.gitkeep`, "")
		changed = true
	end
	if not fs.isFile(`{work}/README.md`) then
		fs.writeFile(`{work}/README.md`, README)
		changed = true
	end

	if not changed then
		util.removeDir(work)
		term.info("index already has a packages/ directory — left alone")
		return true
	end

	source.git({ "add", "-A" }, work)
	source.git({ "commit", "-m", "Initialize the Boil package index" }, work)

	local pushed, pushOutput = source.git({ "push", "-u", "origin", "HEAD" }, work)
	util.removeDir(work)
	if not pushed then
		term.warn(`could not push to {url}:\n{util.trim(pushOutput)}`)
		return false
	end
	return true
end

local function setupLocalIndex(path: string): boolean
	util.ensureDir(`{path}/packages`)
	if not fs.isFile(`{path}/packages/.gitkeep`) then
		fs.writeFile(`{path}/packages/.gitkeep`, "")
	end
	if not fs.isFile(`{path}/README.md`) then
		fs.writeFile(`{path}/README.md`, README)
	end
	term.ok(`local index ready at {path}/`)
	return true
end

local function ensureIndex(url: string, opts: Options): boolean
	if fs.isDir(url) or opts.localIndex then
		return setupLocalIndex(url)
	end

	if remoteExists(url) then
		term.ok(`index exists: {url}`)
		return seedIndex(url)
	end

	local owner, name = setup.parseRepoUrl(url)
	if not owner or not name then
		term.warn(`{url} doesn't look like a GitHub URL — create it yourself, then re-run setup`)
		return false
	end

	term.info(`{url} doesn't exist yet`)
	if not opts.yes and not term.confirm(`Create {owner}/{name} on GitHub?`) then
		return false
	end

	local private = opts.private ~= false
	local created, message = if hasGh()
		then createWithGh(owner :: string, name :: string, private)
		else createWithApi(owner :: string, name :: string, private)

	if not created then
		term.warn(`couldn't create it automatically — {message}`)
		term.print("")
		term.info("Create it yourself, then re-run `boil setup`:")
		term.info(term.cyan(`  gh repo create {owner}/{name} {if private then "--private" else "--public"}`))
		term.info(term.dim(`  (or make an empty repo named "{name}" at github.com/{owner})`))
		return false
	end

	term.ok(`{message}: {url}`)
	return seedIndex(url)
end

function setup.run(args: { string }, options: Options?)
	local opts = options or {}
	term.heading("boil setup")

	local proj = project.read()

	-- 1. Project identity.
	local folder = string.match(process.cwd or "", "([^/]+)/?$")
	if proj.name == "boil-game" or proj.name == "boil" then
		local suggested = folder or proj.name
		local name = if opts.yes then suggested else term.text("Project name", suggested)
		proj.name = name or suggested
	end
	term.ok(`project: {proj.name} (Boil {proj.boil})`)

	if opts.skipIndex then
		project.write(proj)
		return
	end

	-- 2. Where the index lives.
	local url = opts.index or args[1]
	if not url then
		local owner = originOwner() or "your-github-username"
		local suggested = `https://github.com/{owner}/boil-index`
		if proj.registries.default and proj.registries.default ~= registry.DEFAULT_URL then
			suggested = proj.registries.default
		end
		url = if opts.yes then suggested else term.text("Index URL (or a local path)", suggested)
	end
	if not url or url == "" then
		term.fail("no index URL — re-run with `boil setup <url>`")
	end

	proj.registries.default = url
	project.write(proj)
	term.ok(`index: {url}`)

	-- 3. Make sure it actually exists, creating it if we can.
	if not ensureIndex(url :: string, opts) then
		term.print("")
		term.warn("setup finished, but the index isn't usable yet")
		term.info("`boil add github:owner/repo` and `boil add path:<dir>` work without an index.")
		return
	end

	-- 4. Cache it so explore/search work immediately.
	local refreshed, message = registry.refresh(url)
	if not refreshed then
		term.warn(message)
	else
		term.ok(`{message} — {#registry.load()} package(s)`)
	end

	term.print("")
	term.info("Next: `boil explore` to browse, or `boil publish <path>` to add a package.")
	term.print("")
end

return setup
