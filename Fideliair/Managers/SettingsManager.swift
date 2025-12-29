import SwiftUI

class SettingsManager: ObservableObject {
    static let shared = SettingsManager()
    
    @AppStorage("selectedFontName") var selectedFontName: String = "Zen Kaku Gothic New"
    @AppStorage("fontSizeScale") var fontSizeScale: Double = 1.0
    @AppStorage("useSystemFont") var useSystemFont: Bool = false
    
    // List of available fonts
    let availableFonts = [
        "Zen Kaku Gothic New",
        "Helvetica Neue",
        "SF Pro",
        "Hiragino Sans",
        "Arial",
        "Courier New"
    ]
    
    func resetToDefaults() {
        selectedFontName = "Zen Kaku Gothic New"
        fontSizeScale = 1.0
        useSystemFont = false
    }
}
