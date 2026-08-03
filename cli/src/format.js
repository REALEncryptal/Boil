// Rendering shared by the scriptable commands and the explorer.
//
// Both surfaces show the same rows and the same detail view, from the same code:
// the explorer is a discovery aid over the commands, never a second
// implementation that can drift from them.

import * as project from "./project.js";
import * as semver from "./semver.js";
import * as term from "./term.js";
import { wrap } from "./util.js";

// Is this release installable into *this* checkout? Checked up front so the
// explorer can mark a package incompatible in the list, rather than letting the
// user find out by installing something that breaks at runtime.
export function compat(release) {
	const boil = project.read().boil;
	if (release.boil && !semver.satisfies(boil, release.boil)) {
		return { ok: false, reason: `needs Boil ${release.boil}, this checkout is ${boil}` };
	}

	if (!release.contract) {
		return { ok: true };
	}

	const contract = project.contractVersion();
	if (!semver.satisfies(`${contract}.0.0`, release.contract)) {
		return { ok: false, reason: `needs skin contract ${release.contract}, this checkout is v${contract}` };
	}
	return { ok: true };
}

export function latest(listing) {
	let best;
	for (const release of listing.versions) {
		const parsed = semver.parse(release.version);
		if (!parsed) continue;
		if (!best || semver.compare(parsed, semver.parse(best.version)) > 0) {
			best = release;
		}
	}
	return best;
}

export function findRelease(listing, range) {
	if (!range) {
		return latest(listing);
	}
	const picked = semver.maxSatisfying(
		listing.versions.map((release) => release.version),
		range,
	);
	if (!picked) {
		return undefined;
	}
	return listing.versions.find((release) => release.version === picked);
}

export function pad(text, columns) {
	const visible = term.width(text);
	return visible >= columns ? String(text) : text + " ".repeat(columns - visible);
}

// One list row: "encryptal/shop      1.2.0  Currency shop with rotating stock"
export function row(listing, installed, nameWidth) {
	const release = latest(listing);
	const version = release ? release.version : "—";
	let marker = " ";
	let suffix = "";

	if (installed[listing.name]) {
		marker = term.green("●");
		if (release && installed[listing.name] !== release.version) {
			suffix = term.yellow(` (installed ${installed[listing.name]})`);
		}
	} else if (release && !compat(release).ok) {
		marker = term.red("×");
	}

	const kind = pad(listing.kind, 8);
	return `${marker} ${pad(listing.name, nameWidth)}  ${term.dim(kind)}${pad(version, 9)}${listing.description}${suffix}`;
}

export function rows(listings, installed) {
	const nameWidth = listings.reduce((widest, listing) => Math.max(widest, listing.name.length), 12);
	return listings.map((listing) => row(listing, installed, nameWidth));
}

// The detail view: everything you need to decide whether to install.
export function detail(listing, release, installedVersion) {
	const lines = [];
	const add = (text) => lines.push(text ?? "");

	add(term.bold(listing.name));
	for (const line of wrap(listing.description, 72, "")) {
		add(term.dim(line));
	}
	add();

	if (!release) {
		add(term.yellow("No published versions."));
		return lines;
	}

	const compatibility = compat(release);
	const installedNote = installedVersion ? term.dim(` (installed: ${installedVersion})`) : "";
	add(`  ${pad("version", 12)}${release.version}${installedNote}`);
	add(`  ${pad("kind", 12)}${listing.kind} → ${project.INSTALL_DIRS[listing.kind] ?? "?"}/`);
	if (release.source) {
		add(`  ${pad("source", 12)}${release.source}${release.tag ? term.dim(` @ ${release.tag}`) : ""}`);
	}
	if (release.published) {
		add(`  ${pad("published", 12)}${release.published}`);
	}
	add(
		`  ${pad("compatible", 12)}${
			compatibility.ok ? term.green("yes") : term.red("no") + term.dim(` — ${compatibility.reason}`)
		}`,
	);

	const other = listing.versions
		.filter((candidate) => candidate.version !== release.version)
		.map((candidate) => candidate.version);
	if (other.length > 0) {
		add(`  ${pad("other", 12)}${term.dim(other.join(", "))}`);
	}

	return lines;
}

// The parts of a manifest that only exist once the package is fetched: its
// dependencies, Wally requirements, and the Studio assets you have to build by
// hand. Printed after an install, and by `doctor`.
export function requirements(pkg) {
	const lines = [];

	if (Object.keys(pkg.dependencies).length > 0) {
		lines.push(term.bold("Depends on"));
		for (const [name, range] of Object.entries(pkg.dependencies)) {
			lines.push(`  ${name} ${term.dim(range)}`);
		}
	}

	const wally = [
		...Object.entries(pkg.wally).map(([name, spec]) => `  ${name} = "${spec}"`),
		...Object.entries(pkg.wallyServer).map(([name, spec]) => `  ${name} = "${spec}" ${term.dim("(server)")}`),
	];
	if (wally.length > 0) {
		lines.push(term.bold("Wally packages"));
		lines.push(...wally);
	}

	const studio = pkg.studio;
	if (!studio.tags && !studio.notes) {
		return lines;
	}

	lines.push(term.bold("Studio setup — you have to create these by hand"));
	for (const tag of studio.tags ?? []) {
		lines.push(`  CollectionService tag: ${term.cyan(tag)}`);
	}
	if (studio.notes) {
		lines.push(...wrap(studio.notes, 70, "  "));
	}

	return lines;
}
