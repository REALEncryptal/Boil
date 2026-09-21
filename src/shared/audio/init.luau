--!strict
-- Centralized sound/music registry plus thin playback helpers.
--
-- Usage:
--   local audio = require(ReplicatedStorage.Shared.audio)
--
--   audio.prepare()                   -- warm registered one-shot SFX at boot
--   audio.playUI("click")             -- fire-and-forget one-shot SFX
--   audio.playUI("levelUp", 0.7)      -- override volume
--   audio.prepareSoundId(id)          -- warm a feature-owned one-shot
--   audio.playMusic("lobby")          -- swap looping background track
--   audio.playMusic("phonk", 0.4)     -- override volume
--   audio.playMusic("lobby", nil, { transitionTime = 0.5, resume = true })
--   audio.stopMusic()                 -- stop background music
--   audio.currentTrack()              -- nil | the active music Sound
--
-- This module is **client-side**. UI sounds use `SoundService:PlayLocalSound`
-- which is local-only by design — calling it from the server errors. Music is
-- played by parenting looping Sounds to SoundService on the client, so each
-- player drives their own tracks independently of the server. If you ever
-- need server-broadcast audio (a global event jingle), use a normal Sound
-- parented to Workspace and replicated through ByteNet, not this module.
--
-- Note: Roblox does not play audio inside Studio plugins (UI Labs runs as a
-- plugin), so the Audio story's playback buttons are silent in-edit. Audition
-- the registry by Play-testing the game, not from UI Labs.

local ContentProvider = game:GetService("ContentProvider")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

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
	soundtrack = "rbxassetid://1845756489",
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
	"soundtrack" | "fastMusic" | "phonk" | "phonk2" | "xmas" | "lobby" | "lobby2" | "lobby3"

export type MusicOptions = {
	transitionTime: number?,
	resume: boolean?,
}

local DEFAULT_UI_VOLUME = 1
local DEFAULT_MUSIC_VOLUME = 0.2
local DEFAULT_MUSIC_TRANSITION_TIME = 0

-- Keep one source per asset under SoundService. ContentProvider warms these exact
-- instances at client boot, and PlayLocalSound makes an independent local voice
-- from the retained source so rapid cues can overlap without restarting it.
local oneShotSources: { [string]: Sound } = {}
local preloadingSources: { [Sound]: boolean } = {}

local function resolveOneShot(id: string): Sound
	local existing = oneShotSources[id]
	if existing then
		return existing
	end

	local sound = Instance.new("Sound")
	sound.Name = `SFX_{string.gsub(id, "%D", "")}`
	sound.SoundId = id
	sound.Volume = DEFAULT_UI_VOLUME
	sound.Parent = SoundService
	oneShotSources[id] = sound
	return sound
end

local function preloadSources(sources: { Sound })
	local pending = {}
	for _, sound in sources do
		if sound.IsLoaded or preloadingSources[sound] then
			continue
		end
		preloadingSources[sound] = true
		table.insert(pending, sound)
	end
	if #pending == 0 then
		return
	end

	task.spawn(function()
		local ok, err = pcall(function()
			ContentProvider:PreloadAsync(pending)
		end)
		for _, sound in pending do
			preloadingSources[sound] = nil
		end
		if not ok then
			warn(`[audio] one-shot preload failed: {err}`)
		end
	end)
end

-- Start warming every registered UI cue. This is deliberately non-blocking so a
-- slow or unavailable audio asset cannot hold up the rest of client startup.
function Audio.prepare()
	local sources = {}
	for _, id in Audio.UI do
		table.insert(sources, resolveOneShot(id))
	end
	preloadSources(sources)
end

-- Feature-owned raw IDs are not known to prepare(). Call this during that
-- feature's startup/presentation load, before the event that needs the cue.
function Audio.prepareSoundId(id: string)
	preloadSources({ resolveOneShot(id) })
end

local function playOneShot(id: string, volume: number?): boolean
	local sound = resolveOneShot(id)
	if not sound.IsLoaded then
		-- Asking Roblox to play an unloaded Sound queues it, which makes a hover or
		-- impact cue arrive after its visual. Warm it for next time and skip this
		-- stale occurrence instead.
		preloadSources({ sound })
		return false
	end

	sound.Volume = math.clamp(volume or DEFAULT_UI_VOLUME, 0, 10)
	SoundService:PlayLocalSound(sound)
	return true
end

-- One-shot UI sound. Plays via SoundService (no 3D position). Returns false for
-- an unknown key or when the cue is not loaded yet; unloaded cues are never
-- queued to play late.
function Audio.playUI(name: string, volume: number?): boolean
	local id = Audio.UI[name]
	if not id then
		warn(`[audio] unknown UI sound "{name}"`)
		return false
	end
	return playOneShot(id, volume)
end

-- Play an arbitrary one-shot by rbxassetid. Use this for sounds outside the
-- registry (e.g. user-uploaded picks, asset-id from data). Prefer `playUI` for
-- anything that's stable enough to live in the registry.
function Audio.playSoundId(id: string, volume: number?): boolean
	return playOneShot(id, volume)
end

local currentMusic: Sound? = nil
local currentMusicKey: string? = nil
local musicTracks: { [string]: Sound } = {}
local musicTweens: { [Sound]: Tween } = {}

local function cancelMusicTween(sound: Sound)
	local tween = musicTweens[sound]
	if not tween then
		return
	end
	musicTweens[sound] = nil
	tween:Cancel()
end

local function fadeMusic(sound: Sound, volume: number, transitionTime: number, onComplete: (() -> ())?)
	cancelMusicTween(sound)
	if transitionTime <= 0 then
		sound.Volume = volume
		if onComplete then
			onComplete()
		end
		return
	end

	local tween = TweenService:Create(
		sound,
		TweenInfo.new(transitionTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Volume = volume }
	)
	musicTweens[sound] = tween
	tween.Completed:Once(function(playbackState)
		if musicTweens[sound] ~= tween then
			return
		end
		musicTweens[sound] = nil
		if playbackState == Enum.PlaybackState.Completed and onComplete then
			onComplete()
		end
	end)
	tween:Play()
end

local function resolveMusic(name: string, id: string): Sound
	local existing = musicTracks[name]
	if existing then
		return existing
	end

	local sound = Instance.new("Sound")
	sound.Name = `Music_{name}`
	sound.SoundId = id
	sound.Volume = 0
	sound.Looped = true
	sound.Parent = SoundService
	musicTracks[name] = sound
	return sound
end

-- Swap looping background music. With a transition, the outgoing track fades
-- to silence and pauses while the incoming track fades in. Cached tracks can
-- resume from their saved TimePosition; pass resume = false for a temporary
-- track that should restart each time it becomes active.
function Audio.playMusic(name: string, volume: number?, options: MusicOptions?): Sound?
	local id = Audio.Music[name]
	if not id then
		warn(`[audio] unknown music track "{name}"`)
		return nil
	end

	local targetVolume = volume or DEFAULT_MUSIC_VOLUME
	local transitionTime = if options and options.transitionTime
		then math.max(0, options.transitionTime)
		else DEFAULT_MUSIC_TRANSITION_TIME
	local shouldResume = options == nil or options.resume ~= false

	if currentMusic and currentMusicKey == name then
		fadeMusic(currentMusic, targetVolume, transitionTime)
		return currentMusic
	end

	local previousMusic = currentMusic
	local nextMusic = resolveMusic(name, id)
	currentMusic = nextMusic
	currentMusicKey = name

	if previousMusic then
		fadeMusic(previousMusic, 0, transitionTime, function()
			if currentMusic ~= previousMusic then
				previousMusic:Pause()
			end
		end)
	end

	cancelMusicTween(nextMusic)
	if not shouldResume then
		nextMusic.TimePosition = 0
	end
	if nextMusic.Playing then
		-- A quick switch can return to a track before its fade-out finishes.
	elseif shouldResume and nextMusic.TimePosition > 0 then
		nextMusic:Resume()
	else
		nextMusic:Play()
	end
	fadeMusic(nextMusic, targetVolume, transitionTime)
	return nextMusic
end

function Audio.stopMusic(transitionTime: number?)
	local previousMusic = currentMusic
	if not previousMusic then
		return
	end

	currentMusic = nil
	currentMusicKey = nil
	fadeMusic(previousMusic, 0, math.max(0, transitionTime or DEFAULT_MUSIC_TRANSITION_TIME), function()
		if currentMusic ~= previousMusic then
			previousMusic:Pause()
		end
	end)
end

function Audio.currentTrack(): Sound?
	return currentMusic
end

function Audio.currentTrackName(): string?
	return currentMusicKey
end

return Audio
