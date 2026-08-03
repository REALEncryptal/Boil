import assert from "node:assert/strict";
import { test } from "node:test";

import { compare, maxSatisfying, parse, satisfies, toString } from "../src/semver.js";

test("parses full, partial and v-prefixed versions", () => {
	assert.deepEqual(parse("1.2.3"), { major: 1, minor: 2, patch: 3, pre: undefined });
	assert.deepEqual(parse("v1.2.3"), { major: 1, minor: 2, patch: 3, pre: undefined });
	assert.deepEqual(parse("1.2"), { major: 1, minor: 2, patch: 0, pre: undefined });
	assert.deepEqual(parse("1"), { major: 1, minor: 0, patch: 0, pre: undefined });
	assert.equal(parse("1.2.3-beta.1").pre, "beta.1");
	assert.equal(parse("not-a-version"), undefined);
});

test("orders releases, with a pre-release below its release", () => {
	assert.equal(compare(parse("1.0.0"), parse("1.0.1")), -1);
	assert.equal(compare(parse("2.0.0"), parse("1.9.9")), 1);
	assert.equal(compare(parse("1.0.0"), parse("1.0.0")), 0);
	assert.equal(compare(parse("1.0.0-beta"), parse("1.0.0")), -1);
	assert.equal(toString(parse("1.2.3-beta")), "1.2.3-beta");
});

test("caret ranges pin the leftmost non-zero component", () => {
	assert.ok(satisfies("1.4.0", "^1.2"));
	assert.ok(!satisfies("2.0.0", "^1.2"));
	assert.ok(!satisfies("1.1.0", "^1.2"));

	// 0.x is the case that matters for a young framework: ^0.3 must not accept 0.4.
	assert.ok(satisfies("0.3.9", "^0.3"));
	assert.ok(!satisfies("0.4.0", "^0.3"));
	assert.ok(satisfies("0.0.5", "^0.0.5"));
	assert.ok(!satisfies("0.0.6", "^0.0.5"));
});

test("tilde, comparators, exact and any", () => {
	assert.ok(satisfies("1.2.9", "~1.2.3"));
	assert.ok(!satisfies("1.3.0", "~1.2.3"));
	assert.ok(satisfies("1.0.0", ">=1.0"));
	assert.ok(!satisfies("0.9.0", ">=1.0"));
	assert.ok(satisfies("2.0.0", ">1.0"));
	assert.ok(satisfies("1.0.0", "<=1.0.0"));
	assert.ok(satisfies("1.2.3", "1.2.3"));
	assert.ok(!satisfies("1.2.4", "1.2.3"));
	assert.ok(satisfies("9.9.9", "*"));
	assert.ok(satisfies("9.9.9", undefined));
});

test("a malformed range is a miss, not a crash", () => {
	assert.equal(satisfies("1.0.0", "^^^"), false);
	assert.equal(satisfies("garbage", "^1.0"), false);
});

test("maxSatisfying picks the newest match", () => {
	const versions = ["1.0.0", "1.4.2", "1.2.0", "2.0.0"];
	assert.equal(maxSatisfying(versions, "^1.0"), "1.4.2");
	assert.equal(maxSatisfying(versions, "^3.0"), undefined);
	assert.equal(maxSatisfying(versions, undefined), "2.0.0");
});
