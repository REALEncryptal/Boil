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
// one it means, `upgrade` reports both, and every other command ends with a
// toast when there's a newer CLI on npm (see `notify`).

import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

import * as config from "./config.js";
import * as semver from "./semver.js";
import * as term from "./term.js";
import { isFile, readFile, writeFile } from "./util.js";

export const PACKAGE = "@encryptal/boil";
export const REGISTRY = "https://registry.npmjs.org";
export const UPDATE_COMMAND = `npm i -g ${PACKAGE}@latest`;

// How long a registry answer is trusted before asking again. The toast rides
// along on ordinary commands, so the cost has to be near zero: one lookup a day,
// every other run reads the cached answer off disk.
export const MAX_AGE_MS = 24 * 60 * 60 * 1000;

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

// The answer from npm, remembered in ~/.boil/ so the toast costs a file read
// instead of a request. A failed lookup is cached too (as null) — offline should
// mean one slow command a day, not one on every command.
export function cacheFile() {
	return path.join(config.dir(), "version-check.json");
}

export function readCache() {
	if (!isFile(cacheFile())) {
		return undefined;
	}
	try {
		const parsed = JSON.parse(readFile(cacheFile()));
		if (typeof parsed?.checkedAt !== "number") {
			return undefined;
		}
		return { checkedAt: parsed.checkedAt, latest: typeof parsed.latest === "string" ? parsed.latest : undefined };
	} catch {
		return undefined;
	}
}

export function writeCache(latest, now = Date.now()) {
	try {
		writeFile(cacheFile(), `${JSON.stringify({ checkedAt: now, latest: latest ?? null })}\n`);
	} catch {
		// A read-only or missing home directory is not worth failing a command over.
	}
}

// `cache: true` accepts a recent cached answer; without it the registry is asked
// every time, which is what a command that exists to report versions wants.
// Either way the result is written back, so the two paths share one answer.
export async function check(options = {}) {
	const { cache = false, now = Date.now(), maxAgeMs = MAX_AGE_MS, ...fetchOptions } = options;
	const local = localVersion();

	if (cache) {
		const cached = readCache();
		const age = cached ? now - cached.checkedAt : undefined;
		// A clock that moved backwards makes `age` negative; treat that as stale
		// rather than trusting the entry until the clock catches up.
		if (cached && age >= 0 && age < maxAgeMs) {
			return { local, latest: cached.latest, status: status(local, cached.latest), cached: true };
		}
	}

	const latest = await latestVersion(fetchOptions);
	writeCache(latest, now);
	return { local, latest, status: status(local, latest), cached: false };
}

// Said once per process. `announce` and the toast carry the same news, and
// `doctor` / `upgrade` reach the first one on their way to the second.
let said = false;

// Test seam: one process runs one command, so nothing else needs this.
export function resetNotice() {
	said = false;
}

// Print the result inline, where a command is already talking about versions.
// Silent when there's nothing worth saying — an unreachable registry shouldn't
// produce noise in a command that otherwise succeeded.
export function announce(result) {
	if (result.status === "behind") {
		term.warn(`your boil CLI is ${result.local} — ${result.latest} is published`);
		term.info(`${term.bold(UPDATE_COMMAND)}   ${term.dim("the CLI updates from npm, not from `boil upgrade`")}`);
		said = true;
		return true;
	}
	if (result.status === "current") {
		term.info(term.dim(`boil CLI ${result.local} (latest)`));
		said = true;
	}
	return false;
}

// The passive version: a small box after a command's own output. It's the last
// thing printed and never a prompt — the command the user actually ran has
// already finished and said its piece.
export function toast(result) {
	if (result.status !== "behind" || said) {
		return false;
	}

	const lines = [
		`${term.bold("Update available")}  ${term.dim(result.local)} → ${term.green(result.latest)}`,
		term.bold(UPDATE_COMMAND),
	];
	const inner = Math.max(...lines.map((line) => term.width(line)));
	const rule = "─".repeat(inner + 2);

	term.print("");
	term.print(term.dim(`  ╭${rule}╮`));
	for (const line of lines) {
		term.print(`  ${term.dim("│")} ${line}${" ".repeat(inner - term.width(line))} ${term.dim("│")}`);
	}
	term.print(term.dim(`  ╰${rule}╯`));
	said = true;
	return true;
}

// Every reason to stay quiet lives here: opted out, output isn't a terminal (a
// box of art has no business in a pipe or a CI log), or CI.
export function enabled(env = process.env, tty = process.stdout.isTTY) {
	if (env.BOIL_NO_UPDATE_NOTIFIER !== undefined) return false;
	if (env.NO_UPDATE_NOTIFIER !== undefined) return false; // npm's spelling, honoured too
	if (env.CI !== undefined) return false;
	return Boolean(tty);
}

// What every command ends with. Nothing in here may fail or hang the command it
// hangs off: the lookup is cached, short-fused, and wrapped.
export async function notify(options = {}) {
	if (said || !enabled()) {
		return false;
	}
	try {
		return toast(await check({ cache: true, timeoutMs: 1500, ...options }));
	} catch {
		return false;
	}
}
