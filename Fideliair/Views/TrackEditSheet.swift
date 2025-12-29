import SwiftUI
import AppKit

/// Track metadata editor sheet with simplified search
struct TrackEditSheet: View {
    let track: Track
    var onSave: (Track) -> Void
    
    @Environment(\.dismiss) var dismiss
    @StateObject private var searchService = MetadataSearchService()
    
    @State private var title: String
    @State private var artist: String
    @State private var album: String
    @State private var genre: String
    @State private var year: String
    @State private var trackNumber: String
    @State private var isSaving = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var fetchedArtwork: NSImage? = nil
    @State private var showSearchResults = false
    
    init(track: Track, onSave: @escaping (Track) -> Void) {
        self.track = track
        self.onSave = onSave
        _title = State(initialValue: track.title)
        _artist = State(initialValue: track.artist)
        _album = State(initialValue: track.album)
        _genre = State(initialValue: track.genre ?? "")
        _year = State(initialValue: track.year.map { String($0) } ?? "")
        _trackNumber = State(initialValue: track.trackNumber.map { String($0) } ?? "")
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.escape)
                
                Spacer()
                
                Text("Edit Track Info")
                    .font(.zen(.headline))
                
                Spacer()
                
                Button("Save") { saveChanges() }
                    .keyboardShortcut(.return)
                    .disabled(isSaving)
            }
            .padding()
            .background(GlassBackground(opacity: 0.3))
            
            // Content
            HStack(spacing: 0) {
                // Left: Editor
                ScrollView {
                    VStack(spacing: 20) {
                        // Artwork and file info
                        HStack(spacing: 16) {
                            // Artwork display - prioritize fetched artwork
                            ZStack {
                                if let artwork = fetchedArtwork ?? track.artwork {
                                    Image(nsImage: artwork)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 80, height: 80)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                } else {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.gray.opacity(0.3))
                                        .frame(width: 80, height: 80)
                                        .overlay(
                                            Image(systemName: "music.note")
                                                .font(.zen(.title2))
                                                .foregroundColor(.secondary)
                                        )
                                }
                                
                                // Indicator for new artwork
                                if fetchedArtwork != nil {
                                    VStack {
                                        HStack {
                                            Spacer()
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(.zen(.caption))
                                                .foregroundColor(.green)
                                                .background(Circle().fill(.white).padding(-2))
                                        }
                                        Spacer()
                                    }
                                    .frame(width: 80, height: 80)
                                }
                            }
                            .animation(.easeInOut(duration: 0.3), value: fetchedArtwork != nil)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(track.fileURL?.lastPathComponent ?? "Unknown")
                                    .font(.zen(.caption).monospaced())
                                    .lineLimit(2)
                                
                                Spacer()
                                
                                // Search Buttons
                                HStack(spacing: 8) {
                                    Button(action: performFilenameSearch) {
                                        Image(systemName: "doc.text.magnifyingglass")
                                    }
                                    .buttonStyle(.bordered)
                                    .help("Search from filename")
                                    .disabled(searchService.isSearching)
                                    
                                    Button(action: performAutoSearch) {
                                        HStack(spacing: 4) {
                                            if searchService.isSearching {
                                                ProgressView()
                                                    .scaleEffect(0.6)
                                            } else {
                                                Image(systemName: "magnifyingglass")
                                            }
                                            Text("Search")
                                        }
                                        .font(.zen(.caption))
                                    }
                                    .buttonStyle(.bordered)
                                    .disabled(searchService.isSearching)
                                }
                            }
                            
                            Spacer()
                        }
                        .padding()
                        .background(GlassBackground(opacity: 0.2, cornerRadius: 12))
                        
                        // Fields
                        VStack(spacing: 14) {
                            SimpleMetadataField(label: "Title", text: $title)
                            SimpleMetadataField(label: "Artist", text: $artist)
                            SimpleMetadataField(label: "Album", text: $album)
                            
                            HStack(spacing: 12) {
                                SimpleMetadataField(label: "Genre", text: $genre)
                                SimpleMetadataField(label: "Year", text: $year)
                                    .frame(width: 80)
                                SimpleMetadataField(label: "Track", text: $trackNumber)
                                    .frame(width: 70)
                            }
                        }
                        .padding()
                        .background(GlassBackground(opacity: 0.2, cornerRadius: 12))
                    }
                    .padding()
                }
                .frame(width: 380)
                
                // Right: Search Results (if any)
                if !searchService.searchResults.isEmpty || searchService.isSearching {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            Text("Search Results")
                                .font(.zen(.headline))
                            Spacer()
                            if searchService.isSearching {
                                ProgressView()
                                    .scaleEffect(0.7)
                            }
                        }
                        .padding()
                        .background(GlassBackground(opacity: 0.3))
                        
                        if searchService.searchResults.isEmpty && searchService.isSearching {
                            VStack {
                                Spacer()
                                Text("Searching...")
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                            .frame(maxWidth: .infinity)
                        } else {
                            ScrollView {
                                VStack(spacing: 6) {
                                    ForEach(searchService.searchResults) { result in
                                        SearchResultButton(result: result) {
                                            applyResult(result)
                                        }
                                    }
                                }
                                .padding()
                            }
                        }
                    }
                    .frame(width: 280)
                    .background(GlassBackground(opacity: 0.2))
                }
            }
        }
        .frame(width: searchService.searchResults.isEmpty && !searchService.isSearching ? 400 : 700, height: 420)
        .animation(.easeInOut(duration: 0.2), value: searchService.searchResults.isEmpty)
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func performAutoSearch() {
        let query = "\(title) \(artist)".trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return }
        Task {
            await searchService.search(query: query)
        }
    }
    
    private func performFilenameSearch() {
        guard let filename = track.fileURL?.lastPathComponent else { return }
        Task {
            await searchService.searchFromFilename(filename)
        }
    }
    
    private func applyResult(_ result: MetadataSearchResult) {
        withAnimation {
            title = result.title
            artist = result.artist
            if !result.album.isEmpty { album = result.album }
            if let y = result.year { year = String(y) }
        }
        
        // Apply artwork directly if available from search results
        if let artwork = result.artwork {
            fetchedArtwork = artwork
        } else if let releaseId = result.releaseId {
            // Fetch album artwork if not already loaded
            Task {
                if let artwork = await searchService.fetchAlbumArt(releaseId: releaseId) {
                    fetchedArtwork = artwork
                }
            }
        }
    }
    
    private func saveChanges() {
        isSaving = true
        
        var updatedTrack = track
        updatedTrack.title = title
        updatedTrack.artist = artist
        updatedTrack.album = album
        updatedTrack.genre = genre.isEmpty ? nil : genre
        updatedTrack.year = Int(year)
        updatedTrack.trackNumber = Int(trackNumber)
        
        // Apply fetched artwork to the track
        if let artwork = fetchedArtwork {
            updatedTrack.artwork = artwork
        }
        
        if let url = track.fileURL {
            let success = MetadataWriter.shared.writeMetadata(
                to: url, title: title, artist: artist, album: album,
                genre: genre.isEmpty ? nil : genre, year: Int(year), trackNumber: Int(trackNumber)
            )
            if !success {
                errorMessage = "Could not save metadata to file."
                showError = true
                isSaving = false
                return
            }
        }
        
        onSave(updatedTrack)
        isSaving = false
        dismiss()
    }
}

/// Simple metadata field with native text input
struct SimpleMetadataField: View {
    let label: String
    @Binding var text: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.zen(.caption))
                .foregroundColor(.secondary)
            
            TextField(label, text: $text)
                .textFieldStyle(.roundedBorder)
        }
    }
}

/// Search result button with artwork thumbnail
struct SearchResultButton: View {
    let result: MetadataSearchResult
    let onApply: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        Button(action: onApply) {
            HStack(spacing: 10) {
                // Artwork thumbnail
                if let artwork = result.artwork {
                    Image(nsImage: artwork)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 40, height: 40)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                } else {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Image(systemName: "music.note")
                                .font(.zen(.caption))
                                .foregroundColor(.secondary)
                        )
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(result.title)
                        .font(.zen(size: 12, weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Text(result.artist)
                        .font(.zen(.caption2))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    
                    if !result.album.isEmpty {
                        Text(result.album)
                            .font(.zen(.caption2))
                            .foregroundColor(.secondary.opacity(0.7))
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                if result.artwork != nil {
                    Image(systemName: "photo.fill")
                        .font(.zen(.caption2))
                        .foregroundColor(.green)
                }
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isHovered ? Color.accentColor.opacity(0.2) : Color.white.opacity(0.05))
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

/// Metadata writer utility
class MetadataWriter {
    static let shared = MetadataWriter()
    private init() {}
    
    func writeMetadata(to url: URL, title: String, artist: String, album: String,
                       genre: String?, year: Int?, trackNumber: Int?) -> Bool {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "mp3": return writeID3Tags(to: url, title: title, artist: artist, album: album, genre: genre, year: year, trackNumber: trackNumber)
        case "m4a", "aac", "alac": return writeMP4Tags(to: url, title: title, artist: artist, album: album, genre: genre, year: year, trackNumber: trackNumber)
        case "flac": return writeVorbisComments(to: url, title: title, artist: artist, album: album, genre: genre, year: year, trackNumber: trackNumber)
        default: return false
        }
    }
    
    private func writeID3Tags(to url: URL, title: String, artist: String, album: String, genre: String?, year: Int?, trackNumber: Int?) -> Bool {
        print("Would write ID3 tags to: \(url.path)")
        return true
    }
    
    private func writeMP4Tags(to url: URL, title: String, artist: String, album: String, genre: String?, year: Int?, trackNumber: Int?) -> Bool {
        print("Would write MP4 tags to: \(url.path)")
        return true
    }
    
    private func writeVorbisComments(to url: URL, title: String, artist: String, album: String, genre: String?, year: Int?, trackNumber: Int?) -> Bool {
        print("Would write Vorbis comments to: \(url.path)")
        return true
    }
}

#Preview {
    TrackEditSheet(
        track: Track(id: UUID(), title: "Sample", artist: "Artist", album: "Album", duration: 180, fileURL: nil, artwork: nil),
        onSave: { _ in }
    )
}
