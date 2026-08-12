// `boil dev` — the two-terminal dev loop in one terminal.
//
// Working on a Boil project means running the splitter in watch mode (so
// build/ tracks src/features/) *and* `rojo serve` (so Studio sees build/).
// Forgetting the first one is the classic confusing failure: you edit a feature,
// Studio syncs, and nothing changes, because build/ was never regenerated.
//
// Output from both is prefixed and interleaved, and Ctrl-C stops both together.

import { spawn, spawnSync } from "node:child_process";

import * as project from "./project.js";
import * as term from "./term.js";
import { isDir, isFile, trim } from "./util.js";

export const DEFAULT_SPLIT = "tools/split";

// Lune 0.9.0 stopped sinking flags passed to `lune run`: `--` is no longer
// needed to get `--watch` through, and passing it anyway sends a literal "--"
// as the script's first argument. Old Lune is the mirror image — without the
// separator it claims `--watch` for itself and refuses to start. So the
// separator is a function of the installed version, not a constant.
//
// Unknown version (a `lune --version` we can't parse) means new Lune: 0.8 is
// years old, and the splitter tolerates a stray "--" either way.
export function needsSeparator(version) {
	const match = /(\d+)\.(\d+)\.(\d+)/.exec(version ?? "");
	if (!match) {
		return false;
	}
	const [major, minor] = [Number(match[1]), Number(match[2])];
	return major === 0 && minor < 9;
}

export function parsePort(value) {
	if (value === undefined || value === true) {
		return [undefined, "--port needs a number, e.g. --port=34872"];
	}
	const port = Number(value);
	if (!Number.isInteger(port) || port < 1 || port > 65535) {
		return [undefined, `"${value}" is not a valid port (1–65535)`];
	}
	return [port, undefined];
}

// The processes `dev` will run. Pure, so the argv assembly is testable without
// spawning anything.
export function buildCommands({
	port,
	address,
	project: projectFile,
	split = true,
	serve = true,
	luneVersion,
} = {}) {
	const commands = [];

	if (split) {
		const args = ["run", DEFAULT_SPLIT];
		if (needsSeparator(luneVersion)) {
			args.push("--");
		}
		args.push("--watch");
		commands.push({ label: "split", command: "lune", args });
	}

	if (serve) {
		const args = ["serve"];
		if (projectFile) {
			args.push(projectFile);
		}
		if (port !== undefined) {
			args.push("--port", String(port));
		}
		if (address) {
			args.push("--address", address);
		}
		commands.push({ label: "rojo", command: "rojo", args });
	}

	return commands;
}

// `--version` doubles as the "is it on PATH?" check and the version probe.
function probe(command) {
	const result = spawnSync(command, ["--version"], { encoding: "utf8" });
	if (result.error || result.status !== 0) {
		return { ok: false };
	}
	return { ok: true, version: trim(`${result.stdout ?? ""}${result.stderr ?? ""}`) };
}

// Prefix every line so two interleaved streams stay readable. Chunks don't
// arrive on line boundaries, so hold the partial tail until the rest shows up.
function prefixed(stream, label, paint) {
	let buffer = "";
	const flush = (final) => {
		const lines = buffer.split("\n");
		buffer = final ? "" : (lines.pop() ?? "");
		for (const line of lines) {
			if (line.trim() !== "" || !final) {
				term.print(`${paint(label)} ${line}`);
			}
		}
	};

	stream.setEncoding("utf8");
	stream.on("data", (chunk) => {
		buffer += chunk;
		flush(false);
	});
	stream.on("end", () => {
		if (buffer !== "") {
			flush(true);
		}
	});
}

export async function run(args, options = {}) {
	const [port, portError] = options.port === undefined ? [undefined, undefined] : parsePort(options.port);
	if (portError) {
		term.fail(portError);
	}

	const split = options.split !== false;
	const serve = options.serve !== false;
	if (!split && !serve) {
		term.fail("nothing to run — `--no-split` and `--no-serve` together leave no work");
	}

	if (split && !isFile(`${DEFAULT_SPLIT}.luau`)) {
		term.fail(`no ${DEFAULT_SPLIT}.luau here — is this a Boil project?`);
	}

	// Probe before assembling argv — the splitter's flags depend on which Lune
	// is installed.
	const missing = (command) => term.fail(`\`${command}\` isn't installed or isn't on PATH — run \`rokit install\``);

	let luneVersion;
	if (split) {
		const lune = probe("lune");
		if (!lune.ok) {
			missing("lune");
		}
		luneVersion = lune.version;
	}
	if (serve && !probe("rojo").ok) {
		missing("rojo");
	}

	const commands = buildCommands({ port, address: options.address, project: args[0], split, serve, luneVersion });

	const paints = { split: term.cyan, rojo: term.green };

	term.heading("boil dev");

	for (const { label, command, args: argv } of commands) {
		term.info(`${paints[label](label)}  ${command} ${argv.join(" ")}`);
	}

	// Build once, synchronously, before rojo starts.
	//
	// default.project.json points at build/shared, build/server and build/client.
	// Those are generated and gitignored, so on a fresh clone they don't exist —
	// and rojo reads its project file the moment it launches. Starting both at
	// once is a race rojo loses: "$path could not be turned into a Roblox
	// Instance". One synchronous build removes the race entirely; the watcher
	// then takes over.
	if (split) {
		const first = project.runSplit();
		if (first && !first.ok) {
			term.fail(`the splitter failed, so there's nothing to serve:\n${trim(first.output)}`);
		}
		if (first) {
			term.info(term.dim(trim(first.output).split("\n").pop() ?? "built once"));
		}
	} else if (serve && !isDir("build")) {
		term.warn("build/ doesn't exist and --no-split was passed — rojo will fail until you run the splitter");
	}
	term.print("");
	term.print(term.dim("Ctrl-C stops both."));
	term.print("");

	const children = [];
	let shuttingDown = false;

	const stopAll = (signal) => {
		shuttingDown = true;
		for (const child of children) {
			if (child.exitCode === null && child.signalCode === null) {
				child.kill(signal);
			}
		}
	};

	const onSignal = () => {
		if (shuttingDown) {
			return;
		}
		term.print("");
		term.info("stopping…");
		stopAll("SIGINT");
	};

	process.on("SIGINT", onSignal);
	process.on("SIGTERM", onSignal);

	// Resolve on the first exit: if either half dies the loop is broken, so stop
	// the other rather than leaving half a dev environment running.
	const exits = commands.map(({ label, command, args: argv }) => {
		const child = spawn(command, argv, { stdio: ["ignore", "pipe", "pipe"] });
		children.push(child);

		prefixed(child.stdout, label, paints[label]);
		prefixed(child.stderr, label, paints[label]);

		return new Promise((resolve) => {
			child.on("error", (error) => {
				term.warn(`${label} failed to start — ${error.message}`);
				resolve({ label, code: 1 });
			});
			child.on("exit", (code, signal) => {
				resolve({ label, code: code ?? 0, signal });
			});
		});
	});

	const first = await Promise.race(exits);
	if (!shuttingDown) {
		term.print("");
		term.warn(`${first.label} exited${first.code ? ` with code ${first.code}` : ""} — stopping the rest`);
		stopAll("SIGTERM");
	}

	await Promise.all(exits);
	process.off("SIGINT", onSignal);
	process.off("SIGTERM", onSignal);

	if (!shuttingDown && first.code) {
		process.exitCode = first.code;
	}
}
