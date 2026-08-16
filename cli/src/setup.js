// `boil setup` — get a checkout ready to install and publish packages.
//
// Mostly this exists to remove the one manual step the registry used to need:
// "go to GitHub, make an empty repo, add a packages/ directory, push". That's
// now automated, with three ways to create the remote, tried in order:
//
//   1. the `gh` CLI, if it's installed and authenticated (handles orgs, no token)
//   2. the GitHub API with GITHUB_TOKEN / GH_TOKEN
//   3. printing the one command you have to run yourself
//
// Every step is idempotent and additive: an index that already exists is left
// alone apart from gaining a packages/ directory if it's missing, and nothing
// here ever force-pushes or deletes.

import { spawnSync } from "node:child_process";
import path from "node:path";

import * as project from "./project.js";
import * as registry from "./registry.js";
import * as source from "./source.js";
import * as term from "./term.js";
import { ensureDir, isDir, isFile, removeDir, tempDir, trim, writeFile } from "./util.js";

const README = `# boil-index

The package index for [Boil](https://github.com/REALEncryptal/Boil) features and
skins. One TOML file per package under \`packages/<scope>/<name>.toml\`, each
listing that package's published versions.

Managed by \`boil publish\`; you shouldn't need to edit it by hand. Browse it
with \`boil explore\`.
`;

// What the user typed at the prompt → something we can actually clone.
//
// A bare `private-index` is a reasonable answer, so treat it as a repo name
// under the GitHub account we can detect, and `owner/name` as that repo. Only
// give up when there's genuinely nothing to go on — and never let an
// unresolvable answer reach the project manifest, because a poisoned
// `[registries] default` then gets suggested back on the next run.
export function normalizeIndex(value, { owner, local } = {}) {
	const text = trim(value ?? "");
	if (text === "") {
		return { error: "no index given" };
	}

	// Anything path-shaped, or an explicit --local, is a directory.
	if (local || isDir(text) || text.startsWith(".") || text.includes("\\") || path.isAbsolute(text)) {
		return { url: text, kind: "local" };
	}

	if (/^(https?:\/\/|git@|ssh:\/\/|file:\/\/)/.test(text)) {
		return { url: text, kind: "remote" };
	}

	const ownerAndName = text.match(/^([A-Za-z0-9._-]+)\/([A-Za-z0-9._-]+)$/);
	if (ownerAndName) {
		return { url: `https://github.com/${text}`, kind: "remote", expanded: true };
	}

	if (/^[A-Za-z0-9._-]+$/.test(text)) {
		if (!owner) {
			return {
				needsOwner: true,
				error:
					`"${text}" is just a name, and I can't tell which GitHub account to put it under ` +
					`(this project has no git remote).\n  Try "<owner>/${text}", a full URL, or --local for a plain directory.`,
			};
		}
		return { url: `https://github.com/${owner}/${text}`, kind: "remote", expanded: true };
	}

	return { error: `"${text}" isn't a URL, an <owner>/<name>, or a directory path` };
}

export function parseRepoUrl(url) {
	const match = String(url).match(/github\.com[:/]([^/]+)\/([^/.]+)/);
	return match ? [match[1], match[2]] : [undefined, undefined];
}

// The owner of this checkout's origin, used to guess a default index URL.
export function originOwner() {
	const [ok, output] = source.git(["remote", "get-url", "origin"]);
	if (!ok) {
		return undefined;
	}
	return parseRepoUrl(trim(output))[0];
}

function remoteExists(url) {
	const [ok] = source.git(["ls-remote", "--exit-code", url, "HEAD"]);
	if (ok) {
		return true;
	}
	// An existing but *empty* repo has no refs, so ls-remote exits non-zero with
	// no error output. Distinguish that from "no such repo", which errors loudly.
	const [reachable, output] = source.git(["ls-remote", url]);
	return reachable && trim(output) === "";
}

function hasGh() {
	const result = spawnSync("gh", ["--version"], { encoding: "utf8" });
	return !result.error && result.status === 0;
}

function createWithGh(owner, name, isPrivate) {
	const result = spawnSync(
		"gh",
		["repo", "create", `${owner}/${name}`, isPrivate ? "--private" : "--public", "--description", "Boil package index"],
		{ encoding: "utf8" },
	);
	if (!result.error && result.status === 0) {
		return [true, "created with gh"];
	}
	return [false, trim(result.stderr || result.stdout || String(result.error))];
}

async function createWithApi(owner, name, isPrivate) {
	const token = process.env.GITHUB_TOKEN ?? process.env.GH_TOKEN;
	if (!token) {
		return [false, "no gh CLI and no GITHUB_TOKEN / GH_TOKEN set"];
	}

	// Personal repos and org repos are different endpoints, and we can't know
	// which the owner is without another call — try the org route first, since
	// /user/repos ignores the owner entirely and would silently create the index
	// under the wrong account.
	const attempts = [
		{ url: `https://api.github.com/orgs/${owner}/repos`, label: "org" },
		{ url: "https://api.github.com/user/repos", label: "user" },
	];

	let lastError = "";
	for (const attempt of attempts) {
		try {
			const response = await fetch(attempt.url, {
				method: "POST",
				headers: {
					Authorization: `Bearer ${token}`,
					"Content-Type": "application/json",
					"User-Agent": "boil-cli",
					Accept: "application/vnd.github+json",
				},
				body: JSON.stringify({ name, private: isPrivate, description: "Boil package index" }),
			});
			if (response.ok) {
				return [true, `created via the GitHub API (${attempt.label})`];
			}
			lastError = `${response.status}: ${trim(await response.text())}`;
		} catch (error) {
			lastError = String(error.message ?? error);
		}
	}

	return [false, lastError];
}

// The registry's own name, for registry.toml — the repo name, or the folder's.
function name(url) {
	return String(url).replace(/\/$/, "").split("/").pop().replace(/\.git$/, "");
}

// Put a packages/ directory, a registry.toml and a README in the index, if they
// aren't there.
function seedIndex(url) {
	const work = tempDir("index-setup");
	removeDir(work);

	const [cloned, output] = source.git(["clone", "--quiet", url, work]);
	if (!cloned) {
		term.warn(`could not clone ${url}:\n${trim(output)}`);
		return false;
	}

	let changed = false;
	if (!isDir(path.join(work, registry.PACKAGES))) {
		writeFile(path.join(work, registry.PACKAGES, ".gitkeep"), "");
		changed = true;
	}
	if (!isFile(path.join(work, "README.md"))) {
		writeFile(path.join(work, "README.md"), README);
		changed = true;
	}
	// Stamps the layout so `publish` and `add` know this holds packages rather
	// than links to other repos.
	if (registry.writeFormat(work, name(url))) {
		changed = true;
	}

	if (!changed) {
		removeDir(work);
		term.info("index already has a packages/ directory — left alone");
		return true;
	}

	source.git(["add", "-A"], work);

	// Check the commit rather than letting a failure surface at push time as
	// "src refspec HEAD does not match any", which says nothing about the actual
	// cause — almost always an unset git identity on a fresh machine.
	const [committed, commitOutput] = source.git(["commit", "-m", "Initialize the Boil package index"], work);
	if (!committed) {
		removeDir(work);
		term.warn(`could not commit to the index:\n${trim(commitOutput)}`);
		if (/user\.email|user\.name|tell me who you are/i.test(commitOutput)) {
			term.info("Set your git identity, then re-run `boil setup`:");
			term.info(term.cyan('  git config --global user.email "you@example.com"'));
			term.info(term.cyan('  git config --global user.name "Your Name"'));
		}
		return false;
	}

	const [pushed, pushOutput] = source.git(["push", "-u", "origin", "HEAD"], work);
	removeDir(work);
	if (!pushed) {
		term.warn(`could not push to ${url}:\n${trim(pushOutput)}`);
		term.info("You need write access to the index repository.");
		return false;
	}
	return true;
}

function setupLocalIndex(target) {
	ensureDir(path.join(target, registry.PACKAGES));
	if (!isFile(path.join(target, registry.PACKAGES, ".gitkeep"))) {
		writeFile(path.join(target, registry.PACKAGES, ".gitkeep"), "");
	}
	registry.writeFormat(target, name(target));
	if (!isFile(path.join(target, "README.md"))) {
		writeFile(path.join(target, "README.md"), README);
	}
	term.ok(`local index ready at ${target}/`);
	return true;
}

// Exported so the interactive registry manager can create a registry the same
// way `setup` does, rather than growing a second implementation of it.
export async function ensureIndex(url, options) {
	if (isDir(url) || options.localIndex) {
		return setupLocalIndex(url);
	}

	if (remoteExists(url)) {
		term.ok(`index exists: ${url}`);
		return seedIndex(url);
	}

	const [owner, name] = parseRepoUrl(url);
	if (!owner || !name) {
		term.warn(`${url} doesn't look like a GitHub URL — create it yourself, then re-run setup`);
		return false;
	}

	term.info(`${url} doesn't exist yet`);
	if (!options.yes && !(await term.confirm(`Create ${owner}/${name} on GitHub?`))) {
		return false;
	}

	const isPrivate = options.private !== false;
	const [created, message] = hasGh()
		? createWithGh(owner, name, isPrivate)
		: await createWithApi(owner, name, isPrivate);

	if (!created) {
		term.warn(`couldn't create it automatically — ${message}`);
		term.print("");
		term.info("Create it yourself, then re-run `boil setup`:");
		term.info(term.cyan(`  gh repo create ${owner}/${name} ${isPrivate ? "--private" : "--public"}`));
		term.info(term.dim(`  (or make an empty repo named "${name}" at github.com/${owner})`));
		return false;
	}

	term.ok(`${message}: ${url}`);
	return seedIndex(url);
}

export async function run(args, options = {}) {
	term.heading("boil setup");

	const proj = project.read();

	// 1. Project identity.
	const folder = path.basename(process.cwd());
	if (proj.name === "boil-game" || proj.name === "boil") {
		const suggested = folder || proj.name;
		const name = options.yes ? suggested : await term.text("Project name", suggested);
		proj.name = name ?? suggested;
	}
	term.ok(`project: ${proj.name} (Boil ${proj.boil})`);

	if (options.skipIndex) {
		project.write(proj);
		return;
	}

	// 2. Where the index lives.
	let url = options.index ?? args[0];
	if (!url) {
		const detected = originOwner();
		let suggested = detected ? `https://github.com/${detected}/boil-index` : "boil-index";
		if (proj.registries.default && proj.registries.default !== registry.DEFAULT_URL) {
			suggested = proj.registries.default;
		}
		url = options.yes ? suggested : await term.text("Index URL (or a local path)", suggested);
	}
	if (!url || url === "") {
		term.fail("no index URL — re-run with `boil setup <url>`");
	}

	// Resolve before persisting. A value that can't be cloned must never reach
	// boil.toml, or the next run offers it back as the default.
	let resolved = normalizeIndex(url, { owner: originOwner(), local: options.localIndex });

	// A name with no detectable owner is the common case for a project that was
	// scaffolded but never pushed — ask rather than dead-end.
	if (resolved.needsOwner && !options.yes) {
		const owner = await term.text("GitHub owner (your username or org)");
		if (owner && trim(owner) !== "") {
			resolved = normalizeIndex(url, { owner: trim(owner), local: options.localIndex });
		}
	}
	if (resolved.error) {
		term.fail(resolved.error);
	}
	if (resolved.expanded) {
		term.info(`${url} → ${resolved.url}`);
	}
	url = resolved.url;

	proj.registries.default = url;
	project.write(proj);
	term.ok(`index: ${url}`);

	// 3. Make sure it actually exists, creating it if we can.
	if (!(await ensureIndex(url, options))) {
		term.print("");
		term.warn("setup finished, but the index isn't usable yet");
		term.info("`boil add github:owner/repo` and `boil add path:<dir>` work without an index.");
		return;
	}

	// 4. Cache it so explore/search work immediately.
	const [refreshed, message] = registry.refresh(url);
	if (!refreshed) {
		term.warn(message);
	} else {
		term.ok(`${message} — ${registry.load().length} package(s)`);
	}

	term.print("");
	term.info("Next: `boil explore` to browse, or `boil publish <path>` to add a package.");
	term.print("");
}
