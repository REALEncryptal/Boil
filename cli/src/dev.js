// `boil dev` — the two-terminal dev loop in one terminal.
//
// Working on a Boil project means running the splitter in watch mode (so
// build/ tracks src/features/) *and* `rojo serve` (so Studio sees build/).
// Forgetting the first one is the classic confusing failure: you edit a feature,
// Studio syncs, and nothing changes, because build/ was never regenerated.
//
// Output from both is prefixed and interleaved, and Ctrl-C stops both together.

import { spawn, spawnSync } from "node:child_process";

import * as term from "./term.js";
import { isFile } from "./util.js";

export const DEFAULT_SPLIT = "tools/split";

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
export function buildCommands({ port, address, project, split = true, serve = true } = {}) {
	const commands = [];

	if (split) {
		commands.push({
			label: "split",
			command: "lune",
			args: ["run", DEFAULT_SPLIT, "--", "--watch"],
		});
	}

	if (serve) {
		const args = ["serve"];
		if (project) {
			args.push(project);
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

function hasCommand(command) {
	const result = spawnSync(command, ["--version"], { encoding: "utf8" });
	return !result.error && result.status === 0;
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

	const commands = buildCommands({ port, address: options.address, project: args[0], split, serve });

	for (const { command } of commands) {
		if (!hasCommand(command)) {
			term.fail(`\`${command}\` isn't installed or isn't on PATH — run \`rokit install\``);
		}
	}

	const paints = { split: term.cyan, rojo: term.green };

	term.heading("boil dev");
	for (const { label, command, args: argv } of commands) {
		term.info(`${paints[label](label)}  ${command} ${argv.join(" ")}`);
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
