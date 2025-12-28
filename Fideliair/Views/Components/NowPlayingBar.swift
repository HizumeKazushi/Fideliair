import SwiftUI

/// Floating Now Playing bar with Liquid Glass design
struct NowPlayingBar: View {
    @EnvironmentObject var audioPlayer: AudioPlayerManager
    @Binding var showingLyrics: Bool
    var onArtworkTap: (() -> Void)? = nil
    @State private var isDragging = false
    
    var body: some View {
        HStack(spacing: 16) {
            // Album artwork (clickable to open full-screen)
            Group {
                if let artwork = audioPlayer.currentTrack?.artwork {
                    Image(nsImage: artwork)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 56, height: 56)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(LinearGradient(
                            colors: [.gray.opacity(0.3), .gray.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 56, height: 56)
                        .overlay(
                            Image(systemName: "music.note")
                                .font(.title2)
                                .foregroundStyle(.secondary)
                        )
                }
            }
            .onTapGesture {
                onArtworkTap?()
            }
            .help("Click to open full-screen player")
            
            // Track info
            VStack(alignment: .leading, spacing: 2) {
                Text(audioPlayer.currentTrack?.title ?? "Not Playing")
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
                
                Text(audioPlayer.currentTrack?.artist ?? "—")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(width: 160, alignment: .leading)
            
            Spacer()
            
            // Playback controls
            HStack(spacing: 24) {
                Button(action: { audioPlayer.previousTrack() }) {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 18))
                }
                .buttonStyle(PlayerButtonStyle())
                
                Button(action: { audioPlayer.togglePlayPause() }) {
                    Image(systemName: audioPlayer.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 40))
                }
                .buttonStyle(PlayerButtonStyle(isMain: true))
                
                Button(action: { audioPlayer.nextTrack() }) {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 18))
                }
                .buttonStyle(PlayerButtonStyle())
            }
            
            Spacer()
            
            // Progress bar
            VStack(spacing: 4) {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background track
                        Capsule()
                            .fill(.white.opacity(0.2))
                            .frame(height: 4)
                        
                        // Progress
                        Capsule()
                            .fill(LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            ))
                            .frame(width: progressWidth(in: geometry.size.width), height: 4)
                        
                        // Drag handle
                        Circle()
                            .fill(.white)
                            .frame(width: isDragging ? 12 : 8, height: isDragging ? 12 : 8)
                            .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                            .offset(x: progressWidth(in: geometry.size.width) - (isDragging ? 6 : 4))
                            .opacity(isDragging ? 1 : 0)
                    }
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                isDragging = true
                                let progress = max(0, min(1, value.location.x / geometry.size.width))
                                audioPlayer.seek(to: progress * audioPlayer.duration)
                            }
                            .onEnded { _ in
                                withAnimation(.spring(duration: 0.2)) {
                                    isDragging = false
                                }
                            }
                    )
                }
                .frame(height: 12)
                
                // Time labels
                HStack {
                    Text(audioPlayer.formattedTime(audioPlayer.currentTime))
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    Text(audioPlayer.formattedTime(audioPlayer.duration))
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 200)
            
            Spacer()
            
            // Volume slider
            HStack(spacing: 8) {
                Image(systemName: audioPlayer.volume == 0 ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                
                Slider(value: Binding(
                    get: { Double(audioPlayer.volume) },
                    set: { audioPlayer.setVolume(Float($0)) }
                ), in: 0...1)
                .frame(width: 80)
                .tint(.white.opacity(0.8))
            }
            
            // Action buttons
            HStack(spacing: 16) {
                Button(action: {
                    if var track = audioPlayer.currentTrack {
                        track.isFavorite.toggle()
                    }
                }) {
                    Image(systemName: audioPlayer.currentTrack?.isFavorite == true ? "heart.fill" : "heart")
                        .font(.system(size: 16))
                        .foregroundStyle(audioPlayer.currentTrack?.isFavorite == true ? .pink : .secondary)
                }
                .buttonStyle(.plain)
                
                Button(action: {
                    withAnimation(.spring(duration: 0.4)) {
                        showingLyrics.toggle()
                    }
                }) {
                    Image(systemName: "quote.bubble")
                        .font(.system(size: 16))
                        .foregroundStyle(showingLyrics ? .blue : .secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            GlassBackground(opacity: 0.7)
                .clipShape(RoundedRectangle(cornerRadius: 20))
        )
        .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
    }
    
    private func progressWidth(in totalWidth: CGFloat) -> CGFloat {
        guard audioPlayer.duration > 0 else { return 0 }
        return CGFloat(audioPlayer.currentTime / audioPlayer.duration) * totalWidth
    }
}

/// Custom button style for player controls
struct PlayerButtonStyle: ButtonStyle {
    var isMain: Bool = false
    @State private var isHovered = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.primary)
            .scaleEffect(configuration.isPressed ? 0.9 : (isHovered ? 1.05 : 1.0))
            .animation(.spring(duration: 0.2), value: configuration.isPressed)
            .animation(.spring(duration: 0.2), value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
    }
}

#Preview {
    VStack {
        Spacer()
        NowPlayingBar(showingLyrics: .constant(false))
            .environmentObject(AudioPlayerManager())
            .padding()
    }
    .frame(height: 200)
    .background(Color.gray.opacity(0.3))
}
