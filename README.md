# Fideliair

Fideliair is a modern, lightweight music player for macOS, designed with a focus on aesthetics and essential features. It offers a seamless experience with your local music library.

## Features

- **Local Library Integration**: Automatically scans and loads tracks from your Music folder.
- **Modern UI**: Clean, Apple Music-inspired interface with blurry album art backgrounds.
- **Lyrics Support**: Synchronized lyrics display with smooth scrolling (Apple Music style).
- **Queue Management**: "Up Next" queue visualization and management.
- **Playlists**: Create and manage local playlists.
- **Gapless Playback**: Seamless transition between tracks.
- **Now Playing View**: Full-screen capable Now Playing overlay with toggleable lyrics/queue.
- **Media Controls**: Supports standard macOS media keys (Play/Pause, Next, Previous).

## Requirements

- macOS 14.0 or later

## Building from Source

Fideliair is built using Swift Package Manager.

1. Clone the repository.
2. Navigate to the project directory.
3. Build the project in release mode:

```bash
swift build -c release
```

4. The compiled application will be located in `.build/arm64-apple-macosx/release/Fideliair`.
   (You may need to move it to `Fideliair.app` structure manually or use the produced executable)

To run easily during development:

```bash
swift run
```

## Structure

- `Fideliair/`: Main source code directory.
  - `App.swift`: Application entry point.
  - `Views/`: SwiftUI views.
  - `Managers/`: Logic managers (Audio, Library, Playlist, Lyrics).
  - `Models/`: Data models.
  - `Resources/`: Assets (Icons, etc).

## License

This project is for educational and personal use.
