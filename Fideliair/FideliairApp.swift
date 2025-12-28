import SwiftUI

@main
struct FideliairApp: App {
    @StateObject private var audioPlayer = AudioPlayerManager()
    @StateObject private var libraryManager = LibraryManager()
    @StateObject private var playlistManager = PlaylistManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(audioPlayer)
                .environmentObject(libraryManager)
                .environmentObject(playlistManager)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1200, height: 800)
        .commands {
            // Media key commands
            CommandGroup(replacing: .newItem) { }
            CommandMenu("Playback") {
                Button("Play/Pause") {
                    audioPlayer.togglePlayPause()
                }
                .keyboardShortcut(.space, modifiers: [])
                
                Button("Next Track") {
                    audioPlayer.nextTrack()
                }
                .keyboardShortcut(.rightArrow, modifiers: .command)
                
                Button("Previous Track") {
                    audioPlayer.previousTrack()
                }
                .keyboardShortcut(.leftArrow, modifiers: .command)
            }
        }
    }
}
