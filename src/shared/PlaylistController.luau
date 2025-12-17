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

local RunService = game:GetService("RunService")

local Signal = require(script.Signal)

local DEBUG_MESSAGE_FORMAT = `[{script.Name}]: %s`

export type LoopModes = "None" | "Song" | "Playlist"

export type Playlist = {
	Name: string,
	Playlist: { Sound },
	CurrentSong: Sound?,
	IsActive: boolean,
	IsPaused: boolean,
	IsShuffled: boolean,
	TotalTime: number,
	Loop: LoopModes,
	SongIndex: number,
	ShuffleOnLoop: boolean,
	Volume: number,

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

if RunService:IsServer() then
	warn(`[{script.Name}]: This module might not work correctly on server.`)
end

local PlaylistController = {}
PlaylistController.__index = PlaylistController

-- Converts seconds into minutes and remaining seconds
function PlaylistController.SecondsToMinute(seconds: number): number
	return math.floor(seconds / 60), seconds % 60
end

-- Creates a new playlist
function PlaylistController.new(songs: { Sound }, name: string?): Playlist
	local self = {}
	self.Name = name or "New playlist"
	self.Playlist = table.clone(songs)
	self.CurrentSong = nil
	self.IsActive = false
	self.IsPaused = false
	self.IsShuffled = false
	self.TotalTime = 0
	self.ShuffleOnLoop = false
	self.Loop = "None"
	self.SongIndex = 1
	self.Volume = 0.5

	-- Events
	self.SongStarted = Signal()
	self.SongEnded = Signal()
	self.SongPaused = Signal()
	self.SongResumed = Signal()
	self.SongStopped = Signal()
	self.PlaylistLooped = Signal()
	self.SongLooped = Signal()
	self.PlaylistDestroyed = Signal()
	self.LoopModeChanged = Signal()

	-- Calculate total time of all songs
	for _, song: Sound in ipairs(songs) do
		self.TotalTime += song.TimeLength
	end

	self._connections = {} -- Internal connections for song events
	self._canPlay = true -- Flag to control if next song can play
	self._originalOrder = table.clone(songs)

	return setmetatable(self, PlaylistController)
end

-- Returns the queue of upcoming songs starting from the current song
function PlaylistController:GetQueue(): { Sound }
	local playlist = table.clone(self.Playlist)
	local songIndex = self.SongIndex

	return { unpack(playlist, songIndex) }
end

-- Plays a song by index or the current song
function PlaylistController:Play(songIndex: number?)
	local self: Playlist = self
	local playlist = self.Playlist

	local index = songIndex or self.SongIndex

	assert(playlist[index] ~= nil, string.format(DEBUG_MESSAGE_FORMAT, `Could not find song with index: {songIndex}.`))

	self.SongIndex = index

	local nextSong: Sound = playlist[self.SongIndex]

	self.CurrentSong = nextSong
	self.IsActive = true
	self.IsPaused = false

	nextSong.TimePosition = 0
	nextSong.Volume = self.Volume
	nextSong:Play()

	self.SongStarted:Fire(nextSong)

	self:_disconnectEvents()
	table.insert(
		self._connections,
		nextSong.Ended:Once(function(soundId: string)
			self.SongEnded:Fire(self.CurrentSong)
		end)
	)
end

-- Stops the current song
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

-- Shuffles the playlist while keeping the current song playing
function PlaylistController:Shuffle(onLoop: boolean)
	local self: Playlist = self
	local playlist = self.Playlist

	for i = #playlist, 2, -1 do
		local j = math.random(i)
		playlist[i], playlist[j] = playlist[j], playlist[i]
	end

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

-- Unshuffles the playlist and reverts it to it's original order
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

-- Plays the previous song or restarts if > 3 seconds
function PlaylistController:Previous()
	local self: Playlist = self
	local playlist = self.Playlist

	if not self.CurrentSong then
		return
	end

	if self.CurrentSong.TimePosition >= 3 then
		self:ChangeTimePosition(0)
		return
	end

	self.CurrentSong:Stop()
	self.CurrentSong = nil

	if self.SongIndex - 1 <= 0 then
		self.SongIndex = #playlist + 1
	end

	self.SongIndex -= 1

	self:Play()
end

-- Pauses the current song
function PlaylistController:Pause()
	if not self.CurrentSong then
		return
	end

	self.IsPaused = true
	self.CurrentSong:Pause()
	self.SongPaused:Fire()
end

-- Resumes the current song
function PlaylistController:Resume()
	if not self.CurrentSong then
		return
	end

	self.IsPaused = false
	self.CurrentSong:Resume()
	self.SongResumed:Fire()
end

-- Swaps two songs in the playlist by their positions
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

-- Adds a song to the playlist
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

-- Removes a song from the playlist by its position
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

	if isLastSong and self.Loop == "Playlist" then
		self.SongIndex = 0
		self.PlaylistLooped:Fire()

		if self.ShuffleOnLoop then
			self:Shuffle(true)
		end
	end

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
