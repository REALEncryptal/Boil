import assert from "node:assert/strict";
import { describe, it } from "node:test";

import { parseSpec } from "../src/source.js";

describe("parseSpec — registry qualification", () => {
	it("reads a bare name as an unqualified lookup", () => {
		assert.deepEqual(parseSpec("encryptal/shop"), { name: "encryptal/shop", version: undefined });
		assert.deepEqual(parseSpec("encryptal/shop@1.2.0"), { name: "encryptal/shop", version: "1.2.0" });
	});

	it("reads <registry>:<scope>/<name> as a qualified lookup", () => {
		assert.deepEqual(parseSpec("company:acme/shop"), {
			registry: "company",
			name: "acme/shop",
			version: undefined,
		});
		assert.deepEqual(parseSpec("company:acme/shop@2.0.0"), {
			registry: "company",
			name: "acme/shop",
			version: "2.0.0",
		});
	});

	it("keeps github: and path: meaning what they always did", () => {
		assert.deepEqual(parseSpec("github:owner/repo"), {
			git: "https://github.com/owner/repo",
			tag: undefined,
		});
		assert.deepEqual(parseSpec("github:owner/repo@v1.0.0"), {
			git: "https://github.com/owner/repo",
			tag: "v1.0.0",
		});
		assert.deepEqual(parseSpec("path:../my-skin"), { path: "../my-skin", tag: undefined });
	});

	it("leaves URLs alone", () => {
		assert.deepEqual(parseSpec("https://github.com/owner/repo"), {
			git: "https://github.com/owner/repo",
			tag: undefined,
		});
		assert.deepEqual(parseSpec("git@github.com:owner/repo.git"), {
			git: "git@github.com:owner/repo.git",
			tag: undefined,
		});
	});

	it("does not mistake a URL-ish string for a registry prefix", () => {
		// "https" would match the prefix pattern if the URL checks didn't run first.
		assert.equal(parseSpec("https://example.com/a/b").registry, undefined);
		assert.equal(parseSpec("http://example.com/a/b").registry, undefined);
	});

	it("needs a scope/name after the prefix, so a bare word isn't a registry", () => {
		// "notes:thing" has no slash — not a package reference, so it stays a name.
		assert.deepEqual(parseSpec("notes:thing"), { name: "notes:thing", version: undefined });
	});
});
