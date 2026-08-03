#!/usr/bin/env node
import { main } from "../src/index.js";

// `boil list | head -5` closes the pipe while we're still writing to it. Without
// this, Node turns that into an unhandled EPIPE and dumps a stack trace over the
// output the user was actually reading. Piping into head/less is normal use, and
// the reader going away is a clean exit, not an error.
for (const stream of [process.stdout, process.stderr]) {
	stream.on("error", (error) => {
		if (error?.code === "EPIPE") {
			process.exit(0);
		}
		throw error;
	});
}

try {
	await main(process.argv.slice(2));
} catch (error) {
	if (error?.code === "EPIPE") {
		process.exit(0);
	}
	process.stderr.write(`\u001b[31m×\u001b[0m ${error?.stack ?? error}\n`);
	process.exit(1);
}
