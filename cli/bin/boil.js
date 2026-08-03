#!/usr/bin/env node
import { main } from "../src/index.js";

try {
	await main(process.argv.slice(2));
} catch (error) {
	process.stderr.write(`\u001b[31m×\u001b[0m ${error?.stack ?? error}\n`);
	process.exit(1);
}
