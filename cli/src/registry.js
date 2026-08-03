// The package index: a git repo of manifests, one TOML file per package.
//
//   boil-index/packages/<scope>/<name>.toml
//
// Cloned to ~/.boil/index/<hash> and read from there, so `explore`, `search` and
// `list` all work offline — refreshing is an explicit action, never a hidden
// network call on every command. A registry URL that resolves to a local
// directory is used in place (handy for developing against an index before it's
// published anywhere).

import crypto from "node:crypto";
import os from "node:os";
import path from "node:path";

import * as config from "./config.js";
import * as project from "./project.js";
import * as source from "./source.js";
import * as toml from "./toml.js";
import { ensureDir, isDir, listFiles, readFile, removeDir, trim, writeFile } from "./util.js";

export const DEFAULT_URL = "https://github.com/REALEncryptal/boil-index";
export const DEFAULT_NAME = "default";

// Every registry this checkout can see, in lookup order.
//
// Three layers, each overriding the last on a name collision: the built-in
// public index, the user's machine-wide config, then the project's boil.toml.
// A project can therefore point `default` somewhere else entirely, or add a
// company index on top of the ones you have everywhere.
export function all() {
	const merged = new Map([[DEFAULT_NAME, { name: DEFAULT_NAME, url: DEFAULT_URL, scope: "built-in" }]]);

	for (const [name, url] of Object.entries(config.read().registries)) {
		merged.set(name, { name, url, scope: "user" });
	}
	for (const [name, url] of Object.entries(project.read().registries)) {
		merged.set(name, { name, url, scope: "project" });
	}

	// `default` first, then the rest in the order they were configured.
	const entries = [...merged.values()];
	return entries.sort((a, b) => (a.name === DEFAULT_NAME ? -1 : b.name === DEFAULT_NAME ? 1 : 0));
}

export function byName(name) {
	return all().find((entry) => entry.name === name);
}

// The default registry's URL — what `publish` targets and what the explorer
// reports when nothing more specific applies.
export function url() {
	return byName(DEFAULT_NAME)?.url ?? DEFAULT_URL;
}

export function cacheDir(target) {
	const hash = crypto.createHash("sha256").update(target).digest("hex").slice(0, 12);
	return path.join(os.homedir(), ".boil", "index", hash);
}

// Where the index actually lives on disk right now, or undefined if it's never
// been fetched. A local-directory registry resolves to itself.
export function localPath(target = url()) {
	if (isDir(target)) {
		return target;
	}
	const cached = cacheDir(target);
	return isDir(cached) ? cached : undefined;
}

export function refresh(target = url()) {
	if (isDir(target)) {
		return [true, `using local index at ${target}`];
	}

	const dir = cacheDir(target);
	if (isDir(path.join(dir, ".git"))) {
		const [ok, output] = source.git(["-C", dir, "pull", "--ff-only", "--quiet"]);
		if (!ok) {
			return [false, `could not update the index at ${dir}:\n${trim(output)}`];
		}
		return [true, `updated ${target}`];
	}

	ensureDir(dir);
	removeDir(dir);
	const [ok, output] = source.git(["clone", "--depth", "1", "--quiet", target, dir]);
	if (!ok) {
		return [false, `could not clone the index ${target}:\n${trim(output)}`];
	}
	return [true, `cloned ${target}`];
}

function parseListing(text) {
	let decoded;
	try {
		decoded = toml.parse(text);
	} catch {
		return undefined;
	}
	if (typeof decoded.name !== "string") {
		return undefined;
	}
	return {
		name: decoded.name,
		kind: decoded.kind ?? "feature",
		description: decoded.description ?? "",
		versions: Array.isArray(decoded.version) ? decoded.version : [],
	};
}

export function load(target) {
	const dir = localPath(target);
	if (!dir) {
		return [];
	}

	const packagesDir = path.join(dir, "packages");
	if (!isDir(packagesDir)) {
		return [];
	}

	const listings = [];
	for (const rel of listFiles(packagesDir)) {
		if (!rel.endsWith(".toml")) continue;
		const listing = parseListing(readFile(path.join(packagesDir, rel)));
		if (listing) {
			listings.push(listing);
		}
	}

	listings.sort((a, b) => (a.name < b.name ? -1 : a.name > b.name ? 1 : 0));
	return listings;
}

export function find(name, target) {
	return load(target).find((listing) => listing.name === name);
}

export function search(term, target) {
	const needle = term.toLowerCase();
	return load(target).filter((listing) =>
		`${listing.name} ${listing.description}`.toLowerCase().includes(needle),
	);
}

// Every listing in every configured registry, tagged with where it came from.
export function loadAll() {
	const out = [];
	for (const entry of all()) {
		for (const listing of load(entry.url)) {
			out.push({ ...listing, registry: entry.name });
		}
	}
	return out;
}

export function searchAll(term) {
	const needle = term.toLowerCase();
	return loadAll().filter((listing) => `${listing.name} ${listing.description}`.toLowerCase().includes(needle));
}

// Find one package across the configured registries.
//
// Returns `{ listing, registry }` on a hit, `{ ambiguous }` when two registries
// publish the same name (the caller tells the user to qualify it), `{ error }`
// for a bad registry name, or `{}` for a miss. Ambiguity is surfaced rather than
// silently resolved by precedence: installing a *different* package than the one
// you meant, because someone else's index happens to use the name, is exactly
// the failure a private registry must not have.
export function resolve(name, registryName) {
	if (registryName) {
		const entry = byName(registryName);
		if (!entry) {
			const known = all()
				.map((candidate) => candidate.name)
				.join(", ");
			return { error: `unknown registry "${registryName}" — configured: ${known}` };
		}
		const listing = find(name, entry.url);
		if (!listing) {
			return { error: `"${name}" is not in the "${registryName}" registry` };
		}
		return { listing: { ...listing, registry: entry.name }, registry: entry };
	}

	const matches = loadAll().filter((listing) => listing.name === name);
	if (matches.length === 0) {
		return {};
	}
	if (matches.length === 1) {
		return { listing: matches[0], registry: byName(matches[0].registry) };
	}
	return { ambiguous: matches };
}

// True when at least one registry has been fetched — the explorer's cue that it
// has something to show.
export function anyCached() {
	return all().some((entry) => localPath(entry.url) !== undefined);
}

export function refreshAll() {
	return all().map((entry) => {
		const [ok, message] = refresh(entry.url);
		return { ...entry, ok, message };
	});
}

// The index file path a listing is published to.
export function listingPath(indexDir, name) {
	const [scope, pkg] = name.split("/");
	return path.join(indexDir, "packages", scope, `${pkg}.toml`);
}

function tomlString(value) {
	return `"${String(value).replace(/\\/g, "\\\\").replace(/"/g, '\\"')}"`;
}

// Emitted field-by-field rather than through the generic serializer so a listing
// always diffs cleanly in the index repo: same keys, same order, every release.
export function serializeListing(listing) {
	const lines = [
		`name = ${tomlString(listing.name)}`,
		`kind = ${tomlString(listing.kind)}`,
		`description = ${tomlString(listing.description)}`,
	];

	const FIELDS = ["version", "source", "tag", "subdir", "boil", "contract", "published"];
	for (const release of listing.versions) {
		lines.push("", "[[version]]");
		for (const field of FIELDS) {
			if (release[field]) {
				lines.push(`${field} = ${tomlString(release[field])}`);
			}
		}
	}

	return `${lines.join("\n")}\n`;
}

export function writeListing(indexDir, listing) {
	writeFile(listingPath(indexDir, listing.name), serializeListing(listing));
}
