// `boil` with no arguments — the front door.
//
// Every row here routes into the same function a script would call, which is
// the rule the explorer already follows: discovery gets easier, nothing becomes
// menu-only. A non-interactive shell never reaches this (index.js prints usage
// instead), so scripts are unaffected.

import * as commands from "./commands.js";
import * as dev from "./dev.js";
import * as explorer from "./explorer.js";
import * as lock from "./lock.js";
import * as project from "./project.js";
import * as publish from "./publish.js";
import * as registries from "./registries.js";
import * as registry from "./registry.js";
import * as term from "./term.js";

// The right-hand column: what each row would show you if you picked it. Read
// from the cache only — the hub must not stall on a network call before it can
// draw itself.
export function summarize({ inProject = true } = {}) {
	const rows = [];

	const available = registry.loadAll().length;
	rows.push({
		label: "Browse packages",
		note: available > 0 ? `${available} available` : "nothing cached yet",
		run: () => explorer.run(),
	});

	if (inProject) {
		const installed = lock.read();
		rows.push({
			label: "Installed",
			note: installed.length === 0 ? "none yet" : `${installed.length} package(s)`,
			run: async () => commands.list(),
		});

		const publishable = publish.candidates().length;
		rows.push({
			label: "Publish from this game",
			note: publishable === 0 ? "no features or skins here" : `${publishable} folder(s)`,
			run: () => publish.run([], {}),
		});
	}

	const configured = registry.all();
	const names = configured.map((entry) => entry.name).join(", ");
	rows.push({
		label: "Registries",
		note: configured.length === 1 ? names : `${configured.length} — ${names}`,
		run: async () => registries.list(),
	});

	if (inProject) {
		rows.push({
			label: "Dev",
			note: "splitter + rojo serve",
			run: () => dev.run([], {}),
		});
	}

	return rows;
}

export async function run() {
	const inProject = project.findRoot() !== undefined;
	const rows = summarize({ inProject });
	const width = Math.max(...rows.map((row) => row.label.length));

	while (true) {
		const title = inProject ? `Boil — ${project.read().name}` : "Boil";
		term.heading(title);
		term.print("");

		const labels = rows.map((row) => `${row.label.padEnd(width)}   ${term.dim(row.note)}`);
		const choice = await term.select("What are you doing?", labels);
		if (!choice) {
			return;
		}

		await rows[choice - 1].run();

		// `dev` and `explore` own the terminal until they're done; coming back to
		// the menu afterwards is the least surprising thing, but one round of
		// anything else is usually all that's wanted.
		if (!(await term.confirm("Back to the menu?"))) {
			return;
		}
	}
}
