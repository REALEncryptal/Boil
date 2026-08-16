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

// Replace the package repo's contents with `dir`, then commit and tag.
function pushPackage(pkg, dir, tag) {
	const repo = pkg.repository;
	const work = tempDir("publish");
	removeDir(work);

	const [cloned, output] = source.git(["clone", "--quiet", repo, work]);
	if (!cloned) {
		term.warn(`could not clone ${repo}:\n${trim(output)}`);
		term.info("Create the repository first, then re-run publish.");
		return false;
	}

	for (const rel of listFiles(work)) {
		fs.rmSync(path.join(work, rel));
	}
	copyDir(dir, work);

	source.git(["add", "-A"], work);
	const [committed] = source.git(["commit", "-m", `${pkg.name} ${pkg.version}`], work);
	if (!committed) {
		term.info("no content changes to commit");
	}

	const [tagged, tagOutput] = source.git(["tag", tag], work);
	if (!tagged) {
		term.warn(`could not create tag ${tag}: ${trim(tagOutput)}`);
		removeDir(work);
		return false;
	}

	const [pushed, pushOutput] = source.git(["push", "origin", "HEAD", "--tags"], work);
	removeDir(work);
	if (!pushed) {
		term.warn(`push failed:\n${trim(pushOutput)}`);
		return false;
	}
	return true;
}

function emptyListing(pkg) {
	return { name: pkg.name, kind: pkg.kind, description: pkg.description ?? "", versions: [] };
}

function pushIndex(pkg, tag, registryName) {
	const url = registryName ? registry.byName(registryName).url : registry.url();
	if (isDir(url)) {
		const listing = registry.find(pkg.name, url) ?? emptyListing(pkg);
		mergeRelease(listing, pkg, tag);
		registry.writeListing(url, listing);
		term.ok(`updated the local index at ${url}`);
		return true;
	}

	const work = tempDir("index");
	removeDir(work);
	const [cloned, output] = source.git(["clone", "--quiet", url, work]);
	if (!cloned) {
		term.warn(`could not clone the index ${url}:\n${trim(output)}`);
		return false;
	}

	const listing = registry.find(pkg.name, work) ?? emptyListing(pkg);
	mergeRelease(listing, pkg, tag);
	registry.writeListing(work, listing);

	source.git(["add", "-A"], work);
	source.git(["commit", "-m", `${pkg.name} ${pkg.version}`], work);
	const [pushed, pushOutput] = source.git(["push", "origin", "HEAD"], work);
	removeDir(work);

	if (!pushed) {
		term.warn(`could not push to the index:\n${trim(pushOutput)}`);
		term.info("You may not have write access — open a pull request against the index instead.");
		return false;
	}
	return true;
}

export function mergeRelease(listing, pkg, tag) {
	listing.description = pkg.description ?? listing.description;
	listing.kind = pkg.kind;

	const release = {
		version: pkg.version,
		source: `git+${pkg.repository}`,
		tag,
		boil: pkg.boil,
		contract: pkg.contract,
	};

	const index = listing.versions.findIndex((existing) => existing.version === pkg.version);
	if (index >= 0) {
		listing.versions[index] = release;
		return;
	}
	listing.versions.push(release);
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
// it answers is "what happens if I pick this one?" — a version already in the
// index means a bump is needed, and no manifest at all means the scaffold runs.
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
		return { note: `${version} · already published — bump the version first`, ready: false };
	}

	const newest = format.latest(listing);
	return { note: newest ? `${version} · index has ${newest.version}` : `${version} · in the index`, ready: true };
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

// `boil publish` with nothing to publish named: show what's here, same as
// `boil explore` does for what's out there.
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

	if (!pkg.repository) {
		// The index stores a git URL per release, so this is the one thing that
		// can't be inferred — say exactly what to write and where.
		term.print("");
		term.info(`add this to ${term.bold(`${dir}/boil.toml`)}, pointing at the repo the package's code lives in:`);
		term.info(term.cyan(`repository = "https://github.com/<you>/${path.basename(dir)}"`));
		term.fail("no `repository` in boil.toml — the index records where each release came from");
	}

	let target = registry.byName(registry.DEFAULT_NAME);
	if (options.registry) {
		target = registry.byName(options.registry);
		if (!target) {
			const known = registry
				.all()
				.map((entry) => entry.name)
				.join(", ");
			term.fail(`unknown registry "${options.registry}" — configured: ${known}`);
		}
	}

	const tag = `v${pkg.version}`;
	if (options.dryRun) {
		term.ok(`dry run: would push ${dir}/ to ${pkg.repository} at ${tag} and register it in ${target.name} (${target.url})`);
		return;
	}

	term.print("");
	term.info(`push ${dir}/ → ${pkg.repository} @ ${tag}`);
	term.info(`register ${pkg.name} ${pkg.version} in ${term.bold(target.name)} ${term.dim(target.url)}`);
	if (!options.yes && !(await term.confirm("Publish?"))) {
		term.print("Cancelled.");
		return;
	}

	if (!pushPackage(pkg, dir, tag)) {
		term.fail("publish aborted — nothing was written to the index");
	}
	term.ok(`pushed ${pkg.repository} @ ${tag}`);

	if (!pushIndex(pkg, tag, options.registry)) {
		term.fail("the package was pushed, but the index was not updated");
	}
	term.ok(`published ${pkg.name} ${pkg.version}`);
	term.info(`anyone pointed at ${target.name} can now run ${term.bold(`boil add ${pkg.name}`)}`);
}
