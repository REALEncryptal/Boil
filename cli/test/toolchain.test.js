import assert from "node:assert/strict";
import path from "node:path";
import { describe, it } from "node:test";

import { binDir, env as rokitEnv, toolPath } from "../src/rokit.js";
import { plan } from "../src/toolchain.js";

const labels = (steps) => steps.map((step) => step.label);

describe("plan", () => {
	it("installs the toolchain before anything that needs it", () => {
		// wally is a tool Rokit installs, so this order is the whole point of the
		// command: reverse it and a fresh machine fails on step one.
		assert.deepEqual(labels(plan()), ["rokit install", "wally install", "rojo plugin install"]);
	});

	it("puts `rokit update` ahead of the install", () => {
		assert.deepEqual(labels(plan({ update: true })), [
			"rokit update",
			"rokit install",
			"wally install",
			"rojo plugin install",
		]);
	});

	it("skips what the project doesn't have", () => {
		assert.deepEqual(labels(plan({ hasWally: false })), ["rokit install", "rojo plugin install"]);
		assert.deepEqual(labels(plan({ hasRokit: false, update: true })), ["wally install", "rojo plugin install"]);
	});

	it("drops the plugin when asked", () => {
		assert.deepEqual(labels(plan({ plugin: false })), ["rokit install", "wally install"]);
	});

	it("marks only the plugin optional — there's no Studio on a build server", () => {
		const optional = plan({ update: true }).filter((step) => step.optional);
		assert.deepEqual(labels(optional), ["rojo plugin install"]);
	});

	it("passes the plugin subcommand through as arguments", () => {
		const step = plan().find((candidate) => candidate.label === "rojo plugin install");
		assert.equal(step.command, "rojo");
		assert.deepEqual(step.args, ["plugin", "install"]);
	});
});

describe("tool resolution", () => {
	it("names the shim Rokit links", () => {
		assert.equal(toolPath("rojo", "linux"), path.join(binDir(), "rojo"));
		assert.equal(toolPath("rojo", "win32"), path.join(binDir(), "rojo.exe"));
	});

	it("puts the Rokit bin directory on the front of PATH", () => {
		const patched = rokitEnv({ PATH: "/usr/bin" });
		assert.equal(patched.PATH, `${binDir()}${path.delimiter}/usr/bin`);
	});

	it("leaves a PATH that already has it alone", () => {
		const base = { PATH: `${binDir()}${path.delimiter}/usr/bin` };
		assert.equal(rokitEnv(base), base);
	});

	it("handles an empty PATH and Windows's spelling of it", () => {
		assert.equal(rokitEnv({ PATH: "" }).PATH, binDir());
		assert.equal(rokitEnv({ Path: "C:\\bin" }).Path, `${binDir()}${path.delimiter}C:\\bin`);
	});
});
