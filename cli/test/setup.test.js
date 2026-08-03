import assert from "node:assert/strict";
import { describe, it } from "node:test";

import { normalizeIndex, parseRepoUrl } from "../src/setup.js";

describe("normalizeIndex", () => {
	it("expands a bare name under the detected owner", () => {
		assert.deepEqual(normalizeIndex("private-index", { owner: "alexa" }), {
			url: "https://github.com/alexa/private-index",
			kind: "remote",
			expanded: true,
		});
	});

	it("asks for an owner rather than writing an unusable value", () => {
		const result = normalizeIndex("private-index", {});
		assert.equal(result.url, undefined, "nothing usable, so nothing to persist");
		assert.equal(result.needsOwner, true);
		assert.match(result.error, /just a name/);
	});

	it("expands owner/name", () => {
		assert.deepEqual(normalizeIndex("alexa/private-index", {}), {
			url: "https://github.com/alexa/private-index",
			kind: "remote",
			expanded: true,
		});
	});

	it("passes full URLs through untouched", () => {
		for (const url of [
			"https://github.com/alexa/private-index",
			"http://example.test/index",
			"git@github.com:alexa/private-index.git",
			"ssh://git@example.test/index.git",
			"file:///tmp/index.git",
		]) {
			assert.deepEqual(normalizeIndex(url, {}), { url, kind: "remote" }, url);
		}
	});

	it("treats path-shaped answers as local directories", () => {
		assert.deepEqual(normalizeIndex("../my-index", {}), { url: "../my-index", kind: "local" });
		assert.deepEqual(normalizeIndex("./idx", {}), { url: "./idx", kind: "local" });
		assert.deepEqual(normalizeIndex("/srv/index", {}), { url: "/srv/index", kind: "local" });
	});

	it("treats a Windows path as local", () => {
		const windows = "C:\\Users\\alexa\\Documents\\my-index";
		assert.deepEqual(normalizeIndex(windows, {}), { url: windows, kind: "local" });
	});

	it("makes --local win over the owner expansion", () => {
		assert.deepEqual(normalizeIndex("private-index", { owner: "alexa", local: true }), {
			url: "private-index",
			kind: "local",
		});
	});

	it("rejects an empty answer and obvious nonsense", () => {
		assert.match(normalizeIndex("", {}).error, /no index/);
		assert.match(normalizeIndex("   ", {}).error, /no index/);
		assert.match(normalizeIndex("a b c", {}).error, /isn't a URL/);
	});
});

describe("parseRepoUrl", () => {
	it("pulls owner and name out of the URL shapes GitHub uses", () => {
		assert.deepEqual(parseRepoUrl("https://github.com/alexa/boil-index"), ["alexa", "boil-index"]);
		assert.deepEqual(parseRepoUrl("git@github.com:alexa/boil-index.git"), ["alexa", "boil-index"]);
	});

	it("returns nothing for a non-GitHub URL", () => {
		assert.deepEqual(parseRepoUrl("https://gitlab.com/alexa/index"), [undefined, undefined]);
	});
});
