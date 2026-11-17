import CoreAudio
import SwiftUI

struct ContentView: View {
    @StateObject private var studio = StudioEngine()

    var body: some View {
        HStack(spacing: 0) {
            sessionColumn
            Rectangle()
                .fill(Theme.line)
                .frame(width: 1)
            libraryColumn
        }
        .frame(minWidth: 1040, minHeight: 680)
        .background(Theme.bg)
        .preferredColorScheme(.dark)
        .onAppear { studio.start() }
    }

    private var sessionColumn: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            deviceCard
            meterCard
            presetCard
            transport
            Text(studio.status)
                .font(.system(size: 12))
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Text("L’ascolto esce dal Mac. Il Mustang II non rimanda l’audio del computer via USB. Sul ampli tieni un suono clean e il volume sotto il clip: l’USB porta il segnale già passato dal modello dell’ampli.")
                .font(.system(size: 11))
                .foregroundStyle(Theme.muted.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text("MUSTANG STUDIO")
                    .font(.system(size: 22, weight: .semibold, design: .serif))
                    .tracking(1.4)
                    .foregroundStyle(Theme.text)
                Text("Registrazione chitarra")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.muted)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(studio.activeDevice?.formatLine ?? "In attesa del dispositivo")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(Theme.amber)
                Text("WAV 24-bit, frequenza nativa")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.muted)
            }
        }
    }

    private var deviceCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Ingresso")
            HStack(spacing: 10) {
                Picker("Dispositivo", selection: deviceBinding) {
                    if studio.devices.isEmpty {
                        Text("Nessun ingresso").tag(AudioDeviceID(0))
                    }
                    ForEach(studio.devices) { device in
                        Text(device.name).tag(device.id)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .disabled(studio.isRecording)
                .frame(maxWidth: .infinity, alignment: .leading)

                Button("Ricollega") { studio.reconnect() }
                    .buttonStyle(QuietButtonStyle())
                    .disabled(studio.isRecording)
            }
            if studio.permissionDenied {
                Button("Apri le impostazioni del microfono") {
                    studio.openMicrophoneSettings()
                }
                .buttonStyle(QuietButtonStyle())
            }
        }
    }

    private var meterCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                sectionLabel("Livello")
                Spacer()
                Text(studio.clipping ? "CLIP" : ItalianFormat.levelDecibels(studio.displayPeak))
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(studio.clipping ? Theme.clip : Theme.text)
            }
            LevelMeter(level: studio.displayPeak, clipping: studio.clipping)
            HStack {
                Text("Guadagno")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.muted)
                Slider(value: gainBinding, in: 0...2)
                    .tint(Theme.amber)
                Text(gainLabel)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(Theme.text)
                    .frame(width: 118, alignment: .trailing)
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.panel))
    }

    private var presetCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionLabel("Preset")
                Spacer()
                if studio.isRecording {
                    Text("Bloccato durante la take")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.amber)
                }
            }
            presetButton(TonePreset.preset(id: "pulito"))
            presetSection(.acoustic)
            presetSection(.electric)
            Text(studio.selectedPreset.summary)
                .font(.system(size: 12))
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func presetSection(_ family: ToneFamily) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(family.title.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.1)
                .foregroundStyle(Theme.accent(for: family))
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 148), spacing: 8)], spacing: 8) {
                ForEach(TonePreset.all.filter { $0.family == family }) { preset in
                    presetButton(preset)
                }
            }
        }
    }

    private func presetButton(_ preset: TonePreset) -> some View {
        let selected = studio.selectedPresetID == preset.id
        return Button {
            studio.selectPreset(preset.id)
        } label: {
            Text(preset.name)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.text)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(selected ? Theme.accent(for: preset.family).opacity(0.18) : Theme.panelRaised)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(selected ? Theme.accent(for: preset.family) : Color.white.opacity(0.04), lineWidth: 1.4)
                )
        }
        .buttonStyle(.plain)
        .disabled(studio.isRecording)
    }

    private var transport: some View {
        HStack(spacing: 12) {
            Button(action: studio.toggleRecord) {
                HStack(spacing: 10) {
                    Circle()
                        .fill(studio.isRecording ? Color.white : Theme.clip)
                        .frame(width: 12, height: 12)
                    Text(studio.isRecording ? "Stop" : "Registra")
                        .font(.system(size: 16, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .foregroundStyle(.white)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(studio.isRecording ? Theme.clip : Color(red: 0.55, green: 0.16, blue: 0.13))
                )
            }
            .buttonStyle(.plain)
            .disabled(!studio.engineRunning && !studio.isRecording)
            .keyboardShortcut(.space, modifiers: [])

            Text(ItalianFormat.clock(studio.isPlaying && !studio.isRecording ? studio.playbackSeconds : studio.recordSeconds))
                .font(.system(size: 28, weight: .medium, design: .monospaced))
                .foregroundStyle(studio.isRecording ? Theme.clip : Theme.text)
                .frame(width: 110, alignment: .trailing)
        }
    }

    private var libraryColumn: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                sectionLabel("Take")
                Spacer()
                Button("Apri cartella") { studio.revealFolder() }
                    .buttonStyle(QuietButtonStyle())
            }
            if studio.takes.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Nessuna take")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.text)
                    Text("Ogni registrazione salva due WAV: la copia pulita dell’ingresso e la stessa take con il preset.")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.muted)
                }
                .padding(.top, 12)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(studio.takes) { take in
                            takeRow(take)
                        }
                    }
                }
            }
        }
        .padding(24)
        .frame(width: 380)
        .background(Theme.panel.opacity(0.55))
    }

    private func takeRow(_ take: Take) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(take.title)
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Theme.text)
                Spacer()
                Text(ItalianFormat.clock(take.duration))
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(Theme.muted)
            }
            Text("\(take.presetName) · \(TakeStore.displayStamp(take.stamp))")
                .font(.system(size: 12))
                .foregroundStyle(Theme.muted)
            HStack(spacing: 6) {
                Button(studio.playingTake == take.number && studio.isPlaying && !studio.playingClean ? "Stop" : "Ascolta") {
                    studio.play(take, clean: false)
                }
                .buttonStyle(QuietButtonStyle())
                .disabled(take.playedURL == nil || studio.isRecording)
                if take.cleanURL != nil {
                    Button(studio.playingTake == take.number && studio.isPlaying && studio.playingClean ? "Stop" : "Pulito") {
                        studio.play(take, clean: true)
                    }
                    .buttonStyle(QuietButtonStyle())
                    .disabled(studio.isRecording)
                }
                Button("Finder") { studio.reveal(take) }
                    .buttonStyle(QuietButtonStyle())
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.panelRaised))
    }

    private var deviceBinding: Binding<AudioDeviceID> {
        Binding(
            get: { studio.selectedID ?? 0 },
            set: { studio.userSelectedDevice($0) }
        )
    }

    private var gainBinding: Binding<Double> {
        Binding(
            get: { studio.gain },
            set: { studio.setGain($0) }
        )
    }

    private var gainLabel: String {
        let percent = Int((studio.gain * 100).rounded())
        return "\(percent)%  \(ItalianFormat.decibels(studio.gain))"
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 10, weight: .semibold))
            .tracking(1.2)
            .foregroundStyle(Theme.muted)
    }
}

private struct LevelMeter: View {
    var level: Double
    var clipping: Bool

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color.white.opacity(0.06))
                RoundedRectangle(cornerRadius: 5)
                    .fill(clipping ? Theme.clip : Theme.amber)
                    .frame(width: max(0, geo.size.width * min(level, 1)))
            }
        }
        .frame(height: 16)
    }
}

private struct QuietButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Theme.text)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Theme.panelRaised.opacity(configuration.isPressed ? 1 : 0.8))
            )
    }
}
