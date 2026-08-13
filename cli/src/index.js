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

import * as commands from "./commands.js";
import * as config from "./config.js";
import * as dev from "./dev.js";
import * as explorer from "./explorer.js";
import * as newProject from "./new.js";
import * as project from "./project.js";
import * as registries from "./registries.js";
import * as publish from "./publish.js";
import * as self from "./self.js";
import * as setup from "./setup.js";
import * as term from "./term.js";
import * as upgrade from "./upgrade.js";

const USAGE = `boil — packages for Boil features and skins

  boil <command> [args] [flags]

Set up
  new [name]                  scaffold a new Boil game from the framework
  setup [index-url]           name the project and create/connect the index
                              (creates the GitHub repo via gh or GITHUB_TOKEN)

Develop
  dev [project-file]          run the splitter (watch) and rojo serve together
                              --port=34872 to change the Rojo port
  upgrade                     pull a newer framework in; features/skins untouched

Browse
  explore                     interactive registry explorer
  search <term>               search every configured registry
  info <package>              show a package's detail view
  refresh                     update every cached index

Registries
  registry list               where packages are looked up, and from which layer
  registry add <name> <url>   add one (--project to scope it to this game)
  registry remove <name>      remove one

Install
  add <package>[@version]     install from any configured registry
  add <registry>:<package>    qualify when two registries share a name
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
  --port=<n> --address=<a>    dev: Rojo serve options
  --no-split / --no-serve     dev: run only one half of the loop
  --empty / --starter         new: framework only, or with the example features
  --no-git                    new: skip git init
  --template=<url> --ref=<t>  new/upgrade: use a different repo or tag
  --registry=<name>           publish: which registry to register in
  --project                   registry add/remove: write to boil.toml, not ~/.boil
  --version                   print the CLI version
`;

// Shown the first time someone runs a bare `boil` with no config and no project
// around them — the three things worth knowing, instead of forty lines of usage.
const WELCOME = `${term.bold("boil")} — packages for Boil features and skins

You don't have a project here yet. Two ways to start:

  ${term.cyan("boil new my-game")}          scaffold a game from the framework
  ${term.cyan("cd <existing-project>")}     then \`boil setup\` to connect an index

Installing from a private or company index? Add it once per machine:

  ${term.cyan("boil registry add company https://github.com/acme/boil-index")}
  ${term.cyan("boil registry list")}        see what's configured

${term.dim("`boil help` lists every command.")}
`;

function parse(argv) {
	const args = [];
	const flags = {};
	let command;

	for (const argument of argv) {
		if (argument.startsWith("--")) {
			// `--flag` is boolean; `--key=value` carries a string (--template=…,
			// --ref=…). Splitting on the first `=` keeps values containing one intact.
			const body = argument.slice(2);
			const equals = body.indexOf("=");
			if (equals >= 0) {
				flags[body.slice(0, equals)] = body.slice(equals + 1);
			} else {
				flags[body] = true;
			}
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

// Commands that read or write project files. Everything else (searching the
// index, reading a package's detail view) works from any directory, which is
// the point of installing this globally.
const NEEDS_PROJECT = new Set([
	"setup",
	"dev",
	"upgrade",
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
	// `--empty` / `--starter` pick a template; leaving both off means "ask", which
	// is why this is undefined rather than false when neither is given.
	new: (parsed) =>
		newProject.run(parsed.args, {
			empty: parsed.flags.empty === true ? true : parsed.flags.starter === true ? false : undefined,
			yes: parsed.flags.yes === true,
			git: parsed.flags["no-git"] === true ? false : undefined,
			template: typeof parsed.flags.template === "string" ? parsed.flags.template : undefined,
			ref: typeof parsed.flags.ref === "string" ? parsed.flags.ref : undefined,
		}),
	setup: (parsed) =>
		setup.run(parsed.args, {
			localIndex: parsed.flags.local,
			private: !parsed.flags.public,
			yes: parsed.flags.yes,
			skipIndex: parsed.flags["skip-index"],
		}),
	dev: (parsed) =>
		dev.run(parsed.args, {
			port: parsed.flags.port,
			address: typeof parsed.flags.address === "string" ? parsed.flags.address : undefined,
			split: parsed.flags["no-split"] === true ? false : undefined,
			serve: parsed.flags["no-serve"] === true ? false : undefined,
		}),
	upgrade: (parsed) =>
		upgrade.run(parsed.args, {
			yes: parsed.flags.yes === true,
			force: parsed.flags.force === true,
			dryRun: parsed.flags["dry-run"] === true,
			template: typeof parsed.flags.template === "string" ? parsed.flags.template : undefined,
			ref: typeof parsed.flags.ref === "string" ? parsed.flags.ref : undefined,
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
	publish: (parsed) =>
		publish.run(parsed.args, {
			yes: parsed.flags.yes,
			dryRun: parsed.flags["dry-run"],
			registry: typeof parsed.flags.registry === "string" ? parsed.flags.registry : undefined,
		}),
	registry: (parsed) => registries.run(parsed.args, { project: parsed.flags.project === true }),
	doctor: () => commands.doctor(),
};

export async function main(argv) {
	const parsed = parse(argv);

	if (parsed.flags.version || parsed.command === "version") {
		term.print(self.localVersion() ?? "unknown");
		return;
	}
	if (!parsed.command && !config.exists() && !project.findRoot()) {
		term.print(WELCOME);
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

	// Last thing printed, after the command has had its say. Skipped entirely on
	// the early returns above — `boil --version` is parsed by scripts, and help
	// text is not the place to be sold an update.
	await self.notify();
}
