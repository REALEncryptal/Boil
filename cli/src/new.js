// `boil new` — scaffold a fresh Boil game from the framework template.
//
// The template is the Boil repo itself: cloned shallowly, stripped of the parts
// that belong to the framework's own repository rather than to a game built on
// it, then renamed and re-initialized as your project's first commit.
//
// The CLI is never copied in. `boil` is a tool you install once
// (`npm i -g @encryptal/boil`), not something every game vendors a copy of —
// same reason `create-react-app` doesn't leave itself inside the app it makes.

import { spawnSync } from "node:child_process";
import fs from "node:fs";
import path from "node:path";

import * as source from "./source.js";
import * as term from "./term.js";
import * as toml from "./toml.js";
import { copyDir, isDir, isFile, readFile, removeDir, tempDir, trim, writeFile } from "./util.js";

export const DEFAULT_TEMPLATE = "https://github.com/REALEncryptal/Boil";

// Paths that belong to the framework's repo, not to a game made from it.
//
// `cli/` is the CLI itself. `LICENSE` is the framework's copyright, and silently
// inheriting it would misstate who owns the new project. `boil-lock.toml` and
// the build outputs describe a different checkout's state.
const STRIP = ["cli", "LICENSE", "boil-lock.toml", "build", "Packages", "ServerPackages", "wally.lock"];

export function validateName(name) {
	if (!name || trim(name) === "") {
		return "a project name is required";
	}
	if (/[/\\]/.test(name)) {
		return `"${name}" can't contain a path separator — run \`boil new\` from where you want the folder`;
	}
	if (name.startsWith(".")) {
		return `"${name}" can't start with a dot`;
	}
	return undefined;
}

function readmeFor(name) {
	return `# ${name}

A Roblox game built on [Boil](${DEFAULT_TEMPLATE}) — Rojo + Wally + React
(jsdotlua) in a Feature-Sliced Design layout, with a Lune splitter that routes
colocated feature code to the right Roblox service at sync time.

## Getting started

\`\`\`bash
rokit install                  # rojo, wally, lune
wally install                  # populate Packages/

lune run tools/split --watch   # terminal 1 — rebuild build/ on change
rojo serve                     # terminal 2 — sync to Studio
\`\`\`

Then connect from Studio's Rojo plugin.

## Adding features and skins

\`\`\`bash
boil explore                      # browse the index and install
boil add <owner>/<package>
\`\`\`

Install the CLI once with \`npm i -g @encryptal/boil\`.

## Docs

\`docs/\` carries the framework's own documentation — the architecture, the file
naming rules, the four UI seams, and the package registry. Start with
\`docs/README.md\`.
`;
}

const FEATURES_README = `# src/features/

Your game's features live here — one flat folder per feature, each removable.

\`\`\`
src/features/<Name>/
  init.luau
  <Name>Service.server.luau
  <Name>Controller.client.luau
  <Name>UI.ui.luau
\`\`\`

The suffix routes the file: \`.server\` → ServerScriptService, \`.client\` →
StarterPlayerScripts, \`.ui\` and plain \`.luau\` → ReplicatedStorage. Both entry
scripts discover features automatically, so adding one is zero edits elsewhere.

Keep the folder flat — the splitter only reads the top level.

See \`docs/adding-a-feature.md\`, or install one with \`boil add <owner>/<name>\`.
`;

// Turn a cloned template into the new project, in place.
//
// Split out from `run` so it's testable without a network round trip: hand it a
// directory that looks like the template and it does the whole transformation.
export function scaffold(dir, { name, empty = false } = {}) {
	for (const rel of STRIP) {
		const target = path.join(dir, rel);
		if (isDir(target)) {
			removeDir(target);
			continue;
		}
		if (isFile(target)) {
			fs.rmSync(target);
		}
	}

	// The project manifest: this game's identity, and none of the template's
	// installed packages.
	const manifestPath = path.join(dir, "boil.toml");
	if (isFile(manifestPath)) {
		let decoded = {};
		try {
			decoded = toml.parse(readFile(manifestPath));
		} catch {
			decoded = {};
		}
		const body = { project: { name, boil: decoded.project?.boil ?? "0.1.0" } };
		if (decoded.registries && Object.keys(decoded.registries).length > 0) {
			body.registries = decoded.registries;
		}
		writeFile(manifestPath, toml.stringify(body));
	}

	// The Rojo project name is what shows up in Studio.
	const rojoPath = path.join(dir, "default.project.json");
	if (isFile(rojoPath)) {
		try {
			const rojo = JSON.parse(readFile(rojoPath));
			rojo.name = name;
			writeFile(rojoPath, `${JSON.stringify(rojo, undefined, 2)}\n`);
		} catch {
			// A malformed template project file is the template's problem, not
			// something to fail the scaffold over — Rojo will report it.
		}
	}

	writeFile(path.join(dir, "README.md"), readmeFor(name));

	if (!empty) {
		return;
	}

	// The framework ships empty by design: every feature is removable, including
	// the bundled ones. Leave a README so the directory survives `git init`.
	const features = path.join(dir, "src", "features");
	removeDir(features);
	writeFile(path.join(features, "README.md"), FEATURES_README);
}

function initGit(dir, name) {
	const init = source.git(["init", "-q", dir]);
	if (!init[0]) {
		term.warn(`could not run git init — ${trim(init[1])}`);
		return false;
	}

	source.git(["add", "-A"], dir);
	const [committed, output] = source.git(["commit", "-m", `Initial commit — ${name} from Boil`], dir);
	if (!committed) {
		term.warn("git repository created, but the first commit failed");
		term.info(trim(output).split("\n")[0] ?? "");
		term.info("Set user.name / user.email, then commit yourself.");
		return false;
	}
	return true;
}

function hasCommand(command) {
	return spawnSync(command, ["--version"], { encoding: "utf8" }).status === 0;
}

export async function run(args, options = {}) {
	term.heading("boil new");

	let name = args[0];
	if (!name && options.yes) {
		term.fail("usage: boil new <project-name>");
	}
	if (!name) {
		name = await term.text("Project name", "my-game");
	}
	if (!name) {
		term.fail("cancelled");
	}

	const nameError = validateName(name);
	if (nameError) {
		term.fail(nameError);
	}

	const target = path.resolve(name);
	if (isDir(target) && fs.readdirSync(target).length > 0) {
		term.fail(`${name}/ already exists and isn't empty`);
	}

	// What goes in src/features. The framework boots fine with none, which is the
	// whole point of the framework/feature boundary — but a starter you can
	// actually run teaches the conventions faster.
	let empty = options.empty === true;
	if (!options.yes && options.empty === undefined) {
		const choice = await term.select("Which template?", [
			"Starter — the example features (PlayerData, Settings, UIShell, …)",
			"Empty — the framework only, no features",
		]);
		if (choice === undefined) {
			term.fail("cancelled");
		}
		empty = choice === 2;
	}

	let git = options.git !== false && hasCommand("git");
	if (git && !options.yes) {
		git = await term.confirm("Initialize a git repository?");
	}

	// Fetch the template.
	const work = tempDir("new");
	removeDir(work);

	const url = options.template ?? DEFAULT_TEMPLATE;
	const cloneArgs = ["clone", "--depth", "1", "--quiet"];
	if (options.ref) {
		cloneArgs.push("--branch", options.ref);
	}
	cloneArgs.push(url, work);

	term.info(`fetching the template from ${url}${options.ref ? ` @ ${options.ref}` : ""}…`);
	const [cloned, output] = source.git(cloneArgs);
	if (!cloned) {
		removeDir(work);
		term.fail(`could not fetch the template:\n${trim(output)}`);
	}

	scaffold(work, { name, empty });

	// copyDir skips .git, so the template's history never follows the clone.
	copyDir(work, target);
	removeDir(work);

	const committed = git ? initGit(target, name) : false;

	term.print("");
	term.ok(`created ${term.bold(name)} → ${target}/`);
	term.info(empty ? "framework only — no features installed" : "starter features included");
	if (committed) {
		term.info("git repository initialized with a first commit");
	}

	term.print("");
	term.print(term.bold("Next"));
	term.info(`cd ${name}`);
	term.info("rokit install && wally install");
	term.info("boil setup                     # connect a package index");
	term.info("lune run tools/split --watch   # terminal 1");
	term.info("rojo serve                     # terminal 2");
	term.print("");
	term.print(term.dim("Then connect from Studio's Rojo plugin. Browse packages with `boil explore`."));
	term.print("");
}
