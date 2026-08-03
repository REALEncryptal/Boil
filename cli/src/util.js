// Filesystem and string helpers shared by the boil CLI.

import fs from "node:fs";
import os from "node:os";
import path from "node:path";

const SKIP_DIRS = new Set([".git", ".github", "node_modules"]);

export function isDir(target) {
	try {
		return fs.statSync(target).isDirectory();
	} catch {
		return false;
	}
}

export function isFile(target) {
	try {
		return fs.statSync(target).isFile();
	} catch {
		return false;
	}
}

export function readFile(target) {
	return fs.readFileSync(target, "utf8");
}

export function writeFile(target, contents) {
	const parent = path.dirname(target);
	if (parent && parent !== ".") {
		ensureDir(parent);
	}
	fs.writeFileSync(target, contents);
}

export function ensureDir(target) {
	fs.mkdirSync(target, { recursive: true });
}

// Every file under `dir`, as paths relative to `dir`, sorted. `.git` is skipped
// so a freshly-cloned package fingerprints the same as an installed one.
export function listFiles(dir) {
	const out = [];

	const recurse = (current, prefix) => {
		if (!isDir(current)) {
			return;
		}
		for (const entry of fs.readdirSync(current)) {
			const full = path.join(current, entry);
			const rel = prefix === "" ? entry : `${prefix}/${entry}`;
			if (isFile(full)) {
				out.push(rel);
				continue;
			}
			if (isDir(full) && !SKIP_DIRS.has(entry)) {
				recurse(full, rel);
			}
		}
	};

	recurse(dir, "");
	out.sort();
	return out;
}

export function copyDir(src, dest) {
	ensureDir(dest);
	for (const rel of listFiles(src)) {
		const target = path.join(dest, rel);
		ensureDir(path.dirname(target));
		fs.copyFileSync(path.join(src, rel), target);
	}
}

export function removeDir(target) {
	fs.rmSync(target, { recursive: true, force: true });
}

// Which files differ between two copies of the same tree. Used to preview a
// package update and a framework upgrade before either overwrites anything.
export function diffDirs(a, b) {
	const added = [];
	const changed = [];
	const inA = new Set(listFiles(a));

	for (const rel of listFiles(b)) {
		if (!inA.has(rel)) {
			added.push(rel);
			continue;
		}
		if (readFile(path.join(a, rel)) !== readFile(path.join(b, rel))) {
			changed.push(rel);
		}
		inA.delete(rel);
	}

	const removed = [...inA];
	added.sort();
	removed.sort();
	changed.sort();
	return { added, removed, changed };
}

// "encryptal/player-data" -> "PlayerData". The folder name becomes the Roblox
// instance name and the registration key, so it has to be PascalCase.
export function pascal(name) {
	const last = name.split("/").pop() ?? name;
	const words = last.match(/[A-Za-z0-9]+/g) ?? [];
	return words.map((word) => word[0].toUpperCase() + word.slice(1)).join("");
}

export function trim(text) {
	return String(text).trim();
}

export function startsWith(text, prefix) {
	return String(text).startsWith(prefix);
}

export function tempDir(label) {
	return fs.mkdtempSync(path.join(os.tmpdir(), `boil-${label}-`));
}

// Word-wrap for the explorer's detail view.
export function wrap(text, width, indent) {
	const lines = [];
	for (const paragraph of trim(text).split("\n")) {
		let line = "";
		for (const word of paragraph.match(/\S+/g) ?? []) {
			if (line === "") {
				line = word;
			} else if (line.length + word.length + 1 <= width) {
				line += ` ${word}`;
			} else {
				lines.push(indent + line);
				line = word;
			}
		}
		lines.push(indent + line);
	}
	return lines;
}

// Regex-escape a string so it can be matched literally inside a pattern.
export function escapeRegex(text) {
	return String(text).replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}
