// Fetching package contents.
//
// Everything goes through `git`, which is already installed and already
// authenticated on any machine that has this repo checked out — that's the whole
// reason the registry is git-backed rather than a hosted service. Private
// packages work through normal GitHub permissions with no token plumbing here.

import { spawnSync } from "node:child_process";

import { copyDir, isDir, removeDir, startsWith, tempDir, trim } from "./util.js";

export function git(args, cwd) {
	const result = spawnSync("git", args, { cwd, encoding: "utf8" });
	if (result.error) {
		return [false, `could not run \`git\`: ${result.error.message}`];
	}
	if (result.status === 0) {
		return [true, result.stdout];
	}
	return [false, result.stderr !== "" ? result.stderr : result.stdout];
}

// "encryptal/shop@1.2.0" | "github:owner/repo@v1" | "https://…" | "path:../dir"
export function parseSpec(text) {
	// An scp-style URL has an @ of its own, so split off the version after it
	// rather than treating "git" as the body.
	if (startsWith(text, "git@")) {
		const rest = text.slice(4);
		const split = rest.match(/^(.*)@([^@]+)$/);
		return { git: `git@${split ? split[1] : rest}`, tag: split ? split[2] : undefined };
	}

	const match = text.match(/^(.*)@([^@]+)$/);
	const body = match ? match[1] : text;
	const version = match ? match[2] : undefined;

	if (startsWith(body, "path:")) {
		return { path: body.slice(5), tag: version };
	}
	if (startsWith(body, "github:")) {
		return { git: `https://github.com/${body.slice(7)}`, tag: version };
	}
	if (startsWith(body, "http://") || startsWith(body, "https://") || startsWith(body, "git@")) {
		return { git: body, tag: version };
	}

	// `company:acme/shop` — qualify which registry to look in when more than one
	// publishes the same name. Checked after the fixed prefixes above, so a
	// registry can't be named "github" or "path" and shadow them.
	const qualified = body.match(/^([A-Za-z0-9_-]+):(.+\/.+)$/);
	if (qualified) {
		return { registry: qualified[1], name: qualified[2], version };
	}

	return { name: body, version };
}

export function describe(spec) {
	if (spec.path) return `path+${spec.path}`;
	if (spec.git) return `git+${spec.git}`;
	return spec.name ?? "?";
}

// Every tag a remote publishes, newest-agnostic (the caller ranks them).
export function remoteTags(url) {
	const [ok, output] = git(["ls-remote", "--tags", "--refs", url]);
	if (!ok) {
		return [];
	}
	const tags = [];
	for (const line of output.split("\n")) {
		const match = line.match(/refs\/tags\/(.+)$/);
		if (match) {
			tags.push(match[1]);
		}
	}
	return tags;
}

export function withSubdir(dir, subdir) {
	if (!subdir || subdir === "") {
		return [dir, undefined];
	}
	const nested = `${dir}/${subdir}`;
	if (!isDir(nested)) {
		return [undefined, `subdir "${subdir}" not found in the fetched source`];
	}
	return [nested, undefined];
}

// Materialize a package into a fresh temp directory and return its path.
// The caller owns cleanup.
export function fetch(spec) {
	if (spec.path) {
		if (!isDir(spec.path)) {
			return [undefined, `no such directory: ${spec.path}`];
		}
		const dest = tempDir("path");
		copyDir(spec.path, dest);
		return withSubdir(dest, spec.subdir);
	}

	const url = spec.git;
	if (!url) {
		return [undefined, "no source to fetch from"];
	}

	const dest = tempDir("fetch");
	removeDir(dest);

	const args = ["clone", "--depth", "1", "--quiet"];
	if (spec.tag) {
		args.push("--branch", spec.tag);
	}
	args.push(url, dest);

	const [ok, output] = git(args);
	if (!ok) {
		removeDir(dest);
		const hint = spec.tag ? ` (tag "${spec.tag}")` : "";
		return [undefined, `git clone failed for ${url}${hint}:\n${trim(output)}`];
	}

	return withSubdir(dest, spec.subdir);
}
