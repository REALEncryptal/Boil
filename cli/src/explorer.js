// `boil explore` — the registry's front end.
//
// This is why there's no website: browsing what's available is a menu in the
// terminal you're already in, reading a git repo you already have cached. It
// renders from the local index clone, so it works offline; refreshing is an
// explicit menu item rather than a network call on every keystroke.
//
// Every action here calls the same command a script would (`commands.add`), so
// the explorer stays a discovery aid and never becomes the only way to do
// something.

import * as commands from "./commands.js";
import * as format from "./format.js";
import * as registry from "./registry.js";
import * as term from "./term.js";

function byKind(listings, kind) {
	return listings.filter((listing) => listing.kind === kind);
}

function installedListings(listings) {
	const installed = commands.installedVersions();
	return listings.filter((listing) => installed[listing.name]);
}

// Detail view + actions. Returns true if something was installed.
async function showPackage(listing) {
	// Install by the qualified name when we know which registry this listing came
	// from — picking a row is unambiguous even when the bare name isn't.
	const spec = listing.registry ? `${listing.registry}:${listing.name}` : listing.name;
	while (true) {
		const installed = commands.installedVersions()[listing.name];
		const newest = format.latest(listing);

		term.print("");
		for (const line of format.detail(listing, newest, installed)) {
			term.print(line);
		}
		term.print("");

		const actions = [];
		const handlers = [];

		if (newest) {
			let label =
				installed === newest.version
					? `Reinstall ${newest.version}`
					: installed
						? `Update to ${newest.version}`
						: `Install ${newest.version}`;
			if (!format.compat(newest).ok) {
				label += " (incompatible — force)";
			}
			actions.push(label);
			handlers.push(async () => {
				await commands.add([`${spec}@${newest.version}`], { force: true });
				return true;
			});
		}

		if (listing.versions.length > 1) {
			actions.push("Install a specific version…");
			handlers.push(async () => {
				const versions = listing.versions.map((release) => release.version);
				const picked = await term.select(`${listing.name} — which version?`, versions);
				if (!picked) {
					return undefined;
				}
				await commands.add([`${spec}@${versions[picked - 1]}`], { force: true });
				return true;
			});
		}

		actions.push("Back");
		handlers.push(async () => false);

		const choice = await term.select("Action", actions);
		if (!choice) {
			return false;
		}

		const result = await handlers[choice - 1]();
		if (result !== undefined) {
			return result;
		}
	}
}

async function browse(title, listings) {
	if (listings.length === 0) {
		term.print("");
		term.print(term.dim(`Nothing in ${title}.`));
		return;
	}

	while (true) {
		const rows = format.rows(listings, commands.installedVersions());
		rows.push("Back");

		term.print("");
		const choice = await term.select(`${title} (${listings.length})`, rows);
		if (!choice || choice > listings.length) {
			return;
		}
		await showPackage(listings[choice - 1]);
	}
}

export async function run() {
	if (!registry.anyCached()) {
		term.print("");
		term.warn(`No index cached yet for ${registry.url()}`);
		if (!(await term.confirm("Fetch it now?"))) {
			return;
		}
		await commands.refresh();
	}

	while (true) {
		const listings = registry.loadAll();
		const features = byKind(listings, "feature");
		const skins = byKind(listings, "skin");
		const installed = installedListings(listings);

		const registries = registry.all();
		const options = [
			`Features (${features.length})`,
			`Skins (${skins.length})`,
			`Installed (${installed.length})`,
			"Search…",
			"Refresh indexes",
			"Quit",
		];
		// Only worth a menu entry when there's more than one to choose between.
		if (registries.length > 1) {
			options.splice(3, 0, `By registry (${registries.length})…`);
		}

		term.print("");
		const choice = await term.select(`Boil registry — ${listings.length} package(s)`, options);
		if (!choice) {
			return;
		}

		const picked = options[choice - 1];
		if (picked === "Quit") {
			return;
		}
		if (picked.startsWith("Features")) {
			await browse("Features", features);
		} else if (picked.startsWith("Skins")) {
			await browse("Skins", skins);
		} else if (picked.startsWith("Installed")) {
			await browse("Installed", installed);
		} else if (picked.startsWith("By registry")) {
			const labels = registries.map(
				(entry) => `${entry.name}  ${term.dim(`${entry.url}  (${entry.scope})`)}`,
			);
			labels.push("Back");
			const which = await term.select("Which registry?", labels);
			if (which && which <= registries.length) {
				const entry = registries[which - 1];
				const owned = listings.filter((listing) => listing.registry === entry.name);
				await browse(entry.name, owned);
			}
		} else if (picked === "Search…") {
			const needle = await term.text("Search");
			if (needle && needle !== "") {
				await browse(`Results for "${needle}"`, registry.searchAll(needle));
			}
		} else if (picked.startsWith("Refresh")) {
			await commands.refresh();
		}
	}
}
