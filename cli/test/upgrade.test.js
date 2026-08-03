import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { after, describe, it } from "node:test";

import { FRAMEWORK_PATHS, applyWally, frameworkVersion, planUpgrade, wallyAdditions } from "../src/upgrade.js";

const scratch = [];

function tree(files) {
	const dir = fs.mkdtempSync(path.join(os.tmpdir(), "boil-upgrade-test-"));
	scratch.push(dir);
	for (const [rel, contents] of Object.entries(files)) {
		fs.mkdirSync(path.join(dir, path.dirname(rel)), { recursive: true });
		fs.writeFileSync(path.join(dir, rel), contents);
	}
	return dir;
}

after(() => {
	for (const dir of scratch) {
		fs.rmSync(dir, { recursive: true, force: true });
	}
});

const BASE = {
	"boil.toml": '[project]\nname = "my-game"\nboil = "0.1.0"\n',
	"wally.toml": '[dependencies]\nReact = "jsdotlua/react@17.1.0"\n',
	"src/shared/Boil.luau": "-- v1",
	"src/client/init.client.luau": "-- client v1",
	"src/server/init.server.luau": "-- server v1",
	"tools/split.luau": "-- splitter v1",
	"src/features/Notes/init.luau": "-- my feature",
	"src/skins/Neon/init.luau": "-- my skin",
	"default.project.json": '{ "name": "my-game" }',
};

describe("planUpgrade", () => {
	it("reports nothing when the trees match", () => {
		const local = tree(BASE);
		const template = tree(BASE);
		const plan = planUpgrade(local, template);
		assert.equal(plan.total, 0);
		assert.deepEqual(plan.paths, []);
	});

	it("classifies added, changed and removed framework files", () => {
		const local = tree(BASE);
		const template = tree({
			...BASE,
			"src/shared/Boil.luau": "-- v2",
			"src/shared/New.luau": "-- brand new",
		});
		fs.rmSync(path.join(template, "tools/split.luau"));

		const plan = planUpgrade(local, template);
		const shared = plan.paths.find((entry) => entry.path === "src/shared");
		assert.deepEqual(shared.changed, ["Boil.luau"]);
		assert.deepEqual(shared.added, ["New.luau"]);

		const tools = plan.paths.find((entry) => entry.path === "tools");
		assert.deepEqual(tools.removed, ["split.luau"]);
	});

	it("never looks at features or skins — those are the project's, not the framework's", () => {
		const local = tree(BASE);
		const template = tree({
			...BASE,
			"src/features/Other/init.luau": "-- template feature",
			"src/skins/Other/init.luau": "-- template skin",
		});

		const plan = planUpgrade(local, template);
		for (const entry of plan.paths) {
			assert.ok(!entry.path.startsWith("src/features"), `${entry.path} must not be upgraded`);
			assert.ok(!entry.path.startsWith("src/skins"), `${entry.path} must not be upgraded`);
		}
		assert.deepEqual(FRAMEWORK_PATHS, ["src/shared", "src/client", "src/server", "tools"]);
	});

	it("reads the framework version out of the template", () => {
		const template = tree({ ...BASE, "boil.toml": '[project]\nname = "boil"\nboil = "0.9.0"\n' });
		assert.equal(frameworkVersion(template), "0.9.0");
		assert.equal(planUpgrade(tree(BASE), template).version, "0.9.0");
	});

	it("flags a differing project file rather than overwriting it", () => {
		const local = tree(BASE);
		const template = tree({ ...BASE, "default.project.json": '{ "name": "Boil" }' });
		assert.equal(planUpgrade(local, template).projectFileDiffers, true);
		assert.equal(planUpgrade(local, tree(BASE)).projectFileDiffers, false);
	});
});

describe("wallyAdditions", () => {
	it("lists dependencies the framework gained", () => {
		const local = tree(BASE);
		const template = tree({
			...BASE,
			"wally.toml": '[dependencies]\nReact = "jsdotlua/react@17.1.0"\nTrove = "sleitnick/trove@1.8.0"\n\n[server-dependencies]\nProfileStore = "lm-loleris/profilestore@1.0.3"\n',
		});

		assert.deepEqual(wallyAdditions(local, template), [
			{ section: "dependencies", name: "Trove", spec: "sleitnick/trove@1.8.0" },
			{ section: "server-dependencies", name: "ProfileStore", spec: "lm-loleris/profilestore@1.0.3" },
		]);
	});

	it("leaves a dependency the project already pins differently alone", () => {
		const local = tree({ ...BASE, "wally.toml": '[dependencies]\nReact = "jsdotlua/react@17.0.0"\n' });
		const template = tree({ ...BASE, "wally.toml": '[dependencies]\nReact = "jsdotlua/react@17.1.0"\n' });
		assert.deepEqual(wallyAdditions(local, template), []);
	});
});

describe("applyWally", () => {
	it("inserts into the existing section, keeping comments and order", () => {
		const local = tree({
			...BASE,
			"wally.toml": '# hand-maintained\n[package]\nname = "me/game"\n\n[dependencies]\nReact = "jsdotlua/react@17.1.0"\n',
		});

		applyWally(local, [{ section: "dependencies", name: "Trove", spec: "sleitnick/trove@1.8.0" }]);

		const text = fs.readFileSync(path.join(local, "wally.toml"), "utf8");
		assert.ok(text.includes("# hand-maintained"), "comments survive");
		assert.ok(text.includes('Trove = "sleitnick/trove@1.8.0"'));
		assert.ok(text.includes('React = "jsdotlua/react@17.1.0"'), "existing entries survive");
	});

	it("creates a missing section", () => {
		const local = tree({ ...BASE, "wally.toml": '[dependencies]\nReact = "jsdotlua/react@17.1.0"\n' });
		applyWally(local, [{ section: "server-dependencies", name: "ProfileStore", spec: "lm-loleris/profilestore@1.0.3" }]);

		const text = fs.readFileSync(path.join(local, "wally.toml"), "utf8");
		assert.ok(text.includes("[server-dependencies]"));
		assert.ok(text.includes('ProfileStore = "lm-loleris/profilestore@1.0.3"'));
	});

	it("is a no-op with nothing to add", () => {
		const local = tree(BASE);
		const before = fs.readFileSync(path.join(local, "wally.toml"), "utf8");
		applyWally(local, []);
		assert.equal(fs.readFileSync(path.join(local, "wally.toml"), "utf8"), before);
	});
});
