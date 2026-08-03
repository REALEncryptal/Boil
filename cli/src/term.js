// Terminal output + prompts for the CLI and the explorer.
//
// Every prompt routes through here so non-interactive runs (CI, a piped shell,
// an agent) fail with an explanation instead of hanging on a read that will
// never come. Prompts are also the one thing the explorer needs that the
// scriptable commands don't — keeping them behind this module is what lets every
// explorer action have a non-interactive twin.

import readline from "node:readline/promises";

const CODES = {
	reset: "\u001b[0m",
	dim: "\u001b[2m",
	bold: "\u001b[1m",
	green: "\u001b[32m",
	yellow: "\u001b[33m",
	red: "\u001b[31m",
	cyan: "\u001b[36m",
};

const ANSI = /\u001b\[[0-9;]*m/g;

function colorEnabled() {
	if (process.env.NO_COLOR !== undefined) return false;
	if (process.env.FORCE_COLOR !== undefined) return true;
	return Boolean(process.stdout.isTTY);
}

function paint(code, text) {
	return colorEnabled() ? `${CODES[code]}${text}${CODES.reset}` : String(text);
}

export const dim = (text) => paint("dim", text);
export const bold = (text) => paint("bold", text);
export const green = (text) => paint("green", text);
export const yellow = (text) => paint("yellow", text);
export const red = (text) => paint("red", text);
export const cyan = (text) => paint("cyan", text);

export function stripAnsi(text) {
	return String(text).replace(ANSI, "");
}

export function width(text) {
	return stripAnsi(text).length;
}

// Truncate to a visible width without cutting an escape sequence in half.
export function truncate(text, limit) {
	if (width(text) <= limit) {
		return text;
	}
	let visible = 0;
	let out = "";
	for (let index = 0; index < text.length; index += 1) {
		const match = text.slice(index).match(/^\u001b\[[0-9;]*m/);
		if (match) {
			out += match[0];
			index += match[0].length - 1;
			continue;
		}
		if (visible >= limit - 1) {
			return `${out}…${colorEnabled() ? CODES.reset : ""}`;
		}
		out += text[index];
		visible += 1;
	}
	return out;
}

export function print(text) {
	process.stdout.write(`${text ?? ""}\n`);
}

export function heading(text) {
	print("");
	print(bold(text));
}

export function info(text) {
	print(`  ${text}`);
}

export function ok(text) {
	print(`${green("✓")} ${text}`);
}

export function warn(text) {
	print(`${yellow("!")} ${text}`);
}

// Print an error and stop. Every failure path in the CLI ends here, so the exit
// code is consistent and callers never have to remember to exit.
export function fail(text) {
	showCursor();
	process.stderr.write(`${red("×")} ${text}\n`);
	process.exit(1);
}

export function isInteractive() {
	if (process.env.CI !== undefined) return false;
	if (process.env.BOIL_NONINTERACTIVE !== undefined) return false;
	return Boolean(process.stdin.isTTY && process.stdout.isTTY);
}

function requireInteractive(what) {
	if (isInteractive()) {
		return;
	}
	fail(`${what} needs an interactive terminal. Use the scriptable commands instead — \`boil help\`.`);
}

function hideCursor() {
	if (process.stdout.isTTY) process.stdout.write("\u001b[?25l");
}

function showCursor() {
	if (process.stdout.isTTY) process.stdout.write("\u001b[?25h");
}

// Raw mode for one prompt, always restored — including on Ctrl-C, which would
// otherwise leave the user's shell with no echo.
function withRawKeys(onKey) {
	return new Promise((resolve) => {
		const stdin = process.stdin;
		const wasRaw = stdin.isRaw;
		stdin.setRawMode(true);
		stdin.resume();
		stdin.setEncoding("utf8");
		hideCursor();

		const cleanup = () => {
			stdin.off("data", handler);
			stdin.setRawMode(Boolean(wasRaw));
			stdin.pause();
			showCursor();
		};

		const handler = (key) => {
			if (key === "\u0003") {
				cleanup();
				print("");
				process.exit(130);
			}
			const outcome = onKey(key);
			if (outcome === undefined) {
				return;
			}
			cleanup();
			resolve(outcome.value);
		};

		stdin.on("data", handler);
	});
}

const done = (value) => ({ value });

// Returns the selected index (1-based, matching the rest of the CLI's counting)
// or undefined when the user backs out.
export async function select(message, options) {
	requireInteractive("This prompt");
	if (options.length === 0) {
		return undefined;
	}

	const rows = Math.max(3, (process.stdout.rows || 24) - 4);
	const visible = Math.min(options.length, rows);
	const columns = (process.stdout.columns || 80) - 1;

	let cursor = 0;
	let offset = 0;
	let rendered = 0;

	const draw = () => {
		if (cursor < offset) offset = cursor;
		if (cursor >= offset + visible) offset = cursor - visible + 1;

		const lines = [`${cyan("?")} ${bold(message)}`];
		for (let index = offset; index < offset + visible; index += 1) {
			const active = index === cursor;
			// The row keeps its own colours when it's the cursor; the rest dim down
			// so the selection is readable in a list of markers and versions.
			const label = active ? options[index] : dim(stripAnsi(options[index]));
			lines.push(truncate(`${active ? cyan("❯") : " "} ${label}`, columns));
		}
		if (options.length > visible) {
			lines.push(dim(`  ${cursor + 1}/${options.length}`));
		}
		lines.push(dim("  ↑/↓ move · enter select · esc back"));

		if (rendered > 0) {
			process.stdout.write(`\u001b[${rendered}A\r\u001b[J`);
		}
		process.stdout.write(`${lines.join("\n")}\n`);
		rendered = lines.length;
	};

	const erase = () => {
		if (rendered > 0) {
			process.stdout.write(`\u001b[${rendered}A\r\u001b[J`);
			rendered = 0;
		}
	};

	draw();

	return withRawKeys((key) => {
		if (key === "\r" || key === "\n") {
			erase();
			print(`${cyan("?")} ${bold(message)} ${dim("›")} ${stripAnsi(options[cursor])}`);
			return done(cursor + 1);
		}
		if (key === "\u001b" || key === "q") {
			erase();
			return done(undefined);
		}
		if (key === "\u001b[A" || key === "k") {
			cursor = (cursor - 1 + options.length) % options.length;
		} else if (key === "\u001b[B" || key === "j") {
			cursor = (cursor + 1) % options.length;
		} else if (key === "g" || key === "\u001b[H") {
			cursor = 0;
		} else if (key === "G" || key === "\u001b[F") {
			cursor = options.length - 1;
		} else {
			return undefined;
		}
		draw();
		return undefined;
	});
}

export async function confirm(message) {
	requireInteractive("This prompt");
	process.stdout.write(`${cyan("?")} ${bold(message)} ${dim("[y/N]")} `);

	return withRawKeys((key) => {
		const yes = key === "y" || key === "Y";
		if (!yes && !"nN\r\n\u001b".includes(key)) {
			return undefined;
		}
		process.stdout.write(`${yes ? green("yes") : dim("no")}\n`);
		return done(yes);
	});
}

export async function text(message, fallback) {
	requireInteractive("This prompt");
	const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
	rl.on("SIGINT", () => {
		rl.close();
		print("");
		process.exit(130);
	});

	const suffix = fallback ? ` ${dim(`(${fallback})`)}` : "";
	try {
		const answer = await rl.question(`${cyan("?")} ${bold(message)}${suffix} `);
		const trimmed = answer.trim();
		return trimmed === "" ? fallback : trimmed;
	} catch {
		return fallback;
	} finally {
		rl.close();
	}
}
