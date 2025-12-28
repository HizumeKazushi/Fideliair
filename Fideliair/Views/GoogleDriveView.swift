import SwiftUI

/// Google Drive view (placeholder for Phase 3)
struct GoogleDriveView: View {
    @State private var isAuthenticated = false
    @State private var isAuthenticating = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Google Drive")
                    .font(.title.bold())
                
                Spacer()
                
                if isAuthenticated {
                    Button(action: { /* Refresh */ }) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
            .background(GlassBackground(opacity: 0.3))
            
            Spacer()
            
            if isAuthenticated {
                // Connected state (placeholder)
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.green)
                    
                    Text("Connected to Google Drive")
                        .font(.title2)
                    
                    Text("Cloud music will appear here")
                        .foregroundStyle(.secondary)
                }
            } else {
                // Not connected state
                VStack(spacing: 24) {
                    Image(systemName: "cloud")
                        .font(.system(size: 64))
                        .foregroundStyle(.secondary)
                    
                    Text("Connect to Google Drive")
                        .font(.title2)
                    
                    Text("Stream your music from the cloud")
                        .foregroundStyle(.secondary)
                    
                    Button(action: {
                        isAuthenticating = true
                        // TODO: Implement Google OAuth
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                            isAuthenticating = false
                            // isAuthenticated = true // Enable after OAuth implementation
                        }
                    }) {
                        HStack {
                            if isAuthenticating {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .padding(.trailing, 4)
                            }
                            Image(systemName: "link")
                            Text("Connect Account")
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(
                            LinearGradient(
                                colors: [.blue, .cyan],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(Capsule())
                        .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                    .disabled(isAuthenticating)
                }
            }
            
            Spacer()
        }
    }
}

#Preview {
    GoogleDriveView()
        .frame(width: 600, height: 400)
}
