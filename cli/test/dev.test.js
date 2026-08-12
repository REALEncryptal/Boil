import assert from "node:assert/strict";
import { describe, it } from "node:test";

import { buildCommands, needsSeparator, parsePort } from "../src/dev.js";

describe("parsePort", () => {
	it("accepts a port in range", () => {
		assert.deepEqual(parsePort("34872"), [34872, undefined]);
		assert.deepEqual(parsePort("1"), [1, undefined]);
		assert.deepEqual(parsePort("65535"), [65535, undefined]);
	});

	it("rejects a bare --port with no value", () => {
		const [port, error] = parsePort(true);
		assert.equal(port, undefined);
		assert.match(error, /needs a number/);
	});

	it("rejects out-of-range and non-numeric values", () => {
		for (const value of ["0", "65536", "-1", "abc", "80.5"]) {
			const [port, error] = parsePort(value);
			assert.equal(port, undefined, `${value} should not parse`);
			assert.match(error, /not a valid port/);
		}
	});
});

describe("buildCommands", () => {
	it("runs the splitter in watch mode and rojo serve by default", () => {
		const commands = buildCommands();
		assert.deepEqual(
			commands.map((entry) => entry.label),
			["split", "rojo"],
		);

		const [split, rojo] = commands;
		assert.equal(split.command, "lune");
		assert.deepEqual(split.args, ["run", "tools/split", "--watch"]);
		assert.equal(rojo.command, "rojo");
		assert.deepEqual(rojo.args, ["serve"]);
	});

	it("passes the port through to rojo", () => {
		const [, rojo] = buildCommands({ port: 34872 });
		assert.deepEqual(rojo.args, ["serve", "--port", "34872"]);
	});

	it("passes an address through", () => {
		const [, rojo] = buildCommands({ address: "0.0.0.0" });
		assert.deepEqual(rojo.args, ["serve", "--address", "0.0.0.0"]);
	});

	it("puts the project file before the flags, where rojo wants it", () => {
		const [, rojo] = buildCommands({ project: "test.project.json", port: 1234 });
		assert.deepEqual(rojo.args, ["serve", "test.project.json", "--port", "1234"]);
	});

	it("can run either half alone", () => {
		assert.deepEqual(
			buildCommands({ serve: false }).map((entry) => entry.label),
			["split"],
		);
		assert.deepEqual(
			buildCommands({ split: false }).map((entry) => entry.label),
			["rojo"],
		);
	});

	it("omits the port when none is given, so rojo keeps its default", () => {
		const [, rojo] = buildCommands({ port: undefined });
		assert.equal(rojo.args.includes("--port"), false);
	});

	it("puts the `--` separator back for a Lune that still sinks flags", () => {
		const [split] = buildCommands({ luneVersion: "lune 0.8.9" });
		assert.deepEqual(split.args, ["run", "tools/split", "--", "--watch"]);
	});
});

describe("needsSeparator", () => {
	it("is true only for Lune older than 0.9, which sinks `lune run` flags", () => {
		for (const version of ["lune 0.8.9", "0.8.0", "lune 0.7.11"]) {
			assert.equal(needsSeparator(version), true, `${version} should need --`);
		}
	});

	it("is false from 0.9 on, where `--` would reach the script literally", () => {
		for (const version of ["lune 0.9.0", "lune 0.10.5", "1.0.0"]) {
			assert.equal(needsSeparator(version), false, `${version} should not need --`);
		}
	});

	it("assumes new Lune when the version can't be read", () => {
		for (const version of [undefined, "", "lune (unknown)"]) {
			assert.equal(needsSeparator(version), false);
		}
	});
});
