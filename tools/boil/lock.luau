--!strict
-- boil-lock.toml — what is actually on disk right now.
--
-- The lockfile is what makes vendored installs honest: it records where each
-- folder came from and a fingerprint of the contents at install time, so `update`
-- can tell an untouched package (safe to overwrite) from one you've edited, and
-- `install` can restore a fresh clone of the game.

local fs = require("@lune/fs")
local serde = require("@lune/serde")

local lock = {}

lock.FILENAME = "boil-lock.toml"

export type Entry = {
	name: string,
	version: string,
	kind: string,
	source: string,
	tag: string?,
	subdir: string?,
	path: string,
	fingerprint: string,
}

function lock.read(): { Entry }
	if not fs.isFile(lock.FILENAME) then
		return {}
	end
	local ok, decoded = pcall(serde.decode, "toml" :: any, fs.readFile(lock.FILENAME))
	if not ok then
		return {}
	end
	local packages = (decoded :: any).package
	if typeof(packages) ~= "table" then
		return {}
	end
	return packages :: { Entry }
end

function lock.write(entries: { Entry })
	table.sort(entries, function(a, b)
		return a.name < b.name
	end)
	if #entries == 0 then
		if fs.isFile(lock.FILENAME) then
			fs.removeFile(lock.FILENAME)
		end
		return
	end
	fs.writeFile(lock.FILENAME, serde.encode("toml", { package = entries }, true))
end

function lock.find(name: string): Entry?
	for _, entry in lock.read() do
		if entry.name == name then
			return entry
		end
	end
	return nil
end

function lock.upsert(entry: Entry)
	local entries = lock.read()
	for index, existing in entries do
		if existing.name == entry.name then
			entries[index] = entry
			lock.write(entries)
			return
		end
	end
	table.insert(entries, entry)
	lock.write(entries)
end

function lock.remove(name: string)
	local kept: { Entry } = {}
	for _, entry in lock.read() do
		if entry.name ~= name then
			table.insert(kept, entry)
		end
	end
	lock.write(kept)
end

return lock
