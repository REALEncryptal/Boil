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
local Assets = require(ReplicatedStorage.Shared.ui.assets)

export type VariantKey = Assets.VariantKey

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
}

export type BadgeProps = {
	variant: VariantKey?,
	text: string?,
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
	padding: number?,
	text: string?,
	defaultText: string?,
	placeholderText: string?,
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
	padding: number?,
}

export type ProgressBarProps = {
	progress: number,
	variant: VariantKey?,
	text: string?,
	showText: boolean?,
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
	gap: number?,
	padding: number?,
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
	top: number?,
	bottom: number?,
	left: number?,
	right: number?,
}

export type WindowProps = {
	title: string?,
	icon: string?,
	titleVariant: VariantKey?,
	closeVariant: VariantKey?,
	size: UDim2?,
	position: UDim2?,
	anchorPoint: Vector2?,
	topBarHeight: number?,
	topBarOverflow: number?,
	contentPadding: WindowContentPadding?,
	contentSpacing: number?,
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

-- A skin = a name, a token table, and the component implementations.
export type Skin = {
	name: string,
	theme: any,
	components: Components,
}

return {}
