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

import * as project from "./project.js";
import * as source from "./source.js";
import * as toml from "./toml.js";
import { ensureDir, isDir, listFiles, readFile, removeDir, trim, writeFile } from "./util.js";

export const DEFAULT_URL = "https://github.com/REALEncryptal/boil-index";

export function url() {
	return project.read().registries.default ?? DEFAULT_URL;
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
