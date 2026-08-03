// boil-lock.toml — what is actually on disk right now.
//
// The lockfile is what makes vendored installs honest: it records where each
// folder came from and a fingerprint of the contents at install time, so
// `update` can tell an untouched package (safe to overwrite) from one you've
// edited, and `install` can restore a fresh clone of the game.

import fs from "node:fs";

import * as toml from "./toml.js";
import { isFile, readFile, writeFile } from "./util.js";

export const FILENAME = "boil-lock.toml";

export function read() {
	if (!isFile(FILENAME)) {
		return [];
	}
	try {
		const decoded = toml.parse(readFile(FILENAME));
		return Array.isArray(decoded.package) ? decoded.package : [];
	} catch {
		return [];
	}
}

export function write(entries) {
	entries.sort((a, b) => (a.name < b.name ? -1 : a.name > b.name ? 1 : 0));
	if (entries.length === 0) {
		if (isFile(FILENAME)) {
			fs.rmSync(FILENAME);
		}
		return;
	}
	writeFile(FILENAME, toml.stringify({ package: entries }));
}

export function find(name) {
	return read().find((entry) => entry.name === name);
}

export function upsert(entry) {
	const entries = read();
	const index = entries.findIndex((existing) => existing.name === entry.name);
	if (index >= 0) {
		entries[index] = entry;
	} else {
		entries.push(entry);
	}
	write(entries);
}

export function remove(name) {
	write(read().filter((entry) => entry.name !== name));
}
