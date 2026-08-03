// The consuming game's side of the registry: the root `boil.toml` (what this
// project depends on), the paths packages install into, and the compatibility
// numbers a package is checked against.

import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import { spawnSync } from "node:child_process";

import * as toml from "./toml.js";
import { escapeRegex, isDir, isFile, listFiles, pascal, readFile, writeFile } from "./util.js";

export const MANIFEST = "boil.toml";
export const CONTRACT = "src/shared/ui/contract.luau";
export const MARKER = "default.project.json";

// Where each package kind lands. Features go through the splitter; skins are
// pure shared-realm code and sync straight to ReplicatedStorage.Skins.
export const INSTALL_DIRS = {
	feature: "src/features",
	skin: "src/skins",
};

// Walk up from `from` looking for a Rojo project file. This is what lets the CLI
// be installed globally and run from anywhere inside a checkout — the Lune
// version could only ever run from the project root, because `lune run
// tools/boil` was itself a path into the project.
export function findRoot(from = process.cwd()) {
	let dir = path.resolve(from);
	while (true) {
		if (isFile(path.join(dir, MARKER))) {
			return dir;
		}
		const parent = path.dirname(dir);
		if (parent === dir) {
			return undefined;
		}
		dir = parent;
	}
}

export function read() {
	const defaults = { name: "boil-game", boil: "0.1.0", registries: {}, dependencies: {} };
	if (!isFile(MANIFEST)) {
		return defaults;
	}

	let decoded;
	try {
		decoded = toml.parse(readFile(MANIFEST));
	} catch {
		return defaults;
	}

	const meta = typeof decoded.project === "object" && decoded.project !== null ? decoded.project : {};
	return {
		name: meta.name ?? defaults.name,
		boil: meta.boil ?? defaults.boil,
		registries: typeof decoded.registries === "object" && decoded.registries !== null ? decoded.registries : {},
		dependencies:
			typeof decoded.dependencies === "object" && decoded.dependencies !== null ? decoded.dependencies : {},
	};
}

export function write(proj) {
	const body = { project: { name: proj.name, boil: proj.boil } };
	if (Object.keys(proj.registries).length > 0) body.registries = proj.registries;
	if (Object.keys(proj.dependencies).length > 0) body.dependencies = proj.dependencies;
	writeFile(MANIFEST, toml.stringify(body));
}

// The skin API version this checkout provides, read from the contract itself so
// it can never drift from the code.
export function contractVersion() {
	if (!isFile(CONTRACT)) {
		return 0;
	}
	const match = readFile(CONTRACT).match(/VERSION\s*=\s*(\d+)/);
	return match ? Number(match[1]) : 0;
}

export function installPath(pkg) {
	const root = INSTALL_DIRS[pkg.kind];
	return `${root}/${pkg.folder ?? pascal(pkg.name)}`;
}

// A content hash of an installed folder. Recorded at install time so `update`
// can tell "you never touched this, safe to overwrite" from "you edited it".
//
// The byte stream is the same one the Lune CLI hashed (path, NUL, contents, NUL,
// …), so lockfiles written by the old version stay valid.
export function fingerprint(dir) {
	const parts = [];
	for (const rel of listFiles(dir)) {
		parts.push(Buffer.from(rel, "utf8"));
		parts.push(fs.readFileSync(path.join(dir, rel)));
	}

	const separator = Buffer.from([0]);
	const joined = [];
	parts.forEach((part, index) => {
		if (index > 0) joined.push(separator);
		joined.push(part);
	});

	return crypto.createHash("sha256").update(Buffer.concat(joined)).digest("hex").slice(0, 16);
}

// Add a package's Wally requirements to wally.toml.
//
// Textual insert rather than a decode/encode round-trip: wally.toml is hand-
// maintained and a round-trip would reformat it and drop its comments. Returns
// the entries actually added.
export function mergeWally(pkg) {
	const added = [];
	if (!isFile("wally.toml")) {
		return added;
	}

	let text = readFile("wally.toml");

	const insert = (section, entries) => {
		for (const [name, spec] of Object.entries(entries)) {
			if (new RegExp(`\\n\\s*${escapeRegex(name)}\\s*=`).test(text)) {
				continue;
			}
			const header = `[${section}]`;
			if (!text.includes(header)) {
				text += `\n${header}\n`;
			}
			text = text.replace(`${header}\n`, () => `${header}\n${name} = "${spec}"\n`);
			added.push(`${name} = "${spec}"`);
		}
	};

	insert("dependencies", pkg.wally);
	insert("server-dependencies", pkg.wallyServer);

	if (added.length > 0) {
		writeFile("wally.toml", text);
	}
	return added;
}

// Run a Lune script from the project's tools/ directory. Returns undefined when
// the script isn't there (a downstream project may have removed a lint) and a
// result otherwise, so callers can tell "skipped" from "failed".
export function runLune(script) {
	if (!isFile(`${script}.luau`) && !isDir(script)) {
		return undefined;
	}
	const result = spawnSync("lune", ["run", script], { encoding: "utf8" });
	if (result.error) {
		return { ok: false, output: `could not run \`lune\` — is Rokit installed? (${result.error.code})` };
	}
	return { ok: result.status === 0, output: result.stderr || result.stdout || "" };
}

export function runSplit() {
	return runLune("tools/split");
}
