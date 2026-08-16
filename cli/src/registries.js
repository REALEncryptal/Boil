// `boil registry` — manage where packages are looked up and published.
//
// Two places to put one: your machine (`~/.boil/config.toml`, the default) or
// the project (`boil.toml`, with `--project`). A company index you use
// everywhere belongs on the machine; an index specific to one game belongs in
// that game's manifest, where it's committed alongside it.

import * as commands from "./commands.js";
import * as config from "./config.js";
import * as project from "./project.js";
import * as registry from "./registry.js";
import * as setup from "./setup.js";
import * as term from "./term.js";
import { isDir, trim } from "./util.js";

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

// Why a name can't be used, or undefined if it can. Shared by the flag-driven
// `add` (which fails on it) and the interactive one (which re-asks), so there is
// one rule rather than two that drift.
export function nameProblem(name) {
	if (!name || name.trim() === "") {
		return "a name is required";
	}
	if (!/^[A-Za-z0-9_-]+$/.test(name)) {
		return `"${name}" must be letters, numbers, dashes or underscores — it's used as a prefix (\`${name}:owner/pkg\`)`;
	}
	if (name === "github" || name === "path") {
		return `"${name}" is reserved — \`github:\` and \`path:\` already mean something to \`boil add\``;
	}
	return undefined;
}

export function add(args, options = {}) {
	const [name, url] = args;
	if (!name || !url) {
		term.fail("usage: boil registry add <name> <url> [--project]");
	}
	const problem = nameProblem(name);
	if (problem) {
		term.fail(problem);
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

// Ask for a name until it's a usable one. Returns undefined if the user backs
// out — an interactive flow re-asks where the flag-driven one exits.
async function askName(suggestion) {
	while (true) {
		const answer = await term.text("Short name (you'll type it as a prefix)", suggestion);
		if (answer === undefined || trim(answer) === "") {
			return undefined;
		}
		const problem = nameProblem(trim(answer));
		if (!problem) {
			return trim(answer);
		}
		term.warn(problem);
	}
}

// Machine-wide or this game's manifest. The distinction is the whole reason
// there are two places to put a registry, so it's a question, not a flag to
// discover later.
async function askScope() {
	const inProject = project.findRoot() !== undefined;
	if (!inProject) {
		return { project: false };
	}

	const choice = await term.select("Where should this be configured?", [
		`This machine    ${term.dim(`${config.file()} — every project you open`)}`,
		`This game only  ${term.dim("boil.toml — committed, so everyone cloning it gets the registry")}`,
	]);
	if (!choice) {
		return undefined;
	}
	return { project: choice === 2 };
}

async function addExisting() {
	const answer = await term.text("Registry URL, <owner>/<name>, or a local directory");
	if (answer === undefined || trim(answer) === "") {
		return;
	}

	const normalized = setup.normalizeIndex(answer, { owner: setup.originOwner() });
	if (normalized.error) {
		term.warn(normalized.error);
		return;
	}
	if (normalized.expanded) {
		term.info(`→ ${normalized.url}`);
	}

	const suggested = String(normalized.url).replace(/\/$/, "").split("/").pop().replace(/\.git$/, "");
	const name = await askName(suggested.replace(/[^A-Za-z0-9_-]/g, "-"));
	if (!name) {
		return;
	}

	const scope = await askScope();
	if (!scope) {
		return;
	}

	// The same function the flag-driven command runs, including the fetch that
	// proves the registry is reachable.
	add([name, normalized.url], scope);
}

async function createNew() {
	term.print("");
	term.info("A registry is one git repo holding the packages. This creates it and connects it.");

	const answer = await term.text("New repo — <owner>/<name>, a URL, or a local directory", "boil-index");
	if (answer === undefined || trim(answer) === "") {
		return;
	}

	const normalized = setup.normalizeIndex(answer, { owner: setup.originOwner() });
	if (normalized.error) {
		term.warn(normalized.error);
		return;
	}

	const isPrivate = normalized.kind === "local" ? true : await term.confirm("Private repository?");
	const created = await setup.ensureIndex(normalized.url, { private: isPrivate, localIndex: normalized.kind === "local" });
	if (!created) {
		return;
	}

	const suggested = String(normalized.url).replace(/\/$/, "").split("/").pop().replace(/\.git$/, "");
	const name = await askName(suggested.replace(/[^A-Za-z0-9_-]/g, "-"));
	if (!name) {
		term.info("created, but not configured — add it later with `boil registry add`");
		return;
	}

	const scope = await askScope();
	if (!scope) {
		return;
	}
	add([name, normalized.url], scope);
}

async function removeOne() {
	const entries = registry.all().filter((entry) => entry.scope !== "built-in");
	if (entries.length === 0) {
		term.info("nothing to remove — only the built-in default is configured");
		return;
	}

	const choice = await term.select(
		"Remove which?",
		entries.map((entry) => `${entry.name}  ${term.dim(`${entry.url}  (${entry.scope})`)}`),
	);
	if (!choice) {
		return;
	}
	const picked = entries[choice - 1];
	if (!(await term.confirm(`Remove ${picked.name} from the ${picked.scope} config?`))) {
		return;
	}
	remove([picked.name], { project: picked.scope === "project" });
}

// The Registries screen: what's configured, and every way to change it.
export async function browse() {
	while (true) {
		list();

		const choice = await term.select("Registries", [
			"Add an existing registry",
			"Create a new registry",
			"Remove one",
			"Refresh them all",
		]);
		if (!choice) {
			return;
		}

		if (choice === 1) await addExisting();
		if (choice === 2) await createNew();
		if (choice === 3) await removeOne();
		if (choice === 4) await commands.refresh();
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

	if (!subcommand) {
		// Same rule as `boil` itself: interactive gets the screen, a pipe gets
		// the scriptable output.
		if (term.isInteractive()) {
			await browse();
			return;
		}
		list();
		return;
	}
	if (subcommand === "list") {
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
