import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { afterEach, describe, it } from "node:test";

import { stripAnsi } from "../src/term.js";
import {
	PACKAGE,
	check,
	enabled,
	latestVersion,
	localVersion,
	readCache,
	resetNotice,
	status,
	toast,
} from "../src/self.js";

// The cache lives under ~/.boil, so every test that touches it gets its own
// home directory rather than the machine's.
function withHome(run) {
	const previous = process.env.HOME;
	const dir = fs.mkdtempSync(path.join(os.tmpdir(), "boil-self-test-"));
	process.env.HOME = dir;
	try {
		return run(dir);
	} finally {
		if (previous === undefined) delete process.env.HOME;
		else process.env.HOME = previous;
		fs.rmSync(dir, { recursive: true, force: true });
	}
}

// term.print writes straight to stdout; capture it to assert on what's shown.
function captured(run) {
	const lines = [];
	const real = process.stdout.write;
	process.stdout.write = (chunk) => {
		lines.push(String(chunk));
		return true;
	};
	try {
		run();
	} finally {
		process.stdout.write = real;
	}
	return lines.join("");
}

const fetching = (version) => async () => ({ ok: true, json: async () => ({ name: PACKAGE, version }) });

describe("localVersion", () => {
	it("reads the version out of the CLI's own package.json", () => {
		assert.match(localVersion(), /^\d+\.\d+\.\d+/);
	});
});

describe("status", () => {
	it("spots an out-of-date CLI", () => {
		assert.equal(status("0.3.1", "0.3.2"), "behind");
		assert.equal(status("0.3.1", "1.0.0"), "behind");
	});

	it("says current when the versions match", () => {
		assert.equal(status("0.3.2", "0.3.2"), "current");
	});

	// The normal state in a checkout of this repo: package.json carries a bump
	// that hasn't been published yet.
	it("says ahead for an unreleased local version", () => {
		assert.equal(status("0.4.0", "0.3.2"), "ahead");
	});

	it("gives no answer when either side is unknown", () => {
		assert.equal(status(undefined, "0.3.2"), undefined);
		assert.equal(status("0.3.2", undefined), undefined);
	});
});

describe("latestVersion", () => {
	it("reads the version off the registry response", async () => {
		let requested;
		const fetchImpl = async (url) => {
			requested = url;
			return { ok: true, json: async () => ({ name: PACKAGE, version: "9.9.9" }) };
		};
		assert.equal(await latestVersion({ fetchImpl }), "9.9.9");
		// Scoped names go on the wire with the slash encoded.
		assert.equal(requested, "https://registry.npmjs.org/@encryptal%2fboil/latest");
	});

	it("returns undefined rather than throwing when the registry is unreachable", async () => {
		const fetchImpl = async () => {
			throw new Error("getaddrinfo ENOTFOUND registry.npmjs.org");
		};
		assert.equal(await latestVersion({ fetchImpl }), undefined);
	});

	it("returns undefined on a non-OK response", async () => {
		const fetchImpl = async () => ({ ok: false, status: 404, json: async () => ({}) });
		assert.equal(await latestVersion({ fetchImpl }), undefined);
	});

	it("returns undefined on a body without a version", async () => {
		const fetchImpl = async () => ({ ok: true, json: async () => ({ error: "Not found" }) });
		assert.equal(await latestVersion({ fetchImpl }), undefined);
	});

	it("gives up rather than hanging", async () => {
		const fetchImpl = (_url, { signal }) =>
			new Promise((_resolve, reject) => {
				signal.addEventListener("abort", () => reject(new Error("aborted")));
			});
		assert.equal(await latestVersion({ fetchImpl, timeoutMs: 10 }), undefined);
	});

	it("does nothing when the runtime has no fetch", async () => {
		const real = globalThis.fetch;
		globalThis.fetch = undefined;
		try {
			assert.equal(await latestVersion(), undefined);
		} finally {
			globalThis.fetch = real;
		}
	});
});

describe("check", () => {
	it("asks the registry and remembers the answer", async () => {
		await withHome(async () => {
			const result = await check({ fetchImpl: fetching("9.9.9"), now: 1000 });
			assert.equal(result.latest, "9.9.9");
			assert.equal(result.cached, false);
			assert.deepEqual(readCache(), { checkedAt: 1000, latest: "9.9.9" });
		});
	});

	it("reads a recent answer off disk instead of the network", async () => {
		await withHome(async () => {
			await check({ fetchImpl: fetching("9.9.9"), now: 1000 });

			let asked = false;
			const result = await check({
				cache: true,
				now: 1000 + 60_000,
				fetchImpl: async () => {
					asked = true;
					throw new Error("should not be reached");
				},
			});
			assert.equal(asked, false, "a fresh cache should not hit the registry");
			assert.equal(result.latest, "9.9.9");
			assert.equal(result.cached, true);
		});
	});

	it("asks again once the answer is a day old", async () => {
		await withHome(async () => {
			await check({ fetchImpl: fetching("9.9.9"), now: 1000 });
			const result = await check({ cache: true, now: 1000 + 25 * 60 * 60 * 1000, fetchImpl: fetching("9.9.10") });
			assert.equal(result.latest, "9.9.10");
			assert.equal(result.cached, false);
		});
	});

	// A clock that jumped backwards would otherwise freeze the cache as
	// permanently "fresh".
	it("treats an entry from the future as stale", async () => {
		await withHome(async () => {
			await check({ fetchImpl: fetching("9.9.9"), now: 5_000_000 });
			const result = await check({ cache: true, now: 1000, fetchImpl: fetching("9.9.10") });
			assert.equal(result.latest, "9.9.10");
		});
	});

	// Otherwise every command pays the timeout for as long as the user is offline.
	it("caches a failed lookup too", async () => {
		await withHome(async () => {
			const failing = async () => {
				throw new Error("ENOTFOUND");
			};
			const result = await check({ fetchImpl: failing, now: 1000 });
			assert.equal(result.latest, undefined);
			assert.equal(result.status, undefined);
			assert.deepEqual(readCache(), { checkedAt: 1000, latest: undefined });

			let asked = false;
			await check({
				cache: true,
				now: 2000,
				fetchImpl: async () => {
					asked = true;
					throw new Error("ENOTFOUND");
				},
			});
			assert.equal(asked, false);
		});
	});
});

describe("toast", () => {
	afterEach(() => resetNotice());

	it("shows the version jump and the npm command", () => {
		const output = captured(() => toast({ local: "0.3.3", latest: "0.3.4", status: "behind" }));
		assert.match(output, /Update available/);
		assert.match(output, /0\.3\.3/);
		assert.match(output, /0\.3\.4/);
		assert.match(output, /npm i -g @encryptal\/boil@latest/);
	});

	it("draws a box whose sides line up", () => {
		const output = captured(() => toast({ local: "0.3.3", latest: "0.10.0", status: "behind" }));
		const rows = output.split("\n").filter((line) => line.includes("│") || line.includes("╭") || line.includes("╰"));
		// Visible width — the colours in a real terminal are escapes, not columns.
		const widths = new Set(rows.map((line) => stripAnsi(line).length));
		assert.equal(widths.size, 1, `box rows should share one width, got ${[...widths].join(", ")}`);
	});

	it("says nothing when there's nothing newer", () => {
		for (const status of ["current", "ahead", undefined]) {
			assert.equal(captured(() => toast({ local: "0.3.4", latest: "0.3.4", status })), "");
		}
	});

	it("only speaks once per run, so a command that already said it isn't echoed", () => {
		const behind = { local: "0.3.3", latest: "0.3.4", status: "behind" };
		assert.notEqual(captured(() => toast(behind)), "");
		assert.equal(captured(() => toast(behind)), "");
	});
});

describe("enabled", () => {
	it("is on for an interactive terminal", () => {
		assert.equal(enabled({}, true), true);
	});

	it("stays out of pipes, CI, and opted-out shells", () => {
		assert.equal(enabled({}, false), false);
		assert.equal(enabled({ CI: "true" }, true), false);
		assert.equal(enabled({ BOIL_NO_UPDATE_NOTIFIER: "1" }, true), false);
		assert.equal(enabled({ NO_UPDATE_NOTIFIER: "1" }, true), false);
	});
});
