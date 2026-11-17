import AVFoundation

enum ToneFamily: String, CaseIterable {
    case clean
    case acoustic
    case electric

    var title: String {
        switch self {
        case .clean: return "Pulito"
        case .acoustic: return "Acustica"
        case .electric: return "Elettrica"
        }
    }
}

struct EQBand {
    var type: AVAudioUnitEQFilterType
    var frequency: Float
    var gain: Float
    var bandwidth: Float
}

struct DynamicsSettings {
    var threshold: Float
    var headRoom: Float
    var attack: Float
    var release: Float
    var gain: Float
}

struct DriveSettings {
    var preset: AVAudioUnitDistortionPreset
    var preGain: Float
    var wet: Float
}

struct DelaySettings {
    var time: TimeInterval
    var feedback: Float
    var cutoff: Float
    var wet: Float
}

struct ReverbSettings {
    var preset: AVAudioUnitReverbPreset
    var wet: Float
}

struct TonePreset: Identifiable, Equatable {
    let id: String
    let name: String
    let family: ToneFamily
    let summary: String
    let bands: [EQBand]
    let dynamics: DynamicsSettings?
    let drive: DriveSettings?
    let delay: DelaySettings?
    let reverb: ReverbSettings?

    static func == (lhs: TonePreset, rhs: TonePreset) -> Bool {
        lhs.id == rhs.id
    }

    var usesLimiter: Bool { drive != nil }

    static let all: [TonePreset] = [
        TonePreset(
            id: "pulito",
            name: "Pulito",
            family: .clean,
            summary: "Nessun effetto. Resta solo il guadagno che imposti tu, sul segnale USB così com’è.",
            bands: [],
            dynamics: nil,
            drive: nil,
            delay: nil,
            reverb: nil
        ),
        TonePreset(
            id: "acustica-naturale",
            name: "Acustica naturale",
            family: .acoustic,
            summary: "Taglio sotto i 75 Hz, un filo di presenza e una stanza corta.",
            bands: [
                EQBand(type: .highPass, frequency: 75, gain: 0, bandwidth: 0.5),
                EQBand(type: .lowShelf, frequency: 200, gain: 1.5, bandwidth: 0.7),
                EQBand(type: .parametric, frequency: 350, gain: -1.5, bandwidth: 1.0),
                EQBand(type: .parametric, frequency: 2_500, gain: 1.2, bandwidth: 1.0),
                EQBand(type: .parametric, frequency: 5_000, gain: 2.0, bandwidth: 0.8),
                EQBand(type: .highShelf, frequency: 10_000, gain: 1.0, bandwidth: 0.5)
            ],
            dynamics: DynamicsSettings(threshold: -18, headRoom: 10, attack: 0.010, release: 0.15, gain: 0.5),
            drive: nil,
            delay: nil,
            reverb: ReverbSettings(preset: .smallRoom, wet: 8)
        ),
        TonePreset(
            id: "acustica-calda",
            name: "Acustica calda",
            family: .acoustic,
            summary: "Più corpo sui bassi, alte arrotondate, compressione morbida.",
            bands: [
                EQBand(type: .highPass, frequency: 60, gain: 0, bandwidth: 0.5),
                EQBand(type: .lowShelf, frequency: 160, gain: 3.0, bandwidth: 0.7),
                EQBand(type: .parametric, frequency: 800, gain: 1.0, bandwidth: 1.0),
                EQBand(type: .parametric, frequency: 3_000, gain: -1.5, bandwidth: 1.0),
                EQBand(type: .highShelf, frequency: 8_000, gain: -2.0, bandwidth: 0.5)
            ],
            dynamics: DynamicsSettings(threshold: -16, headRoom: 12, attack: 0.012, release: 0.18, gain: 0),
            drive: nil,
            delay: nil,
            reverb: ReverbSettings(preset: .mediumRoom, wet: 10)
        ),
        TonePreset(
            id: "acustica-fingerstyle",
            name: "Acustica fingerstyle",
            family: .acoustic,
            summary: "Dinamica aperta, aria sulle alte e un riverbero piccolo.",
            bands: [
                EQBand(type: .highPass, frequency: 80, gain: 0, bandwidth: 0.5),
                EQBand(type: .lowShelf, frequency: 180, gain: 0.5, bandwidth: 0.7),
                EQBand(type: .parametric, frequency: 400, gain: -1.0, bandwidth: 1.0),
                EQBand(type: .parametric, frequency: 1_800, gain: 1.5, bandwidth: 0.9),
                EQBand(type: .parametric, frequency: 6_000, gain: 2.5, bandwidth: 0.8),
                EQBand(type: .highShelf, frequency: 12_000, gain: 2.0, bandwidth: 0.5)
            ],
            dynamics: DynamicsSettings(threshold: -24, headRoom: 14, attack: 0.020, release: 0.22, gain: 0),
            drive: nil,
            delay: nil,
            reverb: ReverbSettings(preset: .smallRoom, wet: 12)
        ),
        TonePreset(
            id: "elettrica-clean",
            name: "Elettrica clean",
            family: .electric,
            summary: "Compressione leggera, brillantezza e un plate corto.",
            bands: [
                EQBand(type: .highPass, frequency: 70, gain: 0, bandwidth: 0.5),
                EQBand(type: .lowShelf, frequency: 150, gain: 1.0, bandwidth: 0.7),
                EQBand(type: .parametric, frequency: 800, gain: 0.5, bandwidth: 1.0),
                EQBand(type: .parametric, frequency: 2_000, gain: 2.0, bandwidth: 0.9),
                EQBand(type: .highShelf, frequency: 6_500, gain: 2.5, bandwidth: 0.5)
            ],
            dynamics: DynamicsSettings(threshold: -20, headRoom: 8, attack: 0.006, release: 0.10, gain: 0.5),
            drive: nil,
            delay: nil,
            reverb: ReverbSettings(preset: .plate, wet: 10)
        ),
        TonePreset(
            id: "elettrica-crunch",
            name: "Elettrica crunch",
            family: .electric,
            summary: "Overdrive leggero e medi in primo piano.",
            bands: [
                EQBand(type: .highPass, frequency: 90, gain: 0, bandwidth: 0.5),
                EQBand(type: .lowShelf, frequency: 180, gain: -1.0, bandwidth: 0.7),
                EQBand(type: .parametric, frequency: 750, gain: 3.0, bandwidth: 1.0),
                EQBand(type: .parametric, frequency: 2_200, gain: 2.0, bandwidth: 0.9),
                EQBand(type: .highShelf, frequency: 6_500, gain: 1.0, bandwidth: 0.5)
            ],
            dynamics: DynamicsSettings(threshold: -14, headRoom: 6, attack: 0.004, release: 0.08, gain: 0),
            drive: DriveSettings(preset: .multiDistortedSquared, preGain: -10, wet: 22),
            delay: nil,
            reverb: ReverbSettings(preset: .smallRoom, wet: 6)
        ),
        TonePreset(
            id: "elettrica-lead",
            name: "Elettrica lead",
            family: .electric,
            summary: "Drive, delay breve e plate.",
            bands: [
                EQBand(type: .highPass, frequency: 100, gain: 0, bandwidth: 0.5),
                EQBand(type: .parametric, frequency: 1_000, gain: 3.0, bandwidth: 1.0),
                EQBand(type: .parametric, frequency: 3_000, gain: 2.5, bandwidth: 0.9),
                EQBand(type: .highShelf, frequency: 7_000, gain: 1.0, bandwidth: 0.5)
            ],
            dynamics: DynamicsSettings(threshold: -16, headRoom: 5, attack: 0.003, release: 0.10, gain: 1),
            drive: DriveSettings(preset: .multiDistortedFunk, preGain: -6, wet: 30),
            delay: DelaySettings(time: 0.22, feedback: 22, cutoff: 3_500, wet: 14),
            reverb: ReverbSettings(preset: .plate, wet: 16)
        ),
        TonePreset(
            id: "elettrica-jazz",
            name: "Elettrica jazz",
            family: .electric,
            summary: "Alte chiuse, medi caldi, compressione morbida.",
            bands: [
                EQBand(type: .highPass, frequency: 80, gain: 0, bandwidth: 0.5),
                EQBand(type: .lowShelf, frequency: 200, gain: 2.0, bandwidth: 0.7),
                EQBand(type: .parametric, frequency: 500, gain: 1.5, bandwidth: 1.0),
                EQBand(type: .parametric, frequency: 2_500, gain: -2.0, bandwidth: 1.0),
                EQBand(type: .highShelf, frequency: 5_000, gain: -4.0, bandwidth: 0.5)
            ],
            dynamics: DynamicsSettings(threshold: -18, headRoom: 9, attack: 0.010, release: 0.16, gain: 0),
            drive: nil,
            delay: nil,
            reverb: ReverbSettings(preset: .mediumRoom, wet: 8)
        )
    ]

    static func preset(id: String) -> TonePreset {
        all.first { $0.id == id } ?? all[0]
    }
}
