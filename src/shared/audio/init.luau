--!strict
-- Centralized sound/music registry plus thin playback helpers.
--
-- Usage:
--   local audio = require(ReplicatedStorage.Shared.audio)
--
--   audio.playUI("click")             -- fire-and-forget one-shot SFX
--   audio.playUI("levelUp", 0.7)      -- override volume
--   audio.playMusic("lobby")          -- swap looping background track
--   audio.playMusic("phonk", 0.4)     -- override volume
--   audio.stopMusic()                 -- stop background music
--   audio.currentTrack()              -- nil | the active music Sound
--
-- This module is **client-side**. UI sounds use `SoundService:PlayLocalSound`
-- which is local-only by design — calling it from the server errors. Music is
-- played by parenting a single looping Sound to SoundService on the client, so
-- each player drives their own track independently of the server. If you ever
-- need server-broadcast audio (a global event jingle), use a normal Sound
-- parented to Workspace and replicated through ByteNet, not this module.
--
-- Note: Roblox does not play audio inside Studio plugins (UI Labs runs as a
-- plugin), so the Audio story's playback buttons are silent in-edit. Audition
-- the registry by Play-testing the game, not from UI Labs.

local SoundService = game:GetService("SoundService")

local Audio = {}

-- Short one-shot UI SFX. Keys are referenced as strings by `playUI`.
Audio.UI = {
	click = "rbxassetid://6895079853",
	click2 = "rbxassetid://103866342467024",
	purchase = "rbxassetid://10066947742",
	hoverIn = "rbxassetid://99955064134003",
	hoverOut = "rbxassetid://10066931761",
	levelUp = "rbxassetid://112485797063762",
	swipe = "rbxassetid://10128766965",
	select = "rbxassetid://10128760939",
	reward = "rbxassetid://82616454607059",
	tick = "rbxassetid://9055474333",
	money = "rbxassetid://307631257",
}

-- Looping music tracks. Keys are referenced as strings by `playMusic`.
Audio.Music = {
	fastMusic = "rbxassetid://140228184971194",
	phonk = "rbxassetid://138118304933431",
	phonk2 = "rbxassetid://140675348569592",
	xmas = "rbxassetid://140633727133993",
	lobby = "rbxassetid://1841647742",
	lobby2 = "rbxassetid://114376757380093",
	lobby3 = "rbxassetid://1840684529",
}

export type UISoundKey =
	"click" | "click2" | "purchase" | "hoverIn" | "hoverOut" | "levelUp"
	| "swipe" | "select" | "reward" | "tick" | "money"

export type MusicKey =
	"fastMusic" | "phonk" | "phonk2" | "xmas" | "lobby" | "lobby2" | "lobby3"

local DEFAULT_UI_VOLUME = 1
local DEFAULT_MUSIC_VOLUME = 0.2

-- One-shot UI sound. Plays via SoundService (no 3D position). PlayLocalSound
-- doesn't yield and is safe from event handlers.
function Audio.playUI(name: string, volume: number?)
	local id = Audio.UI[name]
	if not id then
		warn(`[audio] unknown UI sound "{name}"`)
		return
	end
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume or DEFAULT_UI_VOLUME
	s.Ended:Connect(function()
		s:Destroy()
	end)
	SoundService:PlayLocalSound(s)
	-- Safety net for assets that never fire Ended (bad encoder, etc.).
	task.delay(15, function()
		if s.Parent ~= nil or s.IsPlaying then
			s:Destroy()
		end
	end)
end

-- Play an arbitrary one-shot by rbxassetid. Use this for sounds outside the
-- registry (e.g. user-uploaded picks, asset-id from data). Prefer `playUI` for
-- anything that's stable enough to live in the registry.
function Audio.playSoundId(id: string, volume: number?)
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume or DEFAULT_UI_VOLUME
	s.Ended:Connect(function()
		s:Destroy()
	end)
	SoundService:PlayLocalSound(s)
	task.delay(15, function()
		if s.Parent ~= nil or s.IsPlaying then
			s:Destroy()
		end
	end)
end

local currentMusic: Sound? = nil
local currentMusicKey: string? = nil

-- Swap looping background music. If the requested track is already playing,
-- this is a no-op (returns the existing Sound). Otherwise destroys the prior
-- Sound and starts the new one. Returns the active Sound so callers can fade
-- Volume, hook .Ended, etc.
function Audio.playMusic(name: string, volume: number?): Sound?
	local id = Audio.Music[name]
	if not id then
		warn(`[audio] unknown music track "{name}"`)
		return nil
	end
	if currentMusic and currentMusicKey == name then
		return currentMusic
	end
	if currentMusic then
		currentMusic:Destroy()
		currentMusic = nil
		currentMusicKey = nil
	end
	local s = Instance.new("Sound")
	s.Name = `Music_{name}`
	s.SoundId = id
	s.Volume = volume or DEFAULT_MUSIC_VOLUME
	s.Looped = true
	s.Parent = SoundService
	s:Play()
	currentMusic = s
	currentMusicKey = name
	return s
end

function Audio.stopMusic()
	if currentMusic then
		currentMusic:Destroy()
		currentMusic = nil
		currentMusicKey = nil
	end
end

function Audio.currentTrack(): Sound?
	return currentMusic
end

function Audio.currentTrackName(): string?
	return currentMusicKey
end

return Audio
