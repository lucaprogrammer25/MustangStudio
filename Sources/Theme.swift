import SwiftUI

enum Theme {
    static let bg = Color(red: 0.07, green: 0.066, blue: 0.058)
    static let panel = Color(red: 0.12, green: 0.112, blue: 0.098)
    static let panelRaised = Color(red: 0.17, green: 0.155, blue: 0.135)
    static let line = Color.white.opacity(0.08)
    static let text = Color(red: 0.96, green: 0.94, blue: 0.89)
    static let muted = Color(red: 0.70, green: 0.66, blue: 0.58)
    static let amber = Color(red: 0.88, green: 0.64, blue: 0.30)
    static let electric = Color(red: 0.42, green: 0.70, blue: 0.74)
    static let clean = Color(red: 0.84, green: 0.81, blue: 0.72)
    static let clip = Color(red: 0.90, green: 0.28, blue: 0.22)
    static let ok = Color(red: 0.55, green: 0.73, blue: 0.42)

    static func accent(for family: ToneFamily) -> Color {
        switch family {
        case .clean: return clean
        case .acoustic: return amber
        case .electric: return electric
        }
    }
}

enum ItalianFormat {
    static func decibels(_ linearGain: Double) -> String {
        if linearGain <= 0.000_1 { return "−∞ dB" }
        let db = 20 * log10(linearGain)
        if abs(db) < 0.05 { return "0 dB" }
        return String(format: "%+.1f dB", db).replacingOccurrences(of: ".", with: ",")
    }

    static func levelDecibels(_ peak: Double) -> String {
        if peak <= 0.000_01 { return "−∞ dB" }
        let db = 20 * log10(peak)
        if db < -80 { return "−∞ dB" }
        return String(format: "%.0f dB", db).replacingOccurrences(of: ".", with: ",")
    }

    static func sampleRate(_ rate: Double) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "it_IT")
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        let number = formatter.string(from: NSNumber(value: rate)) ?? "\(Int(rate))"
        return "\(number) Hz"
    }

    static func clock(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded(.down)))
        if total >= 3600 {
            return String(format: "%d:%02d:%02d", total / 3600, (total / 60) % 60, total % 60)
        }
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}
