// boil — the package CLI for Boil features and skins.
//
//   boil explore              browse and install
//   boil add encryptal/shop   install by name
//   boil publish src/features/Shop
//
// A package is one folder: `src/features/<Name>/` or `src/skins/<Name>/`, with a
// boil.toml inside it. Installs are vendored — the folder lands in src/ and you
// commit it — and boil-lock.toml records where each one came from.
//
// See docs/registry.md.

import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

import * as commands from "./commands.js";
import * as explorer from "./explorer.js";
import * as project from "./project.js";
import * as publish from "./publish.js";
import * as setup from "./setup.js";
import * as term from "./term.js";

const USAGE = `boil — packages for Boil features and skins

  boil <command> [args] [flags]

Set up
  setup [index-url]           name the project and create/connect the index
                              (creates the GitHub repo via gh or GITHUB_TOKEN)

Browse
  explore                     interactive registry explorer
  search <term>               search the index
  info <package>              show a package's detail view
  refresh                     update the cached index

Install
  add <package>[@version]     install from the index
  add github:owner/repo[@tag] install straight from a git repo
  add path:<dir>              install from a local directory
  remove <package>            uninstall and drop from the lockfile
  install                     restore everything in boil-lock.toml
  update [package]            upgrade to the newest compatible version
  outdated                    what has a newer version available
  list                        what's installed, and what you've edited

Author
  publish <path>              lint, tag, push, and register a package
  doctor                      missing deps, Wally gaps, untracked packages

Flags
  --force                     overwrite an existing install / ignore compat
  --yes                       skip confirmations (setup, publish)
  --dry-run                   publish: run the gate, push nothing
  --local                     setup: scaffold a plain directory, not a git repo
  --public                    setup: create the index repo public (default private)
  --skip-index                setup: only write the project manifest
  --version                   print the CLI version
`;

function parse(argv) {
	const args = [];
	const flags = {};
	let command;

	for (const argument of argv) {
		if (argument.startsWith("--")) {
			flags[argument.slice(2)] = true;
			continue;
		}
		if (!command) {
			command = argument;
			continue;
		}
		args.push(argument);
	}

	return { command, args, flags };
}

function version() {
	const here = path.dirname(fileURLToPath(import.meta.url));
	const manifest = JSON.parse(fs.readFileSync(path.join(here, "..", "package.json"), "utf8"));
	return manifest.version;
}

// Commands that read or write project files. Everything else (searching the
// index, reading a package's detail view) works from any directory, which is
// the point of installing this globally.
const NEEDS_PROJECT = new Set([
	"setup",
	"explore",
	"add",
	"remove",
	"install",
	"update",
	"outdated",
	"list",
	"publish",
	"doctor",
]);

const HANDLERS = {
	setup: (parsed) =>
		setup.run(parsed.args, {
			localIndex: parsed.flags.local,
			private: !parsed.flags.public,
			yes: parsed.flags.yes,
			skipIndex: parsed.flags["skip-index"],
		}),
	explore: () => explorer.run(),
	search: (parsed) => commands.search(parsed.args),
	info: (parsed) => commands.info(parsed.args),
	refresh: () => commands.refresh(),
	add: (parsed) => commands.add(parsed.args, { force: parsed.flags.force }),
	remove: (parsed) => commands.remove(parsed.args),
	install: () => commands.install(),
	update: (parsed) => commands.update(parsed.args, parsed.flags.force === true),
	outdated: () => commands.outdated(),
	list: () => commands.list(),
	publish: (parsed) => publish.run(parsed.args, { yes: parsed.flags.yes, dryRun: parsed.flags["dry-run"] }),
	doctor: () => commands.doctor(),
};

export async function main(argv) {
	const parsed = parse(argv);

	if (parsed.flags.version || parsed.command === "version") {
		term.print(version());
		return;
	}
	if (!parsed.command || parsed.flags.help || parsed.command === "help") {
		term.print(USAGE);
		return;
	}

	const handler = HANDLERS[parsed.command];
	if (!handler) {
		term.fail(`unknown command "${parsed.command}" — \`boil help\` lists them`);
	}

	// Commands read and write project files by relative path, so run them from
	// the project root wherever in the checkout the user happened to be.
	if (NEEDS_PROJECT.has(parsed.command)) {
		const root = project.findRoot();
		if (!root) {
			term.fail(
				`\`boil ${parsed.command}\` must run inside a Boil project (no ${project.MARKER} in this directory or any parent)`,
			);
		}
		process.chdir(root);
	}

	await handler(parsed);
}
