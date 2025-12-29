import SwiftUI
import UniformTypeIdentifiers
import AVFoundation
import CoreMedia

/// Manages the music library with fast concurrent scanning
@MainActor
class LibraryManager: ObservableObject {
    // MARK: - Published Properties
    @Published var tracks: [Track] = []
    @Published var albums: [Album] = []
    @Published var artists: [Artist] = []
    @Published var isScanning = false
    @Published var scanProgress: Double = 0
    @Published var libraryPaths: [URL] = []
    
    // MARK: - Supported Formats
    static let supportedExtensions: Set<String> = [
        "flac", "m4a", "alac", "wav", "aiff", "mp3", "aac", "ogg", "wma"
    ]
    
    // Concurrent loading limit
    private let maxConcurrentTasks = 8
    
    // MARK: - Initialization
    init() {
        loadLibraryPaths()
        
        // Auto-scan on startup if there are saved library paths
        if !libraryPaths.isEmpty {
            Task {
                await scanAllLibraries()
            }
        }
    }
    
    // MARK: - Library Path Management
    func addLibraryPath(_ url: URL) {
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }
        
        if !libraryPaths.contains(url) {
            libraryPaths.append(url)
            saveLibraryPaths()
            Task {
                await scanDirectory(url)
            }
        }
    }
    
    func removeLibraryPath(_ url: URL) {
        libraryPaths.removeAll { $0 == url }
        saveLibraryPaths()
        tracks.removeAll { $0.fileURL?.path.hasPrefix(url.path) == true }
        rebuildCollections()
    }
    
    private func saveLibraryPaths() {
        let paths = libraryPaths.map { $0.path }
        UserDefaults.standard.set(paths, forKey: "libraryPaths")
    }
    
    private func loadLibraryPaths() {
        if let paths = UserDefaults.standard.stringArray(forKey: "libraryPaths") {
            libraryPaths = paths.compactMap { URL(fileURLWithPath: $0) }
        }
    }
    
    // MARK: - Scanning (Fast Concurrent)
    func scanAllLibraries() async {
        isScanning = true
        scanProgress = 0
        tracks.removeAll()
        
        for (index, path) in libraryPaths.enumerated() {
            await scanDirectory(path)
            scanProgress = Double(index + 1) / Double(libraryPaths.count)
        }
        
        rebuildCollections()
        isScanning = false
    }
    
    func scanDirectory(_ url: URL) async {
        let fileManager = FileManager.default
        
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return }
        
        // Remove existing tracks from this directory to avoid duplicates
        let directoryPath = url.path
        tracks.removeAll { $0.fileURL?.path.hasPrefix(directoryPath) == true }
        
        // Collect all audio files first (fast)
        var audioFiles: [URL] = []
        while let fileURL = enumerator.nextObject() as? URL {
            let ext = fileURL.pathExtension.lowercased()
            if Self.supportedExtensions.contains(ext) {
                audioFiles.append(fileURL)
            }
        }
        
        let totalFiles = audioFiles.count
        guard totalFiles > 0 else { 
            rebuildCollections()
            return 
        }
        
        // Process files concurrently in batches
        var processedTracks: [Track] = []
        
        await withTaskGroup(of: Track?.self) { group in
            var submitted = 0
            var index = 0
            
            // Submit initial batch
            while submitted < maxConcurrentTasks && index < audioFiles.count {
                let fileURL = audioFiles[index]
                group.addTask {
                    await self.extractMetadataFast(from: fileURL)
                }
                submitted += 1
                index += 1
            }
            
            // Process results and submit more tasks
            for await result in group {
                if let track = result {
                    processedTracks.append(track)
                }
                
                // Submit next task if available
                if index < audioFiles.count {
                    let fileURL = audioFiles[index]
                    group.addTask {
                        await self.extractMetadataFast(from: fileURL)
                    }
                    index += 1
                }
                
                // Update progress periodically
                if processedTracks.count % 20 == 0 {
                    scanProgress = Double(processedTracks.count) / Double(totalFiles)
                }
            }
        }
        
        // Deduplicate by file URL before adding
        let existingURLs = Set(tracks.compactMap { $0.fileURL?.absoluteString })
        let newTracks = processedTracks.filter { 
            guard let url = $0.fileURL else { return false }
            return !existingURLs.contains(url.absoluteString)
        }
        
        tracks.append(contentsOf: newTracks)
        rebuildCollections()
    }
    
    // MARK: - Fast Metadata Extraction with Fallbacks
    nonisolated private func extractMetadataFast(from url: URL) async -> Track? {
        let asset = AVAsset(url: url)
        
        var title = url.deletingPathExtension().lastPathComponent
        var artist = "Unknown Artist"
        var albumName = "Unknown Album"
        var artwork: NSImage?
        var duration: TimeInterval = 0
        var genre: String?
        var year: Int?
        var trackNumber: Int?
        var discNumber: Int?
        var albumArtist: String?
        var composer: String?
        var copyright: String?
        var bpm: Int?
        var comment: String?
        var encoder: String?
        var sampleRate: Int?
        var channels: Int?
        // var bitrate: Int? // Not used yet, model property exists but local var wasn't defined
        
        // Try modern async API first
        do {
            // Load duration and all metadata formats
            async let durationTask = asset.load(.duration)
            async let metadataTask = asset.load(.commonMetadata)
            async let formatMetadataTask = asset.load(.metadata)
            
            let (durationValue, commonMetadata, formatMetadata) = try await (durationTask, metadataTask, formatMetadataTask)
            duration = CMTimeGetSeconds(durationValue)
            
            // Extract audio format details
            if let audioTrack = try? await asset.loadTracks(withMediaType: .audio).first {
                // Get format descriptions
                 let formatDescriptions = try? await audioTrack.load(.formatDescriptions)
                 if let desc = formatDescriptions?.first {
                     // Get AudioStreamBasicDescription from the format description
                     if let asbdPointer = CMAudioFormatDescriptionGetStreamBasicDescription(desc) {
                         let asbd = asbdPointer.pointee
                         sampleRate = Int(asbd.mSampleRate)
                         channels = Int(asbd.mChannelsPerFrame)
                         
                         // Determine format
                         let formatID = asbd.mFormatID
                         switch formatID {
                         case kAudioFormatLinearPCM: encoder = "PCM"
                         case kAudioFormatMPEG4AAC: encoder = "AAC"
                         case kAudioFormatMPEGLayer3: encoder = "MP3"
                         case kAudioFormatAppleLossless: encoder = "ALAC"
                         case kAudioFormatFLAC: encoder = "FLAC"
                         default: encoder = "Unknown"
                         }
                     }
                 }
            }
            
            // Process common metadata
            for item in commonMetadata {
                guard let key = item.commonKey else { continue }
                
                switch key {
                case .commonKeyTitle:
                    if let value = try? await item.load(.stringValue), !value.isEmpty {
                        title = value
                    }
                case .commonKeyArtist:
                    if let value = try? await item.load(.stringValue), !value.isEmpty {
                        artist = value
                    }
                case .commonKeyAlbumName:
                    if let value = try? await item.load(.stringValue), !value.isEmpty {
                        albumName = value
                    }
                case .commonKeyArtwork:
                    if let data = try? await item.load(.dataValue) {
                        artwork = NSImage(data: data)
                    }
                case .commonKeyAuthor:
                    if let value = try? await item.load(.stringValue), !value.isEmpty {
                        composer = value
                    }
                case .commonKeyCopyrights:
                    if let value = try? await item.load(.stringValue), !value.isEmpty {
                        copyright = value
                    }
                case .commonKeyDescription:
                    if let value = try? await item.load(.stringValue), !value.isEmpty {
                        comment = value
                    }
                default:
                    break
                }
            }
            
            // Try format-specific metadata for additional info
            for item in formatMetadata {
                if let keyString = item.key as? String {
                    let key = keyString.trimmingCharacters(in: .controlCharacters)
                    let keyLower = key.lowercased()
                    
                    // ID3 Frame IDs (Standard) - Prioritize these over commonMetadata
                    if key == "TIT2" {
                        if let value = try? await item.load(.stringValue), !value.isEmpty { title = value }
                    } else if key == "TPE1" {
                        if let value = try? await item.load(.stringValue), !value.isEmpty { artist = value }
                    } else if key == "TALB" {
                        if let value = try? await item.load(.stringValue), !value.isEmpty { albumName = value }
                    } else if key == "APIC" {
                        if let data = try? await item.load(.dataValue) { artwork = NSImage(data: data) }
                    } else if key == "TYER" || key == "TDRC" { // Year / Recording time
                        if let value = try? await item.load(.stringValue), let yearVal = Int(value.prefix(4)) { year = yearVal }
                    } else if key == "TRCK" {
                        if let value = try? await item.load(.stringValue) {
                            let parts = value.split(separator: "/")
                            if let first = parts.first, let num = Int(first) { trackNumber = num }
                        }
                    } else if key == "TPOS" {
                        if let value = try? await item.load(.stringValue) {
                            let parts = value.split(separator: "/")
                            if let first = parts.first, let num = Int(first) { discNumber = num }
                        }
                    } else if key == "TCON" {
                        if let value = try? await item.load(.stringValue), !value.isEmpty { genre = value }
                    }
                    // iTunes / QuickTime Atoms - Prioritize these over commonMetadata
                    else if key == "©nam" {
                         if let value = try? await item.load(.stringValue), !value.isEmpty { title = value }
                    } else if key == "©ART" {
                         if let value = try? await item.load(.stringValue), !value.isEmpty { artist = value }
                    } else if key == "©alb" {
                         if let value = try? await item.load(.stringValue), !value.isEmpty { albumName = value }
                    }
                    
                    // Fallback to loose text matching (only if not set)
                    else if keyLower.contains("genre") && genre == nil {
                        if let value = try? await item.load(.stringValue) {
                            genre = value
                        }
                    } else if (keyLower.contains("year") || keyLower.contains("date")) && year == nil {
                        if let value = try? await item.load(.stringValue), let yearVal = Int(value.prefix(4)) {
                            year = yearVal
                        }
                    } else if keyLower.contains("track") && !keyLower.contains("total") && trackNumber == nil {
                        if let value = try? await item.load(.numberValue) as? Int {
                            trackNumber = value
                        } else if let value = try? await item.load(.stringValue) {
                            // Handle "1/12" format
                            let parts = value.split(separator: "/")
                            if let first = parts.first, let num = Int(first) {
                                trackNumber = num
                            }
                        }
                    } else if keyLower.contains("disc") && !keyLower.contains("total") && discNumber == nil {
                        if let value = try? await item.load(.numberValue) as? Int {
                            discNumber = value
                        } else if let value = try? await item.load(.stringValue) {
                            let parts = value.split(separator: "/")
                            if let first = parts.first, let num = Int(first) {
                                discNumber = num
                            }
                        }
                    } else if keyLower.contains("albumartist") || keyLower.contains("album_artist") || key == "TPE2" {
                        if let value = try? await item.load(.stringValue), !value.isEmpty {
                            albumArtist = value
                        }
                    } else if (keyLower.contains("composer") || key == "TCOM") && composer == nil {
                        if let value = try? await item.load(.stringValue), !value.isEmpty {
                            composer = value
                        }
                    } else if keyLower.contains("bpm") || keyLower.contains("tempo") || key == "TBPM" {
                        if let value = try? await item.load(.numberValue) as? Int {
                            bpm = value
                        } else if let value = try? await item.load(.stringValue), let bpmVal = Int(value) {
                            bpm = bpmVal
                        }
                    } else if (keyLower.contains("comment") || key == "COMM") && comment == nil {
                        if let value = try? await item.load(.stringValue), !value.isEmpty {
                            comment = value
                        }
                    } else if keyLower.contains("encoder") || keyLower.contains("software") || key == "TSSE" {
                        if let value = try? await item.load(.stringValue), !value.isEmpty {
                            encoder = value
                        }
                    } else if (keyLower.contains("copyright") || key == "TCOP") && copyright == nil {
                        if let value = try? await item.load(.stringValue), !value.isEmpty {
                            copyright = value
                        }
                    }
                }
            }
            
        } catch {
            // Fallback: try synchronous metadata extraction
            duration = Self.extractDurationSync(from: url) ?? 0
            let fallbackMeta = Self.extractMetadataSync(from: url)
            if let meta = fallbackMeta {
                if !meta.title.isEmpty { title = meta.title }
                if !meta.artist.isEmpty { artist = meta.artist }
                if !meta.album.isEmpty { albumName = meta.album }
                artwork = meta.artwork
            }
        }
        
        // Parse title from filename if still default
        if title == url.deletingPathExtension().lastPathComponent {
            let parsed = Self.parseFilename(url.deletingPathExtension().lastPathComponent)
            if let parsedTitle = parsed.title { title = parsedTitle }
            if let parsedArtist = parsed.artist, artist == "Unknown Artist" { artist = parsedArtist }
        }
        
        return Track(
            id: UUID(),
            title: title,
            artist: artist,
            album: albumName,
            duration: duration.isNaN ? 0 : duration,
            fileURL: url,
            artwork: artwork,
            trackNumber: trackNumber,
            discNumber: discNumber,
            genre: genre,
            year: year,
            albumArtist: albumArtist,
            composer: composer,
            copyright: copyright,
            bpm: bpm,
            comment: comment,
            lyrics: nil, // Add missing default
            bitrate: nil, // Add missing default
            sampleRate: sampleRate,
            channels: channels,
            encoder: encoder
        )
    }
    
    // MARK: - Sync Fallback Methods
    nonisolated static func extractDurationSync(from url: URL) -> TimeInterval? {
        let asset = AVURLAsset(url: url)
        let duration = CMTimeGetSeconds(asset.duration)
        return duration.isNaN ? nil : duration
    }
    
    nonisolated static func extractMetadataSync(from url: URL) -> (title: String, artist: String, album: String, artwork: NSImage?)? {
        let asset = AVURLAsset(url: url)
        var title = ""
        var artist = ""
        var album = ""
        var artwork: NSImage?
        
        for item in asset.commonMetadata {
            guard let key = item.commonKey else { continue }
            
            switch key {
            case .commonKeyTitle:
                title = item.stringValue ?? ""
            case .commonKeyArtist:
                artist = item.stringValue ?? ""
            case .commonKeyAlbumName:
                album = item.stringValue ?? ""
            case .commonKeyArtwork:
                if let data = item.dataValue {
                    artwork = NSImage(data: data)
                }
            default:
                break
            }
        }
        
        return (title, artist, album, artwork)
    }
    
    // MARK: - Filename Parsing
    nonisolated static func parseFilename(_ filename: String) -> (title: String?, artist: String?) {
        var name = filename
        
        // Remove track number prefix (01, 01., 01 -, etc.)
        if let range = name.range(of: #"^\d{1,3}[\.\-\s]*"#, options: .regularExpression) {
            name = String(name[range.upperBound...])
        }
        
        // Try "Artist - Title" pattern
        if let dashRange = name.range(of: " - ") {
            let artist = String(name[..<dashRange.lowerBound]).trimmingCharacters(in: .whitespaces)
            let title = String(name[dashRange.upperBound...]).trimmingCharacters(in: .whitespaces)
            return (title: title, artist: artist)
        }
        
        return (title: name, artist: nil)
    }
    
    // MARK: - Collection Building
    private func rebuildCollections() {
        let albumGroups = Dictionary(grouping: tracks) { $0.album }
        albums = albumGroups.map { albumName, tracks in
            Album(
                id: UUID(),
                name: albumName,
                artist: tracks.first?.artist ?? "Unknown",
                tracks: tracks.sorted { ($0.trackNumber ?? 0) < ($1.trackNumber ?? 0) },
                artwork: tracks.first?.artwork
            )
        }.sorted { $0.name < $1.name }
        
        let artistGroups = Dictionary(grouping: tracks) { $0.artist }
        artists = artistGroups.map { artistName, tracks in
            let artistAlbums = albums.filter { $0.artist == artistName }
            return Artist(
                id: UUID(),
                name: artistName,
                albums: artistAlbums
            )
        }.sorted { $0.name < $1.name }
    }
    
    // MARK: - Search
    func search(_ query: String) -> [Track] {
        guard !query.isEmpty else { return tracks }
        let lowercasedQuery = query.lowercased()
        return tracks.filter {
            $0.title.lowercased().contains(lowercasedQuery) ||
            $0.artist.lowercased().contains(lowercasedQuery) ||
            $0.album.lowercased().contains(lowercasedQuery)
        }
    }
    
    // MARK: - Track Management
    func updateTrack(_ updatedTrack: Track) {
        if let index = tracks.firstIndex(where: { $0.id == updatedTrack.id }) {
            tracks[index] = updatedTrack
            rebuildCollections()
        }
    }
    
    func removeTrack(_ track: Track) {
        tracks.removeAll { $0.id == track.id }
        rebuildCollections()
    }
}
