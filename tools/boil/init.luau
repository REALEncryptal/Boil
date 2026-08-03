--!strict
-- boil — the package CLI for Boil features and skins.
--
--   lune run tools/boil -- explore              browse and install
--   lune run tools/boil -- add encryptal/shop   install by name
--   lune run tools/boil -- publish src/features/Shop
--
-- A package is one folder: `src/features/<Name>/` or `src/skins/<Name>/`, with a
-- boil.toml inside it. Installs are vendored — the folder lands in src/ and you
-- commit it — and boil-lock.toml records where each one came from.
--
-- See docs/registry.md.

local fs = require("@lune/fs")
local process = require("@lune/process")

local commands = require("./commands")
local explorer = require("./explorer")
local publish = require("./publish")
local setup = require("./setup")
local term = require("./term")

local USAGE = [[
boil — packages for Boil features and skins

  lune run tools/boil -- <command> [args] [flags]

Set up
  setup [index-url]           name the project and create/connect the index
                              (creates the GitHub repo via gh or GITHUB_TOKEN)

Browse
  explore                     interactive registry explorer
  search <term>               search the index
  info <package>              show a package's detail view
  refresh                     update the cached index

Install
  add <package>[@version]     install from the index
  add github:owner/repo[@tag] install straight from a git repo
  add path:<dir>              install from a local directory
  remove <package>            uninstall and drop from the lockfile
  install                     restore everything in boil-lock.toml
  update [package]            upgrade to the newest compatible version
  outdated                    what has a newer version available
  list                        what's installed, and what you've edited

Author
  publish <path>              lint, tag, push, and register a package
  doctor                      missing deps, Wally gaps, untracked packages

Flags
  --force                     overwrite an existing install / ignore compat
  --yes                       skip confirmations (setup, publish)
  --dry-run                   publish: run the gate, push nothing
  --local                     setup: scaffold a plain directory, not a git repo
  --public                    setup: create the index repo public (default private)
  --skip-index                setup: only write the project manifest
]]

type Parsed = {
	command: string?,
	args: { string },
	flags: { [string]: boolean },
}

local function parse(argv: { string }): Parsed
	local args: { string } = {}
	local flags: { [string]: boolean } = {}
	local command: string? = nil

	for _, argument in argv do
		if string.sub(argument, 1, 2) == "--" then
			flags[string.sub(argument, 3)] = true
			continue
		end
		if not command then
			command = argument
			continue
		end
		table.insert(args, argument)
	end

	return { command = command, args = args, flags = flags }
end

local parsed = parse(process.args)

if not parsed.command or parsed.flags.help or parsed.command == "help" then
	print(USAGE)
	return
end

-- Every command reads or writes project files by relative path, so a wrong cwd
-- would silently create a stray boil.toml somewhere.
if not fs.isFile("default.project.json") then
	term.fail("run this from the root of a Boil project (no default.project.json here)")
end

local handlers: { [string]: () -> () } = {
	setup = function()
		setup.run(parsed.args, {
			localIndex = parsed.flags["local"],
			private = not parsed.flags.public,
			yes = parsed.flags.yes,
			skipIndex = parsed.flags["skip-index"],
		})
	end,
	explore = function()
		explorer.run()
	end,
	search = function()
		commands.search(parsed.args)
	end,
	info = function()
		commands.info(parsed.args)
	end,
	refresh = function()
		commands.refresh()
	end,
	add = function()
		commands.add(parsed.args, { force = parsed.flags.force })
	end,
	remove = function()
		commands.remove(parsed.args)
	end,
	install = function()
		commands.install()
	end,
	update = function()
		commands.update(parsed.args, parsed.flags.force == true)
	end,
	outdated = function()
		commands.outdated()
	end,
	list = function()
		commands.list()
	end,
	publish = function()
		publish.run(parsed.args, { yes = parsed.flags.yes, dryRun = parsed.flags["dry-run"] })
	end,
	doctor = function()
		commands.doctor()
	end,
}

local handler = handlers[parsed.command]
if not handler then
	term.fail(`unknown command "{parsed.command}" — \`lune run tools/boil -- help\` lists them`)
end

handler()
