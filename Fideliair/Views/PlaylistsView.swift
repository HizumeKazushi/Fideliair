import SwiftUI

/// Playlists view with persistence support
struct PlaylistsView: View {
    @EnvironmentObject var playlistManager: PlaylistManager
    @EnvironmentObject var audioPlayer: AudioPlayerManager
    @State private var showingNewPlaylist = false
    @State private var newPlaylistName = ""
    @State private var selectedPlaylist: Playlist?
    
    var body: some View {
        NavigationSplitView {
            // Playlist list
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Playlists")
                        .font(.title.bold())
                    
                    Spacer()
                    
                    Button(action: { showingNewPlaylist = true }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                    .buttonStyle(.plain)
                }
                .padding()
                .background(GlassBackground(opacity: 0.3))
                
                if playlistManager.playlists.isEmpty {
                    // Empty state
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "music.note.list")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        
                        Text("No playlists yet")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                        
                        Button("Create Playlist") {
                            showingNewPlaylist = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    Spacer()
                } else {
                    // Playlist list
                    List(selection: $selectedPlaylist) {
                        ForEach(playlistManager.playlists) { playlist in
                            PlaylistRowView(playlist: playlist)
                                .tag(playlist)
                                .contextMenu {
                                    Button("Delete", role: .destructive) {
                                        playlistManager.deletePlaylist(playlist)
                                    }
                                }
                        }
                    }
                    .listStyle(.sidebar)
                    .padding(.bottom, 100) // Space for NowPlayingBar
                }
            }
            .frame(minWidth: 250)
        } detail: {
            // Playlist detail
            if let playlist = selectedPlaylist {
                PlaylistDetailView(playlistID: playlist.id)
            } else {
                Text("Select a playlist")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
        }
        .sheet(isPresented: $showingNewPlaylist) {
            NewPlaylistSheet(
                name: $newPlaylistName,
                onCreate: {
                    _ = playlistManager.createPlaylist(name: newPlaylistName)
                    newPlaylistName = ""
                    showingNewPlaylist = false
                }
            )
        }
    }
}

/// Playlist detail view showing tracks
struct PlaylistDetailView: View {
    let playlistID: UUID
    @EnvironmentObject var playlistManager: PlaylistManager
    @EnvironmentObject var audioPlayer: AudioPlayerManager
    @EnvironmentObject var libraryManager: LibraryManager
    @State private var selectedTracks: Set<Track> = []
    
    // Search & Add
    @State private var searchText = ""
    @State private var showSearch = false
    
    // Artwork
    @State private var showFileImporter = false
    
    // Live playlist object from source of truth
    var playlist: Playlist? {
        playlistManager.playlists.first(where: { $0.id == playlistID })
    }
    
    var filteredLibraryTracks: [Track] {
        guard !searchText.isEmpty, let playlist = playlist else { return [] }
        return libraryManager.search(searchText).filter { track in
            !playlist.tracks.contains { $0.id == track.id }
        }
    }
    
    var body: some View {
        Group {
            if let playlist = playlist {
                VStack(spacing: 0) {
                    // Header
                    HStack(spacing: 20) {
                        // Artwork
                        Button(action: { showFileImporter = true }) {
                            ZStack {
                                if let artwork = playlist.artwork { // Uses custom or first track artwork
                                    Image(nsImage: artwork)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                } else {
                                    LinearGradient(
                                        colors: [.blue.opacity(0.5), .purple.opacity(0.5)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                    .overlay(
                                        Image(systemName: "music.note.list")
                                            .font(.system(size: 40))
                                            .foregroundStyle(.white.opacity(0.7))
                                    )
                                }
                                
                                // Edit overlay
                                VStack {
                                    Spacer()
                                    HStack {
                                        Spacer()
                                        Image(systemName: "pencil.circle.fill")
                                            .font(.title2)
                                            .foregroundStyle(.white)
                                            .padding(4)
                                    }
                                }
                                .padding(4)
                            }
                            .frame(width: 150, height: 150)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .shadow(radius: 5)
                        }
                        .buttonStyle(.plain)
                        .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.image]) { result in
                            if let url = try? result.get(),
                               let image = NSImage(contentsOf: url) {
                                playlistManager.setCustomArtwork(image, for: playlist)
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text(playlist.name)
                                .font(.largeTitle.bold())
                            
                            Text("\(playlist.tracks.count) songs • \(formattedDuration(playlist.duration))")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            
                            HStack(spacing: 12) {
                                Button(action: {
                                    audioPlayer.playQueue(playlist.tracks)
                                }) {
                                    Label("Play", systemImage: "play.fill")
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(playlist.tracks.isEmpty)
                                
                                Button(action: {
                                    var shuffled = playlist.tracks
                                    shuffled.shuffle()
                                    audioPlayer.playQueue(shuffled)
                                }) {
                                    Label("Shuffle", systemImage: "shuffle")
                                }
                                .buttonStyle(.bordered)
                                .disabled(playlist.tracks.isEmpty)
                            }
                        }
                        
                        Spacer()
                    }
                    .padding()
                    .background(GlassBackground(opacity: 0.3))
                    
                    // Search Bar
                    VStack(spacing: 0) {
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(.secondary)
                            TextField("Search to add songs...", text: $searchText)
                                .textFieldStyle(.plain)
                            
                            if !searchText.isEmpty {
                                Button(action: { searchText = "" }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(10)
                        .background(Color.white.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .padding(.horizontal)
                        .padding(.top, 8)
                        
                        // Search Results
                        if !searchText.isEmpty {
                            ScrollView {
                                LazyVStack(alignment: .leading, spacing: 0) {
                                    if filteredLibraryTracks.isEmpty {
                                        Text("No matching songs found in Library")
                                            .foregroundStyle(.secondary)
                                            .padding()
                                    } else {
                                        ForEach(filteredLibraryTracks) { track in
                                            HStack {
                                                // Artwork (small)
                                                if let artwork = track.artwork {
                                                    Image(nsImage: artwork)
                                                        .resizable()
                                                        .aspectRatio(contentMode: .fill)
                                                        .frame(width: 30, height: 30)
                                                        .clipShape(RoundedRectangle(cornerRadius: 4))
                                                } else {
                                                    RoundedRectangle(cornerRadius: 4)
                                                        .fill(.gray.opacity(0.3))
                                                        .frame(width: 30, height: 30)
                                                }
                                                
                                                VStack(alignment: .leading) {
                                                    Text(track.title).lineLimit(1)
                                                    Text(track.artist).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                                                }
                                                
                                                Spacer()
                                                
                                                Button(action: {
                                                    playlistManager.addTrack(track, to: playlist)
                                                    searchText = ""
                                                }) {
                                                    Image(systemName: "plus.circle.fill")
                                                        .font(.title2)
                                                        .foregroundStyle(.green)
                                                }
                                                .buttonStyle(.plain)
                                            }
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 8)
                                            .contentShape(Rectangle())
                                            .background(Color.white.opacity(0.05))
                                        }
                                    }
                                }
                            }
                            .frame(height: 200) // Limit height
                            .background(Color.black.opacity(0.4))
                            .cornerRadius(8)
                            .padding(.horizontal)
                        }
                    }
                    
                    if playlist.tracks.isEmpty && searchText.isEmpty {
                        Spacer()
                        VStack(spacing: 12) {
                            Image(systemName: "music.note")
                                .font(.system(size: 40))
                                .foregroundStyle(.secondary)
                            Text("No songs in this playlist")
                                .foregroundStyle(.secondary)
                            Text("Search above or right-click tracks in Library to add")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        Spacer()
                    } else if !searchText.isEmpty && filteredLibraryTracks.isEmpty {
                        // Empty search results, show nothing or playlist below?
                        // Just show playlist below as usual
                    }
                    
                    // Playlist Tracks List
                    List(selection: $selectedTracks) {
                        ForEach(Array(playlist.tracks.enumerated()), id: \.element.id) { index, track in
                            PlaylistTrackRow(track: track, index: index + 1)
                                .tag(track)
                                .contextMenu {
                                    Button("Play") {
                                        audioPlayer.playQueue(playlist.tracks, startingAt: index)
                                    }
                                    Divider()
                                    Button("Remove from Playlist", role: .destructive) {
                                        playlistManager.removeTrack(track, from: playlist)
                                    }
                                }
                                .onTapGesture(count: 2) {
                                    audioPlayer.playQueue(playlist.tracks, startingAt: index)
                                }
                        }
                        .onMove { source, destination in
                            playlistManager.moveTrack(in: playlist, from: source, to: destination)
                        }
                    }
                    .listStyle(.inset)
                    .padding(.bottom, 100)
                }
            } else {
                Text("Playlist not found") // Fallback
            }
        }
    }
    
    private func formattedDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        if hours > 0 {
            return "\(hours) hr \(minutes) min"
        }
        return "\(minutes) min"
    }
}

/// Track row in playlist
struct PlaylistTrackRow: View {
    let track: Track
    let index: Int
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 12) {
            Text("\(index)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 30)
            
            // Artwork
            if let artwork = track.artwork {
                Image(nsImage: artwork)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 40, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(.tertiary)
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: "music.note")
                            .foregroundStyle(.secondary)
                    )
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(track.title)
                    .lineLimit(1)
                Text(track.artist)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            Text(formattedDuration(track.duration))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .background(isHovered ? Color.white.opacity(0.05) : Color.clear)
        .onHover { isHovered = $0 }
    }
    
    private func formattedDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

/// Playlist row in sidebar
struct PlaylistRowView: View {
    let playlist: Playlist
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Artwork
            ZStack {
                if let artwork = playlist.artwork ?? playlist.tracks.first?.artwork {
                    Image(nsImage: artwork)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    LinearGradient(
                        colors: [.blue.opacity(0.5), .purple.opacity(0.5)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .overlay(
                        Image(systemName: "music.note.list")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))
                    )
                }
            }
            .frame(width: 40, height: 40)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(playlist.name)
                    .font(.headline)
                    .lineLimit(1)
                
                Text("\(playlist.tracks.count) songs")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

/// New playlist creation sheet
struct NewPlaylistSheet: View {
    @Binding var name: String
    var onCreate: () -> Void
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 24) {
            Text("New Playlist")
                .font(.title2.bold())
            
            TextField("Playlist name", text: $name)
                .textFieldStyle(.roundedBorder)
                .frame(width: 300)
            
            HStack(spacing: 16) {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.escape)
                
                Button("Create") {
                    onCreate()
                }
                .keyboardShortcut(.return)
                .disabled(name.isEmpty)
            }
        }
        .padding(32)
        .frame(width: 400)
    }
}

#Preview {
    PlaylistsView()
        .environmentObject(PlaylistManager())
        .environmentObject(AudioPlayerManager())
        .frame(width: 800, height: 600)
}

