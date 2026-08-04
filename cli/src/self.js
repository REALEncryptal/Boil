// The CLI's own version — what's installed here vs. what's published on npm.
//
// Two different things answer to the name "Boil" and each carries its own
// version number. The *framework* (src/shared, src/client, src/server, tools)
// lives inside a project and is what `boil upgrade` replaces. The *CLI* is
// installed globally from npm and moves on its own schedule; nothing inside a
// project can update it.
//
// Left alone, that's a trap: hit a bug that a newer CLI already fixed, run the
// command named "upgrade", and get told "already up to date" — true of the
// framework, useless to you. So every place that reports a version says which
// one it means, and `upgrade` reports both.

import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

import * as semver from "./semver.js";
import * as term from "./term.js";

export const PACKAGE = "@encryptal/boil";
export const REGISTRY = "https://registry.npmjs.org";
export const UPDATE_COMMAND = `npm i -g ${PACKAGE}@latest`;

export function localVersion() {
	try {
		const here = path.dirname(fileURLToPath(import.meta.url));
		return JSON.parse(fs.readFileSync(path.join(here, "..", "package.json"), "utf8")).version;
	} catch {
		return undefined;
	}
}

// undefined on any failure — offline, a proxy in the way, npm having a bad day.
// This is a courtesy hanging off another command; it never gets to fail one, and
// it never gets to hang one either, hence the timeout.
export async function latestVersion({ timeoutMs = 2500, fetchImpl = globalThis.fetch } = {}) {
	if (typeof fetchImpl !== "function") {
		return undefined;
	}

	const controller = new AbortController();
	const timer = setTimeout(() => controller.abort(), timeoutMs);
	try {
		// Scoped names go on the wire with the slash encoded: @encryptal%2fboil.
		const response = await fetchImpl(`${REGISTRY}/${PACKAGE.replace("/", "%2f")}/latest`, {
			signal: controller.signal,
			headers: { accept: "application/json" },
		});
		if (!response.ok) {
			return undefined;
		}
		const body = await response.json();
		return typeof body?.version === "string" ? body.version : undefined;
	} catch {
		return undefined;
	} finally {
		clearTimeout(timer);
	}
}

// "behind" | "current" | "ahead" | undefined when either side is unknown.
// "ahead" is the normal state in a checkout of this repo with an unreleased
// bump in package.json, so it is not something to nag about.
export function status(local, latest) {
	const here = semver.parse(local);
	const there = semver.parse(latest);
	if (!here || !there) {
		return undefined;
	}
	const order = semver.compare(here, there);
	if (order < 0) return "behind";
	if (order > 0) return "ahead";
	return "current";
}

export async function check(options) {
	const local = localVersion();
	const latest = await latestVersion(options);
	return { local, latest, status: status(local, latest) };
}

// Print the result. Silent when there's nothing worth saying — an unreachable
// registry shouldn't produce noise in a command that otherwise succeeded.
export function announce(result) {
	if (result.status === "behind") {
		term.warn(`your boil CLI is ${result.local} — ${result.latest} is published`);
		term.info(`${term.bold(UPDATE_COMMAND)}   ${term.dim("the CLI updates from npm, not from `boil upgrade`")}`);
		return true;
	}
	if (result.status === "current") {
		term.info(term.dim(`boil CLI ${result.local} (latest)`));
	}
	return false;
}
