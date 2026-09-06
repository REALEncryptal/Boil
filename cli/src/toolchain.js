// The toolchain half of `boil install` — everything a checkout needs before
// `boil dev` can work, in the order it has to happen.
//
//   rokit update       (--update only) bump rokit.toml to the newest tools
//   rokit install      rojo, wally, lune on PATH at the pinned versions
//   wally install      Packages/ and ServerPackages/ from wally.lock
//   rojo plugin install  the Rojo Studio plugin, so Studio can connect
//
// This used to be four commands in the README that a new user ran by hand, and
// the one they skipped — `rojo plugin install` — is invisible until Studio has
// nothing to connect to. Ordering is not cosmetic: wally is a tool Rokit
// installs, so `wally install` before `rokit install` fails on a fresh machine.
//
// Nothing here is fatal on its own. A missing tool or a failed step is reported
// and the run continues, because `boil install` also restores packages and
// half a toolchain is still worth more than an early exit.

import { spawnSync } from "node:child_process";
import path from "node:path";

import * as rokit from "./rokit.js";
import * as term from "./term.js";
import { isFile } from "./util.js";

// What to run, given what this project has. Pure — the sequencing is the part
// worth testing, and testing it must not install anything.
export function plan({ update = false, plugin = true, hasRokit = true, hasWally = true } = {}) {
	const steps = [];

	if (hasRokit && update) {
		steps.push({ label: "rokit update", command: "rokit", args: ["update"] });
	}
	if (hasRokit) {
		steps.push({ label: "rokit install", command: "rokit", args: ["install"] });
	}
	if (hasWally) {
		steps.push({ label: "wally install", command: "wally", args: ["install"] });
	}
	// Optional: there's no Studio to install a plugin into on a build server, and
	// a headless CI run must not go red over it.
	if (plugin) {
		steps.push({ label: "rojo plugin install", command: "rojo", args: ["plugin", "install"], optional: true });
	}

	return steps;
}

function detect(root) {
	return {
		hasRokit: isFile(path.join(root, "rokit.toml")),
		hasWally: isFile(path.join(root, "wally.toml")),
	};
}

// Make sure Rokit itself is here before asking it to install anything. The npm
// postinstall already tries this; it's repeated because `--ignore-scripts`, a
// sudo'd install and a machine that was offline that day are all common.
async function ensureRokit() {
	const already = rokit.installed();
	if (already) {
		return true;
	}

	const skipped = rokit.skip();
	if (skipped) {
		term.warn(`Rokit isn't installed and the bootstrap is off — ${skipped}`);
		term.info(rokit.INSTALL_PAGE);
		return false;
	}

	term.info("Rokit isn't installed — fetching it…");
	const result = await rokit.install({ log: (line) => term.info(term.dim(line)) });
	if (!result.ok) {
		term.warn(`couldn't install Rokit — ${result.reason}`);
		term.info(`install it by hand and run \`boil install\` again — ${rokit.INSTALL_PAGE}`);
		return false;
	}

	term.ok(`installed Rokit ${result.version} → ${result.path}`);
	return true;
}

function execute(step, cwd) {
	const binary = rokit.resolve(step.command);
	if (!binary) {
		return { ...step, status: "missing" };
	}

	// Inherited stdio on purpose: these are the slow steps, and Rokit asks before
	// trusting a tool it hasn't seen. Swallowing that output would turn a prompt
	// into a hang.
	const result = spawnSync(binary, step.args, { cwd, stdio: "inherit", env: rokit.env() });
	if (result.error) {
		return { ...step, status: "failed", reason: result.error.message };
	}
	return { ...step, status: result.status === 0 ? "ok" : "failed", code: result.status ?? 1 };
}

// Returns every step's outcome so callers can decide what to say and whether to
// carry on. `ok` is false when a required step didn't run cleanly.
export async function run({ update = false, plugin = true, cwd = process.cwd() } = {}) {
	term.heading(update ? "updating the toolchain" : "installing the toolchain");

	const rokitReady = await ensureRokit();
	const steps = plan({ update, plugin, ...detect(cwd) });
	const results = [];

	for (const step of steps) {
		if (!rokitReady && step.command === "rokit") {
			results.push({ ...step, status: "missing" });
			continue;
		}

		term.print(`${term.cyan("→")} ${step.label}`);
		const result = execute(step, cwd);
		results.push(result);

		if (result.status === "ok") {
			continue;
		}
		if (result.status === "missing") {
			term.warn(`\`${step.command}\` isn't installed or isn't on PATH — skipped ${step.label}`);
			continue;
		}
		term.warn(`${step.label} failed${result.code ? ` (exit ${result.code})` : ""}`);
	}

	const failed = results.filter((result) => result.status !== "ok");
	const blocking = failed.filter((result) => !result.optional);

	if (failed.length === 0) {
		term.ok(`toolchain ready — ${results.map((result) => result.label).join(", ")}`);
	} else if (blocking.length > 0) {
		term.warn(`${blocking.length} step(s) didn't finish — fix what they reported, then \`boil install\` again`);
	}

	return { ok: blocking.length === 0, ran: results.length > 0, results };
}
