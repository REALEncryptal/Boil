import assert from "node:assert/strict";
import { describe, it } from "node:test";

import { PACKAGE, latestVersion, localVersion, status } from "../src/self.js";

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
