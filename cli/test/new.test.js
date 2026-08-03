import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { after, describe, it } from "node:test";

import { DEFAULT_TEMPLATE, scaffold, validateName } from "../src/new.js";
import * as toml from "../src/toml.js";

const scratch = [];

function template() {
	const dir = fs.mkdtempSync(path.join(os.tmpdir(), "boil-new-test-"));
	scratch.push(dir);

	const write = (rel, contents) => {
		fs.mkdirSync(path.join(dir, path.dirname(rel)), { recursive: true });
		fs.writeFileSync(path.join(dir, rel), contents);
	};

	write("boil.toml", '[project]\nname = "boil"\nboil = "0.4.0"\n\n[registries]\ndefault = "https://example.test/index"\n\n[dependencies]\n"someone/shop" = "^1.0"\n');
	write("default.project.json", '{\n  "name": "Boil",\n  "tree": { "$className": "DataModel" }\n}\n');
	write("README.md", "# Boil\n\nthe framework's own readme\n");
	write("LICENSE", "MIT License\n\nCopyright (c) 2026 REALEncryptal\n");
	write("boil-lock.toml", '[[package]]\nname = "someone/shop"\n');
	write("wally.toml", "[package]\nname = \"realencryptal/boil\"\n");
	write("cli/package.json", '{ "name": "@encryptal/boil" }');
	write("cli/src/index.js", "// the CLI itself");
	write("src/shared/Boil.luau", "-- framework");
	write("src/features/Notes/init.luau", "-- a bundled feature");
	write("src/skins/README.md", "# skins");
	write("tools/split.luau", "-- splitter");
	write("docs/README.md", "# docs");

	return dir;
}

after(() => {
	for (const dir of scratch) {
		fs.rmSync(dir, { recursive: true, force: true });
	}
});

describe("validateName", () => {
	it("requires a name", () => {
		assert.match(validateName(""), /required/);
		assert.match(validateName(undefined), /required/);
	});

	it("rejects path separators, so the folder lands where you ran the command", () => {
		assert.match(validateName("games/my-game"), /path separator/);
		assert.match(validateName("games\\my-game"), /path separator/);
	});

	it("rejects dotfiles", () => {
		assert.match(validateName(".hidden"), /dot/);
	});

	it("accepts an ordinary name", () => {
		assert.equal(validateName("my-game"), undefined);
	});
});

describe("scaffold", () => {
	it("never copies the CLI into the new project", () => {
		const dir = template();
		scaffold(dir, { name: "my-game" });
		assert.equal(fs.existsSync(path.join(dir, "cli")), false);
	});

	it("strips the framework's licence and lockfile but keeps the framework itself", () => {
		const dir = template();
		scaffold(dir, { name: "my-game" });

		assert.equal(fs.existsSync(path.join(dir, "LICENSE")), false);
		assert.equal(fs.existsSync(path.join(dir, "boil-lock.toml")), false);

		assert.ok(fs.existsSync(path.join(dir, "src/shared/Boil.luau")));
		assert.ok(fs.existsSync(path.join(dir, "tools/split.luau")));
		assert.ok(fs.existsSync(path.join(dir, "docs/README.md")));
		assert.ok(fs.existsSync(path.join(dir, "wally.toml")));
	});

	it("renames the project and drops the template's dependencies", () => {
		const dir = template();
		scaffold(dir, { name: "my-game" });

		const manifest = toml.parse(fs.readFileSync(path.join(dir, "boil.toml"), "utf8"));
		assert.equal(manifest.project.name, "my-game");
		assert.equal(manifest.project.boil, "0.4.0", "the framework version carries over");
		assert.equal(manifest.registries.default, "https://example.test/index", "the index carries over");
		assert.equal(manifest.dependencies, undefined, "the template's installed packages do not");
	});

	it("renames the Rojo project, since that name shows up in Studio", () => {
		const dir = template();
		scaffold(dir, { name: "my-game" });

		const rojo = JSON.parse(fs.readFileSync(path.join(dir, "default.project.json"), "utf8"));
		assert.equal(rojo.name, "my-game");
		assert.equal(rojo.tree.$className, "DataModel", "the rest of the tree is untouched");
	});

	it("writes a README for the new project, not the framework's", () => {
		const dir = template();
		scaffold(dir, { name: "my-game" });

		const readme = fs.readFileSync(path.join(dir, "README.md"), "utf8");
		assert.match(readme, /^# my-game/);
		assert.ok(readme.includes(DEFAULT_TEMPLATE));
		assert.equal(readme.includes("the framework's own readme"), false);
	});

	it("keeps the bundled features by default", () => {
		const dir = template();
		scaffold(dir, { name: "my-game" });
		assert.ok(fs.existsSync(path.join(dir, "src/features/Notes/init.luau")));
	});

	it("empties src/features for the empty template, leaving the directory tracked", () => {
		const dir = template();
		scaffold(dir, { name: "my-game", empty: true });

		assert.equal(fs.existsSync(path.join(dir, "src/features/Notes")), false);
		assert.ok(fs.existsSync(path.join(dir, "src/features/README.md")), "a README keeps the dir in git");
		assert.ok(fs.existsSync(path.join(dir, "src/shared/Boil.luau")), "the framework survives");
	});

	it("survives a template with a malformed project file", () => {
		const dir = template();
		fs.writeFileSync(path.join(dir, "default.project.json"), "{ not json");
		assert.doesNotThrow(() => scaffold(dir, { name: "my-game" }));
		assert.match(fs.readFileSync(path.join(dir, "README.md"), "utf8"), /^# my-game/);
	});
});
