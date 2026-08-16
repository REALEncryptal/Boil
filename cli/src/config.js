// User-level config — `~/.boil/config.toml`.
//
// Registries you use across every project live here, so adding your company's
// index is something you do once per machine rather than once per game. A
// project's own boil.toml can add more, and wins on a name collision.
//
//   [registries]
//   company = "https://github.com/acme/boil-index"
//   private = "git@github.com:me/secret-index"

import os from "node:os";
import path from "node:path";

import * as toml from "./toml.js";
import { isFile, readFile, writeFile } from "./util.js";

export function dir() {
	return path.join(os.homedir(), ".boil");
}

export function file() {
	return path.join(dir(), "config.toml");
}

export function exists() {
	return isFile(file());
}

export function read() {
	if (!exists()) {
		return { registries: {} };
	}
	try {
		const decoded = toml.parse(readFile(file()));
		return {
			registries: typeof decoded.registries === "object" && decoded.registries !== null ? decoded.registries : {},
			cli: typeof decoded.cli === "object" && decoded.cli !== null ? decoded.cli : {},
		};
	} catch {
		return { registries: {}, cli: {} };
	}
}

// Sections are preserved rather than rebuilt from the fields this module knows
// about: `boil registry add` must not wipe the [cli] block someone set by hand.
export function write(config) {
	const body = {};
	if (Object.keys(config.registries ?? {}).length > 0) {
		body.registries = config.registries;
	}
	if (Object.keys(config.cli ?? {}).length > 0) {
		body.cli = config.cli;
	}
	writeFile(file(), toml.stringify(body));
}

// One setting, read through the same file everything else uses.
export function setting(key, fallback) {
	const value = read().cli?.[key];
	return value === undefined ? fallback : value;
}

export function setSetting(key, value) {
	const current = read();
	current.cli = { ...current.cli, [key]: value };
	write(current);
}
