import SwiftUI

/// Fullscreen lyrics overlay with Apple Music style
struct LyricsOverlay: View {
    @Binding var isShowing: Bool
    @EnvironmentObject var audioPlayer: AudioPlayerManager
    @StateObject private var lyricsService = LyricsService()
    @State private var currentLineIndex: Int = 0
    
    var body: some View {
        ZStack {
            // Blurred album art background
            AlbumArtBackground(artwork: audioPlayer.currentTrack?.artwork)
                .blur(radius: 30)
                .overlay(Color.black.opacity(0.3))
            
            VStack {
                // Close button
                HStack {
                    Spacer()
                    Button(action: { isShowing = false }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                    .padding()
                }
                
                Spacer()
                
                // Lyrics content
                if let lyrics = lyricsService.currentLyrics, !lyrics.lines.isEmpty {
                    LyricsScrollView(
                        lyrics: lyrics,
                        currentTime: audioPlayer.currentTime,
                        onSeek: { time in
                            audioPlayer.seek(to: time)
                        }
                    )
                } else if lyricsService.isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(.white)
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "quote.bubble")
                            .font(.system(size: 48))
                            .foregroundStyle(.white.opacity(0.5))
                        
                        Text("No lyrics available")
                            .font(.title2)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
                
                Spacer()
                
                // Track info at bottom
                HStack(spacing: 16) {
                    if let artwork = audioPlayer.currentTrack?.artwork {
                        Image(nsImage: artwork)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 60, height: 60)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    
                    VStack(alignment: .leading) {
                        Text(audioPlayer.currentTrack?.title ?? "Unknown")
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text(audioPlayer.currentTrack?.artist ?? "Unknown")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    
                    Spacer()
                }
                .padding()
                .background(GlassBackground(opacity: 0.5, cornerRadius: 16))
                .padding()
            }
        }
        .ignoresSafeArea()
        .onChange(of: audioPlayer.currentTrack?.id) { oldValue, newValue in
            if let track = audioPlayer.currentTrack {
                Task {
                    await lyricsService.fetchLyrics(for: track)
                }
            }
        }
        .onAppear {
            if let track = audioPlayer.currentTrack {
                Task {
                    await lyricsService.fetchLyrics(for: track)
                }
            }
        }
    }
}

/// Scrollable lyrics view with current line highlighting
struct LyricsScrollView: View {
    let lyrics: Lyrics
    let currentTime: TimeInterval
    var onSeek: (TimeInterval) -> Void
    
    @State private var visibleLineIndex: Int?
    
    private var currentLineIndex: Int? {
        lyrics.currentLineIndex(for: currentTime)
    }
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    ForEach(Array(lyrics.lines.enumerated()), id: \.element.id) { index, line in
                        OverlayLyricLineView(
                            line: line,
                            isCurrent: index == currentLineIndex,
                            isPast: (currentLineIndex ?? 0) > index
                        )
                        .id(index)
                        .onTapGesture {
                            onSeek(line.timestamp)
                        }
                    }
                }
                .padding(.vertical, 200)
                .padding(.horizontal, 60)
            }
            .onChange(of: currentLineIndex) { oldValue, newValue in
                if let index = newValue, index != visibleLineIndex {
                    visibleLineIndex = index
                    withAnimation(.spring(duration: 0.5)) {
                        proxy.scrollTo(index, anchor: .center)
                    }
                }
            }
        }
    }
}

/// Individual lyric line for overlay view
struct OverlayLyricLineView: View {
    let line: LyricLine
    let isCurrent: Bool
    let isPast: Bool
    
    var body: some View {
        Text(line.text)
            .font(.system(size: isCurrent ? 32 : 24, weight: isCurrent ? .bold : .medium))
            .foregroundStyle(
                isCurrent
                    ? .white
                    : (isPast ? .white.opacity(0.3) : .white.opacity(0.5))
            )
            .blur(radius: isCurrent ? 0 : (isPast ? 1 : 0.5))
            .scaleEffect(isCurrent ? 1.0 : 0.9)
            .animation(.spring(duration: 0.3), value: isCurrent)
            .multilineTextAlignment(.center)
    }
}

#Preview {
    LyricsOverlay(isShowing: .constant(true))
        .environmentObject(AudioPlayerManager())
}
