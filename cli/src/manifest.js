// The package manifest: `boil.toml` inside a package folder.
//
// It lives *inside* the package because the splitter only copies `.luau` files —
// a TOML file in `src/features/Shop/` never reaches Roblox. So a package is
// exactly one self-describing directory, with nothing to keep in sync elsewhere.
//
// See docs/registry.md for the schema.

import * as semver from "./semver.js";
import * as toml from "./toml.js";
import { isFile, readFile, writeFile } from "./util.js";

export const FILENAME = "boil.toml";

function asStringMap(value) {
	const out = {};
	if (typeof value !== "object" || value === null || Array.isArray(value)) {
		return out;
	}
	for (const [key, entry] of Object.entries(value)) {
		if (typeof entry === "string") {
			out[key] = entry;
		}
	}
	return out;
}

export function parse(text) {
	let decoded;
	try {
		decoded = toml.parse(text);
	} catch (error) {
		return [undefined, `not valid TOML: ${error.message}`];
	}

	const pkg = decoded.package;
	if (typeof pkg !== "object" || pkg === null || Array.isArray(pkg)) {
		return [undefined, "missing a [package] section"];
	}

	const studio = typeof decoded.studio === "object" && decoded.studio !== null ? decoded.studio : {};

	return [
		{
			name: pkg.name ?? "",
			kind: pkg.kind ?? "feature",
			version: pkg.version ?? "",
			description: pkg.description,
			license: pkg.license,
			author: pkg.author,
			repository: pkg.repository,
			folder: pkg.folder,
			boil: pkg.boil,
			contract: pkg.contract,
			dependencies: asStringMap(decoded.dependencies),
			wally: asStringMap(decoded.wally),
			wallyServer: asStringMap(decoded["wally-server"]),
			studio: { tags: studio.tags, notes: studio.notes },
		},
		undefined,
	];
}

export function read(dir) {
	const path = `${dir}/${FILENAME}`;
	if (!isFile(path)) {
		return [undefined, `no ${FILENAME} in ${dir}/`];
	}
	return parse(readFile(path));
}

// Everything that must be true before a package can be published or installed.
export function validate(pkg) {
	const errors = [];

	if (!/^[A-Za-z0-9\-_.]+\/[A-Za-z0-9\-_.]+$/.test(pkg.name)) {
		errors.push(`name "${pkg.name}" must be scoped, e.g. "encryptal/shop"`);
	}
	if (pkg.kind !== "feature" && pkg.kind !== "skin") {
		errors.push(`kind "${pkg.kind}" must be "feature" or "skin"`);
	}
	if (!semver.parse(pkg.version)) {
		errors.push(`version "${pkg.version}" is not semver (e.g. "1.2.0")`);
	}
	if (!pkg.description) {
		errors.push("description is required — it's the line the explorer lists");
	}
	if (!pkg.boil) {
		errors.push('boil range is required, e.g. boil = "^0.3"');
	}
	if (pkg.kind === "skin" && !pkg.contract) {
		errors.push('skins must declare a contract range, e.g. contract = "^1"');
	}

	return errors;
}

function hasEntries(table) {
	return Object.keys(table ?? {}).length > 0;
}

export function serialize(pkg) {
	const body = {
		package: {
			name: pkg.name,
			kind: pkg.kind,
			version: pkg.version,
			description: pkg.description,
			license: pkg.license,
			author: pkg.author,
			repository: pkg.repository,
			folder: pkg.folder,
			boil: pkg.boil,
			contract: pkg.contract,
		},
	};
	if (hasEntries(pkg.dependencies)) body.dependencies = pkg.dependencies;
	if (hasEntries(pkg.wally)) body.wally = pkg.wally;
	if (hasEntries(pkg.wallyServer)) body["wally-server"] = pkg.wallyServer;
	if (pkg.studio.tags || pkg.studio.notes) {
		body.studio = { tags: pkg.studio.tags, notes: pkg.studio.notes };
	}
	return toml.stringify(body);
}

export function write(dir, pkg) {
	writeFile(`${dir}/${FILENAME}`, serialize(pkg));
}

export function empty(name, kind) {
	return {
		name,
		kind,
		version: "0.1.0",
		dependencies: {},
		wally: {},
		wallyServer: {},
		studio: {},
	};
}
