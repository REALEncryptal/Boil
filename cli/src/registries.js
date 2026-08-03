// `boil registry` — manage where packages are looked up and published.
//
// Two places to put one: your machine (`~/.boil/config.toml`, the default) or
// the project (`boil.toml`, with `--project`). A company index you use
// everywhere belongs on the machine; an index specific to one game belongs in
// that game's manifest, where it's committed alongside it.

import * as config from "./config.js";
import * as project from "./project.js";
import * as registry from "./registry.js";
import * as term from "./term.js";
import { isDir } from "./util.js";

function scopeOf(options) {
	return options.project ? "project" : "user";
}

function readScope(scope) {
	return scope === "project" ? project.read() : config.read();
}

function writeScope(scope, data) {
	if (scope === "project") {
		project.write(data);
		return;
	}
	config.write(data);
}

function where(scope) {
	return scope === "project" ? project.MANIFEST : config.file();
}

export function list() {
	const entries = registry.all();

	term.heading(`Registries (${entries.length})`);
	const width = Math.max(...entries.map((entry) => entry.name.length), 8);

	for (const entry of entries) {
		const cached = registry.localPath(entry.url) !== undefined;
		const count = cached ? registry.load(entry.url).length : undefined;
		const status = cached
			? term.dim(`${count} package(s)`)
			: term.yellow("not fetched — run `boil refresh`");
		term.print(`  ${term.bold(entry.name.padEnd(width))}  ${entry.url}`);
		term.print(`  ${" ".repeat(width)}  ${term.dim(entry.scope)}  ${status}`);
	}

	term.print("");
	term.print(term.dim(`user config: ${config.file()}`));
	term.print(term.dim("Add one with `boil registry add <name> <url>` (--project to scope it to this game)."));
	term.print("");
}

export function add(args, options = {}) {
	const [name, url] = args;
	if (!name || !url) {
		term.fail("usage: boil registry add <name> <url> [--project]");
	}
	if (!/^[A-Za-z0-9_-]+$/.test(name)) {
		term.fail(`"${name}" must be letters, numbers, dashes or underscores — it's used as a prefix (\`${name}:owner/pkg\`)`);
	}
	if (name === "github" || name === "path") {
		term.fail(`"${name}" is reserved — \`github:\` and \`path:\` already mean something to \`boil add\``);
	}

	const scope = scopeOf(options);
	const data = readScope(scope);
	const existing = data.registries[name];

	data.registries[name] = url;
	writeScope(scope, data);

	term.ok(existing ? `updated ${term.bold(name)} in ${where(scope)}` : `added ${term.bold(name)} → ${url}`);
	if (existing) {
		term.info(`${existing} → ${url}`);
	}

	// Fetch it now: an index you can't search yet is an index you'll forget you
	// added. A local directory needs nothing.
	if (!isDir(url)) {
		const [ok, message] = registry.refresh(url);
		if (!ok) {
			term.warn(message);
			term.info("The registry is configured — fix access and run `boil refresh`.");
			return;
		}
		term.ok(`${message} — ${registry.load(url).length} package(s)`);
	}
}

export function remove(args, options = {}) {
	const [name] = args;
	if (!name) {
		term.fail("usage: boil registry remove <name> [--project]");
	}

	const scope = scopeOf(options);
	const data = readScope(scope);

	if (data.registries[name] === undefined) {
		const other = scope === "project" ? "user" : "project";
		const inOther = readScope(other).registries[name] !== undefined;
		const hint = inOther ? ` — it's defined in the ${other} config, try ${other === "project" ? "--project" : "without --project"}` : "";
		term.fail(`no registry "${name}" in ${where(scope)}${hint}`);
	}

	delete data.registries[name];
	writeScope(scope, data);
	term.ok(`removed ${term.bold(name)} from ${where(scope)}`);

	if (registry.byName(name)) {
		term.info(`"${name}" is still visible — another config layer defines it too`);
	}
}

export async function run(args, options = {}) {
	const [subcommand, ...rest] = args;

	// Machine-wide config works from anywhere; touching the project's manifest
	// obviously doesn't, so only that path needs a project around it.
	if (options.project) {
		const root = project.findRoot();
		if (!root) {
			term.fail("--project needs to run inside a Boil project (no default.project.json here or above)");
		}
		process.chdir(root);
	}

	if (!subcommand || subcommand === "list") {
		list();
		return;
	}
	if (subcommand === "add") {
		add(rest, options);
		return;
	}
	if (subcommand === "remove" || subcommand === "rm") {
		remove(rest, options);
		return;
	}

	term.fail(`unknown subcommand "${subcommand}" — try list, add, remove`);
}
