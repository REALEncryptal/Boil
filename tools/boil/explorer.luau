--!strict
-- `boil explore` — the registry's front end.
--
-- This is why there's no website: browsing what's available is a menu in the
-- terminal you're already in, reading a git repo you already have cached. It
-- renders from the local index clone, so it works offline; refreshing is an
-- explicit menu item rather than a network call on every keystroke.
--
-- Every action here calls the same command a script would (`commands.add`), so
-- the explorer stays a discovery aid and never becomes the only way to do
-- something.

local commands = require("./commands")
local format = require("./format")
local registry = require("./registry")
local term = require("./term")

local explorer = {}

local function byKind(listings: { registry.Listing }, kind: string): { registry.Listing }
	local out: { registry.Listing } = {}
	for _, listing in listings do
		if listing.kind == kind then
			table.insert(out, listing)
		end
	end
	return out
end

local function installedListings(listings: { registry.Listing }): { registry.Listing }
	local installed = commands.installedVersions()
	local out: { registry.Listing } = {}
	for _, listing in listings do
		if installed[listing.name] then
			table.insert(out, listing)
		end
	end
	return out
end

-- Detail view + actions. Returns true if something was installed.
local function showPackage(listing: registry.Listing): boolean
	while true do
		local installed = commands.installedVersions()[listing.name]
		local latest = format.latest(listing)

		term.print("")
		for _, line in format.detail(listing, latest, installed) do
			term.print(line)
		end
		term.print("")

		local actions: { string } = {}
		local handlers: { () -> boolean? } = {}

		if latest then
			local compat = format.compat(latest)
			local label = if installed == latest.version
				then `Reinstall {latest.version}`
				elseif installed then `Update to {latest.version}`
				else `Install {latest.version}`
			if not compat.ok then
				label ..= " (incompatible — force)"
			end
			table.insert(actions, label)
			table.insert(handlers, function()
				commands.add({ `{listing.name}@{latest.version}` }, { force = true })
				return true
			end)
		end

		if #listing.versions > 1 then
			table.insert(actions, "Install a specific version…")
			table.insert(handlers, function()
				local versions: { string } = {}
				for _, release in listing.versions do
					table.insert(versions, release.version)
				end
				local picked = term.select(`{listing.name} — which version?`, versions)
				if not picked then
					return nil
				end
				commands.add({ `{listing.name}@{versions[picked]}` }, { force = true })
				return true
			end)
		end

		table.insert(actions, "Back")
		table.insert(handlers, function()
			return false
		end)

		local choice = term.select("Action", actions)
		if not choice then
			return false
		end

		local result = handlers[choice]()
		if result ~= nil then
			return result
		end
	end
end

local function browse(title: string, listings: { registry.Listing })
	if #listings == 0 then
		term.print("")
		term.print(term.dim(`Nothing in {title}.`))
		return
	end

	while true do
		local rows = format.rows(listings, commands.installedVersions())
		table.insert(rows, "Back")

		term.print("")
		local choice = term.select(`{title} ({#listings})`, rows)
		if not choice or choice > #listings then
			return
		end
		showPackage(listings[choice])
	end
end

function explorer.run()
	if not registry.localPath() then
		term.print("")
		term.warn(`No index cached yet for {registry.url()}`)
		if not term.confirm("Fetch it now?") then
			return
		end
		commands.refresh()
	end

	while true do
		local listings = registry.load()
		local features = byKind(listings, "feature")
		local skins = byKind(listings, "skin")
		local installed = installedListings(listings)

		local options = {
			`Features ({#features})`,
			`Skins ({#skins})`,
			`Installed ({#installed})`,
			"Search…",
			"Refresh index",
			"Quit",
		}

		term.print("")
		local choice = term.select(`Boil registry — {#listings} package(s)`, options)

		if not choice or choice == 6 then
			return
		elseif choice == 1 then
			browse("Features", features)
		elseif choice == 2 then
			browse("Skins", skins)
		elseif choice == 3 then
			browse("Installed", installed)
		elseif choice == 4 then
			local needle = term.text("Search")
			if needle and needle ~= "" then
				browse(`Results for "{needle}"`, registry.search(needle))
			end
		elseif choice == 5 then
			commands.refresh()
		end
	end
end

return explorer
