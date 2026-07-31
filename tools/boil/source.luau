--!strict
-- Fetching package contents.
--
-- Everything goes through `git`, which is already installed and already
-- authenticated on any machine that has this repo checked out — that's the whole
-- reason the registry is git-backed rather than a hosted service. Private
-- packages work through normal GitHub permissions with no token plumbing here.

local fs = require("@lune/fs")
local process = require("@lune/process")

local util = require("./util")

local source = {}

export type Spec = {
	name: string?, -- index lookup name, e.g. "encryptal/shop"
	version: string?, -- requested range/version
	git: string?, -- direct git URL (bypasses the index)
	path: string?, -- local directory (bypasses the index)
	tag: string?,
	subdir: string?,
}

function source.git(args: { string }, cwd: string?): (boolean, string)
	local result = process.spawn("git", args, { cwd = cwd })
	if result.ok then
		return true, result.stdout
	end
	return false, if result.stderr ~= "" then result.stderr else result.stdout
end

-- "encryptal/shop@1.2.0" | "github:owner/repo@v1" | "https://…" | "path:../dir"
function source.parseSpec(text: string): Spec
	local body, version = string.match(text, "^(.-)@([^@]+)$")
	body = body or text

	if util.startsWith(body, "path:") then
		return { path = string.sub(body, 6), tag = version }
	end
	if util.startsWith(body, "github:") then
		return { git = `https://github.com/{string.sub(body, 8)}`, tag = version }
	end
	if util.startsWith(body, "http://") or util.startsWith(body, "https://") or util.startsWith(body, "git@") then
		return { git = body, tag = version }
	end
	return { name = body, version = version }
end

function source.describe(spec: Spec): string
	if spec.path then
		return `path+{spec.path}`
	end
	if spec.git then
		return `git+{spec.git}`
	end
	return spec.name or "?"
end

-- Every tag a remote publishes, newest-agnostic (the caller ranks them).
function source.remoteTags(url: string): { string }
	local ok, output = source.git({ "ls-remote", "--tags", "--refs", url })
	if not ok then
		return {}
	end
	local tags: { string } = {}
	for line in string.gmatch(output, "[^\n]+") do
		local tag = string.match(line, "refs/tags/(.+)$")
		if tag then
			table.insert(tags, tag)
		end
	end
	return tags
end

-- Materialize a package into a fresh temp directory and return its path.
-- The caller owns cleanup.
function source.fetch(spec: Spec): (string?, string?)
	if spec.path then
		if not fs.isDir(spec.path) then
			return nil, `no such directory: {spec.path}`
		end
		local dest = util.tempDir("path")
		util.copyDir(spec.path, dest)
		return source.withSubdir(dest, spec.subdir)
	end

	local url = spec.git
	if not url then
		return nil, "no source to fetch from"
	end

	local dest = util.tempDir("fetch")
	util.removeDir(dest)

	local args = { "clone", "--depth", "1", "--quiet" }
	if spec.tag then
		table.insert(args, "--branch")
		table.insert(args, spec.tag)
	end
	table.insert(args, url)
	table.insert(args, dest)

	local ok, output = source.git(args)
	if not ok then
		util.removeDir(dest)
		local hint = if spec.tag then ` (tag "{spec.tag}")` else ""
		return nil, `git clone failed for {url}{hint}:\n{util.trim(output)}`
	end

	return source.withSubdir(dest, spec.subdir)
end

function source.withSubdir(dir: string, subdir: string?): (string?, string?)
	if not subdir or subdir == "" then
		return dir, nil
	end
	local nested = `{dir}/{subdir}`
	if not fs.isDir(nested) then
		return nil, `subdir "{subdir}" not found in the fetched source`
	end
	return nested, nil
end

return source
