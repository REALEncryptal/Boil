// Tests that touch the filesystem run in a throwaway directory, because every
// project function reads and writes by relative path.

import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { test } from "node:test";

import * as lock from "../src/lock.js";
import * as project from "../src/project.js";
import * as publish from "../src/publish.js";
import * as registry from "../src/registry.js";
import { writeFile } from "../src/util.js";

function sandbox(t) {
	const dir = fs.mkdtempSync(path.join(os.tmpdir(), "boil-test-"));
	const previous = process.cwd();
	process.chdir(dir);
	t.after(() => {
		process.chdir(previous);
		fs.rmSync(dir, { recursive: true, force: true });
	});
	return dir;
}

test("the project manifest round-trips", (t) => {
	sandbox(t);
	project.write({
		name: "my-game",
		boil: "0.1.0",
		registries: { default: "https://example.com/index" },
		dependencies: { "encryptal/shop": "^1.2" },
	});
	const read = project.read();
	assert.equal(read.name, "my-game");
	assert.equal(read.registries.default, "https://example.com/index");
	assert.deepEqual(read.dependencies, { "encryptal/shop": "^1.2" });
});

test("a missing or unreadable manifest falls back to defaults", (t) => {
	sandbox(t);
	assert.equal(project.read().name, "boil-game");
	writeFile("boil.toml", "[project\nbroken");
	assert.equal(project.read().name, "boil-game");
});

test("findRoot walks up to the Rojo project file", (t) => {
	const dir = sandbox(t);
	fs.mkdirSync("src/features/Shop", { recursive: true });
	writeFile(project.MARKER, "{}");
	assert.equal(project.findRoot(path.join(dir, "src", "features", "Shop")), fs.realpathSync(dir));
	assert.equal(project.findRoot(os.tmpdir()), undefined);
});

test("mergeWally inserts new entries and leaves comments and existing pins alone", (t) => {
	sandbox(t);
	writeFile(
		"wally.toml",
		['[package]', 'name = "me/game"', "", "# keep this comment", "[dependencies]", 'React = "jsdotlua/react@17.0.1"', ""].join("\n"),
	);

	const added = project.mergeWally({
		wally: { ByteNet: "ffrostflame/bytenet@0.4.6", React: "someone/else@1.0.0" },
		wallyServer: { ProfileStore: "madstudioroblox/profilestore@1.0.0" },
	});

	const text = fs.readFileSync("wally.toml", "utf8");
	assert.deepEqual(added.sort(), [
		'ByteNet = "ffrostflame/bytenet@0.4.6"',
		'ProfileStore = "madstudioroblox/profilestore@1.0.0"',
	]);
	assert.ok(text.includes("# keep this comment"));
	assert.ok(text.includes('React = "jsdotlua/react@17.0.1"'));
	assert.ok(!text.includes("someone/else"), "an already-pinned package is never overwritten");
	assert.ok(text.includes("[server-dependencies]"));
});

test("mergeWally is a no-op without a wally.toml", (t) => {
	sandbox(t);
	assert.deepEqual(project.mergeWally({ wally: { ByteNet: "x@1" }, wallyServer: {} }), []);
});

test("fingerprint is stable, and changes when a byte does", (t) => {
	sandbox(t);
	fs.mkdirSync("pkg");
	writeFile("pkg/init.luau", "return {}\n");
	writeFile("pkg/boil.toml", "[package]\n");

	const first = project.fingerprint("pkg");
	assert.equal(first, project.fingerprint("pkg"));
	assert.equal(first.length, 16);

	writeFile("pkg/init.luau", "return { changed = true }\n");
	assert.notEqual(first, project.fingerprint("pkg"));
});

test("fingerprint ignores .git, so a clone matches an install", (t) => {
	sandbox(t);
	fs.mkdirSync("pkg/.git", { recursive: true });
	writeFile("pkg/init.luau", "return {}\n");
	const before = project.fingerprint("pkg");
	writeFile("pkg/.git/HEAD", "ref: refs/heads/main\n");
	assert.equal(before, project.fingerprint("pkg"));
});

test("installPath routes by kind and honours a folder override", (t) => {
	sandbox(t);
	assert.equal(project.installPath({ kind: "feature", name: "encryptal/shop" }), "src/features/Shop");
	assert.equal(project.installPath({ kind: "skin", name: "encryptal/neon" }), "src/skins/Neon");
	assert.equal(project.installPath({ kind: "feature", name: "a/b", folder: "Custom" }), "src/features/Custom");
});

test("contractVersion reads the number out of the contract module", (t) => {
	sandbox(t);
	assert.equal(project.contractVersion(), 0);
	writeFile(project.CONTRACT, "local contract = {}\ncontract.VERSION = 3\nreturn contract\n");
	assert.equal(project.contractVersion(), 3);
});

test("the lockfile round-trips, upserts in place, and deletes itself when empty", (t) => {
	sandbox(t);
	const entry = {
		name: "encryptal/shop",
		version: "1.0.0",
		kind: "feature",
		source: "git+https://example.com/shop",
		tag: "v1.0.0",
		path: "src/features/Shop",
		fingerprint: "abc123",
	};

	lock.upsert(entry);
	lock.upsert({ ...entry, name: "encryptal/aaa" });
	assert.deepEqual(
		lock.read().map((item) => item.name),
		["encryptal/aaa", "encryptal/shop"],
		"entries are sorted so the file diffs cleanly",
	);

	lock.upsert({ ...entry, version: "1.1.0" });
	assert.equal(lock.read().length, 2);
	assert.equal(lock.find("encryptal/shop").version, "1.1.0");

	lock.remove("encryptal/shop");
	lock.remove("encryptal/aaa");
	assert.equal(fs.existsSync(lock.FILENAME), false);
});

test("the publish gate catches undeclared requires and registration files", (t) => {
	sandbox(t);
	fs.mkdirSync("src/features/PlayerData", { recursive: true });
	fs.mkdirSync("pkg/nested", { recursive: true });

	writeFile("pkg/init.luau", "local Trove = require(Packages.Trove)\n");
	writeFile("pkg/Server.luau", "local Store = require(ServerPackages.ProfileStore)\n");
	writeFile("pkg/PlayerData.luau", "return function(PlayerData) end\n");
	writeFile("pkg/nested/Deep.luau", "return {}\n");

	const problems = publish
		.check(
			{
				name: "encryptal/shop",
				kind: "feature",
				version: "1.0.0",
				description: "Shop",
				boil: "^0.1",
				dependencies: {},
				wally: {},
				wallyServer: {},
				studio: {},
			},
			"pkg",
		)
		.join("\n");

	assert.match(problems, /Packages\.Trove/);
	assert.match(problems, /Packages\.ProfileStore/);
	assert.match(problems, /PlayerData\.luau/);
	assert.match(problems, /nested\/Deep\.luau is in a subfolder/);
});

// The documented example is `"boil/playerdata" = "^1.0"` alongside a
// PlayerData.luau — a declared dependency that an exact-match check would flag.
test("a declared dependency satisfies its registration file regardless of case", (t) => {
	sandbox(t);
	fs.mkdirSync("src/features/PlayerData", { recursive: true });
	fs.mkdirSync("pkg", { recursive: true });
	writeFile("pkg/PlayerData.luau", "return function(PlayerData) end\n");

	const base = {
		name: "encryptal/notes",
		kind: "feature",
		version: "1.0.0",
		description: "Notes",
		boil: "^0.1",
		wally: {},
		wallyServer: {},
		studio: {},
	};

	assert.deepEqual(publish.check({ ...base, dependencies: { "boil/playerdata": "^1.0" } }, "pkg"), []);
	assert.match(publish.check({ ...base, dependencies: {} }, "pkg").join("\n"), /PlayerData\.luau/);
});

test("the publish gate ignores requires that are commented out", (t) => {
	sandbox(t);
	fs.mkdirSync("pkg", { recursive: true });
	writeFile("pkg/init.luau", "-- local Trove = require(Packages.Trove)\n");

	const problems = publish.check(
		{
			name: "encryptal/shop",
			kind: "feature",
			version: "1.0.0",
			description: "Shop",
			boil: "^0.1",
			dependencies: {},
			wally: {},
			wallyServer: {},
			studio: {},
		},
		"pkg",
	);

	assert.deepEqual(problems, []);
});
