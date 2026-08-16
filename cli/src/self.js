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

import { spawnSync } from "node:child_process";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

import * as config from "./config.js";
import * as semver from "./semver.js";
import * as term from "./term.js";
import { isFile, readFile, trim, writeFile } from "./util.js";

export const PACKAGE = "@encryptal/boil";
export const REGISTRY = "https://registry.npmjs.org";
export const UPDATE_COMMAND = `npm i -g ${PACKAGE}@latest`;

// How long a registry answer is trusted before asking again. The toast rides
// along on ordinary commands, so the cost has to be near zero: one lookup a day,
// every other run reads the cached answer off disk.
export const MAX_AGE_MS = 24 * 60 * 60 * 1000;

// How this copy of the CLI got here, which decides both whether it can update
// itself and what command would do it. Installing with pnpm and updating with
// npm leaves two copies and a confusing PATH, so the manager has to match.
const MANAGERS = [
	{ manager: "pnpm", marker: /[\\/]pnpm[\\/]/i, command: (spec) => ["pnpm", "add", "-g", spec] },
	{ manager: "yarn", marker: /[\\/]yarn[\\/]/i, command: (spec) => ["yarn", "global", "add", spec] },
	{ manager: "bun", marker: /[\\/]\.bun[\\/]/i, command: (spec) => ["bun", "add", "-g", spec] },
	{ manager: "npx", marker: /[\\/]_npx[\\/]/i, command: undefined },
	{ manager: "npm", marker: /[\\/]node_modules[\\/]/i, command: (spec) => ["npm", "i", "-g", spec] },
];

export function installKind(dir = path.dirname(fileURLToPath(import.meta.url))) {
	for (const entry of MANAGERS) {
		if (entry.marker.test(dir)) {
			return { manager: entry.manager, command: entry.command?.(`${PACKAGE}@latest`), dir };
		}
	}
	// No node_modules anywhere in the path: this is a checkout being run in
	// place (`node bin/boil.js`), where updating the published copy would change
	// nothing about the code that's running.
	return { manager: "source", command: undefined, dir };
}

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

// Run the package manager's install. Deliberately the last thing a process
// does: replacing the package directory under a running node process is asking
// for a half-loaded module, so nothing may import anything after this.
export function update({ spawnImpl = spawnSync, install = installKind() } = {}) {
	if (!install.command) {
		const reason =
			install.manager === "source"
				? "this is a source checkout, not an installed copy — `git pull` instead"
				: `it was run through ${install.manager}, which fetches a fresh copy every time`;
		return { ok: false, reason };
	}

	const [command, ...args] = install.command;
	const result = spawnImpl(command, args, { encoding: "utf8" });

	if (result.error) {
		return { ok: false, reason: `could not run \`${command}\` (${result.error.code ?? result.error.message})` };
	}
	if (result.status !== 0) {
		const output = `${result.stdout ?? ""}${result.stderr ?? ""}`;
		// The overwhelmingly common failure: a global prefix the user can't write
		// to. Saying "permission" is more useful than replaying npm's stack.
		const permission = /EACCES|EPERM|permission denied/i.test(output);
		return {
			ok: false,
			reason: permission
				? `no permission to write the global install — try \`sudo ${install.command.join(" ")}\``
				: `\`${install.command.join(" ")}\` exited ${result.status}`,
			output: trim(output),
		};
	}

	return { ok: true, command: install.command.join(" ") };
}

// `boil self-update`, and what the toast runs when you say yes.
export async function selfUpdate({ silent = false } = {}) {
	const result = await check({ cache: false, timeoutMs: 4000 });

	if (result.status === undefined) {
		term.warn("couldn't reach npm to check for a newer version");
		return false;
	}
	if (result.status !== "behind") {
		if (!silent) {
			term.ok(`boil ${result.local} is already the newest`);
		}
		return false;
	}

	term.info(`updating ${result.local} → ${result.latest}…`);
	const outcome = update();
	if (!outcome.ok) {
		term.warn(`couldn't update — ${outcome.reason}`);
		if (outcome.output) {
			term.print(term.dim(outcome.output.split("\n").slice(-3).join("\n")));
		}
		return false;
	}

	said = true;
	term.ok(`updated to ${result.latest} — the next \`boil\` runs it`);
	return true;
}

// What every command ends with. Nothing in here may fail or hang the command it
// hangs off: the lookup is cached, short-fused, and wrapped.
//
// Three behaviours, set by `[cli] autoUpdate` in ~/.boil/config.toml:
//   "prompt" (default) — the toast, plus an offer to run the update now
//   true / "always"    — update without asking
//   false / "never"    — the toast only
export async function notify(options = {}) {
	if (said || !enabled()) {
		return false;
	}

	try {
		const result = await check({ cache: true, timeoutMs: 1500, ...options });
		if (result.status !== "behind") {
			return false;
		}

		const mode = config.setting("autoUpdate", "prompt");
		const install = installKind();

		// Nothing to offer when this copy can't update itself; say what it is and
		// let the toast stand.
		if (mode === "never" || mode === false || !install.command) {
			return toast(result);
		}

		if (mode === true || mode === "always") {
			term.info(`boil ${result.local} → ${result.latest}, updating…`);
			return (await selfUpdate({ silent: true })) || toast(result);
		}

		toast(result);
		said = false; // the toast is the question's context, so it may be shown again
		if (!(await term.confirm("Update now?"))) {
			said = true;
			term.info(term.dim("set `autoUpdate = false` under [cli] in ~/.boil/config.toml to stop asking"));
			return true;
		}
		return await selfUpdate({ silent: true });
	} catch {
		return false;
	}
}
