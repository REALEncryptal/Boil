// The smallest semver that covers what package manifests actually use:
// exact ("1.2.3"), caret ("^1.2"), tilde ("~1.2.3"), comparators (">=1.0"),
// and any ("*" / "").
//
// Deliberately not node-semver: no ranges with spaces, no pre-release ordering
// rules beyond "a pre-release sorts below its release". If a manifest needs more
// than this, it's a sign the version scheme is too clever.

import { trim } from "./util.js";

export function parse(text) {
	const cleaned = String(text ?? "").replace(/^v/, "");

	let match = cleaned.match(/^(\d+)\.(\d+)\.(\d+)-?([0-9A-Za-z.-]*)$/);
	if (match) {
		return {
			major: Number(match[1]),
			minor: Number(match[2]),
			patch: Number(match[3]),
			pre: match[4] === "" ? undefined : match[4],
		};
	}

	match = cleaned.match(/^(\d+)\.(\d+)$/);
	if (match) {
		return { major: Number(match[1]), minor: Number(match[2]), patch: 0, pre: undefined };
	}

	match = cleaned.match(/^(\d+)$/);
	if (match) {
		return { major: Number(match[1]), minor: 0, patch: 0, pre: undefined };
	}

	return undefined;
}

export function toString(version) {
	const base = `${version.major}.${version.minor}.${version.patch}`;
	return version.pre ? `${base}-${version.pre}` : base;
}

// -1 / 0 / 1
export function compare(a, b) {
	for (const key of ["major", "minor", "patch"]) {
		if (a[key] !== b[key]) {
			return a[key] < b[key] ? -1 : 1;
		}
	}
	if (a.pre === b.pre) return 0;
	if (a.pre && !b.pre) return -1;
	if (b.pre && !a.pre) return 1;
	return a.pre < b.pre ? -1 : 1;
}

function caretCeiling(version) {
	if (version.major > 0) {
		return { major: version.major + 1, minor: 0, patch: 0 };
	}
	if (version.minor > 0) {
		return { major: 0, minor: version.minor + 1, patch: 0 };
	}
	return { major: 0, minor: 0, patch: version.patch + 1 };
}

// Does `version` satisfy `range`? Unparseable input is a miss, never an error —
// a malformed range in someone else's manifest shouldn't crash the CLI.
export function satisfies(version, range) {
	if (!range || range === "" || range === "*") {
		return true;
	}

	const target = parse(version);
	if (!target) {
		return false;
	}

	const match = trim(range).match(/^([\^~>=<]*)\s*(.+)$/);
	const wanted = match ? parse(match[2]) : undefined;
	if (!wanted) {
		return false;
	}
	const operator = match[1];

	if (operator === "" || operator === "=") return compare(target, wanted) === 0;
	if (operator === "^") {
		return compare(target, wanted) >= 0 && compare(target, caretCeiling(wanted)) < 0;
	}
	if (operator === "~") {
		const ceiling = { major: wanted.major, minor: wanted.minor + 1, patch: 0 };
		return compare(target, wanted) >= 0 && compare(target, ceiling) < 0;
	}
	if (operator === ">=") return compare(target, wanted) >= 0;
	if (operator === ">") return compare(target, wanted) > 0;
	if (operator === "<=") return compare(target, wanted) <= 0;
	if (operator === "<") return compare(target, wanted) < 0;
	return false;
}

// Highest version in `versions` satisfying `range`, or undefined.
export function maxSatisfying(versions, range) {
	let best;
	let bestParsed;
	for (const candidate of versions) {
		if (!satisfies(candidate, range)) continue;
		const parsed = parse(candidate);
		if (!parsed) continue;
		if (!bestParsed || compare(parsed, bestParsed) > 0) {
			best = candidate;
			bestParsed = parsed;
		}
	}
	return best;
}

// The next version of a given size. A pre-release bumps to its own release
// first — 1.2.0-rc.1 patches to 1.2.0, not 1.2.1, which is what "ship it" means.
export function bump(version, level = "patch") {
	const parsed = parse(version);
	if (!parsed) {
		return undefined;
	}
	const { major, minor, patch, pre } = parsed;

	if (level === "major") {
		return `${major + 1}.0.0`;
	}
	if (level === "minor") {
		return `${major}.${minor + 1}.0`;
	}
	return pre ? `${major}.${minor}.${patch}` : `${major}.${minor}.${patch + 1}`;
}
