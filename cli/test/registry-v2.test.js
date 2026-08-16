// The v2 registry, driven against a real git repo on disk.
//
// Everything here is local — `git` talks to a file path, not a network — so the
// publish → tag → resolve → materialise round trip is exercised for real rather
// than against mocks of git's behaviour.

import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { spawnSync } from "node:child_process";
import { after, before, describe, it } from "node:test";

import * as registry from "../src/registry.js";
import { plan } from "../src/migrate.js";

const git = (args, cwd) => {
	const result = spawnSync("git", args, { cwd, encoding: "utf8" });
	assert.equal(result.status, 0, `git ${args.join(" ")} failed: ${result.stderr}`);
	return result.stdout;
};

let root;

function makeRegistry(name = "index") {
	const dir = path.join(root, name);
	fs.mkdirSync(dir, { recursive: true });
	git(["init", "--quiet", "--initial-branch=main"], dir);
	git(["config", "user.email", "test@example.com"], dir);
	git(["config", "user.name", "Test"], dir);
	fs.writeFileSync(path.join(dir, registry.FORMAT_FILE), registry.formatFile(name));
	git(["add", "-A"], dir);
	git(["commit", "-m", "init", "--quiet"], dir);
	return dir;
}

// Commit a package at a version and tag it the way `publish` does.
function release(dir, name, version, files = {}) {
	const subdir = path.join(dir, registry.PACKAGES, name);
	fs.mkdirSync(subdir, { recursive: true });
	fs.writeFileSync(
		path.join(subdir, "boil.toml"),
		`[package]\nname = "${name}"\nkind = "feature"\nversion = "${version}"\ndescription = "a test package"\n`,
	);
	for (const [file, contents] of Object.entries(files)) {
		fs.writeFileSync(path.join(subdir, file), contents);
	}
	git(["add", "-A"], dir);
	git(["commit", "-m", `${name} ${version}`, "--quiet"], dir);
	git(["tag", registry.tagFor(name, version)], dir);
}

before(() => {
	root = fs.mkdtempSync(path.join(os.tmpdir(), "boil-registry-v2-"));
});

after(() => {
	fs.rmSync(root, { recursive: true, force: true });
});

describe("tags", () => {
	it("round-trips a package name and version through a tag", () => {
		const tag = registry.tagFor("encryptal/shop", "1.2.0");
		assert.equal(tag, "encryptal/shop@1.2.0");
		assert.deepEqual(registry.parseTag(tag), { name: "encryptal/shop", version: "1.2.0" });
	});

	it("keeps the owner slash out of the version", () => {
		assert.deepEqual(registry.parseTag("acme/deep/name@0.1.0"), { name: "acme/deep/name", version: "0.1.0" });
		assert.equal(registry.parseTag("no-at-sign"), undefined);
	});
});

describe("formatOf", () => {
	it("reads the stamped format", () => {
		const dir = makeRegistry("stamped");
		assert.equal(registry.formatOf(dir), 2);
	});

	// Every index written before this change looks exactly like this.
	it("treats a registry.toml-less directory as v1", () => {
		const dir = path.join(root, "unstamped");
		fs.mkdirSync(dir, { recursive: true });
		assert.equal(registry.formatOf(dir), 1);
	});
});

describe("loadV2", () => {
	it("reads the tree as the index, with tags as the versions", () => {
		const dir = makeRegistry("loading");
		release(dir, "me/shop", "1.0.0");
		release(dir, "me/shop", "1.1.0");
		release(dir, "me/hats", "0.1.0");

		const listings = registry.load(dir);
		assert.deepEqual(
			listings.map((entry) => entry.name),
			["me/hats", "me/shop"],
		);

		const shop = listings.find((entry) => entry.name === "me/shop");
		assert.deepEqual(shop.versions.map((entry) => entry.version).sort(), ["1.0.0", "1.1.0"]);
		assert.equal(shop.subdir, "packages/me/shop");
		assert.equal(shop.description, "a test package");
		// Every release carries what materialise needs to find it again.
		for (const version of shop.versions) {
			assert.equal(version.registryUrl, dir);
			assert.equal(version.subdir, "packages/me/shop");
			assert.match(version.commit, /^[0-9a-f]{40}$/);
		}
	});

	it("ignores a folder with no manifest", () => {
		const dir = makeRegistry("partial");
		fs.mkdirSync(path.join(dir, registry.PACKAGES, "me", "empty"), { recursive: true });
		fs.writeFileSync(path.join(dir, registry.PACKAGES, "me", "empty", "README.md"), "no manifest");
		assert.deepEqual(registry.load(dir), []);
	});

	it("falls back to the manifest version for a directory that isn't a git repo", () => {
		const dir = path.join(root, "plain");
		fs.mkdirSync(path.join(dir, registry.PACKAGES, "me", "shop"), { recursive: true });
		fs.writeFileSync(path.join(dir, registry.FORMAT_FILE), registry.formatFile("plain"));
		fs.writeFileSync(
			path.join(dir, registry.PACKAGES, "me", "shop", "boil.toml"),
			'[package]\nname = "me/shop"\nkind = "feature"\nversion = "9.9.9"\n',
		);

		const [listing] = registry.load(dir);
		assert.equal(listing.name, "me/shop");
		assert.deepEqual(
			listing.versions.map((entry) => entry.version),
			["9.9.9"],
		);
	});

	it("reads nothing out of a v1 index, and says why", () => {
		const dir = path.join(root, "v1");
		fs.mkdirSync(path.join(dir, registry.PACKAGES), { recursive: true });
		fs.writeFileSync(
			path.join(dir, registry.PACKAGES, "shop.toml"),
			'name = "me/shop"\nkind = "feature"\n\n[[version]]\nversion = "1.0.0"\nsource = "git+https://example.invalid/shop"\ntag = "v1.0.0"\n',
		);

		assert.deepEqual(registry.load(dir), []);
		assert.equal(registry.needsMigration(dir), true);
		assert.equal(registry.loadV1(dir).length, 1);
	});
});

describe("materialize", () => {
	it("copies the newest release straight off disk", () => {
		const dir = makeRegistry("newest");
		release(dir, "me/shop", "1.0.0", { "Shop.luau": "-- v1\n" });

		const [listing] = registry.load(dir);
		const [out, error] = registry.materialize(listing.versions[0]);
		assert.equal(error, undefined);
		assert.equal(fs.readFileSync(path.join(out, "Shop.luau"), "utf8"), "-- v1\n");
		fs.rmSync(out, { recursive: true, force: true });
	});

	// The point of tags: an old version is still in the repo you already have.
	it("reads an older release out of git history", () => {
		const dir = makeRegistry("history");
		release(dir, "me/shop", "1.0.0", { "Shop.luau": "-- one\n", "Gone.luau": "-- removed later\n" });
		fs.rmSync(path.join(dir, registry.PACKAGES, "me/shop/Gone.luau"));
		release(dir, "me/shop", "2.0.0", { "Shop.luau": "-- two\n" });

		const [listing] = registry.load(dir);
		const old = listing.versions.find((entry) => entry.version === "1.0.0");
		const [out, error] = registry.materialize(old);
		assert.equal(error, undefined);

		assert.equal(fs.readFileSync(path.join(out, "Shop.luau"), "utf8"), "-- one\n");
		// A file that only existed in 1.0.0 comes back too.
		assert.equal(fs.readFileSync(path.join(out, "Gone.luau"), "utf8"), "-- removed later\n");
		fs.rmSync(out, { recursive: true, force: true });
	});

	it("survives a package carrying binary content", () => {
		const dir = makeRegistry("binary");
		const bytes = Buffer.from([0x00, 0x01, 0xfe, 0xff, 0x00, 0x7f]);
		release(dir, "me/shop", "1.0.0", { "icon.bin": bytes });
		release(dir, "me/shop", "1.1.0", { "icon.bin": bytes });

		const [listing] = registry.load(dir);
		const old = listing.versions.find((entry) => entry.version === "1.0.0");
		const [out] = registry.materialize(old);
		assert.deepEqual(fs.readFileSync(path.join(out, "icon.bin")), bytes);
		fs.rmSync(out, { recursive: true, force: true });
	});

	it("reports a registry it has never fetched", () => {
		const [out, error] = registry.materialize({
			registryUrl: "https://example.invalid/never-fetched",
			subdir: "packages/me/shop",
			tag: "me/shop@1.0.0",
		});
		assert.equal(out, undefined);
		assert.match(error, /hasn't been fetched/);
	});
});

describe("migrate plan", () => {
	it("orders releases oldest first within each package", () => {
		const ordered = plan([
			{
				name: "me/shop",
				kind: "feature",
				description: "",
				versions: [
					{ version: "1.2.0", source: "git+https://example.invalid/shop", tag: "v1.2.0" },
					{ version: "1.0.0", source: "git+https://example.invalid/shop", tag: "v1.0.0" },
					{ version: "1.10.0", source: "git+https://example.invalid/shop", tag: "v1.10.0" },
				],
			},
		]);

		assert.deepEqual(
			ordered.map((entry) => entry.version),
			["1.0.0", "1.2.0", "1.10.0"],
		);
		// The git+ prefix is a lockfile spelling, not a URL.
		assert.equal(ordered[0].repo, "https://example.invalid/shop");
	});
});
