import assert from "node:assert/strict";
import { test } from "node:test";

import * as manifest from "../src/manifest.js";
import * as source from "../src/source.js";
import { pascal, wrap } from "../src/util.js";

const VALID = `
[package]
name = "encryptal/shop"
kind = "feature"
version = "1.2.0"
description = "Currency shop"
repository = "https://github.com/encryptal/boil-shop"
boil = "^0.1"

[dependencies]
"boil/playerdata" = "^1.0"

[wally]
ByteNet = "ffrostflame/bytenet@0.4.6"

[wally-server]
ProfileStore = "madstudioroblox/profilestore@1.0.0"

[studio]
tags = ["ShopKiosk"]
notes = "Tag a part."
`;

test("parses every section of a package manifest", () => {
	const [pkg, error] = manifest.parse(VALID);
	assert.equal(error, undefined);
	assert.equal(pkg.name, "encryptal/shop");
	assert.equal(pkg.kind, "feature");
	assert.deepEqual(pkg.dependencies, { "boil/playerdata": "^1.0" });
	assert.deepEqual(pkg.wally, { ByteNet: "ffrostflame/bytenet@0.4.6" });
	assert.deepEqual(pkg.wallyServer, { ProfileStore: "madstudioroblox/profilestore@1.0.0" });
	assert.deepEqual(pkg.studio.tags, ["ShopKiosk"]);
	assert.equal(manifest.validate(pkg).length, 0);
});

test("a manifest with no [package] section is rejected, not half-read", () => {
	const [pkg, error] = manifest.parse('name = "loose"');
	assert.equal(pkg, undefined);
	assert.match(error, /\[package\]/);
});

test("invalid TOML reports as invalid rather than throwing", () => {
	const [pkg, error] = manifest.parse("[package\nname =");
	assert.equal(pkg, undefined);
	assert.match(error, /not valid TOML/);
});

test("validate catches each way a manifest can be unpublishable", () => {
	const [pkg] = manifest.parse(`
[package]
name = "unscoped"
kind = "widget"
version = "one"
`);
	const errors = manifest.validate(pkg).join("\n");
	assert.match(errors, /must be scoped/);
	assert.match(errors, /must be "feature" or "skin"/);
	assert.match(errors, /is not semver/);
	assert.match(errors, /description is required/);
	assert.match(errors, /boil range is required/);
});

test("a skin must declare a contract range", () => {
	const [pkg] = manifest.parse(`
[package]
name = "encryptal/neon"
kind = "skin"
version = "1.0.0"
description = "Neon"
boil = "^0.1"
`);
	assert.match(manifest.validate(pkg).join("\n"), /contract range/);
	pkg.contract = "^1";
	assert.equal(manifest.validate(pkg).length, 0);
});

test("serialize round-trips back to the same package", () => {
	const [pkg] = manifest.parse(VALID);
	const [again, error] = manifest.parse(manifest.serialize(pkg));
	assert.equal(error, undefined);
	assert.deepEqual(again, pkg);
});

test("an empty manifest is valid TOML with no stray empty sections", () => {
	const emitted = manifest.serialize(manifest.empty("encryptal/shop", "feature"));
	assert.ok(!emitted.includes("[dependencies]"));
	assert.ok(!emitted.includes("[studio]"));
	assert.equal(manifest.parse(emitted)[0].name, "encryptal/shop");
});

test("parseSpec understands every source the CLI accepts", () => {
	assert.deepEqual(source.parseSpec("encryptal/shop"), { name: "encryptal/shop", version: undefined });
	assert.deepEqual(source.parseSpec("encryptal/shop@1.2.0"), { name: "encryptal/shop", version: "1.2.0" });
	assert.deepEqual(source.parseSpec("github:owner/repo"), { git: "https://github.com/owner/repo", tag: undefined });
	assert.deepEqual(source.parseSpec("github:owner/repo@v1.0"), { git: "https://github.com/owner/repo", tag: "v1.0" });
	assert.deepEqual(source.parseSpec("path:../boil-shop"), { path: "../boil-shop", tag: undefined });
	assert.deepEqual(source.parseSpec("https://example.com/repo"), { git: "https://example.com/repo", tag: undefined });

	// The @ in an scp-style URL belongs to the host, not to a version.
	assert.deepEqual(source.parseSpec("git@github.com:owner/repo"), {
		git: "git@github.com:owner/repo",
		tag: undefined,
	});
	assert.deepEqual(source.parseSpec("git@github.com:owner/repo@v2"), {
		git: "git@github.com:owner/repo",
		tag: "v2",
	});
});

test("pascal derives the install folder from a scoped name", () => {
	assert.equal(pascal("encryptal/player-data"), "PlayerData");
	assert.equal(pascal("boil/shop"), "Shop");
	assert.equal(pascal("encryptal/ui_shell"), "UiShell");
});

test("wrap breaks long descriptions at the requested width", () => {
	const lines = wrap("one two three four five six", 9, "  ");
	assert.deepEqual(lines, ["  one two", "  three", "  four five", "  six"]);
	assert.deepEqual(wrap("first\nsecond", 20, ""), ["first", "second"], "paragraphs stay separate");
});
