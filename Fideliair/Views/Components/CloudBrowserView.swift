import SwiftUI

/// Browser view for navigating Google Drive folders
struct CloudBrowserView: View {
    let rootURL: URL
    @EnvironmentObject var googleDriveManager: GoogleDriveManager
    @EnvironmentObject var audioPlayer: AudioPlayerManager
    
    // Navigation stack path
    @State private var path: [DriveItem] = []
    
    var body: some View {
        NavigationStack(path: $path) {
            DriveFolderView(url: rootURL)
                .navigationDestination(for: DriveItem.self) { item in
                    if item.isFolder {
                        DriveFolderView(url: item.url, title: item.name)
                    }
                }
        }
    }
}

/// Individual folder listing view
struct DriveFolderView: View {
    let url: URL
    var title: String? = nil
    
    @EnvironmentObject var googleDriveManager: GoogleDriveManager
    @EnvironmentObject var audioPlayer: AudioPlayerManager
    @State private var items: [DriveItem] = []
    
    var body: some View {
        Group {
            if items.isEmpty {
                VStack {
                    Image(systemName: "folder.badge.questionmark")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("Empty Folder".localized)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(items) { item in
                        if item.isFolder {
                            NavigationLink(value: item) {
                                DriveRowContent(item: item)
                            }
                            .buttonStyle(.plain)
                        } else {
                            Button {
                                playFile(item)
                            } label: {
                                DriveRowContent(item: item)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle(title ?? "Google Drive")
        .onAppear {
            loadContents()
        }
    }
    
    private func loadContents() {
        items = googleDriveManager.contents(of: url)
    }
    
    private func playFile(_ item: DriveItem) {
        // Create a temporary Track object for playback
        audioPlayer.play(track: createTrack(from: item))
        
        // Also queue other songs in this folder?
        let audioFiles = items.filter { !$0.isFolder }
        let tracks = audioFiles.map { createTrack(from: $0) }
        
        if let index = tracks.firstIndex(where: { $0.fileURL == item.url }) {
            audioPlayer.playQueue(tracks, startingAt: index)
        }
    }
    
    private func createTrack(from item: DriveItem) -> Track {
        let url = item.url
        
        // Default values
        var title = url.deletingPathExtension().lastPathComponent
        var artist = "Cloud Stream"
        var album = "Google Drive"
        var artwork: NSImage?
        var duration: TimeInterval = 0
        
        // Try to extract metadata synchronously for immediate playback
        // (Since we are streaming local files mounted by Drive, this is fast enough)
        if let meta = LibraryManager.extractMetadataSync(from: url) {
            if !meta.title.isEmpty { title = meta.title }
            if !meta.artist.isEmpty { artist = meta.artist }
            if !meta.album.isEmpty { album = meta.album }
            artwork = meta.artwork
        }
        
        // Fallback to filename parsing if title is still filename
        if title == url.deletingPathExtension().lastPathComponent {
            let parsed = LibraryManager.parseFilename(url.deletingPathExtension().lastPathComponent)
            if let parsedTitle = parsed.title { title = parsedTitle }
            if let parsedArtist = parsed.artist { artist = parsedArtist }
        }
        
        if let dur = LibraryManager.extractDurationSync(from: url) {
            duration = dur
        }
        
        return Track(
            id: UUID(), // Generate new ID for playground
            title: title,
            artist: artist,
            album: album,
            duration: duration,
            fileURL: url,
            artwork: artwork,
            isCached: false
        )
    }
}

struct DriveRowContent: View {
    let item: DriveItem
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: item.isFolder ? "folder.fill" : "music.note")
                .font(.zen(size: 20))
                .foregroundStyle(item.isFolder ? .blue : .secondary)
                .frame(width: 24)
            
            Text(item.name)
                .font(.zen(size: 14))
                .foregroundStyle(.primary)
            
            Spacer()
            
            if !item.isFolder {
                Image(systemName: "play.circle")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}
