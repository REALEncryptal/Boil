--!strict
-- Terminal output + prompts for the CLI and the explorer.
--
-- Every prompt routes through here so non-interactive runs (CI, a piped shell,
-- an agent) fail with an explanation instead of hanging on a read that will never
-- come. Prompts are also the one thing the explorer needs that the scriptable
-- commands don't — keeping them behind this module is what lets every explorer
-- action have a non-interactive twin.

local process = require("@lune/process")
local stdio = require("@lune/stdio")

local term = {}

local function paint(color: stdio.Color, text: string): string
	return `{stdio.color(color)}{text}{stdio.color("reset")}`
end

function term.dim(text: string): string
	return `{stdio.style("dim")}{text}{stdio.style("reset")}`
end

function term.bold(text: string): string
	return `{stdio.style("bold")}{text}{stdio.style("reset")}`
end

function term.green(text: string): string
	return paint("green", text)
end

function term.yellow(text: string): string
	return paint("yellow", text)
end

function term.red(text: string): string
	return paint("red", text)
end

function term.cyan(text: string): string
	return paint("cyan", text)
end

function term.print(text: string?)
	stdio.write(`{text or ""}\n`)
end

function term.heading(text: string)
	term.print("")
	term.print(term.bold(text))
end

function term.info(text: string)
	term.print(`  {text}`)
end

function term.ok(text: string)
	term.print(`{term.green("✓")} {text}`)
end

function term.warn(text: string)
	term.print(`{term.yellow("!")} {text}`)
end

-- Print an error and stop. Every failure path in the CLI ends here, so the exit
-- code is consistent and callers never have to remember to exit.
function term.fail(text: string): never
	stdio.ewrite(`{term.red("×")} {text}\n`)
	process.exit(1)
	error("unreachable")
end

function term.isInteractive(): boolean
	-- A prompt needs a real terminal on stdin. Lune has no isatty, so treat an
	-- explicit CI/BOIL_NONINTERACTIVE marker as the signal, and let the prompt
	-- itself surface anything else.
	return process.env.CI == nil and process.env.BOIL_NONINTERACTIVE == nil
end

local function requireInteractive(what: string)
	if term.isInteractive() then
		return
	end
	term.fail(`{what} needs an interactive terminal. Use the scriptable commands instead — \`lune run tools/boil -- help\`.`)
end

-- Returns the selected index (1-based) or nil when the user backs out.
function term.select(message: string, options: { string }): number?
	requireInteractive("This prompt")
	if #options == 0 then
		return nil
	end
	local ok, result = pcall(stdio.prompt, "select" :: any, message, options)
	if not ok then
		return nil
	end
	return result :: number?
end

function term.confirm(message: string): boolean
	requireInteractive("This prompt")
	local ok, result = pcall(stdio.prompt, "confirm" :: any, message)
	return ok and result == true
end

function term.text(message: string, default: string?): string?
	requireInteractive("This prompt")
	local ok, result = pcall(stdio.prompt, "text" :: any, message, default)
	if not ok then
		return nil
	end
	return result :: string?
end

return term
