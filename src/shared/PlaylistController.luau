--[[

@ZyTheCore

-[PlaylistController]----------------------------------------------------

    Playlist controller

    WARNING: PlaylistController is supposed to be used on the client.

    Functions:
        PlaylistController.SecondsToMinute(seconds: number): number
        PlaylistController.new(songs: { Sound }, playlistName: string): Playlist

    Members [Playlist]:
        Playlist.Name:           string
        Playlist.Playlist:       { Sound }
        Playlist.CurrentSong:    Sound
        Playlist.IsActive:       boolean
        Playlist.IsPaused:       boolean
        Playlist.IsShuffled:     boolean
        Playlist.TotalTime:      number
        Playlist.Loop:           LoopModes
        Playlist.SongIndex:      number
        Playlist.ShuffleOnLoop:  boolean
        Playlist.Volume:         number

    Methods [Playlist]:
        Playlist:GetQueue(): { Sound }
        Playlist:Play(songIndex?: number): ()
        Playlist:Stop(): ()
        Playlist:Pause(): ()
        Playlist:Resume(): ()
        Playlist:Next(): ()
        Playlist:Previous(): ()
        Playlist:Shuffle(onLoop: boolean): ()
        Playlist:Unshuffle(): ()
        Playlist:SwapSongPosition(i: number, j: number): ()
        Playlist:AddSong(song: Sound, index?: number): number
        Playlist:RemoveSong(index: number): Sound
        Playlist:ChangeTimePosition(to: number): ()
        Playlist:SetLoopMode(newMode: LoopModes): ()
        Playlist:SetVolume(newVolume: number): ()
        Playlist:Destroy(): ()

    Events [Playlist]:
        Playlist.SongStarted: (song: Sound)
        Playlist.SongEnded: (song: Sound)
        Playlist.SongPaused: ()
        Playlist.SongResumed: ()
        Playlist.SongStopped: ()
        Playlist.PlaylistLooped: ()
        Playlist.SongLooped: ()
        Playlist.PlaylistDestroyed: ()
		Playlist.LoopModeChanged: (newLoopMode: string)
]]

-- Services
local RunService = game:GetService("RunService")

-- Lightweight signal implementation
local Signal = require(script.Signal)

-- Standardized debug message format
local DEBUG_MESSAGE_FORMAT = `[{script.Name}]: %s`

-- Type definitions

-- Available loop modes for the playlist
-- None: Stops at the end of the playlist
-- Song: Repeats the current song indefinitely
-- Playlist: Loops the entire playlist from the beginning
export type LoopModes = "None" | "Song" | "Playlist"

-- Public Playlist interface
-- Describes all exposed properties, methods, and events of a Playlist instance
export type Playlist = {
	-- Metadata (descriptive, UI-facing)
	Name: string,
	Playlist: { Sound },

	-- Playback state
	CurrentSong: Sound?,
	IsActive: boolean,
	IsPaused: boolean,
	IsShuffled: boolean,
	TotalTime: number,
	Loop: LoopModes,
	SongIndex: number,
	ShuffleOnLoop: boolean,
	Volume: number,

	-- Public methods
	GetQueue: (self: Playlist) -> { Sound },
	Play: (self: Playlist) -> (),
	Stop: (self: Playlist) -> (),
	Pause: (self: Playlist) -> (),
	Resume: (self: Playlist) -> (),
	Next: (self: Playlist) -> (),
	Previous: (self: Playlist) -> (),
	Shuffle: (self: Playlist, onLoop: boolean) -> (),
	Unshuffle: (self: Playlist) -> (),
	SwapSongPosition: (self: Playlist, i: number, j: number) -> (),
	AddSong: (self: Playlist, song: Sound, index: number?) -> number,
	RemoveSong: (self: Playlist, index: number) -> Sound,
	ChangeTimePosition: (self: Playlist, to: number) -> (),
	SetLoopMode: (self: Playlist, newMode: LoopModes) -> (),
	SetVolume: (self: Playlist, newVolume: number) -> (),
	Destroy: (self: Playlist) -> (),

	-- Signals (events)
	SongStarted: typeof(Signal()),
	SongEnded: typeof(Signal()),
	SongPaused: typeof(Signal()),
	SongResumed: typeof(Signal()),
	SongStopped: typeof(Signal()),
	PlaylistLooped: typeof(Signal()),
	SongLooped: typeof(Signal()),
	PlaylistDestroyed: typeof(Signal()),
	LoopModeChanged: typeof(Signal()),
}

-- Since this module is intended for client use, warn if required on server
if RunService:IsServer() then
	warn(`[{script.Name}]: This module might not work correctly on server.`)
end

local PlaylistController = {}
PlaylistController.__index = PlaylistController

-- Utility: converts seconds into minutes and remaining seconds
function PlaylistController.SecondsToMinute(seconds: number): number
	-- Minutes, Seconds
	return math.floor(seconds / 60), seconds % 60
end

-- Constructor

-- Creates and initializes a new Playlist instance
-- Sets default playback state, initializes signals, and prepares internal control variables
function PlaylistController.new(songs: { Sound }, name: string?): Playlist
	local self = {}

	-- Public playlist metadata
	self.Name = name or "New playlist"
	self.Playlist = table.clone(songs)

	-- Playback state properties
	self.CurrentSong = nil
	self.IsActive = false
	self.IsPaused = false
	self.IsShuffled = false
	self.TotalTime = 0
	self.ShuffleOnLoop = false
	self.Loop = "None"
	self.SongIndex = 1
	self.Volume = 0.5

	-- Signals exposed to consumers of the playlist
	self.SongStarted = Signal()
	self.SongEnded = Signal()
	self.SongPaused = Signal()
	self.SongResumed = Signal()
	self.SongStopped = Signal()
	self.PlaylistLooped = Signal()
	self.SongLooped = Signal()
	self.PlaylistDestroyed = Signal()
	self.LoopModeChanged = Signal()

	-- Cached total duration of the playlist
	-- Used for display purposes and external logic
	for _, song: Sound in ipairs(songs) do
		self.TotalTime += song.TimeLength
	end

	-- Internal control variables (not part of public API)
	self._connections = {} -- Active RBXScriptConnections for song events
	self._canPlay = true -- Prevent playback when reaching the end with no looping
	self._originalOrder = table.clone(songs) -- Used to restore order on unshuffle

	return setmetatable(self, PlaylistController)
end

-- Public Methods

-- Returns a shallow copy of the upcoming queue
function PlaylistController:GetQueue(): { Sound }
	local playlist = table.clone(self.Playlist)
	local songIndex = self.SongIndex

	return { unpack(playlist, songIndex) }
end

-- Starts playback of a given song index or resumes current index
function PlaylistController:Play(songIndex: number?)
	local self: Playlist = self
	local playlist = self.Playlist

	local index = songIndex or self.SongIndex

	assert(playlist[index] ~= nil, string.format(DEBUG_MESSAGE_FORMAT, `Could not find song with index: {songIndex}.`))

	-- Update state
	self.SongIndex = index
	self.CurrentSong = playlist[index]
	self.IsActive = true
	self.IsPaused = false

	--Configure and play the song
	self.CurrentSong.TimePosition = 0
	self.CurrentSong.Volume = self.Volume
	self.CurrentSong:Play()

	self.SongStarted:Fire(self.CurrentSong)

	-- Rebind ended event
	self:_disconnectEvents()
	table.insert(
		self._connections,
		self.CurrentSong.Ended:Once(function(_soundId: string)
			self.SongEnded:Fire(self.CurrentSong)
		end)
	)
end

-- Stops playback and resets active state
function PlaylistController:Stop()
	if not self.CurrentSong then
		return
	end

	self.IsActive = false
	self.IsPaused = false
	self._disconnectEvents()
	self.CurrentSong:Stop()
	self.SongStopped:Fire(self.CurrentSong)
	self.CurrentSong = nil
end

-- Shuffles the playlist (Fisher-Yates algorithm) and keeps current song at the front if playing
function PlaylistController:Shuffle(onLoop: boolean)
	local self: Playlist = self
	local playlist = self.Playlist

	-- Fisher-Yates shuffle
	for i = #playlist, 2, -1 do
		local j = math.random(i)
		playlist[i], playlist[j] = playlist[j], playlist[i]
	end

	-- Keep current song at the front
	if self.CurrentSong then
		local currentSongIndex = table.find(playlist, self.CurrentSong)

		table.remove(playlist, currentSongIndex)
		table.insert(playlist, 1, self.CurrentSong)
	end

	if not onLoop then
		self.SongIndex = 1
	end

	self.IsShuffled = true
end

-- Restores the original order of the playlist
function PlaylistController:Unshuffle()
	local self: Playlist = self
	local playlist = self.Playlist

	table.clear(playlist)

	for _, song: Sound in ipairs(self._originalOrder) do
		table.insert(playlist, song)
	end

	local currentSongIndex

	if self.CurrentSong then
		currentSongIndex = table.find(playlist, self.CurrentSong)
	end

	self.SongIndex = currentSongIndex or 1
	self.IsShuffled = false
end

-- Plays the next song in the playlist
function PlaylistController:Next()
	local self: Playlist = self

	-- Stop current song if playing
	if self.CurrentSong then
		self.CurrentSong:Stop()
		self.CurrentSong = nil
	end

	self:_handleLooping()

	if self._canPlay == false then
		return
	end

	self.SongIndex += 1

	self:Play()
end

-- Plays the previous song in the playlist or restarts current if past 3 seconds
function PlaylistController:Previous()
	local self: Playlist = self
	local playlist = self.Playlist

	-- Restarts playback if past 3 seconds
	if self.CurrentSong then
		if self.CurrentSong.TimePosition < 3 then
			self.CurrentSong:Stop()
			self.CurrentSong = nil
		else
			self:ChangeTimePosition(0)
			return
		end
	end

	-- If at the first song, loop to last song
	if self.SongIndex - 1 <= 0 then
		self.SongIndex = #playlist + 1
	end

	self.SongIndex -= 1

	self:Play()
end

-- Pauses the playback
function PlaylistController:Pause()
	if not self.CurrentSong then
		return
	end

	self.IsPaused = true
	self.CurrentSong:Pause()
	self.SongPaused:Fire()
end

-- Resumes the playback
function PlaylistController:Resume()
	if not self.CurrentSong then
		return
	end

	self.IsPaused = false
	self.CurrentSong:Resume()
	self.SongResumed:Fire()
end

-- swaps the position of two songs in the playlist
function PlaylistController:SwapSongPosition(i: number, j: number)
	local playlist = self.Playlist

	if not playlist[i] then
		return
	end

	if not playlist[j] then
		return
	end

	playlist[i], playlist[j] = playlist[j], playlist[i]

	self.SongIndex = table.find(playlist, self.CurrentSong)
end

-- Adds a song to the playlist at an optional index
function PlaylistController:AddSong(song: Sound, index: number?): number
	local playlist = self.Playlist

	assert(
		song:IsA("Sound"),
		string.format(DEBUG_MESSAGE_FORMAT, `Attempt to add a non-sound instance ({typeof(song)}) to the playlist.`)
	)

	if index then
		table.insert(playlist, index, song)
	else
		table.insert(playlist, song)
	end

	return table.find(playlist, song)
end

-- Removes a song from the playlist at the given index
function PlaylistController:RemoveSong(index): Sound
	local self: Playlist = self
	local playlist = self.Playlist

	assert(playlist[index] ~= nil, string.format(DEBUG_MESSAGE_FORMAT, `Could not find song with index: {index}.`))

	local removedSong = playlist[index]
	local wasPlaying = self.IsActive and not self.IsPaused

	table.remove(playlist, index)

	if wasPlaying then
		self:Play()
	end

	return removedSong
end

-- Sets the playback position of the current song
function PlaylistController:ChangeTimePosition(to: number)
	assert(
		typeof(to) == "number",
		string.format(DEBUG_MESSAGE_FORMAT, `Attempt to cast {typeof(to)} to number property.`)
	)

	to = math.clamp(to, 0, self.CurrentSong.TimeLength)
	self.CurrentSong.TimePosition = to
end

-- Sets the loop mode of the playlist
function PlaylistController:SetLoopMode(newMode: LoopModes)
	local self: Playlist = self

	if newMode ~= "None" and self._canPlay == false then
		self._canPlay = true
	end

	self.Loop = newMode
	self.LoopModeChanged:Fire(newMode)
end

-- Sets the volume of the current song
function PlaylistController:SetVolume(newVolume: number)
	local self: Playlist = self

	if not self.CurrentSong then
		return
	end

	newVolume = math.clamp(newVolume, 0, 1)

	self.Volume = newVolume
	self.CurrentSong.Volume = newVolume
end

-- Destroys the playlist and cleans up events
function PlaylistController:Destroy()
	local self: Playlist = self

	if self.CurrentSong then
		self.CurrentSong:Stop()
	end

	self.PlaylistDestroyed:Fire()
	self:_disconnectEvents()

	table.clear(self)

	setmetatable(self, nil)
end

-- Internal: handles playlist looping music
function PlaylistController:_handleLooping()
	local self: Playlist = self
	local isLastSong = self.SongIndex >= #self.Playlist

	if self.Loop == "None" and isLastSong then
		self._canPlay = false
		print(string.format(DEBUG_MESSAGE_FORMAT, "No more songs to play!"))
		return
	end

    -- If at the end of the playlist and looping is enabled, reset to start
	if isLastSong and self.Loop == "Playlist" then
		self.SongIndex = 0
		self.PlaylistLooped:Fire()

        -- Reshuffle if set to do so
		if self.ShuffleOnLoop then
			self:Shuffle(true)
		end
	end

    -- Repeat the current song if song looping is enabled
	if self.Loop == "Song" then
		self.SongLooped:Fire()
		self.SongIndex -= 1
	end
end

-- Internal: disconnects all song-related events
function PlaylistController:_disconnectEvents()
	for _, v: RBXScriptConnection in ipairs(self._connections) do
		v:Disconnect()
	end

	table.clear(self._connections)
end

return PlaylistController
