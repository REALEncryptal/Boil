--!strict
-- Component contract — the keystone of the skin seam.
--
-- These are the typed prop shapes every primitive speaks, promoted out of the
-- individual implementation files into one shared, named place. A *skin* is a
-- table of implementations keyed by component name, each honoring the matching
-- prop type here. The semantic components exported from `ui` (e.g. `ui.Button`)
-- resolve the active skin from React context and render `skin.components.Button`.
--
-- Rules of the contract (see docs/game/skin-contract.md):
--   * Every skin must implement every component key with the documented props.
--   * Structural insertion points are named slot props (`children` maps keyed by
--     name), so every skin agrees on where caller content goes.
--   * `variant` is per-skin: each skin interprets the VariantKey however it likes
--     (gem → gradient palette; flat → flat accent color). Unknown variants fall
--     back to the skin's default.
--   * Tokens live under each skin (`skin.theme`), not in the contract. The
--     contract is shape-only; it says nothing about colors, strokes, or spacing.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local tokens = require(ReplicatedStorage.Shared.ui.tokens)

------------------------------------------------------------------------------
-- Shared vocabulary
------------------------------------------------------------------------------
-- Type and space are part of the contract, not per-skin inventions. A skin may
-- retune the VALUES; it may not change the KEYS, because call sites depend on
-- them. This is what makes `role = "body"` portable across skins — the thing the
-- old shape-only contract could not express.
export type TypeRole = tokens.TypeRole
export type SpaceRole = tokens.SpaceRole

-- Anywhere a gap or inset is taken: a named step (preferred) or a raw reference
-- pixel count (escape hatch, for values a scale genuinely can't express).
export type SpaceValue = SpaceRole | number
-- Anywhere a text size is taken: a named role (preferred) or a raw size.
export type TypeValue = TypeRole | number

export type TypeScale = { display: number, title: number, heading: number, body: number, label: number, caption: number }
export type SpaceScale = { xs: number, sm: number, md: number, lg: number, xl: number, xxl: number }

-- `variant` is what a control MEANS, not what colour it is. The documented set
-- is `primary | secondary | danger | success | warning | neutral | special`, and
-- each skin maps those onto its own palette.
--
-- The type is an open string, not a closed union: skins are installable (see
-- docs/registry.md), so a skin must be able to offer a variant the framework
-- never shipped. Unknown names fall back to the skin's default rather than
-- erroring. The seven legacy colour names still resolve for older call sites.
export type VariantKey = string

-- Props shared by virtually every primitive (placement in the parent).
export type LayoutProps = {
	size: UDim2?,
	position: UDim2?,
	anchorPoint: Vector2?,
	layoutOrder: number?,
	zIndex: number?,
}

export type ButtonProps = {
	variant: VariantKey?,
	text: string?,
	-- Type role for the label, e.g. "body". Prefer this over `textSize`.
	role: TypeRole?,
	textSize: number?,
	textWeight: Enum.FontWeight?,
	size: UDim2?,
	position: UDim2?,
	anchorPoint: Vector2?,
	layoutOrder: number?,
	zIndex: number?,
	-- Disabled: the skin dims the button (e.g. a dark overlay) and ignores
	-- clicks and hover feedback. `onClick` is never fired while disabled.
	disabled: boolean?,
	onClick: (() -> ())?,
}

export type IconButtonProps = {
	variant: VariantKey?,
	icon: string?,
	iconColor: Color3?,
	iconScale: number?,
	size: UDim2?,
	position: UDim2?,
	anchorPoint: Vector2?,
	layoutOrder: number?,
	zIndex: number?,
	onClick: (() -> ())?,
	-- Named slot: caller content mounted inside the button's frame — a caption
	-- across its bottom edge, a notification marker on a corner.
	--
	-- Inside, not beside, and that is the whole point: content here sits within
	-- the skin's hover growth, so it scales with the button instead of staying
	-- put while the button swells underneath it. It is not clipped, so a child
	-- may deliberately overhang an edge.
	children: { [string]: any }?,
}

export type BadgeProps = {
	variant: VariantKey?,
	text: string?,
	role: TypeRole?,
	textSize: number?,
	icon: string?,
	size: UDim2?,
	position: UDim2?,
	anchorPoint: Vector2?,
	layoutOrder: number?,
	zIndex: number?,
}

export type PanelProps = {
	size: UDim2?,
	position: UDim2?,
	anchorPoint: Vector2?,
	layoutOrder: number?,
	zIndex: number?,
	transparency: number?,
	strokeThickness: number?,
	-- Gem mode: when a variant is set the panel paints a gem surface instead of
	-- the dark-glass default. Skins without a gem surface ignore these.
	variant: VariantKey?,
	hasShine: boolean?,
	tileSize: UDim2?,
	-- Named slot: caller content mounted inside the panel body.
	children: { [string]: any }?,
}

export type TextProps = {
	text: string,
	-- Type role — the call site names a JOB ("title", "body", "caption") and the
	-- skin supplies the size. `textSize` still wins when set, for the rare value a
	-- scale can't express.
	role: TypeRole?,
	textSize: number?,
	weight: Enum.FontWeight?,
	color: Color3?,
	xAlignment: Enum.TextXAlignment?,
	yAlignment: Enum.TextYAlignment?,
	size: UDim2?,
	position: UDim2?,
	anchorPoint: Vector2?,
	layoutOrder: number?,
	zIndex: number?,
	automaticSize: Enum.AutomaticSize?,
	-- Wrap onto multiple lines instead of clipping. Text that can outgrow its
	-- box must set this or `truncate` — a clipped label is a bug.
	wrap: boolean?,
	-- Ellipsize at the end instead of clipping mid-glyph.
	truncate: boolean?,
	-- Enable Roblox rich-text markup in `text`.
	richText: boolean?,
	lineHeight: number?,
	-- Drop-shadow (gem look); flat skins may render a plain label.
	shadow: boolean?,
	shadowColor: Color3?,
	strokeThickness: number?,
	foregroundOffset: number?,
}

export type TextFieldProps = {
	size: UDim2?,
	position: UDim2?,
	anchorPoint: Vector2?,
	layoutOrder: number?,
	zIndex: number?,
	transparency: number?,
	strokeThickness: number?,
	padding: SpaceValue?,
	text: string?,
	defaultText: string?,
	placeholderText: string?,
	role: TypeRole?,
	textSize: number?,
	textColor: Color3?,
	placeholderColor: Color3?,
	xAlignment: Enum.TextXAlignment?,
	yAlignment: Enum.TextYAlignment?,
	weight: Enum.FontWeight?,
	clearTextOnFocus: boolean?,
	multiLine: boolean?,
	textWrapped: boolean?,
	maxGraphemes: number?,
	onTextChanged: ((text: string) -> ())?,
	onFocused: (() -> ())?,
	onFocusLost: ((text: string, enterPressed: boolean) -> ())?,
}

export type CheckboxProps = {
	checked: boolean,
	onToggle: ((next: boolean) -> ())?,
	variant: VariantKey?,
	size: UDim2?,
	position: UDim2?,
	anchorPoint: Vector2?,
	layoutOrder: number?,
	zIndex: number?,
	transparency: number?,
	strokeThickness: number?,
	padding: SpaceValue?,
}

export type ProgressBarProps = {
	progress: number,
	variant: VariantKey?,
	text: string?,
	showText: boolean?,
	role: TypeRole?,
	textSize: number?,
	size: UDim2?,
	position: UDim2?,
	anchorPoint: Vector2?,
	layoutOrder: number?,
	zIndex: number?,
	transparency: number?,
	strokeThickness: number?,
	tweenDuration: number?,
	showBleeds: boolean?,
}

export type ScrollDirection = "vertical" | "horizontal"

export type ScrollListProps = {
	direction: ScrollDirection?,
	gap: SpaceValue?,
	padding: SpaceValue?,
	horizontalAlignment: Enum.HorizontalAlignment?,
	verticalAlignment: Enum.VerticalAlignment?,
	fillHorizontal: boolean?,
	fillVertical: boolean?,
	scrollBarThickness: number?,
	scrollBarColor: Color3?,
	scrollBarTransparency: number?,
	size: UDim2?,
	position: UDim2?,
	anchorPoint: Vector2?,
	layoutOrder: number?,
	zIndex: number?,
	background: Color3?,
	backgroundTransparency: number?,
	clipsDescendants: boolean?,
	-- Named slot: list items keyed by name (give each a LayoutOrder).
	children: { [string]: any }?,
}

export type WindowContentPadding = {
	top: SpaceValue?,
	bottom: SpaceValue?,
	left: SpaceValue?,
	right: SpaceValue?,
}

export type WindowProps = {
	title: string?,
	icon: string?,
	titleRole: TypeRole?,
	titleVariant: VariantKey?,
	closeVariant: VariantKey?,
	size: UDim2?,
	position: UDim2?,
	anchorPoint: Vector2?,
	topBarHeight: number?,
	topBarOverflow: number?,
	-- Content-area padding: the inset from the content edge, on top of whatever
	-- clearance the skin needs for its own chrome.
	--
	-- The caller does NOT specify total inset, because it can't know it. Gem draws
	-- its top bar as a row above the body (clearance = a stroke); slop half-
	-- overlaps the body with a floating title badge (clearance = a stroke plus
	-- half the bar). A feature passing `top = "lg"` and meaning "total" silently
	-- lost 47px under slop and the title sat on the first row.
	--
	-- So each skin adds its own clearance to whatever is passed here. Omit a side
	-- to take the skin's default inset for it.
	contentPadding: WindowContentPadding?,
	contentSpacing: SpaceValue?,
	-- Reference-pixel size the window is authored at. A Window mounts its own
	-- responsive Surface, so `size` is NOT screen pixels — see Surface.luau.
	responsive: boolean?,
	onClose: (() -> ())?,
	-- Overlay element pinned to the top bar's right edge.
	topBarExtra: any?,
	topBarExtraSize: UDim2?,
	-- Enter/exit scale tween ref (see useTweenedScale).
	scaleRef: any?,
	initialScale: number?,
	-- Named slot: window body content keyed by name.
	children: { [string]: any }?,
}

export type GemBackgroundProps = {
	fillGradient: ColorSequence,
	glowGradient: ColorSequence,
	glowTransparency: NumberSequence?,
	fillRotation: number?,
	glowRotation: number?,
	tileSize: UDim2?,
	hasShine: boolean?,
	size: UDim2?,
	layoutOrder: number?,
	zIndex: number?,
}

-- The set of component keys a complete skin must implement.
export type Components = {
	Button: (ButtonProps) -> any,
	IconButton: (IconButtonProps) -> any,
	Badge: (BadgeProps) -> any,
	Panel: (PanelProps) -> any,
	Text: (TextProps) -> any,
	TextField: (TextFieldProps) -> any,
	Checkbox: (CheckboxProps) -> any,
	ProgressBar: (ProgressBarProps) -> any,
	ScrollList: (ScrollListProps) -> any,
	Window: (WindowProps) -> any,
	GemBackground: (GemBackgroundProps) -> any,
}

-- The token table a skin must expose. `type` and `space` are mandatory and their
-- keys are fixed; everything past them is the skin's own business.
-- The portable surface of a theme: everything a FEATURE may read. A skin adds
-- whatever private tokens it likes on top, but only these are guaranteed to
-- exist, with these types, in every skin.
export type Theme = {
	type: TypeScale,
	space: SpaceScale,
	motion: { [string]: number },
	roles: { [string]: string },
	textColor: Color3,
	mutedText: Color3,
	resolveVariant: (string?) -> string,
	[string]: any,
}

-- A skin = a name, a token table, and the component implementations.
--
-- `default = true` claims the role of this game's default skin: `skins.get(nil)`,
-- an unparameterised `<SkinProvider>`, and every UI Labs story resolve to it. At
-- most one installed skin should set it.
export type Skin = {
	name: string,
	theme: Theme,
	components: Components,
	default: boolean?,
}

-- What `tools/check-skins` verifies a skin's theme provides. Keeping the list
-- here rather than in the tool means the contract stays the single source of
-- truth for what a skin owes its call sites.
local REQUIRED_TYPE_KEYS = { "display", "title", "heading", "body", "label", "caption" }
local REQUIRED_SPACE_KEYS = { "xs", "sm", "md", "lg", "xl", "xxl" }

-- The ONLY theme members feature code may read.
--
-- Everything else on a theme — `strokeThickness`, `glassTransparency`,
-- `windowSize`, `checkboxSize` — is that skin's private business. A feature that
-- reads one is writing against one skin by accident: the key may be a different
-- TYPE in another skin (gem's `checkboxSize` is a number, slop's is a UDim2) or
-- absent entirely, and the failure lands at render time as an arithmetic error
-- deep inside React with no hint that a skin swap caused it.
--
-- `tools/check-ui` enforces this against feature code. Skin implementations are
-- exempt — reading their own private tokens is the whole point.
local CONTRACT_THEME_KEYS = {
	"type",
	"space",
	"motion",
	"roles",
	"resolveVariant",
	"textColor",
	"mutedText",
	"tokens",
}

-- Motion keys every skin must supply, so a shared hook can tween consistently.
local REQUIRED_MOTION_KEYS = { "hoverScale", "pressScale", "hoverDuration", "pressDuration", "idleScale" }
-- Role slots every skin must map to a type role.
local REQUIRED_ROLE_KEYS = { "default", "button", "badge", "input", "windowTitle" }

-- Returns a list of problems (empty when the theme is complete). Used by the
-- lint and by `skins.register` so a malformed installed skin is caught loudly
-- rather than rendering nil sizes.
local function checkTheme(theme: any): { string }
	local problems: { string } = {}
	if typeof(theme) ~= "table" then
		return { "theme is missing (a skin must expose a token table)" }
	end
	for _, key in REQUIRED_TYPE_KEYS do
		if typeof((theme.type or {})[key]) ~= "number" then
			table.insert(problems, `theme.type.{key} is missing`)
		end
	end
	for _, key in REQUIRED_SPACE_KEYS do
		if typeof((theme.space or {})[key]) ~= "number" then
			table.insert(problems, `theme.space.{key} is missing`)
		end
	end
	for _, key in REQUIRED_MOTION_KEYS do
		if typeof((theme.motion or {})[key]) ~= "number" then
			table.insert(problems, `theme.motion.{key} is missing`)
		end
	end
	for _, key in REQUIRED_ROLE_KEYS do
		if typeof((theme.roles or {})[key]) ~= "string" then
			table.insert(problems, `theme.roles.{key} is missing`)
		end
	end
	-- Features need *some* portable way to colour text; without these they reach
	-- for a raw Color3 literal, which is the drift the scales were meant to end.
	for _, key in { "textColor", "mutedText" } do
		if typeof((theme :: any)[key]) ~= "Color3" then
			table.insert(problems, `theme.{key} is missing (a Color3)`)
		end
	end
	if typeof(theme.resolveVariant) ~= "function" then
		table.insert(problems, "theme.resolveVariant(key) is missing")
	end
	return problems
end

-- Contract version — the skin API's compatibility number.
--
-- Installed skins declare the range they were built against (`contract = "^1"` in
-- their boil.toml) and `boil` refuses to install a skin that doesn't match.
--
--   * Adding a component key is a MINOR change: skins that predate it keep working
--     via the per-key gem fallback in `skins.resolve`, degraded but not broken.
--   * Changing an existing prop shape is a MAJOR change: bump the integer, because
--     every published skin now renders the wrong thing.
--
-- See docs/registry.md.
return {
	-- v2: `type` and `space` scales became part of the contract, `variant` became
	-- an open semantic string, and text-bearing props gained `role`. Skins built
	-- against v1 supply neither scale, so they cannot render sizes — a major bump.
	VERSION = 2,
	REQUIRED_TYPE_KEYS = REQUIRED_TYPE_KEYS,
	REQUIRED_SPACE_KEYS = REQUIRED_SPACE_KEYS,
	REQUIRED_MOTION_KEYS = REQUIRED_MOTION_KEYS,
	REQUIRED_ROLE_KEYS = REQUIRED_ROLE_KEYS,
	CONTRACT_THEME_KEYS = CONTRACT_THEME_KEYS,
	checkTheme = checkTheme,
	COMPONENT_KEYS = {
		"Button",
		"IconButton",
		"Badge",
		"Panel",
		"Text",
		"TextField",
		"Checkbox",
		"ProgressBar",
		"ScrollList",
		"Window",
		"GemBackground",
	},
}
