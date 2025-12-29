import SwiftUI

struct SettingsView: View {
    @ObservedObject var settingsManager = SettingsManager.shared
    @ObservedObject private var audioOutputManager = AudioOutputManager.shared
    @ObservedObject var languageManager = LanguageManager.shared // Observe language changes
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Settings".localized)
                    .font(.zen(.largeTitle).bold())
                Spacer()
            }
            .padding(32)
            .background(GlassBackground(opacity: 0.3))
            
            ScrollView {
                VStack(spacing: 32) {
                    
                    // Language Section (New)
                    SettingsSection(title: "Language".localized) {
                        HStack {
                            Text("Select Language".localized)
                                .font(.zen(.headline))
                                .foregroundStyle(.secondary)
                            
                            Spacer()
                            
                            Picker("Select Language".localized, selection: $languageManager.currentLanguage) {
                                ForEach(AppLanguage.allCases) { lang in
                                    Text(lang.rawValue).tag(lang)
                                }
                            }
                            .pickerStyle(.segmented)
                            .labelsHidden() // Fix doubled label wrapping issue
                            .frame(width: 200)
                        }
                        .padding()
                        .background(Color.white.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    
                    // Audio Section
                    SettingsSection(title: "Audio".localized) {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Image(systemName: "waveform")
                                    .font(.title2)
                                    .foregroundStyle(.blue)
                                
                                VStack(alignment: .leading) {
                                    Text("Output Device".localized)
                                        .font(.zen(.headline))
                                    
                                    Picker("Output Device", selection: $audioOutputManager.selectedDeviceID) {
                                        ForEach(audioOutputManager.availableDevices) { device in
                                            Text(device.name).tag(device.id)
                                        }
                                    }
                                    .labelsHidden()
                                    .pickerStyle(.menu)
                                    .frame(minWidth: 150)
                                }
                                
                                Spacer()
                                
                                VStack(alignment: .trailing) {
                                    Text("Sample Rate".localized)
                                        .font(.zen(.caption))
                                        .foregroundStyle(.secondary)
                                    Text(String(format: "%.1f kHz", audioOutputManager.currentSampleRate / 1000.0))
                                        .font(.zen(.body).monospaced())
                                }
                            }
                            
                            Divider()
                            
                            Toggle(isOn: $audioOutputManager.isAutoSampleRateMatchEnabled) {
                                VStack(alignment: .leading) {
                                    Text("Auto Sample Rate Matching".localized)
                                        .font(.zen(.headline))
                                    Text("Automatically adjusts the output device's sample rate to match the playing track for high-resolution playback.".localized)
                                        .font(.zen(.caption))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .toggleStyle(.switch)
                            .tint(.blue)
                        }
                        .padding()
                        .background(Color.white.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    
                    // Appearance Section
                    SettingsSection(title: "Appearance".localized) {
                        // Font Selection
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Font".localized)
                                .font(.zen(.headline))
                                .foregroundStyle(.secondary)
                            
                            Toggle("Use System Font".localized, isOn: $settingsManager.useSystemFont)
                                .toggleStyle(.switch)
                            
                            if !settingsManager.useSystemFont {
                                Picker("Font Family".localized, selection: $settingsManager.selectedFontName) {
                                    ForEach(settingsManager.availableFonts, id: \.self) { fontName in
                                        Text(fontName)
                                            .font(.custom(fontName, size: 14))
                                            .tag(fontName)
                                    }
                                }
                                .pickerStyle(.menu)
                                .frame(maxWidth: 300)
                            }
                        }
                        .padding()
                        .background(Color.white.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        
                        // Size Adjustment
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text("Text Size Scale".localized)
                                    .font(.zen(.headline))
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(String(format: "%.1fx", settingsManager.fontSizeScale))
                                    .font(.zen(.subheadline).monospaced())
                                    .foregroundStyle(.secondary)
                            }
                            
                            Slider(value: $settingsManager.fontSizeScale, in: 0.8...1.5, step: 0.1) {
                                Text("Scale")
                            } minimumValueLabel: {
                                Image(systemName: "textformat.size.smaller")
                            } maximumValueLabel: {
                                Image(systemName: "textformat.size.larger")
                            }
                            
                            Text("Adjust the relative size of text throughout the application.".localized)
                                .font(.zen(.caption))
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .background(Color.white.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    
                    // About Section
                    SettingsSection(title: "About".localized) {
                        VStack(spacing: 16) {
                            Image("AppIcon") // Assuming generic icon if not available
                                .resizable()
                                .frame(width: 80, height: 80)
                                .clipShape(RoundedRectangle(cornerRadius: 18))
                                .shadow(radius: 5)
                            
                            Text("Fideliair")
                                .font(.zen(.title2).bold())
                            
                            Text("Version 1.0.0")
                                .font(.zen(.subheadline))
                                .foregroundStyle(.secondary)
                            
                            Button("Reset Settings".localized) {
                                settingsManager.resetToDefaults()
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.red)
                            .padding(.top, 8)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.white.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    
                    // Support Section
                    SettingsSection(title: "Support Development".localized) {
                         VStack(spacing: 16) {
                             Button(action: {
                                 // Placeholder for future implementation
                                 print("Buy me a coffee tapped")
                             }) {
                                 HStack {
                                     Image(systemName: "cup.and.saucer.fill")
                                         .font(.title2)
                                     Text("Buy me a coffee".localized)
                                         .font(.zen(.headline).bold())
                                 }
                                 .frame(maxWidth: .infinity)
                                 .padding()
                                 .background(Color.yellow.opacity(0.8))
                                 .foregroundStyle(.black)
                                 .clipShape(RoundedRectangle(cornerRadius: 12))
                                 .shadow(color: .yellow.opacity(0.3), radius: 5, x: 0, y: 2)
                             }
                             .buttonStyle(.plain)
                         }
                         .padding()
                         .background(Color.white.opacity(0.05))
                         .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(32)
                .padding(.bottom, 100) // Space for NowPlayingBar
            }
        }
    }
}

struct SettingsSection<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.zen(.title2).bold())
            
            content
        }
    }
}
