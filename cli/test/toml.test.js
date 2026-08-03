import assert from "node:assert/strict";
import { test } from "node:test";

import { parse, stringify } from "../src/toml.js";

test("parses the shapes a package manifest uses", () => {
	const decoded = parse(`
# leading comment
[package]
name = "encryptal/shop"   # trailing comment
kind = "feature"
version = "1.2.0"
pinned = true
weight = 3
ratio = 1.5

[dependencies]
"boil/playerdata" = "^1.0"

[studio]
tags = ["ShopKiosk", "ShopDoor"]
`);

	assert.equal(decoded.package.name, "encryptal/shop");
	assert.equal(decoded.package.pinned, true);
	assert.equal(decoded.package.weight, 3);
	assert.equal(decoded.package.ratio, 1.5);
	assert.equal(decoded.dependencies["boil/playerdata"], "^1.0");
	assert.deepEqual(decoded.studio.tags, ["ShopKiosk", "ShopDoor"]);
});

test("parses an array of tables, which is how the index and the lockfile are shaped", () => {
	const decoded = parse(`
name = "encryptal/shop"

[[version]]
version = "1.0.0"
tag = "v1.0.0"

[[version]]
version = "1.2.0"
tag = "v1.2.0"
`);

	assert.equal(decoded.name, "encryptal/shop");
	assert.equal(decoded.version.length, 2);
	assert.deepEqual(decoded.version[1], { version: "1.2.0", tag: "v1.2.0" });
});

test("parses multi-line strings, literal strings and inline tables", () => {
	const decoded = parse(`
notes = """
first
second
"""
literal = 'C:\\raw\\path'
inline = { a = 1, b = "two" }
multiline_array = [
  "one",
  "two",
]
`);

	assert.equal(decoded.notes, "first\nsecond\n");
	assert.equal(decoded.literal, "C:\\raw\\path");
	assert.deepEqual(decoded.inline, { a: 1, b: "two" });
	assert.deepEqual(decoded.multiline_array, ["one", "two"]);
});

test("round-trips a document unchanged", () => {
	const original = parse(`
[package]
name = "encryptal/shop"
version = "1.2.0"

[dependencies]
"boil/playerdata" = "^1.0"

[studio]
notes = """
Tag a part.
"""

[[version]]
version = "1.0.0"
`);

	assert.deepEqual(parse(stringify(original)), original);
});

// The failure this guards against: a table header emitted before a sibling
// scalar, which silently reparents that scalar into the table.
test("emits every scalar before the first table header", () => {
	const emitted = stringify({
		name: "encryptal/shop",
		kind: "feature",
		nested: { inner: 1 },
		description: "written last, must still be top-level",
	});

	assert.deepEqual(parse(emitted), {
		name: "encryptal/shop",
		kind: "feature",
		description: "written last, must still be top-level",
		nested: { inner: 1 },
	});
});

test("skips undefined values instead of emitting them", () => {
	const emitted = stringify({ package: { name: "a/b", license: undefined, version: "1.0.0" } });
	assert.ok(!emitted.includes("license"));
	assert.deepEqual(parse(emitted).package, { name: "a/b", version: "1.0.0" });
});

test("escapes quotes and backslashes so they survive a round-trip", () => {
	const value = { text: 'a "quoted" \\ backslash', "key with spaces": "ok" };
	assert.deepEqual(parse(stringify(value)), value);
});

test("reports where a malformed document went wrong", () => {
	assert.throws(() => parse("[unterminated\n"), /line 1/);
});
