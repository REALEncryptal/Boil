// TOML, parsed and emitted without a dependency.
//
// Lune gave the old CLI `serde.decode("toml", …)` for free. Node doesn't, and
// pulling a package in for it would cost this CLI its "npm i -g, no install
// tree" property — so it's here. The scope is TOML 1.0 minus the parts a
// manifest never uses: dates come back as strings (every date in the format is
// quoted anyway), and there's no attempt at the exotic corners of the spec.
//
// `stringify` emits scalars before sub-tables before arrays-of-tables, which is
// what TOML requires. The old Lua path leaned on serde and table iteration order
// for that, which is why registry.luau hand-wrote its own listing serializer;
// registry.js still emits listings by hand, but now for the reason that survives
// review — stable field order in a file that gets read as a git diff.

const BARE_KEY = /^[A-Za-z0-9_-]+$/;

class Reader {
	constructor(source) {
		this.source = source;
		this.index = 0;
	}

	get done() {
		return this.index >= this.source.length;
	}

	peek(offset = 0) {
		return this.source[this.index + offset];
	}

	startsWith(text) {
		return this.source.startsWith(text, this.index);
	}

	take(count = 1) {
		const out = this.source.slice(this.index, this.index + count);
		this.index += count;
		return out;
	}

	// Line/column for an error message, computed only when something goes wrong.
	position() {
		const upto = this.source.slice(0, this.index);
		const line = upto.split("\n").length;
		const column = this.index - (upto.lastIndexOf("\n") + 1) + 1;
		return `line ${line}, column ${column}`;
	}

	fail(message) {
		throw new Error(`${message} (${this.position()})`);
	}
}

function skipInline(reader) {
	while (!reader.done) {
		const char = reader.peek();
		if (char === " " || char === "\t") {
			reader.index += 1;
			continue;
		}
		if (char === "#") {
			while (!reader.done && reader.peek() !== "\n") {
				reader.index += 1;
			}
			continue;
		}
		return;
	}
}

function skipAny(reader) {
	while (!reader.done) {
		skipInline(reader);
		const char = reader.peek();
		if (char === "\n" || char === "\r") {
			reader.index += 1;
			continue;
		}
		return;
	}
}

function expectLineEnd(reader) {
	skipInline(reader);
	if (reader.done) {
		return;
	}
	const char = reader.peek();
	if (char === "\n" || char === "\r") {
		reader.index += 1;
		return;
	}
	reader.fail(`unexpected "${char}" after a value`);
}

function readEscape(reader) {
	const char = reader.take();
	const simple = { b: "\b", t: "\t", n: "\n", f: "\f", r: "\r", '"': '"', "\\": "\\" };
	if (simple[char] !== undefined) {
		return simple[char];
	}
	if (char === "u" || char === "U") {
		const width = char === "u" ? 4 : 8;
		const digits = reader.take(width);
		if (!/^[0-9a-fA-F]+$/.test(digits) || digits.length !== width) {
			reader.fail(`bad \\${char} escape`);
		}
		return String.fromCodePoint(Number.parseInt(digits, 16));
	}
	reader.fail(`unknown escape \\${char}`);
	return "";
}

function readBasicString(reader) {
	reader.take(); // opening quote
	let out = "";
	while (true) {
		if (reader.done) {
			reader.fail("unterminated string");
		}
		const char = reader.take();
		if (char === '"') {
			return out;
		}
		if (char === "\n") {
			reader.fail("unterminated string");
		}
		out += char === "\\" ? readEscape(reader) : char;
	}
}

function readMultilineBasic(reader) {
	reader.take(3);
	if (reader.peek() === "\r") {
		reader.index += 1;
	}
	if (reader.peek() === "\n") {
		reader.index += 1;
	}

	let out = "";
	while (true) {
		if (reader.done) {
			reader.fail("unterminated multi-line string");
		}
		if (reader.startsWith('"""')) {
			reader.take(3);
			// """" and """"" mean the string ends with quotes.
			while (reader.peek() === '"' && out.length < 2) {
				out += reader.take();
			}
			return out;
		}
		const char = reader.take();
		if (char !== "\\") {
			out += char;
			continue;
		}
		// A backslash at end of line swallows the newline and the indent after it.
		let ahead = reader.index;
		while (" \t\r".includes(reader.source[ahead])) {
			ahead += 1;
		}
		if (reader.source[ahead] === "\n") {
			reader.index = ahead + 1;
			while (" \t\r\n".includes(reader.source[reader.index])) {
				reader.index += 1;
			}
			continue;
		}
		out += readEscape(reader);
	}
}

function readLiteralString(reader) {
	reader.take();
	let out = "";
	while (true) {
		if (reader.done) {
			reader.fail("unterminated literal string");
		}
		const char = reader.take();
		if (char === "'") {
			return out;
		}
		if (char === "\n") {
			reader.fail("unterminated literal string");
		}
		out += char;
	}
}

function readMultilineLiteral(reader) {
	reader.take(3);
	if (reader.peek() === "\r") {
		reader.index += 1;
	}
	if (reader.peek() === "\n") {
		reader.index += 1;
	}
	let out = "";
	while (true) {
		if (reader.done) {
			reader.fail("unterminated multi-line literal string");
		}
		if (reader.startsWith("'''")) {
			reader.take(3);
			while (reader.peek() === "'" && out.length < 2) {
				out += reader.take();
			}
			return out;
		}
		out += reader.take();
	}
}

function readString(reader) {
	if (reader.startsWith('"""')) {
		return readMultilineBasic(reader);
	}
	if (reader.startsWith("'''")) {
		return readMultilineLiteral(reader);
	}
	if (reader.peek() === '"') {
		return readBasicString(reader);
	}
	return readLiteralString(reader);
}

// Integers, floats, booleans, and anything else scalar. Dates are deliberately
// left as strings: nothing in the package format reads one as a date, and a
// Date object would only complicate the round-trip back out.
function readAtom(reader) {
	const start = reader.index;
	while (!reader.done && !",]}\n\r#".includes(reader.peek())) {
		reader.index += 1;
	}
	const raw = reader.source.slice(start, reader.index).trim();
	if (raw === "") {
		reader.fail("expected a value");
	}

	if (raw === "true") return true;
	if (raw === "false") return false;

	const cleaned = raw.replace(/_/g, "");
	const radix = { "0x": 16, "0o": 8, "0b": 2 }[cleaned.slice(0, 2).toLowerCase()];
	if (radix && /^[+-]?0[xob]/i.test(cleaned)) {
		const digits = cleaned.slice(2);
		const value = Number.parseInt(digits, radix);
		return Number.isNaN(value) ? raw : value;
	}
	if (/^[+-]?(inf|nan)$/.test(cleaned)) {
		if (cleaned.endsWith("nan")) return Number.NaN;
		return cleaned.startsWith("-") ? -Infinity : Infinity;
	}
	if (/^[+-]?[0-9]+$/.test(cleaned)) {
		return Number.parseInt(cleaned, 10);
	}
	if (/^[+-]?(?:[0-9]+\.[0-9]+|[0-9]+)(?:[eE][+-]?[0-9]+)?$/.test(cleaned)) {
		return Number.parseFloat(cleaned);
	}
	return raw;
}

function readArray(reader) {
	reader.take();
	const out = [];
	while (true) {
		skipAny(reader);
		if (reader.done) {
			reader.fail("unterminated array");
		}
		if (reader.peek() === "]") {
			reader.take();
			return out;
		}
		out.push(readValue(reader));
		skipAny(reader);
		if (reader.peek() === ",") {
			reader.take();
			continue;
		}
		if (reader.peek() === "]") {
			reader.take();
			return out;
		}
		reader.fail("expected , or ] in an array");
	}
}

function readInlineTable(reader) {
	reader.take();
	const out = {};
	skipInline(reader);
	if (reader.peek() === "}") {
		reader.take();
		return out;
	}
	while (true) {
		skipInline(reader);
		const path = readKeyPath(reader);
		skipInline(reader);
		if (reader.peek() !== "=") {
			reader.fail("expected = in an inline table");
		}
		reader.take();
		skipInline(reader);
		assign(out, path, readValue(reader), reader);
		skipInline(reader);
		if (reader.peek() === ",") {
			reader.take();
			continue;
		}
		if (reader.peek() === "}") {
			reader.take();
			return out;
		}
		reader.fail("expected , or } in an inline table");
	}
}

function readValue(reader) {
	const char = reader.peek();
	if (char === '"' || char === "'") {
		return readString(reader);
	}
	if (char === "[") {
		return readArray(reader);
	}
	if (char === "{") {
		return readInlineTable(reader);
	}
	return readAtom(reader);
}

function readKeyPath(reader) {
	const path = [];
	while (true) {
		skipInline(reader);
		const char = reader.peek();
		if (char === '"' || char === "'") {
			path.push(readString(reader));
		} else {
			const start = reader.index;
			while (!reader.done && /[A-Za-z0-9_-]/.test(reader.peek())) {
				reader.index += 1;
			}
			if (reader.index === start) {
				reader.fail("expected a key");
			}
			path.push(reader.source.slice(start, reader.index));
		}
		skipInline(reader);
		if (reader.peek() !== ".") {
			return path;
		}
		reader.take();
	}
}

function assign(table, path, value, reader) {
	let current = table;
	for (const key of path.slice(0, -1)) {
		if (current[key] === undefined) {
			current[key] = {};
		}
		if (Array.isArray(current[key])) {
			current[key] = current[key][current[key].length - 1];
		}
		if (typeof current[key] !== "object") {
			reader.fail(`"${path.join(".")}" conflicts with an existing value`);
		}
		current = current[key];
	}
	current[path[path.length - 1]] = value;
}

// Walk a header path, creating tables as it goes. `[a.b]` after `[[a]]` targets
// the last element of the array, which is how array-of-tables nesting works.
function descend(root, path, reader) {
	let current = root;
	for (const key of path) {
		if (current[key] === undefined) {
			current[key] = {};
		}
		if (Array.isArray(current[key])) {
			current = current[key][current[key].length - 1];
			continue;
		}
		if (typeof current[key] !== "object" || current[key] === null) {
			reader.fail(`"${path.join(".")}" conflicts with an existing value`);
		}
		current = current[key];
	}
	return current;
}

export function parse(text) {
	const reader = new Reader(String(text).replace(/^﻿/, ""));
	const root = {};
	let current = root;

	while (true) {
		skipAny(reader);
		if (reader.done) {
			return root;
		}

		if (reader.peek() !== "[") {
			const path = readKeyPath(reader);
			skipInline(reader);
			if (reader.peek() !== "=") {
				reader.fail(`expected = after "${path.join(".")}"`);
			}
			reader.take();
			skipInline(reader);
			assign(current, path, readValue(reader), reader);
			expectLineEnd(reader);
			continue;
		}

		const isArrayTable = reader.startsWith("[[");
		reader.take(isArrayTable ? 2 : 1);
		const path = readKeyPath(reader);
		const closer = isArrayTable ? "]]" : "]";
		if (!reader.startsWith(closer)) {
			reader.fail("unterminated table header");
		}
		reader.take(closer.length);
		expectLineEnd(reader);

		if (!isArrayTable) {
			current = descend(root, path, reader);
			continue;
		}

		const parent = descend(root, path.slice(0, -1), reader);
		const key = path[path.length - 1];
		if (!Array.isArray(parent[key])) {
			parent[key] = [];
		}
		const entry = {};
		parent[key].push(entry);
		current = entry;
	}
}

function quoteKey(key) {
	return BARE_KEY.test(key) ? key : encodeString(key);
}

function encodeString(value) {
	const escaped = value
		.replace(/\\/g, "\\\\")
		.replace(/"/g, '\\"')
		.replace(/\n/g, "\\n")
		.replace(/\t/g, "\\t")
		.replace(/\r/g, "\\r");
	return `"${escaped}"`;
}

function encodeScalar(value) {
	if (typeof value === "string") {
		// A multi-line value (a [studio] notes block) stays readable as a literal
		// block rather than one long line full of escapes.
		if (value.includes("\n")) {
			const body = value.replace(/\\/g, "\\\\").replace(/"""/g, '\\"\\"\\"');
			return `"""\n${body}${body.endsWith("\n") ? "" : "\n"}"""`;
		}
		return encodeString(value);
	}
	if (typeof value === "boolean") {
		return value ? "true" : "false";
	}
	if (typeof value === "number") {
		if (Number.isNaN(value)) return "nan";
		if (value === Infinity) return "inf";
		if (value === -Infinity) return "-inf";
		return String(value);
	}
	if (Array.isArray(value)) {
		return `[${value.map((entry) => encodeScalar(entry)).join(", ")}]`;
	}
	throw new Error(`cannot serialize ${typeof value} to TOML`);
}

function isPlainTable(value) {
	return typeof value === "object" && value !== null && !Array.isArray(value);
}

function isTableArray(value) {
	return Array.isArray(value) && value.length > 0 && value.every(isPlainTable);
}

function skip(value) {
	return value === undefined || value === null;
}

// One table's contents: its own scalars first, then its sub-tables and
// arrays-of-tables. Scalars have to come first — after a `[a.b]` header, any
// remaining `key = value` at this level would silently land in `a.b` instead.
// That ordering is exactly what the old Lua path couldn't guarantee.
function emitBody(table, path, lines) {
	for (const [key, value] of Object.entries(table)) {
		if (skip(value) || isPlainTable(value) || isTableArray(value)) continue;
		lines.push(`${quoteKey(key)} = ${encodeScalar(value)}`);
	}

	for (const [key, value] of Object.entries(table)) {
		if (skip(value)) continue;
		const childPath = [...path, key];
		const header = childPath.map(quoteKey).join(".");

		if (isTableArray(value)) {
			for (const entry of value) {
				lines.push("");
				lines.push(`[[${header}]]`);
				emitBody(entry, childPath, lines);
			}
			continue;
		}
		if (isPlainTable(value)) {
			lines.push("");
			lines.push(`[${header}]`);
			emitBody(value, childPath, lines);
		}
	}
}

export function stringify(value) {
	if (!isPlainTable(value)) {
		throw new Error("TOML documents must be a table");
	}
	const lines = [];
	emitBody(value, [], lines);
	while (lines.length > 0 && lines[0] === "") {
		lines.shift();
	}
	while (lines.length > 0 && lines[lines.length - 1] === "") {
		lines.pop();
	}
	return `${lines.join("\n")}\n`;
}
