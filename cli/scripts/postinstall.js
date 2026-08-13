#!/usr/bin/env node
// Runs after `npm i -g @encryptal/boil`.
//
// Boil is a Roblox toolchain: without Rokit there is no rojo, wally or lune, and
// nothing the CLI scaffolds can be built or synced. Installing Boil and then
// being told to go install something else is a bad first five minutes, so the
// toolchain manager comes with it.
//
// Two rules govern everything here, because an npm lifecycle script is a rude
// place to do work — no TTY to ask with, and often a sudo'd or automated shell:
//
//   1. Never fail the install. Every path exits 0; a failed bootstrap prints
//      how to do it by hand and gets out of the way.
//   2. Never do it twice, and never without an exit. Rokit already on the
//      machine means silence, and BOIL_SKIP_ROKIT=1 (or npm's own
//      --ignore-scripts) turns the whole thing off.

import * as rokit from "../src/rokit.js";

// Plain writes, not the CLI's term module: npm captures this output and replays
// it in its own log format, where colour and cursor tricks only make a mess.
const say = (line) => process.stdout.write(`${line}\n`);

async function main() {
	const skipped = rokit.skip();
	if (skipped) {
		say(`boil: skipping the Rokit install — ${skipped}`);
		return;
	}

	const already = rokit.installed();
	if (already) {
		say(`boil: found ${already}`);
		return;
	}

	say("boil: installing Rokit, the toolchain manager for rojo, wally and lune…");
	const result = await rokit.install({ log: (line) => say(`boil: ${line}`) });

	if (!result.ok) {
		say(`boil: couldn't install Rokit — ${result.reason}`);
		say(`boil: install it yourself when convenient — ${rokit.INSTALL_PAGE}`);
		say("boil: everything else works; `boil dev` and `boil new` will need it.");
		return;
	}

	say(`boil: installed Rokit ${result.version} → ${result.path}`);
	say("boil: open a new terminal (or reload your shell) to pick it up on PATH.");
}

// The catch-all that keeps rule 1 true even if something above throws.
main()
	.catch((error) => {
		say(`boil: skipping the Rokit install — ${error?.message ?? error}`);
	})
	.finally(() => {
		process.exitCode = 0;
	});
