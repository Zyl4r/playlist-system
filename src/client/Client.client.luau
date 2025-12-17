local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local PlaylistController = require(ReplicatedStorage.PlaylistController)

local templatesFolder = ReplicatedStorage.Templates
local playlistGui = script.Parent
local mainFrame = playlistGui.Main
local queue = playlistGui.Queue
local playlistControls = mainFrame.PlaylistControls
local songInfo = mainFrame.SongInfo
local miscControls = mainFrame.MiscControls
local newPlaylist: PlaylistController.Playlist =
	PlaylistController.new(ReplicatedStorage.Songs:GetChildren(), "Cool Playlist!")
local isDraggingSlider = false
local isHoveringSlider = false
local isShowingQueue = false
local currentHoveredSlider
local newTimePosition
local newVolume

queue.NextFrom.Header.Text = "Next from: " .. newPlaylist.Name

local function handleSlider(sliderParentName: string, ...: any)
	local values = { ... }

	if sliderParentName == "SongTime" then
		newTimePosition = values[1] * values[2]
	else
		newVolume = values[1]
	end
end

local function refreshQueue()
	local currentQueuePlaying = queue.CurrentPlaying.Song_1
	local playlistQueue = newPlaylist:GetQueue()
	local currentSong = newPlaylist.CurrentSong

	currentQueuePlaying.SongImage.Image = currentSong:GetAttribute("SongImage")
		or "rbxasset://textures/ui/GuiImagePlaceholder.png"
	currentQueuePlaying.Labels.SongArtist.Text = currentSong:GetAttribute("Artist") or "Not specified"
	currentQueuePlaying.Labels.SongName.Text = currentSong.Name

	for i, frame: Frame in ipairs(queue.NextFrom:GetChildren()) do
		if not frame:IsA("Frame") then
			continue
		end

		frame:Destroy()
	end

	for i, song: Sound in ipairs(playlistQueue) do
		if i == 1 then
			continue
		end

		local newSongFrame = templatesFolder.SongInfo:Clone()
		newSongFrame.Name = "Song_" .. i
		newSongFrame.SongImage.Image = song:GetAttribute("SongImage")
			or "rbxasset://textures/ui/GuiImagePlaceholder.png"
		newSongFrame.Labels.SongArtist.Text = song:GetAttribute("Artist") or "Not specified"
		newSongFrame.Labels.SongName.Text = song.Name
		newSongFrame.Parent = queue.NextFrom
	end
end

playlistControls.Buttons.Pause.MouseButton1Click:Connect(function()
	if newPlaylist.IsPaused == false then
		newPlaylist:Pause()
		playlistControls.Buttons.Pause.Image = "http://www.roblox.com/asset/?id=6026663705"
	else
		newPlaylist:Resume()
		playlistControls.Buttons.Pause.Image = "http://www.roblox.com/asset/?id=6026663718"
	end
end)

playlistControls.Buttons.Loop.MouseButton1Click:Connect(function()
	if newPlaylist.Loop == "Playlist" then
		newPlaylist:SetLoopMode("Song")
		playlistControls.Buttons.Loop.Image = "http://www.roblox.com/asset/?id=6026681590"
	elseif newPlaylist.Loop == "Song" then
		newPlaylist:SetLoopMode("None")
		playlistControls.Buttons.Loop.Image = "http://www.roblox.com/asset/?id=6026666998"
		playlistControls.Buttons.Loop.ImageColor3 = Color3.fromRGB(255, 255, 255)
	else
		newPlaylist:SetLoopMode("Playlist")
		playlistControls.Buttons.Loop.ImageColor3 = Color3.fromRGB(0, 222, 81)
	end
end)

playlistControls.Buttons.Next.MouseButton1Click:Connect(function()
	newPlaylist:Next()
end)

playlistControls.Buttons.Previous.MouseButton1Click:Connect(function()
	newPlaylist:Previous()
end)

playlistControls.Buttons.Shuffle.MouseButton1Click:Connect(function()
	newPlaylist.ShuffleOnLoop = not newPlaylist.ShuffleOnLoop

	if newPlaylist.IsShuffled == false then
		playlistControls.Buttons.Shuffle.ImageColor3 = Color3.fromRGB(0, 222, 81)
		newPlaylist:Shuffle()
	else
		playlistControls.Buttons.Shuffle.ImageColor3 = Color3.fromRGB(255, 255, 255)
		newPlaylist:Unshuffle()
	end

	refreshQueue()
end)

playlistControls.Buttons.Shuffle.MouseEnter:Connect(function()
	playlistControls.Buttons.Shuffle.Size = UDim2.fromOffset(26, 26)

	if newPlaylist.IsShuffled == false then
		playlistControls.Buttons.Shuffle.ImageColor3 = Color3.fromRGB(255, 255, 255)
	end
end)

playlistControls.Buttons.Shuffle.MouseLeave:Connect(function()
	playlistControls.Buttons.Shuffle.Size = UDim2.fromOffset(24, 24)

	if newPlaylist.IsShuffled == false then
		playlistControls.Buttons.Shuffle.ImageColor3 = Color3.fromRGB(202, 202, 202)
	end
end)

playlistControls.Buttons.Loop.MouseEnter:Connect(function()
	playlistControls.Buttons.Loop.Size = UDim2.fromOffset(26, 26)

	if newPlaylist.Loop == "None" then
		playlistControls.Buttons.Loop.ImageColor3 = Color3.fromRGB(255, 255, 255)
	end
end)

playlistControls.Buttons.Loop.MouseLeave:Connect(function()
	playlistControls.Buttons.Loop.Size = UDim2.fromOffset(24, 24)

	if newPlaylist.Loop == "None" then
		playlistControls.Buttons.Loop.ImageColor3 = Color3.fromRGB(202, 202, 202)
	end
end)

playlistControls.Buttons.Next.MouseEnter:Connect(function()
	playlistControls.Buttons.Next.Size = UDim2.fromOffset(26, 26)
	playlistControls.Buttons.Next.ImageColor3 = Color3.fromRGB(255, 255, 255)
end)

playlistControls.Buttons.Next.MouseLeave:Connect(function()
	playlistControls.Buttons.Next.Size = UDim2.fromOffset(24, 24)
	playlistControls.Buttons.Next.ImageColor3 = Color3.fromRGB(202, 202, 202)
end)

playlistControls.Buttons.Previous.MouseEnter:Connect(function()
	playlistControls.Buttons.Previous.Size = UDim2.fromOffset(26, 26)
	playlistControls.Buttons.Previous.ImageColor3 = Color3.fromRGB(255, 255, 255)
end)

playlistControls.Buttons.Previous.MouseLeave:Connect(function()
	playlistControls.Buttons.Previous.Size = UDim2.fromOffset(24, 24)
	playlistControls.Buttons.Previous.ImageColor3 = Color3.fromRGB(202, 202, 202)
end)

playlistControls.Buttons.Pause.MouseEnter:Connect(function()
	playlistControls.Buttons.Pause.Size = UDim2.fromOffset(34, 34)
end)

playlistControls.Buttons.Pause.MouseLeave:Connect(function()
	playlistControls.Buttons.Pause.Size = UDim2.fromOffset(32, 32)
end)

playlistControls.SongTime.Slider.HoverArea.MouseEnter:Connect(function()
	isHoveringSlider = true
	currentHoveredSlider = playlistControls.SongTime.Slider
end)

playlistControls.SongTime.Slider.HoverArea.MouseLeave:Connect(function()
	isHoveringSlider = false
end)

playlistControls.SongTime.Slider.HoverArea.InputBegan:Connect(function(input: InputObject)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		isDraggingSlider = true
	end
end)

playlistControls.SongTime.Slider.HoverArea.InputEnded:Connect(function(input: InputObject)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		isDraggingSlider = false
	end
end)

miscControls.VolumeControl.Slider.HoverArea.InputBegan:Connect(function(input: InputObject)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		isDraggingSlider = true
	end
end)

miscControls.VolumeControl.Slider.HoverArea.InputEnded:Connect(function(input: InputObject)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		isDraggingSlider = false
	end
end)

miscControls.ShowQueue.MouseButton1Click:Connect(function()
	queue.Visible = not queue.Visible
	isShowingQueue = queue.Visible

	if isShowingQueue then
		miscControls.ShowQueue.ImageColor3 = Color3.fromRGB(0, 222, 81)
	else
		miscControls.ShowQueue.ImageColor3 = Color3.fromRGB(255, 255, 255)
	end
end)

miscControls.VolumeControl.Slider.HoverArea.MouseEnter:Connect(function()
	isHoveringSlider = true
	currentHoveredSlider = miscControls.VolumeControl.Slider
end)

miscControls.VolumeControl.Slider.HoverArea.MouseLeave:Connect(function()
	isHoveringSlider = false
end)

miscControls.VolumeControl.Slider.HoverArea.MouseEnter:Connect(function()
	isHoveringSlider = true
	currentHoveredSlider = miscControls.VolumeControl.Slider
end)

miscControls.VolumeControl.Slider.HoverArea.MouseLeave:Connect(function()
	isHoveringSlider = false
end)

miscControls.ShowQueue.MouseEnter:Connect(function()
	miscControls.ShowQueue.Size = UDim2.fromOffset(26, 26)

	if isShowingQueue then
		return
	end

	miscControls.ShowQueue.ImageColor3 = Color3.fromRGB(255, 255, 255)
end)

miscControls.ShowQueue.MouseLeave:Connect(function()
	miscControls.ShowQueue.Size = UDim2.fromOffset(24, 24)

	if isShowingQueue then
		return
	end

	miscControls.ShowQueue.ImageColor3 = Color3.fromRGB(202, 202, 202)
end)

RunService.RenderStepped:Connect(function(_: number)
	local currentSong = newPlaylist.CurrentSong

	if not currentSong then
		return
	end

	local currentSongTime = currentSong.TimePosition
	local currentSongLength = currentSong.TimeLength
	local currentSongPercentage = currentSongTime / currentSongLength
	local songTimeElapsed = math.floor(currentSong.TimePosition)
	local songTimeLeft = math.floor(currentSong.TimeLength - songTimeElapsed)

	local elapsedMinutes, elapsedSeconds = PlaylistController.SecondsToMinute(songTimeElapsed)
	local minutesLeft, secondsLeft = PlaylistController.SecondsToMinute(songTimeLeft)

	if isDraggingSlider then
		local mousePosition = UserInputService:GetMouseLocation()
		local newSliderPosition = (mousePosition.X - currentHoveredSlider.AbsolutePosition.X)
			/ currentHoveredSlider.AbsoluteSize.X
		local positionPercentage = math.clamp(newSliderPosition, 0, 1)

		handleSlider(currentHoveredSlider.Parent.Name, positionPercentage, currentSongLength)

		currentHoveredSlider.PositionCircle.Visible = true
		currentHoveredSlider.Fill.BackgroundColor3 = Color3.fromRGB(0, 222, 81)
		currentHoveredSlider.PositionCircle.Position =
			UDim2.fromScale(positionPercentage, playlistControls.SongTime.Slider.PositionCircle.Position.Y.Scale)

		if newVolume then
			newPlaylist:SetVolume(newVolume)
			newVolume = nil
		end
	else
		playlistControls.SongTime.TimeElapsed.Text = string.format("%02i:%02i", elapsedMinutes, elapsedSeconds)
		playlistControls.SongTime.TimeLeft.Text = string.format("-%02i:%02i", minutesLeft, secondsLeft)

		if isHoveringSlider then
			currentHoveredSlider.PositionCircle.Visible = true
			currentHoveredSlider.Fill.BackgroundColor3 = Color3.fromRGB(0, 222, 81)
		elseif not isHoveringSlider and currentHoveredSlider then
			currentHoveredSlider.PositionCircle.Visible = false
			currentHoveredSlider.Fill.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
			currentHoveredSlider = nil
		end

		if newTimePosition then
			newPlaylist:ChangeTimePosition(newTimePosition)
			newTimePosition = nil
		else
			playlistControls.SongTime.Slider.PositionCircle.Position = UDim2.fromScale(currentSongPercentage, 0.5)
		end
	end

	playlistControls.SongTime.Slider.Fill.Size =
		UDim2.fromScale(playlistControls.SongTime.Slider.PositionCircle.Position.X.Scale, 1)
	miscControls.VolumeControl.Slider.Fill.Size =
		UDim2.fromScale(miscControls.VolumeControl.Slider.PositionCircle.Position.X.Scale, 1)
end)

newPlaylist.SongStarted:Connect(function(song: Sound)
	songInfo.Labels.SongName.Text = song.Name
	songInfo.Labels.SongArtist.Text = song:GetAttribute("Artist") or "Not specified"
	songInfo.SongImage.Image = song:GetAttribute("SongImage") or "rbxasset://textures/ui/GuiImagePlaceholder.png"

	refreshQueue()
end)

newPlaylist.SongEnded:Connect(function(_: Sound)
	newPlaylist:Next()
end)

newPlaylist.LoopModeChanged:Connect(function(newLoopMode: PlaylistController.LoopModes)
	if newLoopMode == "None" then
		return
	end

	if not newPlaylist.CurrentSong then
		newPlaylist:Next()
		return
	end

	local isLastSong = newPlaylist.CurrentIndex == #newPlaylist.Playlist

	if not isLastSong then
		return
	end

	if newPlaylist.CurrentSong.TimePosition >= newPlaylist.CurrentSong.TimeLength then
		newPlaylist:Next()
	end
end)

newPlaylist:Play()
