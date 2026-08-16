// `boil publish` — take a folder you built inside a real game and put it in the
// index.
//
// The gate matters more than the upload. A package that quietly assumes another
// feature exists, or requires a Wally package the consuming game doesn't have,
// installs cleanly and then breaks at runtime in someone else's project. Those
// checks are the reason this command exists rather than "just push the folder".

import fs from "node:fs";
import path from "node:path";

import * as format from "./format.js";
import * as manifest from "./manifest.js";
import * as project from "./project.js";
import * as registry from "./registry.js";
import * as semver from "./semver.js";
import * as source from "./source.js";
import * as term from "./term.js";
import { copyDir, isDir, listFiles, pascal, readFile, removeDir, startsWith, tempDir, trim } from "./util.js";

const LINTS = ["tools/split", "tools/check-views", "tools/check-framework-boundary", "tools/check-skins"];

function runLints() {
	const failures = [];
	const ran = [];
	for (const lint of LINTS) {
		const result = project.runLune(lint);
		if (result === undefined) {
			continue; // a downstream project may not carry every lint
		}
		ran.push(lint);
		if (!result.ok) {
			failures.push(`${lint}:\n${trim(result.output)}`);
		}
	}
	return { failures, ran };
}

// Wally packages the code requires but the manifest doesn't declare.
function undeclaredWally(pkg, dir) {
	const missing = new Set();
	for (const rel of listFiles(dir)) {
		if (!rel.endsWith(".luau")) continue;
		for (const line of readFile(path.join(dir, rel)).split("\n")) {
			if (startsWith(trim(line), "--")) continue;

			const server = line.match(/ServerPackages\.([A-Za-z0-9_]+)/);
			if (server) {
				if (!pkg.wallyServer[server[1]]) {
					missing.add(server[1]);
				}
				continue;
			}
			const shared = line.match(/Packages\.([A-Za-z0-9_]+)/);
			if (shared && !pkg.wally[shared[1]]) {
				missing.add(shared[1]);
			}
		}
	}
	return [...missing].sort();
}

// Cross-feature registration files imply a dependency.
//
// The convention is that a feature extends another by dropping a sibling file
// named after it (Notes/PlayerData.luau registers a profile slice into the
// PlayerData feature). Detected generically — a root file whose name matches an
// installed feature folder — so this tool never names a feature.
function undeclaredFeatureDeps(pkg, dir) {
	// Matched case-insensitively: a package name is lowercase by convention
	// ("boil/playerdata") while the folder and the registration file are
	// PascalCase ("PlayerData.luau"), so an exact match would flag a dependency
	// that *is* declared.
	const selfFolder = (pkg.folder ?? pascal(pkg.name)).toLowerCase();
	const declared = new Set(Object.keys(pkg.dependencies).map((name) => pascal(name).toLowerCase()));

	const missing = [];
	for (const rel of listFiles(dir)) {
		const match = rel.match(/^([A-Za-z0-9_]+)\.luau$/);
		if (!match) continue;
		const base = match[1];
		if (base.toLowerCase() === selfFolder || declared.has(base.toLowerCase())) continue;
		if (isDir(`${project.INSTALL_DIRS.feature}/${base}`)) {
			missing.push(base);
		}
	}
	return missing;
}

export function check(pkg, dir) {
	const problems = [...manifest.validate(pkg)];

	if (pkg.kind === "feature") {
		for (const rel of listFiles(dir)) {
			if (rel.includes("/") && rel.endsWith(".luau")) {
				problems.push(`${rel} is in a subfolder — the splitter only reads a feature folder's top level`);
			}
		}
	}

	for (const name of undeclaredWally(pkg, dir)) {
		problems.push(`requires Packages.${name} but doesn't declare it under [wally]`);
	}

	for (const name of undeclaredFeatureDeps(pkg, dir)) {
		problems.push(`has ${name}.luau (a registration file for the ${name} feature) but no [dependencies] entry for it`);
	}

	return problems;
}

// Fill in a manifest for a folder that doesn't have one yet.
async function scaffold(dir) {
	const folder = path.basename(dir);
	const kind = startsWith(dir, project.INSTALL_DIRS.skin) ? "skin" : "feature";

	term.print(`No ${manifest.FILENAME} in ${dir}/ — let's write one.`);
	const scope = (await term.text("Scope (your GitHub username or org)", "encryptal")) ?? "encryptal";
	const name = (await term.text("Package name", folder.toLowerCase())) ?? folder.toLowerCase();
	const description = (await term.text("One-line description")) ?? "";
	const version = (await term.text("Version", "0.1.0")) ?? "0.1.0";
	const repository = await term.text("Package git URL", `https://github.com/${scope}/boil-${folder.toLowerCase()}`);

	const pkg = manifest.empty(`${scope}/${name}`, kind);
	pkg.description = description;
	pkg.version = version;
	pkg.repository = repository;
	pkg.boil = `^${project.read().boil}`;
	if (kind === "skin") {
		pkg.contract = `^${project.contractVersion()}`;
	}

	manifest.write(dir, pkg);
	term.ok(`wrote ${dir}/${manifest.FILENAME} — edit it and re-run publish`);
	return pkg;
}

// Put the package into the registry and tag the release.
//
// One repo, one push. The v1 flow pushed the folder to a repo you had to create
// yourself and *then* pushed a listing to the index, which could half-succeed —
// code published, index not. There is nothing to half-succeed here.
function publishToRegistry(pkg, dir, target, tag) {
	const local = isDir(target.url);
	const work = local ? target.url : tempDir("publish");

	if (!local) {
		removeDir(work);
		const [cloned, output] = source.git(["clone", "--quiet", target.url, work]);
		if (!cloned) {
			term.warn(`could not clone the registry ${target.url}:\n${trim(output)}`);
			return false;
		}
	}

	if (registry.formatOf(work) !== registry.FORMAT) {
		term.warn(`${target.name} is still the old index format (a list of links to other repos)`);
		term.info(`convert it once with ${term.bold(`boil migrate ${target.url}`)}, then publish again`);
		if (!local) removeDir(work);
		return false;
	}

	const dest = path.join(work, pkg.subdir ?? subdirFor(pkg));
	removeDir(dest);
	copyDir(dir, dest);

	source.git(["add", "-A"], work);
	const [committed, commitOutput] = source.git(["commit", "-m", `${pkg.name} ${pkg.version}`], work);
	if (!committed && !trim(commitOutput).includes("nothing to commit")) {
		term.warn(`could not commit:\n${trim(commitOutput)}`);
		if (!local) removeDir(work);
		return false;
	}

	const [tagged, tagOutput] = source.git(["tag", tag], work);
	if (!tagged) {
		term.warn(`could not create tag ${tag}: ${trim(tagOutput)}`);
		if (!local) removeDir(work);
		return false;
	}

	if (local) {
		term.ok(`updated the local registry at ${target.url}`);
		return true;
	}

	const pushed = pushWithRetry(work, tag);
	removeDir(work);
	return pushed;
}

// Two people publishing at once race on the push. Rebase onto whatever landed
// first and try again rather than reporting a conflict that isn't one.
function pushWithRetry(work, tag, attempts = 3) {
	for (let attempt = 1; attempt <= attempts; attempt += 1) {
		const [pushed, output] = source.git(["push", "origin", "HEAD", tag], work);
		if (pushed) {
			return true;
		}
		if (attempt === attempts) {
			term.warn(`push failed:\n${trim(output)}`);
			return false;
		}
		term.info(term.dim("someone else pushed first — rebasing and retrying"));
		const [rebased, rebaseOutput] = source.git(["pull", "--rebase", "--quiet", "origin", "HEAD"], work);
		if (!rebased) {
			term.warn(`could not rebase onto the registry:\n${trim(rebaseOutput)}`);
			return false;
		}
	}
	return false;
}

export function subdirFor(pkg) {
	return `${registry.PACKAGES}/${pkg.name}`;
}

// Every folder in this checkout that could be published — one per feature and
// skin, whether or not it has a boil.toml yet, since publishing scaffolds one.
export function candidates(dirs = project.INSTALL_DIRS) {
	const found = [];

	for (const [kind, root] of Object.entries(dirs)) {
		if (!isDir(root)) {
			continue;
		}
		for (const entry of fs.readdirSync(root, { withFileTypes: true })) {
			if (!entry.isDirectory()) {
				continue;
			}
			const dir = `${root}/${entry.name}`;
			const [pkg] = manifest.read(dir);
			found.push({ kind, dir, folder: entry.name, pkg });
		}
	}

	return found.sort((a, b) => (a.dir < b.dir ? -1 : a.dir > b.dir ? 1 : 0));
}

// What the picker says about a candidate on its right-hand side. The question
// it answers is "what happens if I pick this one?" — a version already released
// means a bump is coming, and no manifest at all means the scaffold runs.
export function describe(candidate, listings = allListings()) {
	if (!candidate.pkg) {
		return { note: "no boil.toml yet — publishing writes one", ready: false };
	}

	const listing = listings.find((entry) => entry.name === candidate.pkg.name);
	const version = candidate.pkg.version;
	if (!listing) {
		return { note: `${version} · new package`, ready: true };
	}
	if (listing.versions.some((release) => release.version === version)) {
		return { note: `${version} · already published — publishing offers a bump`, ready: false };
	}

	const newest = format.latest(listing);
	return { note: newest ? `${version} · registry has ${newest.version}` : `${version} · in the registry`, ready: true };
}

function allListings() {
	const seen = new Map();
	for (const entry of registry.all()) {
		for (const listing of registry.load(entry.url)) {
			if (!seen.has(listing.name)) {
				seen.set(listing.name, listing);
			}
		}
	}
	return [...seen.values()];
}

// `boil publish` with nothing named: show what's here, the way `explore` shows
// what's out there.
async function pick() {
	const found = candidates();
	if (found.length === 0) {
		term.fail(
			`nothing to publish — ${Object.values(project.INSTALL_DIRS).join("/ and ")}/ are empty. A package is one folder in either.`,
		);
	}

	const listings = allListings();
	const width = Math.max(...found.map((candidate) => candidate.folder.length));
	const rows = found.map((candidate) => {
		const { note, ready } = describe(candidate, listings);
		const name = ready ? term.bold(candidate.folder.padEnd(width)) : candidate.folder.padEnd(width);
		return `${name}  ${term.dim(`${candidate.kind}  ·  ${note}`)}`;
	});

	term.heading(`Publish from this project (${found.length})`);
	term.print("");
	const choice = await term.select("Which package?", rows);
	return choice ? found[choice - 1].dir : undefined;
}

export async function run(args, options = {}) {
	let dir = args[0];
	if (!dir) {
		if (!term.isInteractive()) {
			term.fail("usage: boil publish <path-to-package> — or run it with no arguments in a terminal to pick one");
		}
		dir = await pick();
		if (!dir) {
			term.print("Nothing published.");
			return;
		}
	}
	dir = dir.replace(/\/$/, "");
	if (!isDir(dir)) {
		term.fail(`no such directory: ${dir}`);
	}

	const [pkg] = manifest.read(dir);
	if (!pkg) {
		await scaffold(dir);
		return;
	}

	term.heading(`Publishing ${pkg.name} ${pkg.version}`);

	const problems = check(pkg, dir);
	if (problems.length > 0) {
		term.print("");
		for (const message of problems) {
			term.print(`  ${term.red("×")} ${message}`);
		}
		term.fail(`${problems.length} problem(s) — fix these before publishing`);
	}
	term.ok("manifest, layout and declared dependencies check out");

	const { failures, ran } = runLints();
	if (failures.length > 0) {
		term.print("");
		for (const failure of failures) {
			term.print(term.red(failure));
		}
		term.fail("lints failed");
	}
	if (ran.length === 0) {
		term.warn("no lints ran — `lune` or tools/ is missing, so the gate only covered the manifest");
	} else {
		term.ok(`lints pass (${ran.join(", ")})`);
	}

	const target = await chooseRegistry(options);

	registry.ensureFresh(target.url);

	// The version is the release. If it's taken, publishing it again would be a
	// second meaning for one number, so offer the next one instead of failing.
	const published = releasedVersions(pkg.name, target.url);
	if (published.includes(pkg.version)) {
		const bumped = await offerBump(pkg, published, dir, options);
		if (!bumped) {
			term.fail(`${pkg.name} ${pkg.version} is already published in ${target.name} — bump the version to publish again`);
		}
	}

	const tag = registry.tagFor(pkg.name, pkg.version);
	const subdir = subdirFor(pkg);

	if (options.dryRun) {
		term.ok(`dry run: would write ${dir}/ to ${subdir}/ in ${target.name} (${target.url}) and tag ${tag}`);
		return;
	}

	term.print("");
	term.info(`${target.name} ${term.dim(target.url)}`);
	term.info(`${dir}/ → ${subdir}/, tagged ${term.bold(tag)}`);
	if (!options.yes && !(await term.confirm("Publish?"))) {
		term.print("Cancelled.");
		return;
	}

	if (!publishToRegistry(pkg, dir, target, tag)) {
		term.fail("publish aborted — nothing was written to the registry");
	}

	term.ok(`published ${pkg.name} ${pkg.version}`);
	term.info(`anyone pointed at ${target.name} can now run ${term.bold(`boil add ${pkg.name}`)}`);
}

// Where this release is going.
//
// Defaulting to the built-in public index is wrong the moment someone has
// configured their own: a private feature would be aimed at a registry the
// whole world reads. So when there's a choice to make, make it out loud.
async function chooseRegistry(options) {
	const configured = registry.all();

	if (options.registry) {
		const named = registry.byName(options.registry);
		if (!named) {
			const known = configured.map((entry) => entry.name).join(", ");
			term.fail(`unknown registry "${options.registry}" — configured: ${known}`);
		}
		return named;
	}

	if (configured.length === 1) {
		return configured[0];
	}

	// Non-interactive keeps the old, predictable answer rather than guessing.
	if (!term.isInteractive() || options.yes) {
		return registry.byName(registry.DEFAULT_NAME);
	}

	term.print("");
	const labels = configured.map((entry) => `${entry.name}  ${term.dim(`${entry.url}  (${entry.scope})`)}`);
	const choice = await term.select("Publish to which registry?", labels);
	if (!choice) {
		term.print("Cancelled.");
		process.exit(0);
	}
	return configured[choice - 1];
}

// Versions already tagged in the registry.
export function releasedVersions(name, registryUrl) {
	const listing = registry.find(name, registryUrl);
	return listing ? listing.versions.map((release) => release.version) : [];
}

// Offer the next patch/minor/major and write the choice into boil.toml, so a
// re-publish is one keypress rather than an edit, a save and a re-run.
async function offerBump(pkg, published, dir, options) {
	const next = {
		patch: semver.bump(pkg.version, "patch"),
		minor: semver.bump(pkg.version, "minor"),
		major: semver.bump(pkg.version, "major"),
	};

	term.print("");
	term.warn(`${pkg.name} ${pkg.version} is already published`);
	if (options.yes || !term.isInteractive()) {
		return false;
	}

	const labels = [
		`patch  ${next.patch}`,
		`minor  ${next.minor}`,
		`major  ${next.major}`,
	];
	const choice = await term.select(`Publish a new version instead? (published: ${published.join(", ")})`, labels);
	if (!choice) {
		return false;
	}

	pkg.version = [next.patch, next.minor, next.major][choice - 1];
	manifest.write(dir, pkg);
	term.ok(`${dir}/${manifest.FILENAME} → version = "${pkg.version}"`);
	return true;
}
