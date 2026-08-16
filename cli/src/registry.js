// The package index: one git repo that *contains* the packages.
//
//   boil-index/registry.toml            format = 2
//   boil-index/packages/<owner>/<name>/ the package's own files, at newest
//
// Releases are tags — `<owner>/<name>@1.2.0` — so an older version is read out
// of the clone you already have rather than fetched from somewhere else. That
// is the whole point of the v2 layout: there is no second repo to create, to
// keep in sync, or to lose. See docs/registry-v2.md.
//
// Cloned to ~/.boil/index/<hash> and read from there, so `explore`, `search` and
// `list` work offline. A registry URL that resolves to a local directory is used
// in place, which is how the tests drive a real registry without a network.
//
// The v1 layout (a listing per package, pointing at another repo) is still
// *readable* — `boil migrate` needs it — but nothing installs from it.

import crypto from "node:crypto";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";

import * as config from "./config.js";
import * as manifest from "./manifest.js";
import * as project from "./project.js";
import * as source from "./source.js";
import * as toml from "./toml.js";
import { copyDir, ensureDir, isDir, isFile, listFiles, readFile, removeDir, tempDir, trim, writeFile } from "./util.js";

export const FORMAT_FILE = "registry.toml";
export const PACKAGES = "packages";
export const FORMAT = 2;

// How long a fetched index is trusted before a command refreshes it in passing.
export const MAX_AGE_MS = 6 * 60 * 60 * 1000;

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
		// Tags are the release list, and `pull` alone won't drop ones deleted
		// upstream — so ask for them explicitly.
		source.git(["-C", dir, "fetch", "--tags", "--prune", "--prune-tags", "--quiet"]);
		return [true, `updated ${target}`];
	}

	ensureDir(dir);
	removeDir(dir);
	// A blobless partial clone, not a shallow one: `--depth 1` would cut off the
	// tags that *are* the version history, while `--filter=blob:none` keeps every
	// tag reachable and fetches old file contents only when a version is actually
	// installed. HEAD's files arrive with the checkout, so browsing and
	// installing the newest version stay offline.
	const [ok, output] = source.git(["clone", "--filter=blob:none", "--quiet", target, dir]);
	if (!ok) {
		return [false, `could not clone the index ${target}:\n${trim(output)}`];
	}
	return [true, `cloned ${target}`];
}

// When the cache was last known to agree with the remote.
export function lastFetched(dir) {
	for (const marker of ["FETCH_HEAD", "HEAD"]) {
		try {
			return fs.statSync(path.join(dir, ".git", marker)).mtimeMs;
		} catch {
			// try the next marker
		}
	}
	return undefined;
}

// Refresh in passing when the cache has gone stale. Best-effort by design: a
// command that can work from the cache must not fail because the network is
// down, so a failed refresh is silent and the stale copy is used.
export function ensureFresh(target = url(), { maxAgeMs = MAX_AGE_MS, now = Date.now() } = {}) {
	if (isDir(target)) {
		return false;
	}
	const dir = localPath(target);
	if (!dir) {
		// Never fetched. Clone it now rather than reporting an empty registry.
		const [cloned] = refresh(target);
		return cloned;
	}
	const fetched = lastFetched(dir);
	if (fetched !== undefined && now - fetched < maxAgeMs) {
		return false;
	}
	const [ok] = refresh(target);
	return ok;
}

// Which layout this registry uses. v1 is "no registry.toml", since that's what
// every index written before this change looks like.
export function formatOf(dir) {
	const file = path.join(dir, FORMAT_FILE);
	if (!isFile(file)) {
		return 1;
	}
	try {
		const decoded = toml.parse(readFile(file));
		return Number(decoded.registry?.format ?? decoded.format) === 2 ? 2 : 1;
	} catch {
		return 1;
	}
}

export function formatFile(name) {
	return toml.stringify({ registry: { format: FORMAT, name } });
}

// Stamp a directory as a v2 registry. Idempotent — `setup` and `migrate` both
// call it, and either may be running against a repo that's already stamped.
export function writeFormat(dir, name) {
	const file = path.join(dir, FORMAT_FILE);
	if (isFile(file)) {
		return false;
	}
	writeFile(file, formatFile(name));
	return true;
}

// `<owner>/<name>@<version>`. Legal as a git ref: the only rule is that no tag
// may be a directory prefix of another, and the `@<version>` suffix guarantees
// that (the directory part is always refs/tags/<owner>/).
export function tagFor(name, version) {
	return `${name}@${version}`;
}

export function parseTag(tag) {
	const at = tag.lastIndexOf("@");
	if (at <= 0) {
		return undefined;
	}
	return { name: tag.slice(0, at), version: tag.slice(at + 1) };
}

// Every release tag in one call, rather than one call per package.
function releaseTags(dir) {
	// `*objectname` is the commit an annotated tag points at, empty for a
	// lightweight one — prefer it, so both kinds report the commit rather than a
	// tag object nothing else can compare against.
	const [ok, output] = source.git([
		"-C",
		dir,
		"for-each-ref",
		"--format=%(refname:strip=2) %(objectname) %(*objectname)",
		"refs/tags",
	]);
	if (!ok) {
		return new Map();
	}

	const byPackage = new Map();
	for (const line of output.split("\n")) {
		const [ref, object, dereferenced] = trim(line).split(" ");
		const commit = dereferenced && dereferenced !== "" ? dereferenced : object;
		const parsed = ref ? parseTag(ref) : undefined;
		if (!parsed) {
			continue;
		}
		const list = byPackage.get(parsed.name) ?? [];
		list.push({ version: parsed.version, tag: ref, commit });
		byPackage.set(parsed.name, list);
	}
	return byPackage;
}

function directories(dir) {
	try {
		return fs
			.readdirSync(dir, { withFileTypes: true })
			.filter((entry) => entry.isDirectory() && entry.name !== ".git")
			.map((entry) => entry.name);
	} catch {
		return [];
	}
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

// v1: a directory of listing files, each pointing at another repo. Only
// `migrate` reads this now.
export function loadV1(dir) {
	const packagesDir = path.join(dir, PACKAGES);
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

// v2: the tree is the index. Each package folder's own boil.toml describes it,
// and its releases are the tags pointing at it.
//
// Compat ranges (`boil`, `contract`) are read from the manifest at HEAD and
// attached to every release, which is approximate for older versions — the
// authoritative check happens in `add`, against the manifest that actually comes
// out of the tag.
export function loadV2(dir, target) {
	const root = path.join(dir, PACKAGES);
	if (!isDir(root)) {
		return [];
	}

	const tags = releaseTags(dir);
	const listings = [];

	for (const owner of directories(root)) {
		for (const folder of directories(path.join(root, owner))) {
			const subdir = `${PACKAGES}/${owner}/${folder}`;
			const [pkg] = manifest.read(path.join(dir, subdir));
			if (!pkg) {
				continue;
			}

			const released = tags.get(pkg.name) ?? [];
			// A local directory used as a registry may not be a git repo at all;
			// fall back to what the manifest says so it still resolves.
			const versions = (released.length > 0 ? released : [{ version: pkg.version, tag: undefined }]).map(
				(release) => ({
					...release,
					subdir,
					registryUrl: target,
					boil: pkg.boil,
					contract: pkg.contract,
				}),
			);

			listings.push({
				name: pkg.name,
				kind: pkg.kind ?? "feature",
				description: pkg.description ?? "",
				subdir,
				versions,
			});
		}
	}

	listings.sort((a, b) => (a.name < b.name ? -1 : a.name > b.name ? 1 : 0));
	return listings;
}

export function load(target = url()) {
	const dir = localPath(target);
	if (!dir) {
		return [];
	}
	return formatOf(dir) === 2 ? loadV2(dir, target) : [];
}

// A v1 index reads as empty, which would otherwise look like "nothing published
// here". Callers use this to say something truer.
export function needsMigration(target = url()) {
	const dir = localPath(target);
	return dir !== undefined && formatOf(dir) === 1 && loadV1(dir).length > 0;
}

// Copy one package out of the registry at a given release.
//
// The newest release is already checked out, so that case is a plain file copy —
// no git, no network. Older ones are read out of the object store with plumbing,
// which is also what makes a blobless clone work: only the blobs for the version
// being installed get fetched.
export function materialize(release) {
	const dir = localPath(release.registryUrl);
	if (!dir) {
		return [undefined, `the registry ${release.registryUrl} hasn't been fetched — run \`boil refresh\``];
	}

	const live = path.join(dir, release.subdir);
	if (release.tag === undefined || isHead(dir, release.commit)) {
		if (!isDir(live)) {
			return [undefined, `${release.subdir} is not in the registry`];
		}
		const dest = tempDir("package");
		removeDir(dest);
		copyDir(live, dest);
		return [dest, undefined];
	}

	const ref = release.commit ?? release.tag;
	const [listed, output] = source.git(["-C", dir, "ls-tree", "-r", "--name-only", ref, "--", release.subdir]);
	if (!listed) {
		return [undefined, `could not read ${release.subdir} at ${release.tag}:\n${trim(output)}`];
	}

	const files = output.split("\n").map(trim).filter(Boolean);
	if (files.length === 0) {
		return [undefined, `${release.subdir} is empty at ${release.tag}`];
	}

	const dest = tempDir("package");
	removeDir(dest);
	for (const file of files) {
		const [read, contents] = source.gitBytes(["-C", dir, "show", `${ref}:${file}`]);
		if (!read) {
			removeDir(dest);
			return [undefined, `could not read ${file} at ${release.tag}`];
		}
		const relative = file.slice(release.subdir.length + 1);
		const out = path.join(dest, relative);
		ensureDir(path.dirname(out));
		fs.writeFileSync(out, contents);
	}
	return [dest, undefined];
}

function isHead(dir, commit) {
	if (!commit) {
		return false;
	}
	const [ok, output] = source.git(["-C", dir, "rev-parse", "HEAD"]);
	return ok && trim(output) === commit;
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

// Nothing writes the v1 format any more — `migrate` reads it and that is all.
// The writers (listingPath/serializeListing/writeListing) went with it.
