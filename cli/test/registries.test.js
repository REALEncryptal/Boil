import assert from "node:assert/strict";
import { describe, it } from "node:test";

import { nameProblem } from "../src/registries.js";

describe("nameProblem", () => {
	it("accepts a name usable as a prefix", () => {
		for (const name of ["company", "acme-private", "my_index", "Index2"]) {
			assert.equal(nameProblem(name), undefined, `${name} should be allowed`);
		}
	});

	it("requires one", () => {
		assert.match(nameProblem(""), /required/);
		assert.match(nameProblem(undefined), /required/);
	});

	// The name is typed as `name:owner/pkg`, so anything that would confuse that
	// parse has to be rejected at the point of naming.
	it("rejects characters that would break the prefix syntax", () => {
		for (const name of ["has space", "slash/es", "colon:", "https://x"]) {
			assert.match(nameProblem(name), /letters, numbers, dashes or underscores/);
		}
	});

	it("rejects the two prefixes `boil add` already understands", () => {
		assert.match(nameProblem("github"), /reserved/);
		assert.match(nameProblem("path"), /reserved/);
	});
});
