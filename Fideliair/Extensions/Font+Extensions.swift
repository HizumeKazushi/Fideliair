import SwiftUI

extension Font {
    // Helper to get current settings
    private static var settingsInfo: (name: String, scale: Double, useSystem: Bool) {
        let defaults = UserDefaults.standard
        let name = defaults.string(forKey: "selectedFontName") ?? "Zen Kaku Gothic New"
        let scale = defaults.double(forKey: "fontSizeScale")
        let useSystem = defaults.bool(forKey: "useSystemFont")
        // Default scale is 1.0 if not set (double returns 0 if missing, so handle that)
        let actualScale = scale == 0 ? 1.0 : scale
        return (name, actualScale, useSystem)
    }

    static func zen(_ style: Font.TextStyle) -> Font {
        let (name, scale, useSystem) = settingsInfo
        
        // Base sizes for each style
        let baseSize: CGFloat
        switch style {
        case .largeTitle: baseSize = 34
        case .title: baseSize = 28
        case .title2: baseSize = 22
        case .title3: baseSize = 20
        case .headline: baseSize = 17
        case .subheadline: baseSize = 15
        case .body: baseSize = 17
        case .callout: baseSize = 16
        case .footnote: baseSize = 13
        case .caption: baseSize = 12
        case .caption2: baseSize = 11
        @unknown default: baseSize = 17
        }
        
        let scaledSize = baseSize * scale
        
        if useSystem {
            // Apply weight for specific styles if needed
            switch style {
            case .headline: return .system(size: scaledSize, weight: .semibold)
            default: return .system(size: scaledSize)
            }
        } else {
            // Support "SF Pro" mapping to system font if selected manually, otherwise custom
            if name == "SF Pro" {
                 switch style {
                case .headline: return .system(size: scaledSize, weight: .semibold)
                default: return .system(size: scaledSize)
                }
            } else {
                switch style {
                case .headline: return .custom(name, size: scaledSize).weight(.semibold)
                default: return .custom(name, size: scaledSize)
                }
            }
        }
    }
    
    // Helper to replace .system(size:weight:)
    static func zen(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let (name, scale, useSystem) = settingsInfo
        let scaledSize = size * scale
        
        if useSystem || name == "SF Pro" {
            return .system(size: scaledSize, weight: weight)
        } else {
            return .custom(name, size: scaledSize).weight(weight)
        }
    }
}
