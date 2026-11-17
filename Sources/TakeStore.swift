import AVFoundation
import Foundation

struct Take: Identifiable, Equatable {
    let number: Int
    let stamp: String
    let presetName: String
    let cleanURL: URL?
    let processedURL: URL?
    let duration: TimeInterval

    var id: Int { number }

    var title: String {
        String(format: "Take %03d", number)
    }

    var playedURL: URL? {
        processedURL ?? cleanURL
    }
}

enum TakeStore {
    static func directory() throws -> URL {
        let music = FileManager.default.urls(for: .musicDirectory, in: .userDomainMask)[0]
        let folder = music.appendingPathComponent("MustangStudio", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    static func load() -> [Take] {
        guard let folder = try? directory() else { return [] }
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: nil
        )) ?? []
        let pattern = try? NSRegularExpression(pattern: #"^Take (\d+) - (\d{8}-\d{4}) - (.+)\.wav$"#)
        guard let pattern else { return [] }

        struct Parts {
            var stamp: String
            var clean: URL?
            var processed: URL?
            var presetName: String = "Pulito"
        }
        var grouped: [Int: Parts] = [:]

        for url in urls where url.pathExtension.lowercased() == "wav" {
            let name = url.lastPathComponent
            let range = NSRange(name.startIndex..., in: name)
            guard let match = pattern.firstMatch(in: name, range: range),
                  match.numberOfRanges == 4,
                  let numberRange = Range(match.range(at: 1), in: name),
                  let stampRange = Range(match.range(at: 2), in: name),
                  let titleRange = Range(match.range(at: 3), in: name),
                  let number = Int(name[numberRange]) else {
                continue
            }
            var parts = grouped[number] ?? Parts(stamp: String(name[stampRange]))
            parts.stamp = String(name[stampRange])
            let title = String(name[titleRange])
            if title == "pulito" {
                parts.clean = url
            } else {
                parts.processed = url
                parts.presetName = title
            }
            grouped[number] = parts
        }

        return grouped.keys.sorted(by: >).map { number in
            let parts = grouped[number]!
            let url = parts.processed ?? parts.clean
            return Take(
                number: number,
                stamp: parts.stamp,
                presetName: parts.presetName,
                cleanURL: parts.clean,
                processedURL: parts.processed,
                duration: url.flatMap(duration(of:)) ?? 0
            )
        }
    }

    static func nextNumber() -> Int {
        (load().map(\.number).max() ?? 0) + 1
    }

    static func fileURLs(number: Int, stamp: String, presetName: String) throws -> (clean: URL, processed: URL) {
        let folder = try directory()
        let prefix = String(format: "Take %03d - %@", number, stamp)
        let clean = folder.appendingPathComponent("\(prefix) - pulito.wav")
        // Il disco del Mac non distingue le maiuscole: "Pulito.wav" e "pulito.wav" sono lo stesso file.
        let processedTitle = presetName.compare("pulito", options: .caseInsensitive) == .orderedSame
            ? "Pulito (preset)"
            : safeFileName(presetName)
        let processed = folder.appendingPathComponent("\(prefix) - \(processedTitle).wav")
        return (clean, processed)
    }

    static func stamp(for date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmm"
        return formatter.string(from: date)
    }

    static func displayStamp(_ stamp: String) -> String {
        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.dateFormat = "yyyyMMdd-HHmm"
        guard let date = parser.date(from: stamp) else { return stamp }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "it_IT")
        formatter.dateFormat = "d MMM yyyy, HH:mm"
        return formatter.string(from: date)
    }

    private static func safeFileName(_ name: String) -> String {
        let cleaned = name.replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        return cleaned.isEmpty ? "preset" : cleaned
    }

    private static func duration(of url: URL) -> TimeInterval? {
        guard let file = try? AVAudioFile(forReading: url) else { return nil }
        let rate = file.processingFormat.sampleRate
        guard rate > 0 else { return nil }
        return Double(file.length) / rate
    }
}
