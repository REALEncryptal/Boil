--!strict
-- SkinProvider — the skin seam (seam #1: how a primitive *looks*).
--
-- Holds the active skin in React context. The semantic components exported from
-- `ui` resolve their implementation from here, so flipping the provider's `skin`
-- re-skins the entire tree with no change to feature code.
--
-- Mount once near the root:  React.createElement(ui.SkinProvider, { skin = "gem" }, children)
-- Read in a component:        local skin = ui.useSkin()
--
-- useSkin() falls back to the gem skin when no provider is mounted, so existing
-- call sites and UI Labs stories work untouched.
--
-- `skin` is a plain string, resolved against the registry at render: the set of
-- available skins is open (a game can install more — see docs/registry.md), so it
-- can't be a closed union. An unknown name warns once and renders gem.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local contract = require(script.Parent.contract)
local skins = require(script.Parent.skins)

export type SkinName = string

local SkinContext = React.createContext(nil :: contract.Skin?)

type ProviderProps = {
	skin: SkinName?,
	children: { [string]: any }?,
}

local function SkinProvider(props: ProviderProps)
	return React.createElement(SkinContext.Provider, { value = skins.get(props.skin or "gem") }, props.children)
end

local function useSkin(): contract.Skin
	local skin = React.useContext(SkinContext)
	if skin == nil then
		return skins.get("gem")
	end
	return skin
end

return {
	SkinProvider = SkinProvider,
	useSkin = useSkin,
	Context = SkinContext,
	skins = skins,
}
