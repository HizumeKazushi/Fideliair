import SwiftUI

/// Main library view showing tracks, albums, and artists
struct LibraryView: View {
    @EnvironmentObject var libraryManager: LibraryManager
    @EnvironmentObject var audioPlayer: AudioPlayerManager
    @EnvironmentObject var playlistManager: PlaylistManager
    @State private var viewMode: LibraryViewMode = .albums
    @State private var searchText = ""
    @State private var selectedAlbum: Album?
    @State private var selectedArtist: Artist?
    
    var filteredAlbums: [Album] {
        guard !searchText.isEmpty else { return libraryManager.albums }
        let query = searchText.lowercased()
        return libraryManager.albums.filter {
            $0.name.lowercased().contains(query) ||
            $0.artist.lowercased().contains(query)
        }
    }
    
    var filteredArtists: [Artist] {
        guard !searchText.isEmpty else { return libraryManager.artists }
        let query = searchText.lowercased()
        return libraryManager.artists.filter {
            $0.name.lowercased().contains(query)
        }
    }
    
    var filteredTracks: [Track] {
        guard !searchText.isEmpty else { return libraryManager.tracks }
        return libraryManager.search(searchText)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                // View mode picker
                Picker("View", selection: $viewMode) {
                    ForEach(LibraryViewMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 300)
                
                Spacer()
                
                // Search
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    NativeSearchField(text: $searchText, placeholder: "Search")
                        .frame(width: 180, height: 22)
                    
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding()
            .background(GlassBackground(opacity: 0.3))
            
            // Content
            ScrollView {
                switch viewMode {
                case .albums:
                    AlbumsGridView(albums: filteredAlbums, selectedAlbum: $selectedAlbum)
                case .artists:
                    ArtistsGridView(artists: filteredArtists, selectedArtist: $selectedArtist)
                case .songs:
                    TracksListView(tracks: filteredTracks)
                }
            }
            .padding()
        }
        .sheet(item: $selectedAlbum) { album in
            AlbumDetailView(album: album)
                .environmentObject(audioPlayer)
                .environmentObject(libraryManager)
                .environmentObject(playlistManager)
        }
        .sheet(item: $selectedArtist) { artist in
            ArtistDetailView(artist: artist, selectedAlbum: $selectedAlbum)
                .environmentObject(audioPlayer)
                .environmentObject(libraryManager)
                .environmentObject(playlistManager)
        }
    }
}

enum LibraryViewMode: String, CaseIterable {
    case albums = "Albums"
    case artists = "Artists"
    case songs = "Songs"
}

/// Grid view of albums
struct AlbumsGridView: View {
    let albums: [Album]
    @Binding var selectedAlbum: Album?
    
    let columns = [
        GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 20)
    ]
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: 20) {
            ForEach(albums) { album in
                AlbumCardView(album: album)
                    .onTapGesture {
                        selectedAlbum = album
                    }
            }
        }
        .padding()
    }
}

/// Album card with artwork and play button
struct AlbumCardView: View {
    let album: Album
    @EnvironmentObject var audioPlayer: AudioPlayerManager
    @State private var isHovered = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Artwork
            ZStack {
                if let artwork = album.artwork {
                    Image(nsImage: artwork)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    LinearGradient(
                        colors: [.gray.opacity(0.3), .gray.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .overlay(
                        Image(systemName: "music.note")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                    )
                }
                
                // Overlay on hover
                if isHovered {
                    Color.black.opacity(0.4)
                    
                    // Play button
                    Button(action: {
                        audioPlayer.playQueue(album.tracks)
                    }) {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 50))
                            .foregroundStyle(.white)
                            .shadow(radius: 10)
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(width: 160, height: 160)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.2), radius: isHovered ? 15 : 8, x: 0, y: isHovered ? 8 : 4)
            .scaleEffect(isHovered ? 1.02 : 1.0)
            
            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(album.name)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
                
                Text(album.artist)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .onHover { hovering in
            withAnimation(.spring(duration: 0.2)) {
                isHovered = hovering
            }
        }
    }
}

/// Artists grid view
struct ArtistsGridView: View {
    let artists: [Artist]
    @Binding var selectedArtist: Artist?
    
    let columns = [
        GridItem(.adaptive(minimum: 140, maximum: 180), spacing: 20)
    ]
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: 20) {
            ForEach(artists) { artist in
                ArtistCardView(artist: artist)
                    .onTapGesture {
                        selectedArtist = artist
                    }
            }
        }
        .padding()
    }
}

/// Artist card
struct ArtistCardView: View {
    let artist: Artist
    @State private var isHovered = false
    
    var body: some View {
        VStack(spacing: 8) {
            // Artwork (circular)
            ZStack {
                if let artwork = artist.artwork {
                    Image(nsImage: artwork)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    LinearGradient(
                        colors: [.purple.opacity(0.5), .blue.opacity(0.5)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.largeTitle)
                            .foregroundStyle(.white.opacity(0.7))
                    )
                }
            }
            .frame(width: 120, height: 120)
            .clipShape(Circle())
            .shadow(color: .black.opacity(0.2), radius: isHovered ? 12 : 6)
            .scaleEffect(isHovered ? 1.05 : 1.0)
            
            Text(artist.name)
                .font(.system(size: 14, weight: .medium))
                .lineLimit(1)
            
            Text("\(artist.albumCount) albums")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .onHover { hovering in
            withAnimation(.spring(duration: 0.2)) {
                isHovered = hovering
            }
        }
    }
}

/// List view of all tracks
struct TracksListView: View {
    let tracks: [Track]
    @EnvironmentObject var audioPlayer: AudioPlayerManager
    
    var body: some View {
        LazyVStack(spacing: 0) {
            ForEach(Array(tracks.enumerated()), id: \.element.id) { index, track in
                TrackRowView(track: track, index: index + 1)
                    .onTapGesture(count: 2) {
                        audioPlayer.playQueue(tracks, startingAt: index)
                    }
                
                if index < tracks.count - 1 {
                    Divider()
                        .padding(.leading, 60)
                }
            }
        }
        .background(
            GlassBackground(opacity: 0.3, cornerRadius: 12)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

/// Single track row
struct TrackRowView: View {
    let track: Track
    let index: Int
    var onTrackUpdated: ((Track) -> Void)? = nil
    @EnvironmentObject var audioPlayer: AudioPlayerManager
    @EnvironmentObject var libraryManager: LibraryManager
    @EnvironmentObject var playlistManager: PlaylistManager
    @State private var isHovered = false
    @State private var showingEditSheet = false
    
    var isPlaying: Bool {
        audioPlayer.currentTrack?.id == track.id
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Track number or playing indicator
            ZStack {
                if isPlaying && audioPlayer.isPlaying {
                    MusicVisualizerView()
                        .frame(width: 24)
                } else if isHovered {
                    Image(systemName: "play.fill")
                        .font(.caption)
                        .foregroundStyle(.primary)
                } else {
                    Text("\(index)")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 30)
            
            // Artwork (small)
            if let artwork = track.artwork {
                Image(nsImage: artwork)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 40, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            
            // Track info
            VStack(alignment: .leading, spacing: 2) {
                Text(track.title)
                    .font(.system(size: 14, weight: isPlaying ? .semibold : .regular))
                    .foregroundStyle(isPlaying ? .blue : .primary)
                    .lineLimit(1)
                
                Text(track.artist)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Edit button (visible on hover)
            if isHovered {
                Button(action: { showingEditSheet = true }) {
                    Image(systemName: "pencil")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .transition(.opacity)
            }
            
            // Duration
            Text(formatDuration(track.duration))
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isHovered ? Color.white.opacity(0.05) : Color.clear)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .contextMenu {
            Menu("Add to Playlist", systemImage: "plus.circle") {
                Button("New Playlist...") {
                    playlistManager.createPlaylist(name: "New Playlist", tracks: [track])
                }
                
                if !playlistManager.playlists.isEmpty {
                    Divider()
                    ForEach(playlistManager.playlists) { playlist in
                        Button(playlist.name) {
                            playlistManager.addTrack(track, to: playlist)
                        }
                    }
                }
            }
            
            Divider()
            
            Button(action: { showingEditSheet = true }) {
                Label("Edit Info", systemImage: "pencil")
            }
            
            Divider()
            
            Button(action: {
                if let url = track.fileURL {
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                }
            }) {
                Label("Show in Finder", systemImage: "folder")
            }
            
            Divider()
            
            Button(role: .destructive, action: {
                libraryManager.removeTrack(track)
            }) {
                Label("Remove from Library", systemImage: "trash")
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            TrackEditSheet(track: track) { updatedTrack in
                libraryManager.updateTrack(updatedTrack)
                onTrackUpdated?(updatedTrack)
            }
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

/// Album detail view (sheet)
struct AlbumDetailView: View {
    let album: Album
    @EnvironmentObject var audioPlayer: AudioPlayerManager
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            // Background from album art
            AlbumArtBackground(artwork: album.artwork)
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    
                    Spacer()
                }
                .padding()
                
                // Album info
                HStack(spacing: 24) {
                    // Large artwork
                    if let artwork = album.artwork {
                        Image(nsImage: artwork)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 200, height: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .shadow(color: .black.opacity(0.3), radius: 20)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text(album.name)
                            .font(.largeTitle.bold())
                        
                        Text(album.artist)
                            .font(.title2)
                            .foregroundStyle(.secondary)
                        
                        Text("\(album.trackCount) songs • \(formatDuration(album.duration))")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        Spacer()
                        
                        Button(action: {
                            audioPlayer.playQueue(album.tracks)
                        }) {
                            HStack {
                                Image(systemName: "play.fill")
                                Text("Play")
                            }
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(32)
                
                // Track list
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(album.tracks.enumerated()), id: \.element.id) { index, track in
                            TrackRowView(track: track, index: index + 1)
                                .onTapGesture(count: 2) {
                                    audioPlayer.playQueue(album.tracks, startingAt: index)
                                }
                            
                            if index < album.tracks.count - 1 {
                                Divider()
                                    .padding(.leading, 60)
                            }
                        }
                    }
                    .background(GlassBackground(opacity: 0.3, cornerRadius: 12))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 32)
                }
                
                Spacer()
            }
        }
        .frame(minWidth: 700, minHeight: 600)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let totalMinutes = Int(duration) / 60
        if totalMinutes >= 60 {
            let hours = totalMinutes / 60
            let minutes = totalMinutes % 60
            return "\(hours) hr \(minutes) min"
        }
        return "\(totalMinutes) min"
    }
}

/// Artist detail view showing albums
struct ArtistDetailView: View {
    let artist: Artist
    @Binding var selectedAlbum: Album?
    @EnvironmentObject var audioPlayer: AudioPlayerManager
    @Environment(\.dismiss) var dismiss
    
    let columns = [
        GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 20)
    ]
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [.purple.opacity(0.3), .blue.opacity(0.2), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    
                    Spacer()
                }
                .padding()
                
                // Artist info
                HStack(spacing: 24) {
                    // Artist image (circular)
                    ZStack {
                        if let artwork = artist.artwork ?? artist.albums.first?.artwork {
                            Image(nsImage: artwork)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } else {
                            LinearGradient(
                                colors: [.purple.opacity(0.5), .blue.opacity(0.5)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            .overlay(
                                Image(systemName: "person.fill")
                                    .font(.system(size: 50))
                                    .foregroundStyle(.white.opacity(0.7))
                            )
                        }
                    }
                    .frame(width: 180, height: 180)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.3), radius: 20)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text(artist.name)
                            .font(.largeTitle.bold())
                        
                        Text("\(artist.albumCount) albums • \(artist.trackCount) songs")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        Spacer()
                        
                        HStack(spacing: 12) {
                            // Play all button
                            Button(action: {
                                let allTracks = artist.albums.flatMap { $0.tracks }
                                audioPlayer.playQueue(allTracks)
                            }) {
                                HStack {
                                    Image(systemName: "play.fill")
                                    Text("Play All")
                                }
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(
                                    LinearGradient(
                                        colors: [.blue, .purple],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                            
                            // Shuffle button
                            Button(action: {
                                var allTracks = artist.albums.flatMap { $0.tracks }
                                allTracks.shuffle()
                                audioPlayer.playQueue(allTracks)
                            }) {
                                HStack {
                                    Image(systemName: "shuffle")
                                    Text("Shuffle")
                                }
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(Color.white.opacity(0.1))
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 24)
                
                // Albums section
                Text("Albums")
                    .font(.title2.bold())
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 12)
                
                // Albums grid
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 20) {
                        ForEach(artist.albums) { album in
                            AlbumCardView(album: album)
                                .onTapGesture {
                                    dismiss()
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                        selectedAlbum = album
                                    }
                                }
                        }
                    }
                    .padding(.horizontal, 32)
                }
                
                Spacer()
            }
        }
        .frame(minWidth: 800, minHeight: 600)
    }
}

#Preview {
    LibraryView()
        .environmentObject(LibraryManager())
        .environmentObject(AudioPlayerManager())
        .frame(width: 800, height: 600)
}

