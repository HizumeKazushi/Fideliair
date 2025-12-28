import SwiftUI

struct ContentView: View {
    @EnvironmentObject var audioPlayer: AudioPlayerManager
    @EnvironmentObject var libraryManager: LibraryManager
    @EnvironmentObject var playlistManager: PlaylistManager
    @State private var selectedSidebarItem: SidebarItem = .library
    @State private var showingLyrics = false
    @State private var showNowPlayingFull = false
    
    var body: some View {
        ZStack {
            // Dynamic background from album art
            AlbumArtBackground(artwork: audioPlayer.currentTrack?.artwork)
            
            // Main content
            HStack(spacing: 0) {
                // Sidebar
                SidebarView(selectedItem: $selectedSidebarItem)
                    .frame(width: 220)
                
                // Main content area
                VStack(spacing: 0) {
                    // Content based on selection
                    switch selectedSidebarItem {
                    case .library:
                        LibraryView()
                    case .playlists:
                        PlaylistsView()
                    case .googleDrive:
                        GoogleDriveView()
                    }
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            }
            
            // Now Playing bar (floating at bottom)
            if !showNowPlayingFull {
                VStack {
                    Spacer()
                    NowPlayingBar(showingLyrics: $showingLyrics, onArtworkTap: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.85, blendDuration: 0)) {
                            showNowPlayingFull = true
                        }
                    })
                        .padding(.horizontal, 20)
                        .padding(.bottom, 16)
                }
            }
            
            // Fullscreen lyrics overlay (old style)
            if showingLyrics && !showNowPlayingFull {
                LyricsOverlay(isShowing: $showingLyrics)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }
            
            if showNowPlayingFull {
                NowPlayingFullView(isShowing: $showNowPlayingFull)
                    .environmentObject(audioPlayer)
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .move(edge: .bottom).combined(with: .opacity)
                    ))
                    .zIndex(100)
            }
        }
        .ignoresSafeArea()
        .onChange(of: audioPlayer.currentTrack?.id) { oldValue, newValue in
            // Auto-show Now Playing when a new track starts
            if newValue != nil && oldValue != newValue {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85, blendDuration: 0)) {
                    showNowPlayingFull = true
                }
            }
        }
    }
}

enum SidebarItem: String, CaseIterable {
    case library = "Library"
    case playlists = "Playlists"
    case googleDrive = "Google Drive"
    
    var icon: String {
        switch self {
        case .library: return "music.note.house"
        case .playlists: return "music.note.list"
        case .googleDrive: return "cloud"
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AudioPlayerManager())
        .environmentObject(LibraryManager())
}
