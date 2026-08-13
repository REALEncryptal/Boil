// Installing Rokit — the toolchain manager that puts rojo, wally and lune on
// PATH. Boil is unusable without them, so the CLI bootstraps Rokit rather than
// leaving a new user to find the install page.
//
// This mirrors what Rokit's own install script does (resolve the latest
// release, pull the zip for this platform, run `rokit self-install`), in Node
// instead of bash: the shell script needs curl, unzip and a POSIX shell, none of
// which are a given on Windows — and this package has no dependencies to reach
// for instead. Hence the small zip reader below.

import { spawnSync } from "node:child_process";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import zlib from "node:zlib";

export const REPOSITORY = "rojo-rbx/rokit";
export const LATEST_RELEASE = `https://api.github.com/repos/${REPOSITORY}/releases/latest`;
export const INSTALL_PAGE = `https://github.com/${REPOSITORY}#installation`;

// Rokit's asset names, keyed by Node's own platform/arch spellings.
const OPERATING_SYSTEMS = { darwin: "macos", linux: "linux", win32: "windows" };
const ARCHITECTURES = { x64: "x86_64", arm64: "aarch64" };

export function target(platform = process.platform, arch = process.arch) {
	const system = OPERATING_SYSTEMS[platform];
	const cpu = ARCHITECTURES[arch];
	if (!system || !cpu) {
		return undefined;
	}
	return { os: system, arch: cpu, binary: system === "windows" ? "rokit.exe" : "rokit" };
}

// rokit-1.2.0-linux-x86_64.zip. Matched rather than constructed, because the
// release carries every platform and only the version varies.
export function pickAsset(assets, spec) {
	const pattern = new RegExp(`^rokit-\\d+\\.\\d+\\.\\d+-${spec.os}-${spec.arch}\\.zip$`);
	return (assets ?? []).find((asset) => pattern.test(asset?.name ?? ""));
}

export function binaryPath() {
	return path.join(os.homedir(), ".rokit", "bin", process.platform === "win32" ? "rokit.exe" : "rokit");
}

// The version string, or undefined when Rokit isn't here. `self-install` puts
// Rokit in ~/.rokit/bin and edits the shell profile, so a shell opened before
// that won't have it on PATH yet — checking the well-known location too keeps us
// from reinstalling over a perfectly good install.
export function installed() {
	for (const command of ["rokit", binaryPath()]) {
		const result = spawnSync(command, ["--version"], { encoding: "utf8" });
		if (!result.error && result.status === 0) {
			return String(result.stdout ?? "").trim() || "installed";
		}
	}
	return undefined;
}

// Why the bootstrap would stand down, or undefined to go ahead. Separate from
// the postinstall script so it's testable without running the script — importing
// that would perform an install.
export function skip(env = process.env, platform = process.platform, arch = process.arch) {
	if (env.BOIL_SKIP_ROKIT !== undefined) {
		return "BOIL_SKIP_ROKIT is set";
	}
	if (!target(platform, arch)) {
		return `there's no Rokit build for ${platform}/${arch}`;
	}
	return undefined;
}

const EOCD_SIGNATURE = 0x06054b50;
const CENTRAL_SIGNATURE = 0x02014b50;

// Pull one file out of a zip. Deliberately minimal: enough for a release archive
// of a handful of files, stored or deflated. Anything else — zip64, encryption,
// an unknown compression method — throws rather than guessing.
export function extract(buffer, name) {
	// The end-of-central-directory record is last, but a trailing comment can
	// push it back by up to 64KB, so scan backwards for its signature.
	let eocd = -1;
	for (let index = buffer.length - 22; index >= 0 && index >= buffer.length - 22 - 0xffff; index -= 1) {
		if (buffer.readUInt32LE(index) === EOCD_SIGNATURE) {
			eocd = index;
			break;
		}
	}
	if (eocd < 0) {
		throw new Error("not a zip archive");
	}

	const count = buffer.readUInt16LE(eocd + 10);
	let entry = buffer.readUInt32LE(eocd + 16);

	for (let index = 0; index < count; index += 1) {
		if (buffer.readUInt32LE(entry) !== CENTRAL_SIGNATURE) {
			throw new Error("damaged zip central directory");
		}

		const method = buffer.readUInt16LE(entry + 10);
		const compressedSize = buffer.readUInt32LE(entry + 20);
		const nameLength = buffer.readUInt16LE(entry + 28);
		const extraLength = buffer.readUInt16LE(entry + 30);
		const commentLength = buffer.readUInt16LE(entry + 32);
		const localOffset = buffer.readUInt32LE(entry + 42);
		const entryName = buffer.toString("utf8", entry + 46, entry + 46 + nameLength);

		if (entryName === name) {
			if (compressedSize === 0xffffffff || localOffset === 0xffffffff) {
				throw new Error("zip64 archives are not supported");
			}
			// The local header repeats the name and carries its own extra field,
			// which is often a different length from the central one.
			const localNameLength = buffer.readUInt16LE(localOffset + 26);
			const localExtraLength = buffer.readUInt16LE(localOffset + 28);
			const start = localOffset + 30 + localNameLength + localExtraLength;
			const body = buffer.subarray(start, start + compressedSize);

			if (method === 0) return Buffer.from(body);
			if (method === 8) return zlib.inflateRawSync(body);
			throw new Error(`unsupported compression method ${method}`);
		}

		entry += 46 + nameLength + extraLength + commentLength;
	}

	throw new Error(`"${name}" is not in the archive`);
}

function headers(accept, token) {
	const base = {
		accept: accept ?? "application/vnd.github+json",
		"user-agent": "boil-cli",
		"x-github-api-version": "2022-11-28",
	};
	return token ? { ...base, authorization: `token ${token}` } : base;
}

async function get(url, { timeoutMs, fetchImpl, accept, token }) {
	const controller = new AbortController();
	const timer = setTimeout(() => controller.abort(), timeoutMs);
	try {
		const response = await fetchImpl(url, {
			signal: controller.signal,
			headers: headers(accept, token),
			redirect: "follow",
		});
		if (!response.ok) {
			throw new Error(`${url} responded ${response.status}`);
		}
		return response;
	} finally {
		clearTimeout(timer);
	}
}

// Everything Rokit publishes is public, so a token is only ever a rate-limit
// courtesy — and a liability when it's the wrong one. Two rules follow:
//
// Only GITHUB_PAT is read, the variable Rokit's own installer documents, never
// the ambient GITHUB_TOKEN that GitHub Actions injects into every job and that
// carries no permission for another org's repo. And if the token is refused, the
// request goes again without it — a stale PAT in someone's shell profile has no
// business breaking a public download.
async function fetchRelease(url, options) {
	const token = process.env.GITHUB_PAT;
	if (!token) {
		return get(url, options);
	}
	try {
		return await get(url, { ...options, token });
	} catch (error) {
		if (!/responded 40[0-9]/.test(String(error?.message))) {
			throw error;
		}
		return get(url, options);
	}
}

// Download, unpack and run `rokit self-install`. Returns a result rather than
// throwing — every caller so far is a courtesy that must not fail the thing it
// hangs off.
export async function install({
	fetchImpl = globalThis.fetch,
	log = () => {},
	apiTimeoutMs = 15_000,
	downloadTimeoutMs = 120_000,
	platform,
	arch,
} = {}) {
	const spec = target(platform, arch);
	if (!spec) {
		return { ok: false, reason: `no Rokit build for ${platform ?? process.platform}/${arch ?? process.arch}` };
	}
	if (typeof fetchImpl !== "function") {
		return { ok: false, reason: "this Node build has no fetch" };
	}

	let scratch;
	try {
		const release = await (await fetchRelease(LATEST_RELEASE, { timeoutMs: apiTimeoutMs, fetchImpl })).json();
		const asset = pickAsset(release?.assets, spec);
		if (!asset?.browser_download_url) {
			return { ok: false, reason: `the latest Rokit release has no ${spec.os}-${spec.arch} build` };
		}

		log(`downloading ${asset.name}`);
		const response = await fetchRelease(asset.browser_download_url, {
			timeoutMs: downloadTimeoutMs,
			fetchImpl,
			accept: "application/octet-stream",
		});
		const archive = Buffer.from(await response.arrayBuffer());

		scratch = fs.mkdtempSync(path.join(os.tmpdir(), "boil-rokit-"));
		const executable = path.join(scratch, spec.binary);
		fs.writeFileSync(executable, extract(archive, spec.binary));
		if (spec.os !== "windows") {
			fs.chmodSync(executable, 0o755);
		}

		// Rokit installs itself properly from here: ~/.rokit/bin, the tool links,
		// and the PATH entry in the shell profile.
		log("running rokit self-install");
		const result = spawnSync(executable, ["self-install"], { encoding: "utf8" });
		if (result.error) {
			return { ok: false, reason: `could not run the Rokit binary (${result.error.code ?? result.error.message})` };
		}
		if (result.status !== 0) {
			return { ok: false, reason: `rokit self-install exited ${result.status}`, output: result.stderr };
		}

		return { ok: true, version: release?.tag_name ?? asset.name, path: binaryPath() };
	} catch (error) {
		return { ok: false, reason: error?.name === "AbortError" ? "timed out" : String(error?.message ?? error) };
	} finally {
		if (scratch) {
			fs.rmSync(scratch, { recursive: true, force: true });
		}
	}
}
