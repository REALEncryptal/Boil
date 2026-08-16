import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { describe, it } from "node:test";

import { candidates, describe as describeCandidate } from "../src/publish.js";

// A checkout with the folders `boil publish` offers to publish.
function checkout(layout) {
	const root = fs.mkdtempSync(path.join(os.tmpdir(), "boil-publish-test-"));
	for (const [rel, manifest] of Object.entries(layout)) {
		fs.mkdirSync(path.join(root, rel), { recursive: true });
		if (manifest) {
			fs.writeFileSync(path.join(root, rel, "boil.toml"), manifest);
		}
	}
	return {
		root,
		dirs: { feature: path.join(root, "src/features"), skin: path.join(root, "src/skins") },
		cleanup: () => fs.rmSync(root, { recursive: true, force: true }),
	};
}

const packaged = (name, version) => `[package]\nname = "${name}"\nversion = "${version}"\nkind = "feature"\n`;

describe("candidates", () => {
	it("lists every feature and skin folder, with and without a manifest", () => {
		const { dirs, cleanup } = checkout({
			"src/features/Pets": packaged("me/pets", "0.2.0"),
			"src/features/Notes": undefined,
			"src/skins/Neon": packaged("me/neon", "1.0.0"),
		});
		try {
			const found = candidates(dirs);
			assert.deepEqual(
				found.map((entry) => `${entry.kind}:${entry.folder}`),
				["feature:Notes", "feature:Pets", "skin:Neon"],
			);
			assert.equal(found.find((entry) => entry.folder === "Pets").pkg.name, "me/pets");
			// No boil.toml is not a reason to hide it — publishing scaffolds one.
			assert.equal(found.find((entry) => entry.folder === "Notes").pkg, undefined);
		} finally {
			cleanup();
		}
	});

	it("ignores loose files and missing directories", () => {
		const { root, dirs, cleanup } = checkout({ "src/features/Pets": packaged("me/pets", "0.1.0") });
		try {
			fs.writeFileSync(path.join(root, "src/features/README.md"), "not a package");
			const found = candidates(dirs);
			assert.deepEqual(
				found.map((entry) => entry.folder),
				["Pets"],
			);
			// src/skins never existed in this checkout.
			assert.deepEqual(candidates({ skin: path.join(root, "nope") }), []);
		} finally {
			cleanup();
		}
	});
});

describe("describe", () => {
	const listings = [
		{ name: "me/pets", versions: [{ version: "0.1.0" }, { version: "0.2.0" }] },
		{ name: "me/neon", versions: [] },
	];

	it("says a manifest will be scaffolded when there isn't one", () => {
		const { note, ready } = describeCandidate({ folder: "Notes", pkg: undefined }, listings);
		assert.match(note, /no boil\.toml/);
		assert.equal(ready, false);
	});

	it("calls out a version that's already in the index", () => {
		const { note, ready } = describeCandidate({ pkg: { name: "me/pets", version: "0.2.0" } }, listings);
		assert.match(note, /already published/);
		assert.equal(ready, false, "publishing this would collide, so it isn't offered as ready");
	});

	it("shows what the index has when the local version is newer", () => {
		const { note, ready } = describeCandidate({ pkg: { name: "me/pets", version: "0.3.0" } }, listings);
		assert.match(note, /0\.3\.0/);
		assert.match(note, /index has 0\.2\.0/);
		assert.equal(ready, true);
	});

	it("marks a package the index has never seen as new", () => {
		const { note, ready } = describeCandidate({ pkg: { name: "me/hats", version: "0.1.0" } }, listings);
		assert.match(note, /new package/);
		assert.equal(ready, true);
	});
});
