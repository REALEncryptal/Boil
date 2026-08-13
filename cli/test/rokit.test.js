import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { describe, it } from "node:test";
import zlib from "node:zlib";

import { LATEST_RELEASE, extract, install, pickAsset, skip, target } from "../src/rokit.js";

// A zip writer, so the reader is tested against archives built to the spec
// rather than to its own assumptions. Stored or deflated, optionally with an
// extra field on the local header only — the layout that trips readers which
// assume both headers agree.
function zip(entries, { comment = "" } = {}) {
	const locals = [];
	const centrals = [];
	let offset = 0;

	for (const { name, body, method = 8, localExtra = 0 } of entries) {
		const raw = Buffer.from(body);
		const data = method === 8 ? zlib.deflateRawSync(raw) : raw;
		const nameBytes = Buffer.from(name, "utf8");

		const local = Buffer.alloc(30 + nameBytes.length + localExtra);
		local.writeUInt32LE(0x04034b50, 0);
		local.writeUInt16LE(20, 4);
		local.writeUInt16LE(method, 8);
		local.writeUInt32LE(data.length, 18);
		local.writeUInt32LE(raw.length, 22);
		local.writeUInt16LE(nameBytes.length, 26);
		local.writeUInt16LE(localExtra, 28);
		nameBytes.copy(local, 30);
		locals.push(local, data);

		const central = Buffer.alloc(46 + nameBytes.length);
		central.writeUInt32LE(0x02014b50, 0);
		central.writeUInt16LE(20, 6);
		central.writeUInt16LE(method, 10);
		central.writeUInt32LE(data.length, 20);
		central.writeUInt32LE(raw.length, 24);
		central.writeUInt16LE(nameBytes.length, 28);
		central.writeUInt32LE(offset, 42);
		nameBytes.copy(central, 46);
		centrals.push(central);

		offset += local.length + data.length;
	}

	const directory = Buffer.concat(centrals);
	const commentBytes = Buffer.from(comment, "utf8");
	const end = Buffer.alloc(22 + commentBytes.length);
	end.writeUInt32LE(0x06054b50, 0);
	end.writeUInt16LE(entries.length, 8);
	end.writeUInt16LE(entries.length, 10);
	end.writeUInt32LE(directory.length, 12);
	end.writeUInt32LE(offset, 16);
	end.writeUInt16LE(commentBytes.length, 20);
	commentBytes.copy(end, 22);

	return Buffer.concat([...locals, directory, end]);
}

const release = (names) => ({
	ok: true,
	json: async () => ({
		tag_name: "v1.2.0",
		assets: names.map((name) => ({ name, browser_download_url: `https://example.invalid/${name}` })),
	}),
});

describe("target", () => {
	it("maps Node's platform names to Rokit's", () => {
		assert.deepEqual(target("linux", "x64"), { os: "linux", arch: "x86_64", binary: "rokit" });
		assert.deepEqual(target("darwin", "arm64"), { os: "macos", arch: "aarch64", binary: "rokit" });
		assert.deepEqual(target("win32", "x64"), { os: "windows", arch: "x86_64", binary: "rokit.exe" });
	});

	it("has no answer for a platform Rokit doesn't build for", () => {
		assert.equal(target("freebsd", "x64"), undefined);
		assert.equal(target("linux", "ppc64"), undefined);
	});
});

describe("pickAsset", () => {
	const assets = [
		{ name: "rokit-1.2.0-linux-aarch64.zip" },
		{ name: "rokit-1.2.0-linux-x86_64.zip" },
		{ name: "rokit-1.2.0-macos-x86_64.zip" },
		{ name: "rokit-1.2.0-windows-x86_64.zip" },
	];

	it("finds this platform's archive among all of them", () => {
		assert.equal(pickAsset(assets, target("linux", "x64")).name, "rokit-1.2.0-linux-x86_64.zip");
		assert.equal(pickAsset(assets, target("linux", "arm64")).name, "rokit-1.2.0-linux-aarch64.zip");
		assert.equal(pickAsset(assets, target("win32", "x64")).name, "rokit-1.2.0-windows-x86_64.zip");
	});

	// linux-x86_64 must not answer for macos-x86_64, and a source tarball must
	// not answer for anything.
	it("doesn't settle for a near miss", () => {
		assert.equal(pickAsset(assets, target("darwin", "arm64")), undefined);
		assert.equal(pickAsset([{ name: "rokit-1.2.0-linux-x86_64.tar.gz" }], target("linux", "x64")), undefined);
		assert.equal(pickAsset(undefined, target("linux", "x64")), undefined);
	});
});

describe("extract", () => {
	it("reads a deflated file", () => {
		const archive = zip([{ name: "rokit", body: "#!/bin/sh\necho hi\n".repeat(50) }]);
		assert.equal(String(extract(archive, "rokit")), "#!/bin/sh\necho hi\n".repeat(50));
	});

	it("reads a stored file", () => {
		const archive = zip([{ name: "rokit", body: "uncompressed", method: 0 }]);
		assert.equal(String(extract(archive, "rokit")), "uncompressed");
	});

	it("picks the right file out of several", () => {
		const archive = zip([
			{ name: "README.md", body: "docs" },
			{ name: "rokit", body: "the binary" },
			{ name: "LICENSE", body: "MIT" },
		]);
		assert.equal(String(extract(archive, "rokit")), "the binary");
		assert.equal(String(extract(archive, "LICENSE")), "MIT");
	});

	// The local header carries its own extra field, routinely a different length
	// from the central one — reading the central length here lands mid-file.
	it("uses the local header's extra-field length, not the central one", () => {
		const archive = zip([{ name: "rokit", body: "aligned", localExtra: 16 }]);
		assert.equal(String(extract(archive, "rokit")), "aligned");
	});

	it("finds the directory behind a trailing comment", () => {
		const archive = zip([{ name: "rokit", body: "commented" }], { comment: "x".repeat(400) });
		assert.equal(String(extract(archive, "rokit")), "commented");
	});

	it("throws rather than guessing", () => {
		assert.throws(() => extract(zip([{ name: "rokit", body: "x" }]), "rokit.exe"), /not in the archive/);
		assert.throws(() => extract(Buffer.from("not a zip at all"), "rokit"), /not a zip/);
	});
});

describe("install", () => {
	it("reports the platform it can't serve instead of downloading anything", async () => {
		const result = await install({ platform: "freebsd", arch: "x64", fetchImpl: () => assert.fail("no request") });
		assert.equal(result.ok, false);
		assert.match(result.reason, /no Rokit build for freebsd/);
	});

	it("reports a release with nothing for this platform", async () => {
		const result = await install({
			platform: "darwin",
			arch: "arm64",
			fetchImpl: async () => release(["rokit-1.2.0-linux-x86_64.zip"]),
		});
		assert.equal(result.ok, false);
		assert.match(result.reason, /no macos-aarch64 build/);
	});

	it("reports an unhappy registry instead of throwing", async () => {
		const result = await install({
			platform: "linux",
			arch: "x64",
			fetchImpl: async () => ({ ok: false, status: 403 }),
		});
		assert.equal(result.ok, false);
		assert.match(result.reason, /responded 403/);
	});

	it("gives up rather than hanging the install", async () => {
		const result = await install({
			platform: "linux",
			arch: "x64",
			apiTimeoutMs: 10,
			fetchImpl: (_url, { signal }) =>
				new Promise((_resolve, reject) => {
					signal.addEventListener("abort", () => reject(Object.assign(new Error("aborted"), { name: "AbortError" })));
				}),
		});
		assert.equal(result.ok, false);
		assert.equal(result.reason, "timed out");
	});

	// The whole pipeline against a stand-in binary: resolve the release, download
	// the asset, unzip it, make it executable, run it. The script writes a file
	// when handed `self-install`, so the assertion is that it really ran.
	it("unpacks the archive and runs the binary", async (t) => {
		if (process.platform === "win32") {
			return t.skip("the stand-in binary is a POSIX shell script");
		}

		const marker = path.join(os.tmpdir(), `boil-rokit-proof-${process.pid}`);
		fs.rmSync(marker, { force: true });
		const archive = zip([
			{ name: "README.md", body: "not the binary" },
			{ name: "rokit", body: `#!/bin/sh\n[ "$1" = "self-install" ] && printf ran > ${marker}\n` },
		]);

		try {
			const result = await install({
				platform: "linux",
				arch: "x64",
				fetchImpl: async (url) =>
					url.endsWith(".zip")
						? { ok: true, arrayBuffer: async () => archive }
						: release(["rokit-1.2.0-linux-x86_64.zip"]),
			});

			assert.equal(result.ok, true, result.reason);
			assert.equal(result.version, "v1.2.0");
			assert.equal(fs.readFileSync(marker, "utf8"), "ran", "the extracted binary should have been executed");
		} finally {
			fs.rmSync(marker, { force: true });
		}
	});

	it("asks GitHub for the latest release", async () => {
		let requested;
		await install({
			platform: "linux",
			arch: "x64",
			fetchImpl: async (url) => {
				requested = url;
				return release([]);
			},
		});
		assert.equal(requested, LATEST_RELEASE);
	});
});

describe("skip", () => {
	it("runs by default on a supported platform", () => {
		assert.equal(skip({}, "linux", "x64"), undefined);
	});

	it("stands down when asked", () => {
		assert.match(skip({ BOIL_SKIP_ROKIT: "1" }, "linux", "x64"), /BOIL_SKIP_ROKIT/);
	});

	it("stands down where Rokit has no build", () => {
		assert.match(skip({}, "freebsd", "x64"), /no Rokit build/);
	});
});
