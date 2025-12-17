# 🎵 Playlist System (Roblox)

A **modular, event-driven playlist system** written in **Luau**, designed for Roblox experiences that need full control over music playback — like a Spotify-style player inside your game 🎧

> ⚠️ **Warning:** `PlaylistController` is intended to be used **on the client**.

---

## 🚀 Features

* ▶️ Play / Pause / Resume / Stop
* ⏭️ Next / Previous
* 🔁 Loop modes:

  * `None` – no looping
  * `Song` – repeat current song
  * `Playlist` – loop the entire playlist
* 🔀 Shuffle (with optional shuffle on playlist loop)
* 🎚️ Volume control
* ⏱️ Change song time position (seek)
* 📃 Dynamic queue system
* 📡 Event-based architecture (perfect for UI integration)
* 🧩 Fully modular and strongly typed

---

## 🧠 Core Concept

The core of this project is the **`PlaylistController`**, responsible for:

* Managing `Sound` objects
* Handling playback state (playing, paused, loop, shuffle)
* Emitting events to keep UI and logic in sync

---

## 🛠️ Basic Usage

```lua
local PlaylistController = require(ReplicatedStorage.PlaylistController)

local playlist = PlaylistController.new(
    ReplicatedStorage.Songs:GetChildren(),
    "My Cool Playlist"
)

playlist:Play()
```

---

## 🎮 Available Events

You can easily react to playlist changes:

```lua
playlist.SongStarted:Connect(function(song)
    print("Now playing:", song.Name)
end)

playlist.SongEnded:Connect(function(song)
    print("Finished:", song.Name)
end)
```

Available events:

* `SongStarted`
* `SongEnded`
* `SongPaused`
* `SongResumed`
* `SongStopped`
* `SongLooped`
* `PlaylistLooped`
* `LoopModeChanged`
* `PlaylistDestroyed`

---

## 🧪 Example

This repository includes a **fully working UI example** demonstrating:

* Playback controls
* Song progress slider
* Volume control
* Queue visualization
* Full event-based integration

Perfect as a foundation for an **in-game music player** 🎶

---

## 🧼 Notes

* Disabling shuffle restores the original playlist order
* Events are safely disconnected when the playlist is destroyed
* Designed to be simple, predictable, and UI-friendly

---

## ✍️ Author

Created by **@ZyTheCore**
If you found this useful, feel free to leave a ⭐ — future you will appreciate it 😉
