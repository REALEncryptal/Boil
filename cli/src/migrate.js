// `boil migrate` — convert a v1 index into a v2 registry, once.
//
// v1 stored a listing per package: a name, a description, and a list of
// versions each pointing at *another* repo and a tag. v2 stores the packages
// themselves. So migrating means following every one of those pointers while
// they still resolve, and writing what comes back into the new layout — oldest
// release first, so the history reads in the order things were published.
//
// This is throwaway code by design. It runs once per index and then the v1
// reader has no other caller.

import path from "node:path";

import * as manifest from "./manifest.js";
import * as registry from "./registry.js";
import * as semver from "./semver.js";
import * as source from "./source.js";
import * as term from "./term.js";
import { copyDir, isDir, removeDir, tempDir, trim } from "./util.js";

// Every release in the old index, oldest first across the whole index, so the
// new repo's history is chronological rather than grouped by package.
export function plan(listings) {
	const releases = [];
	for (const listing of listings) {
		for (const release of listing.versions) {
			releases.push({
				name: listing.name,
				kind: listing.kind,
				description: listing.description,
				version: release.version,
				repo: (release.source ?? "").replace(/^git\+/, ""),
				tag: release.tag,
			});
		}
	}

	return releases.sort((a, b) => {
		if (a.name !== b.name) return a.name < b.name ? -1 : 1;
		const left = semver.parse(a.version);
		const right = semver.parse(b.version);
		if (!left || !right) return 0;
		return semver.compare(left, right);
	});
}

function readOldIndex(url) {
	if (isDir(url)) {
		return [registry.loadV1(url), undefined];
	}

	const work = tempDir("old-index");
	removeDir(work);
	const [cloned, output] = source.git(["clone", "--quiet", url, work]);
	if (!cloned) {
		return [undefined, `could not clone ${url}:\n${trim(output)}`];
	}
	const listings = registry.loadV1(work);
	removeDir(work);
	return [listings, undefined];
}

export async function run(args, options = {}) {
	const from = args[0];
	if (!from) {
		term.fail("usage: boil migrate <old-index-url> [--registry=<name>]");
	}

	const target = options.registry ? registry.byName(options.registry) : registry.byName(registry.DEFAULT_NAME);
	if (!target) {
		term.fail(`unknown registry "${options.registry}"`);
	}

	term.heading("boil migrate");
	term.info(`from ${from}`);
	term.info(`into ${term.bold(target.name)} ${term.dim(target.url)}`);

	const [listings, readError] = readOldIndex(from);
	if (!listings) {
		term.fail(readError);
	}
	if (listings.length === 0) {
		term.fail(`no v1 listings found in ${from} — is that the old index?`);
	}

	const releases = plan(listings);
	term.print("");
	term.ok(`${listings.length} package(s), ${releases.length} release(s) to move`);

	if (options.dryRun) {
		for (const release of releases) {
			term.info(`${release.name} ${release.version}  ${term.dim(release.repo)}`);
		}
		return;
	}

	if (!options.yes && !(await term.confirm(`Write ${releases.length} release(s) into ${target.name}?`))) {
		term.print("Cancelled.");
		return;
	}

	// Work in one clone and push once at the end: a half-migrated registry is
	// worse than an unmigrated one.
	const local = isDir(target.url);
	const work = local ? target.url : tempDir("migrate");
	if (!local) {
		removeDir(work);
		const [cloned, output] = source.git(["clone", "--quiet", target.url, work]);
		if (!cloned) {
			term.fail(`could not clone ${target.url}:\n${trim(output)}`);
		}
	}

	registry.writeFormat(work, target.name);

	const moved = [];
	const skipped = [];

	for (const release of releases) {
		const [dir, error] = source.fetch({ git: release.repo, tag: release.tag });
		if (!dir) {
			skipped.push({ release, reason: trim(String(error)).split("\n")[0] });
			term.warn(`${release.name} ${release.version} — ${skipped.at(-1).reason}`);
			continue;
		}

		const [pkg] = manifest.read(dir);
		const subdir = `${registry.PACKAGES}/${release.name}`;
		const dest = path.join(work, subdir);
		removeDir(dest);
		copyDir(dir, dest);
		removeDir(dir);

		// v2 has no use for `repository` as a publish target; keep it only as a
		// link back to where the package was developed.
		if (pkg) {
			manifest.write(dest, { ...pkg, version: release.version });
		}

		source.git(["add", "-A"], work);
		source.git(["commit", "-m", `${release.name} ${release.version}`], work);
		const tag = registry.tagFor(release.name, release.version);
		const [tagged, tagOutput] = source.git(["tag", tag], work);
		if (!tagged) {
			term.warn(`could not tag ${tag}: ${trim(tagOutput)}`);
			continue;
		}
		moved.push(release);
		term.ok(`${release.name} ${release.version} → ${subdir}/  ${term.dim(tag)}`);
	}

	if (moved.length === 0) {
		term.fail("nothing could be migrated — every package repo failed to fetch");
	}

	if (!local) {
		const [pushed, output] = source.git(["push", "origin", "HEAD", "--tags"], work);
		removeDir(work);
		if (!pushed) {
			term.fail(`could not push the migrated registry:\n${trim(output)}`);
		}
	}

	term.print("");
	term.ok(`migrated ${moved.length} release(s) into ${target.name}`);
	if (skipped.length > 0) {
		term.warn(`${skipped.length} could not be fetched and were left behind:`);
		for (const { release, reason } of skipped) {
			term.info(`${release.name} ${release.version} — ${reason}`);
		}
	}
	term.info(`the old index at ${from} is now unused — archive it when you're happy`);
}
