// The scriptable commands. Every explorer action maps onto one of these, so
// anything you can do by browsing you can also do from a script or CI.

import * as format from "./format.js";
import * as lock from "./lock.js";
import * as manifest from "./manifest.js";
import * as project from "./project.js";
import * as registry from "./registry.js";
import * as self from "./self.js";
import * as semver from "./semver.js";
import * as source from "./source.js";
import * as term from "./term.js";
import { copyDir, diffDirs, isDir, isFile, listFiles, readFile, removeDir } from "./util.js";
import fs from "node:fs";
import path from "node:path";

export function installedVersions() {
	const out = {};
	for (const entry of lock.read()) {
		out[entry.name] = entry.version;
	}
	return out;
}

// A feature package must be a flat folder: the splitter iterates files and skips
// nested directories entirely, so a nested .luau would vanish at build time
// rather than fail loudly.
function checkFlat(pkg, dir) {
	if (pkg.kind !== "feature") {
		return [];
	}
	return listFiles(dir).filter((rel) => rel.includes("/") && rel.endsWith(".luau"));
}

function resolveIndexed(spec) {
	const found = registry.resolve(spec.name, spec.registry);

	if (found.error) {
		term.fail(found.error);
	}
	if (found.ambiguous) {
		term.print(term.red(`"${spec.name}" is published in more than one registry:`));
		for (const match of found.ambiguous) {
			term.info(`• ${term.bold(`${match.registry}:${spec.name}`)}  ${term.dim(match.description)}`);
		}
		term.fail("qualify which one you mean, e.g. `boil add <registry>:<package>`");
	}

	const listing = found.listing;
	if (!listing) {
		const hint = registry.anyCached() ? "" : " (no index has been fetched — try `boil refresh`)";
		term.fail(`"${spec.name}" is not in any configured registry${hint}`);
	}

	const release = format.findRelease(listing, spec.version);
	if (!release) {
		const available = listing.versions.map((candidate) => candidate.version).join(", ");
		term.fail(`no version of "${spec.name}" matches "${spec.version}" — published: ${available}`);
	}

	return { listing, release };
}

function reportSplit(result) {
	if (result === undefined || result.ok) {
		return;
	}
	term.warn(`the splitter didn't run — ${term.dim(result.output.split("\n")[0])}`);
	term.info("run `lune run tools/split` once the toolchain is available");
}

export async function add(args, options = {}) {
	const specText = args[0];
	if (!specText) {
		term.fail("usage: boil add <package>[@version] | github:owner/repo[@tag] | path:<dir>");
	}

	const spec = source.parseSpec(specText);
	let fetchSpec = spec;
	let fromRegistry;

	if (spec.name) {
		const { listing, release } = resolveIndexed(spec);
		fromRegistry = listing.registry;
		const compatibility = format.compat(release);
		if (!compatibility.ok && !options.force) {
			term.fail(
				`${spec.name}@${release.version} is not compatible — ${compatibility.reason}. Pass --force to install anyway.`,
			);
		}
		fetchSpec = {
			git: (release.source ?? "").replace(/^git\+/, ""),
			tag: release.tag,
			subdir: release.subdir,
		};
	}

	const [dir, fetchError] = source.fetch(fetchSpec);
	if (!dir) {
		term.fail(fetchError);
	}

	const [pkg, manifestError] = manifest.read(dir);
	if (!pkg) {
		removeDir(dir);
		term.fail(`${specText}: ${manifestError}`);
	}

	const errors = manifest.validate(pkg);
	if (errors.length > 0) {
		removeDir(dir);
		term.print(term.red(`${specText} has an invalid boil.toml:`));
		for (const message of errors) {
			term.info(`• ${message}`);
		}
		term.fail("refusing to install an invalid package");
	}

	// The fetched manifest is the authority, not the index entry: this is the only
	// compat check that also covers `add github:…` and `add path:…`, which never
	// touch the index.
	const compatibility = format.compat({ version: pkg.version, boil: pkg.boil, contract: pkg.contract });
	if (!compatibility.ok && !options.force) {
		removeDir(dir);
		term.fail(`${pkg.name} ${pkg.version} is not compatible — ${compatibility.reason}. Pass --force to install anyway.`);
	}

	const nested = checkFlat(pkg, dir);
	if (nested.length > 0) {
		removeDir(dir);
		term.fail(
			`${pkg.name} has .luau files in subfolders (${nested.join(", ")}) — ` +
				"the splitter only reads the top level of a feature folder, so those would silently never build",
		);
	}

	const target = project.installPath(pkg);
	if (isDir(target) && !options.force) {
		removeDir(dir);
		term.fail(`${target}/ already exists — use \`boil update ${pkg.name}\`, or --force to overwrite`);
	}

	removeDir(target);
	copyDir(dir, target);
	removeDir(dir);

	const wallyAdded = project.mergeWally(pkg);

	lock.upsert({
		name: pkg.name,
		version: pkg.version,
		kind: pkg.kind,
		source: source.describe(fetchSpec),
		tag: fetchSpec.tag,
		subdir: fetchSpec.subdir,
		// Which registry it came from, so `outdated` and `update` look there
		// first rather than re-resolving a name two registries might share.
		registry: fromRegistry,
		path: target,
		fingerprint: project.fingerprint(target),
	});

	if (options.direct !== false) {
		const proj = project.read();
		proj.dependencies[pkg.name] = `^${pkg.version}`;
		project.write(proj);
	}

	// Transitive dependencies. Recorded in the lockfile but not in the project
	// manifest — the project only declares what it asked for directly.
	const installed = installedVersions();
	for (const [name, range] of Object.entries(pkg.dependencies)) {
		if (installed[name] && semver.satisfies(installed[name], range)) {
			continue;
		}
		if (!registry.resolve(name).listing) {
			term.warn(`${pkg.name} depends on ${name} ${range}, which isn't in any registry — install it yourself`);
			continue;
		}
		await add([`${name}@${range}`], { quiet: true, skipSplit: true, direct: false, force: options.force });
	}

	if (!options.skipSplit) {
		reportSplit(project.runSplit());
	}

	if (options.quiet) {
		term.ok(`${pkg.name} ${pkg.version} → ${target}/`);
		return target;
	}

	term.print("");
	term.ok(`installed ${term.bold(pkg.name)} ${pkg.version} → ${target}/`);
	if (wallyAdded.length > 0) {
		term.print("");
		term.print(term.bold("Added to wally.toml — run `wally install`"));
		for (const line of wallyAdded) {
			term.info(line);
		}
	}

	const requirements = format.requirements(pkg);
	if (requirements.length > 0) {
		term.print("");
		for (const line of requirements) {
			term.print(line);
		}
	}
	term.print("");

	return target;
}

export async function remove(args) {
	const name = args[0];
	if (!name) {
		term.fail("usage: boil remove <package>");
	}

	const entry = lock.find(name);
	if (!entry) {
		term.fail(`"${name}" is not installed (see \`boil list\`)`);
	}

	// Anything that declares it as a dependency is about to break.
	for (const other of lock.read()) {
		if (other.name === name) continue;
		const [otherPackage] = manifest.read(other.path);
		if (otherPackage && otherPackage.dependencies[name]) {
			term.warn(`${other.name} depends on ${name} — it will break`);
		}
	}

	removeDir(entry.path);
	lock.remove(name);

	const proj = project.read();
	delete proj.dependencies[name];
	project.write(proj);

	reportSplit(project.runSplit());
	term.ok(`removed ${name} (${entry.path}/)`);
}

export async function list() {
	const entries = lock.read();
	if (entries.length === 0) {
		term.print("No packages installed. Try `boil explore`.");
		return;
	}

	const nameWidth = entries.reduce((widest, entry) => Math.max(widest, entry.name.length), 12);

	term.heading(`Installed (${entries.length})`);
	for (const entry of entries) {
		let status = "";
		if (!isDir(entry.path)) {
			status = term.red("  missing — run `boil install`");
		} else if (project.fingerprint(entry.path) !== entry.fingerprint) {
			status = term.yellow("  modified locally");
		}
		term.print(
			`  ${format.pad(entry.name, nameWidth)}  ${format.pad(entry.version, 9)}${term.dim(`${entry.path}/`)}${status}`,
		);
	}
	term.print("");
}

export async function outdated() {
	let stale = 0;

	for (const entry of lock.read()) {
		const listing = registry.resolve(entry.name, entry.registry).listing;
		if (!listing) continue;

		const newest = format.latest(listing);
		if (!newest || newest.version === entry.version) continue;

		const current = semver.parse(entry.version);
		const candidate = semver.parse(newest.version);
		if (!current || !candidate || semver.compare(candidate, current) <= 0) continue;

		if (stale === 0) {
			term.heading("Outdated");
		}
		stale += 1;
		const compatibility = format.compat(newest);
		const note = compatibility.ok ? "" : term.dim(`  (incompatible: ${compatibility.reason})`);
		term.print(`  ${entry.name}  ${entry.version} → ${term.green(newest.version)}${note}`);
	}

	if (stale === 0) {
		term.print("Everything is up to date.");
		return;
	}
	term.print("");
	term.print(term.dim("Update with `boil update <package>`."));
	term.print("");
}

async function updateOne(entry, force) {
	const listing = registry.resolve(entry.name, entry.registry).listing;
	if (!listing) {
		term.warn(`${entry.name} is not in any configured registry — skipped`);
		return false;
	}

	const newest = format.latest(listing);
	if (!newest) {
		term.warn(`${entry.name} has no published versions — skipped`);
		return false;
	}
	if (newest.version === entry.version) {
		return false;
	}

	const compatibility = format.compat(newest);
	if (!compatibility.ok && !force) {
		term.warn(`${entry.name} ${newest.version} is incompatible — ${compatibility.reason} (skipped)`);
		return false;
	}

	const modified = isDir(entry.path) && project.fingerprint(entry.path) !== entry.fingerprint;
	if (modified) {
		const [fetched] = source.fetch({
			git: (newest.source ?? "").replace(/^git\+/, ""),
			tag: newest.tag,
			subdir: newest.subdir,
		});
		if (fetched) {
			const { added, removed, changed } = diffDirs(entry.path, fetched);
			removeDir(fetched);
			term.warn(`${entry.name} has local edits. Upstream ${entry.version} → ${newest.version} changes:`);
			for (const rel of added) term.info(term.green(`+ ${rel}`));
			for (const rel of removed) term.info(term.red(`- ${rel}`));
			for (const rel of changed) term.info(term.yellow(`~ ${rel}`));
		}
		if (!force && !(await term.confirm(`Overwrite your local changes to ${entry.name}?`))) {
			term.info("skipped");
			return false;
		}
	}

	await add([`${entry.name}@${newest.version}`], { force: true, quiet: true, skipSplit: true, direct: false });
	return true;
}

export async function update(args, force) {
	let targets = lock.read();

	if (args[0]) {
		const entry = lock.find(args[0]);
		if (!entry) {
			term.fail(`"${args[0]}" is not installed`);
		}
		targets = [entry];
	}

	let updated = 0;
	for (const entry of targets) {
		if (await updateOne(entry, force)) {
			updated += 1;
		}
	}

	reportSplit(project.runSplit());
	if (updated === 0) {
		term.print("Nothing to update.");
		return;
	}
	term.ok(`updated ${updated} package(s)`);
}

// Restore every locked package that isn't on disk (a fresh clone of the game).
export async function install() {
	let restored = 0;
	for (const entry of lock.read()) {
		if (isDir(entry.path)) continue;

		const [dir, error] = source.fetch({
			git: entry.source.replace(/^git\+/, ""),
			tag: entry.tag,
			subdir: entry.subdir,
		});
		if (!dir) {
			term.warn(`${entry.name}: ${error}`);
			continue;
		}
		copyDir(dir, entry.path);
		removeDir(dir);
		restored += 1;
		term.ok(`restored ${entry.name} ${entry.version} → ${entry.path}/`);
	}

	if (restored === 0) {
		term.print("Everything in the lockfile is already on disk.");
		return;
	}
	reportSplit(project.runSplit());
}

export async function search(args) {
	const needle = args[0];
	if (!needle) {
		term.fail("usage: boil search <term>");
	}

	if (!registry.anyCached()) {
		term.fail("no index has been fetched yet — run `boil refresh` first");
	}

	const hits = registry.searchAll(needle);
	if (hits.length === 0) {
		term.print(`No packages match "${needle}".`);
		return;
	}

	term.heading(`${hits.length} result(s) for "${needle}"`);
	for (const line of format.rows(hits, installedVersions())) {
		term.print(line);
	}
	term.print("");
}

export async function info(args) {
	const name = args[0];
	if (!name) {
		term.fail("usage: boil info <package>");
	}

	// Same spec grammar as `add`, so `boil info company:acme/shop` works.
	const spec = source.parseSpec(name);
	const wanted = spec.name ?? name;

	const found = registry.resolve(wanted, spec.registry);
	if (found.error) {
		term.fail(found.error);
	}
	if (found.ambiguous) {
		term.print(term.red(`"${wanted}" is published in more than one registry:`));
		for (const match of found.ambiguous) {
			term.info(`• ${term.bold(`${match.registry}:${wanted}`)}  ${term.dim(match.description)}`);
		}
		term.fail("qualify which one you mean, e.g. `boil info <registry>:<package>`");
	}
	const listing = found.listing;
	if (!listing) {
		term.fail(`"${wanted}" is not in any configured registry`);
	}

	term.print("");
	for (const line of format.detail(listing, format.latest(listing), installedVersions()[wanted])) {
		term.print(line);
	}
	term.print("");
}

export async function refresh() {
	const results = registry.refreshAll();
	let failures = 0;

	for (const result of results) {
		if (!result.ok) {
			failures += 1;
			term.warn(`${result.name}: ${result.message}`);
			continue;
		}
		term.ok(`${term.bold(result.name)}  ${result.message} — ${registry.load(result.url).length} package(s)`);
	}

	if (failures === results.length) {
		term.fail("no registry could be reached");
	}
}

// Everything that's wrong with the current install set, in one pass.
export async function doctor() {
	let problems = 0;
	const problem = (text) => {
		problems += 1;
		term.print(`  ${term.yellow("!")} ${text}`);
	};

	term.heading("doctor");

	const entries = lock.read();
	const installed = installedVersions();
	const wallyText = isFile("wally.toml") ? readFile("wally.toml") : "";

	for (const entry of entries) {
		if (!isDir(entry.path)) {
			problem(`${entry.name}: ${entry.path}/ is missing — run \`boil install\``);
			continue;
		}

		const [pkg] = manifest.read(entry.path);
		if (!pkg) {
			problem(`${entry.name}: no boil.toml in ${entry.path}/`);
			continue;
		}

		for (const [name, range] of Object.entries(pkg.dependencies)) {
			if (!installed[name]) {
				problem(`${entry.name} depends on ${name} ${range}, which is not installed`);
				continue;
			}
			if (!semver.satisfies(installed[name], range)) {
				problem(`${entry.name} needs ${name} ${range}, but ${installed[name]} is installed`);
			}
		}

		for (const name of Object.keys(pkg.wally)) {
			if (!new RegExp(`\\n\\s*${name}\\s*=`).test(wallyText)) {
				problem(`${entry.name} needs the Wally package ${name}, which is not in wally.toml`);
			}
		}

		if (pkg.studio.tags || pkg.studio.notes) {
			term.print(`  ${term.cyan("i")} ${entry.name} expects Studio assets — \`boil info ${entry.name}\` to review`);
		}
	}

	// Folders that look like packages but aren't tracked.
	for (const root of Object.values(project.INSTALL_DIRS)) {
		if (!isDir(root)) continue;
		for (const folder of fs.readdirSync(root)) {
			const dir = path.join(root, folder);
			if (!isDir(dir) || !isFile(path.join(dir, manifest.FILENAME))) continue;
			const [pkg] = manifest.read(dir);
			if (pkg && !lock.find(pkg.name)) {
				problem(
					`${dir}/ has a boil.toml (${pkg.name}) but no lockfile entry — publish it or \`boil add path:${dir}\``,
				);
			}
		}
	}

	// Counted separately from the package problems above: a stale CLI is a
	// problem with the tool, not with anything this project installed, and the
	// summary line below is about packages.
	const stale = self.announce(await self.check());

	if (problems === 0) {
		term.ok(`${entries.length} package(s), nothing wrong${stale ? " — but update the CLI" : ""}`);
		return;
	}
	term.print("");
	term.print(term.yellow(`${problems} problem(s).`));
}
