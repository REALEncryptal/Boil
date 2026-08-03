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
		};
	} catch {
		return { registries: {} };
	}
}

export function write(config) {
	const body = {};
	if (Object.keys(config.registries ?? {}).length > 0) {
		body.registries = config.registries;
	}
	writeFile(file(), toml.stringify(body));
}
