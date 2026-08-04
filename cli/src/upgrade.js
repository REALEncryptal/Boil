// `boil upgrade` — pull a newer framework into an existing game.
//
// The counterpart to `boil new`. It works because of the framework/feature
// boundary: the framework is exactly four paths, features and skins are yours,
// and the dependency arrow only points one way. So an upgrade is a replacement
// of those paths, not a merge — src/features/ and src/skins/ are never touched.
//
// Git is the undo button. The command insists on a clean working tree so
// `git diff` after the fact shows precisely what the framework changed, and
// `git checkout .` puts it back.

import path from "node:path";

import * as project from "./project.js";
import * as self from "./self.js";
import * as source from "./source.js";
import * as term from "./term.js";
import * as toml from "./toml.js";
import { copyDir, diffDirs, isDir, isFile, readFile, removeDir, tempDir, trim, writeFile } from "./util.js";

export const DEFAULT_TEMPLATE = "https://github.com/REALEncryptal/Boil";

// The framework, per docs/game/framework-boundary.md. Everything else in a
// checkout is either yours (features, skins, your own docs) or generated.
export const FRAMEWORK_PATHS = ["src/shared", "src/client", "src/server", "tools"];

// Touched by an upgrade but never blindly overwritten — they carry project
// identity (the Rojo name) or hand-maintained content (pinned versions).
export const REVIEW_FILES = ["default.project.json", "wally.toml"];

export function planUpgrade(localDir, templateDir) {
	const paths = [];

	for (const rel of FRAMEWORK_PATHS) {
		const local = path.join(localDir, rel);
		const template = path.join(templateDir, rel);
		if (!isDir(template)) {
			continue;
		}
		const diff = diffDirs(local, template);
		const total = diff.added.length + diff.removed.length + diff.changed.length;
		if (total > 0) {
			paths.push({ path: rel, ...diff, total });
		}
	}

	return {
		paths,
		total: paths.reduce((sum, entry) => sum + entry.total, 0),
		version: frameworkVersion(templateDir),
		wally: wallyAdditions(localDir, templateDir),
		projectFileDiffers: differs(localDir, templateDir, "default.project.json"),
	};
}

function differs(localDir, templateDir, rel) {
	const local = path.join(localDir, rel);
	const template = path.join(templateDir, rel);
	if (!isFile(local) || !isFile(template)) {
		return false;
	}
	return readFile(local) !== readFile(template);
}

export function frameworkVersion(dir) {
	const manifest = path.join(dir, project.MANIFEST);
	if (!isFile(manifest)) {
		return undefined;
	}
	try {
		return toml.parse(readFile(manifest)).project?.boil;
	} catch {
		return undefined;
	}
}

// Wally dependencies the newer framework declares that this project doesn't
// have. Names only — an entry the project already pins is left alone, same rule
// as installing a package.
export function wallyAdditions(localDir, templateDir) {
	const localPath = path.join(localDir, "wally.toml");
	const templatePath = path.join(templateDir, "wally.toml");
	if (!isFile(localPath) || !isFile(templatePath)) {
		return [];
	}

	let local;
	let template;
	try {
		local = toml.parse(readFile(localPath));
		template = toml.parse(readFile(templatePath));
	} catch {
		return [];
	}

	const additions = [];
	for (const section of ["dependencies", "server-dependencies"]) {
		const theirs = template[section] ?? {};
		const ours = local[section] ?? {};
		for (const [name, spec] of Object.entries(theirs)) {
			if (ours[name] === undefined) {
				additions.push({ section, name, spec });
			}
		}
	}
	return additions;
}

// Add the missing entries textually, so the file keeps its comments and order.
export function applyWally(localDir, additions) {
	if (additions.length === 0) {
		return;
	}
	const target = path.join(localDir, "wally.toml");
	let text = readFile(target);

	for (const { section, name, spec } of additions) {
		const header = `[${section}]`;
		if (!text.includes(header)) {
			text += `\n${header}\n`;
		}
		text = text.replace(`${header}\n`, () => `${header}\n${name} = "${spec}"\n`);
	}

	writeFile(target, text);
}

function workingTreeDirty() {
	const [ok, output] = source.git(["status", "--porcelain", ...FRAMEWORK_PATHS, project.MANIFEST, "wally.toml"]);
	if (!ok) {
		return undefined; // not a git repo, or git unavailable
	}
	return trim(output) !== "";
}

function summarize(plan) {
	for (const entry of plan.paths) {
		term.print("");
		term.print(`  ${term.bold(entry.path)}/`);
		for (const rel of entry.added) {
			term.print(`    ${term.green(`+ ${rel}`)}`);
		}
		for (const rel of entry.removed) {
			term.print(`    ${term.red(`- ${rel}`)}`);
		}
		for (const rel of entry.changed) {
			term.print(`    ${term.yellow(`~ ${rel}`)}`);
		}
	}
}

export async function run(args, options = {}) {
	term.heading("boil upgrade");

	// This command upgrades the framework, not the CLI running it — and the
	// version it reports at the end is the framework's, which is not the number
	// `boil --version` prints. Say so up front, so "already up to date" can't be
	// read as "your whole install is current" when the fix you need shipped in a
	// newer CLI.
	self.announce(await self.check());

	const url = options.template ?? DEFAULT_TEMPLATE;
	const work = tempDir("upgrade");
	removeDir(work);

	const cloneArgs = ["clone", "--depth", "1", "--quiet"];
	if (options.ref) {
		cloneArgs.push("--branch", options.ref);
	}
	cloneArgs.push(url, work);

	term.info(`fetching ${url}${options.ref ? ` @ ${options.ref}` : ""}…`);
	const [cloned, output] = source.git(cloneArgs);
	if (!cloned) {
		removeDir(work);
		term.fail(`could not fetch the framework:\n${trim(output)}`);
	}

	const plan = planUpgrade(".", work);
	const current = project.read().boil;

	if (plan.total === 0 && plan.wally.length === 0) {
		removeDir(work);
		term.ok(`the framework is already up to date${plan.version ? ` (Boil ${plan.version})` : ""}`);
		return;
	}

	term.print("");
	term.info(
		`framework ${current} → ${plan.version ?? "unknown"}   ${term.dim(`${plan.total} file(s) across the framework`)}`,
	);
	summarize(plan);

	if (plan.wally.length > 0) {
		term.print("");
		term.print(`  ${term.bold("wally.toml")} ${term.dim("— new framework dependencies")}`);
		for (const { name, spec, section } of plan.wally) {
			term.print(`    ${term.green(`+ ${name} = "${spec}"`)}${section === "dependencies" ? "" : term.dim(" (server)")}`);
		}
	}

	if (plan.projectFileDiffers) {
		term.print("");
		term.warn("default.project.json differs from the template — not touched (it carries your project name)");
		term.info(`compare it yourself if the framework added a sync path: ${term.dim(`diff default.project.json <template>`)}`);
	}

	term.print("");
	if (options.dryRun) {
		removeDir(work);
		term.ok("dry run — nothing was written");
		return;
	}

	// Your VCS is the undo button, so insist on being able to use it.
	const dirty = workingTreeDirty();
	if (dirty === undefined && !options.force) {
		removeDir(work);
		term.fail("not a git repository — upgrading would overwrite the framework with no way back. Pass --force if you're sure.");
	}
	if (dirty && !options.force) {
		removeDir(work);
		term.fail("you have uncommitted changes under the framework paths — commit or stash them first, so `git diff` shows what the upgrade changed. Or pass --force.");
	}

	if (!options.yes && !(await term.confirm("Apply?"))) {
		removeDir(work);
		term.print("Cancelled.");
		return;
	}

	// Replace rather than merge: a file the framework deleted has to disappear,
	// and features/skins are untouched either way.
	for (const entry of plan.paths) {
		removeDir(entry.path);
		copyDir(path.join(work, entry.path), entry.path);
	}

	applyWally(".", plan.wally);

	if (plan.version) {
		const proj = project.read();
		proj.boil = plan.version;
		project.write(proj);
	}

	removeDir(work);

	term.ok(`upgraded the framework${plan.version ? ` to ${plan.version}` : ""}`);
	term.print("");
	term.print(term.bold("Next"));
	if (plan.wally.length > 0) {
		term.info("wally install                        # new dependencies were added");
	}
	term.info("lune run tools/check-framework-boundary");
	term.info("lune run tools/check-views && lune run tools/check-skins");
	term.info("git diff                             # review exactly what changed");
	term.print("");
}
