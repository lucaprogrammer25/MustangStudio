import AppKit
import AVFoundation
import AudioToolbox
import Combine

final class StudioEngine: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published var devices: [InputDevice] = []
    @Published var selectedID: AudioDeviceID?
    @Published var activeDevice: InputDevice?
    @Published var selectedPresetID = "pulito"
    @Published var gain: Double = 1
    @Published var displayPeak: Double = 0
    @Published var clipping = false
    @Published var isRecording = false
    @Published var isPlaying = false
    @Published var recordSeconds: TimeInterval = 0
    @Published var playbackSeconds: TimeInterval = 0
    @Published var takes: [Take] = []
    @Published var status = "Collega il Mustang II acceso, via USB."
    @Published var permissionDenied = false
    @Published var engineRunning = false
    @Published var playingTake: Int?
    @Published var playingClean = false
    @Published var folderURL: URL?

    var selectedPreset: TonePreset {
        TonePreset.preset(id: selectedPresetID)
    }

    private let engine = AVAudioEngine()
    private let gainNode = AVAudioMixerNode()
    private let dryMixer = AVAudioMixerNode()
    private let eq = AVAudioUnitEQ(numberOfBands: 6)
    private let drive = AVAudioUnitDistortion()
    private let delay = AVAudioUnitDelay()
    private let reverb = AVAudioUnitReverb()
    private let monitor = AVAudioMixerNode()
    private var dynamics: AVAudioUnit?
    private var limiter: AVAudioUnit?

    private let peaks = PeakHold()
    private let writerLock = NSLock()
    private var writer: DualWriter?
    private var captureFormat: AVAudioFormat?
    private var activeURLs: (clean: URL, processed: URL)?
    private var activeTakeNumber = 0

    private var attached = false
    private var tapsInstalled = false
    private var effectsReady = false
    private var effectsLoading = false
    private var started = false
    private var userPickedDevice = false
    private var runningDeviceID: AudioDeviceID?
    private var clipUntil: Date?
    private var audioPlayer: AVAudioPlayer?
    private var playingURL: URL?
    private var uiTimer: Timer?
    private var deviceTimer: Timer?

    private static let dynamicsDescription = AudioComponentDescription(
        componentType: kAudioUnitType_Effect,
        componentSubType: kAudioUnitSubType_DynamicsProcessor,
        componentManufacturer: kAudioUnitManufacturer_Apple,
        componentFlags: 0,
        componentFlagsMask: 0
    )

    private static let limiterDescription = AudioComponentDescription(
        componentType: kAudioUnitType_Effect,
        componentSubType: kAudioUnitSubType_PeakLimiter,
        componentManufacturer: kAudioUnitManufacturer_Apple,
        componentFlags: 0,
        componentFlagsMask: 0
    )

    func start() {
        guard !started else { return }
        started = true
        folderURL = try? TakeStore.directory()
        takes = TakeStore.load()
        switch AVAudioApplication.shared.recordPermission {
        case .granted:
            permissionDenied = false
            bootAudio()
        case .denied:
            permissionDenied = true
            status = "Accesso al microfono negato. Senza quel permesso non posso leggere il Mustang."
        case .undetermined:
            status = "In attesa del permesso di registrazione…"
            AVAudioApplication.requestRecordPermission { [weak self] granted in
                DispatchQueue.main.async {
                    guard let self else { return }
                    if granted {
                        self.permissionDenied = false
                        self.bootAudio()
                    } else {
                        self.permissionDenied = true
                        self.status = "Accesso al microfono negato. Senza quel permesso non posso leggere il Mustang."
                    }
                }
            }
        @unknown default:
            status = "Permesso di registrazione non disponibile."
        }
        uiTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        deviceTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            self?.pollDevices()
        }
    }

    func reconnect() {
        guard !isRecording else { return }
        bootAudio(forceRestart: true)
    }

    func userSelectedDevice(_ id: AudioDeviceID) {
        guard !isRecording, id != 0 else { return }
        userPickedDevice = true
        selectedID = id
        activeDevice = devices.first { $0.id == id }
        startGraph(deviceID: id)
    }

    func selectPreset(_ id: String) {
        guard !isRecording else { return }
        selectedPresetID = id
        applyPreset(TonePreset.preset(id: id))
    }

    func setGain(_ value: Double) {
        let clamped = min(2, max(0, value))
        gain = clamped
        gainNode.outputVolume = Float(clamped)
    }

    func toggleRecord() {
        if isRecording {
            stopRecording()
        } else {
            beginRecording()
        }
    }

    func play(_ take: Take, clean: Bool) {
        guard !isRecording else { return }
        let url = clean ? take.cleanURL : (take.processedURL ?? take.cleanURL)
        guard let url else { return }
        if isPlaying, playingURL == url {
            stopPlayback()
            status = "Ascolto fermato."
            return
        }
        stopPlayback()
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.delegate = self
            player.prepareToPlay()
            monitor.outputVolume = 0
            playingURL = url
            playingTake = take.number
            playingClean = clean
            isPlaying = true
            playbackSeconds = 0
            audioPlayer = player
            player.play()
            status = clean ? "Ascolto la traccia pulita di \(take.title)." : "Ascolto \(take.title) con \(take.presetName)."
        } catch {
            status = "Non riesco a riprodurre il file."
        }
    }

    func reveal(_ take: Take) {
        let urls = [take.processedURL, take.cleanURL].compactMap { $0 }
        guard !urls.isEmpty else { return }
        NSWorkspace.shared.activateFileViewerSelecting(urls)
    }

    func revealFolder() {
        guard let folderURL else { return }
        NSWorkspace.shared.open(folderURL)
    }

    func openMicrophoneSettings() {
        let candidates = [
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Microphone",
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone"
        ]
        for candidate in candidates {
            if let url = URL(string: candidate), NSWorkspace.shared.open(url) {
                return
            }
        }
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.isPlaying = false
            self.playingURL = nil
            self.playingTake = nil
            self.monitor.outputVolume = 1
        }
    }

    private func bootAudio(forceRestart: Bool = false) {
        loadEffects { [weak self] in
            self?.refreshDevicesAndStart(forceRestart: forceRestart)
        }
    }

    private func loadEffects(then start: @escaping () -> Void) {
        if effectsReady {
            start()
            return
        }
        if effectsLoading { return }
        effectsLoading = true
        let group = DispatchGroup()

        group.enter()
        AVAudioUnit.instantiate(with: Self.dynamicsDescription, options: []) { [weak self] unit, _ in
            DispatchQueue.main.async {
                self?.dynamics = unit
                group.leave()
            }
        }

        group.enter()
        AVAudioUnit.instantiate(with: Self.limiterDescription, options: []) { [weak self] unit, _ in
            DispatchQueue.main.async {
                self?.limiter = unit
                group.leave()
            }
        }

        group.notify(queue: .main) { [weak self] in
            guard let self else { return }
            self.effectsReady = true
            self.effectsLoading = false
            self.attachIfNeeded()
            start()
        }
    }

    private func attachIfNeeded() {
        guard !attached else { return }
        engine.attach(gainNode)
        engine.attach(dryMixer)
        engine.attach(eq)
        if let dynamics { engine.attach(dynamics) }
        engine.attach(drive)
        engine.attach(delay)
        engine.attach(reverb)
        if let limiter { engine.attach(limiter) }
        engine.attach(monitor)
        attached = true
    }

    private func refreshDevicesAndStart(forceRestart: Bool) {
        devices = AudioDevices.inputs()
        let current = selectedID.flatMap { id in devices.contains(where: { $0.id == id }) ? id : nil }
        let next: AudioDeviceID?
        if let current, userPickedDevice || !devices.contains(where: \.prefersMustang) {
            next = current
        } else if !userPickedDevice, let mustang = devices.first(where: \.prefersMustang) {
            next = mustang.id
        } else if let current {
            next = current
        } else if let fallback = AudioDevices.defaultInputID(), devices.contains(where: { $0.id == fallback }) {
            next = fallback
        } else {
            next = devices.first?.id
        }

        guard let next else {
            selectedID = nil
            activeDevice = nil
            stopGraph()
            status = "Nessun ingresso. Accendi il Mustang II e collegalo in USB."
            return
        }
        selectedID = next
        activeDevice = devices.first { $0.id == next }
        if forceRestart || runningDeviceID != next || !engine.isRunning {
            startGraph(deviceID: next)
        }
    }

    private func pollDevices() {
        let found = AudioDevices.inputs()
        devices = found
        if isRecording {
            if let selectedID, !found.contains(where: { $0.id == selectedID }) {
                stopRecording()
                status = "Ingresso scollegato. Ho salvato quello che c’era."
            }
            return
        }
        guard effectsReady, !isPlaying else { return }
        if !userPickedDevice, let mustang = found.first(where: \.prefersMustang), selectedID != mustang.id {
            selectedID = mustang.id
            activeDevice = mustang
            startGraph(deviceID: mustang.id)
            return
        }
        if selectedID == nil || !found.contains(where: { $0.id == selectedID }) {
            refreshDevicesAndStart(forceRestart: false)
        }
    }

    private func startGraph(deviceID: AudioDeviceID) {
        guard !isRecording else { return }
        guard effectsReady else {
            loadEffects { [weak self] in self?.startGraph(deviceID: deviceID) }
            return
        }
        attachIfNeeded()
        removeTaps()
        engine.stop()
        disconnectChain()
        engineRunning = false

        do {
            try engine.inputNode.auAudioUnit.setDeviceID(deviceID)
            try? engine.inputNode.setVoiceProcessingEnabled(false)

            let hardware = engine.inputNode.inputFormat(forBus: 0)
            let device = devices.first { $0.id == deviceID } ?? activeDevice
            let rate = (device?.sampleRate ?? 0) > 0 ? device!.sampleRate : hardware.sampleRate
            let channelCount = (device?.channels ?? 0) > 0
                ? AVAudioChannelCount(device!.channels)
                : hardware.channelCount
            guard rate > 0, channelCount > 0,
                  let format = AVAudioFormat(
                    commonFormat: .pcmFormatFloat32,
                    sampleRate: rate,
                    channels: channelCount,
                    interleaved: false
                  ) else {
                throw EngineFailure.invalidFormat
            }

            connectChain(format: format)
            gainNode.outputVolume = Float(gain)
            monitor.outputVolume = isPlaying ? 0 : 1
            engine.mainMixerNode.outputVolume = 1
            applyPreset(TonePreset.preset(id: selectedPresetID))
            captureFormat = format
            installTaps(format: format)
            engine.prepare()
            try engine.start()
            runningDeviceID = deviceID
            engineRunning = true
            if device?.prefersMustang == true {
                status = "Mustang collegato. Registro alla sua frequenza nativa, senza ricampionare."
            } else {
                status = "Ingresso attivo. Quando colleghi il Mustang II lo seleziono da solo."
            }
        } catch {
            runningDeviceID = nil
            engineRunning = false
            status = "Non riesco ad aprire l’ingresso. \(error.localizedDescription)"
        }
    }

    private func stopGraph() {
        removeTaps()
        engine.stop()
        engineRunning = false
        runningDeviceID = nil
    }

    private func connectChain(format: AVAudioFormat) {
        var nodes: [AVAudioNode] = [engine.inputNode, gainNode, dryMixer, eq]
        if let dynamics { nodes.append(dynamics) }
        nodes.append(contentsOf: [drive, delay, reverb])
        if let limiter { nodes.append(limiter) }
        nodes.append(monitor)
        for index in 0..<(nodes.count - 1) {
            engine.connect(nodes[index], to: nodes[index + 1], format: format)
        }
        engine.connect(monitor, to: engine.mainMixerNode, format: format)
    }

    private func disconnectChain() {
        var nodes: [AVAudioNode] = [engine.inputNode, gainNode, dryMixer, eq, drive, delay, reverb, monitor]
        if let dynamics { nodes.append(dynamics) }
        if let limiter { nodes.append(limiter) }
        for node in nodes {
            engine.disconnectNodeOutput(node)
        }
    }

    private func installTaps(format: AVAudioFormat) {
        removeTaps()
        dryMixer.installTap(onBus: 0, bufferSize: 4096, format: format) { [weak self] buffer, _ in
            self?.peaks.push(buffer)
            self?.withWriter { $0.writeClean(buffer) }
        }
        monitor.installTap(onBus: 0, bufferSize: 4096, format: format) { [weak self] buffer, _ in
            self?.peaks.push(buffer)
            self?.withWriter { $0.writeProcessed(buffer) }
        }
        tapsInstalled = true
    }

    private func removeTaps() {
        guard tapsInstalled else { return }
        dryMixer.removeTap(onBus: 0)
        monitor.removeTap(onBus: 0)
        tapsInstalled = false
    }

    private func applyPreset(_ preset: TonePreset) {
        applyEQ(preset.bands)
        applyDynamics(preset.dynamics)
        applyDrive(preset.drive)
        applyDelay(preset.delay)
        applyReverb(preset.reverb)
        applyLimiter(enabled: preset.usesLimiter)
    }

    private func applyEQ(_ bands: [EQBand]) {
        guard !bands.isEmpty else {
            eq.bypass = true
            eq.globalGain = 0
            return
        }
        eq.bypass = false
        eq.globalGain = 0
        for index in 0..<eq.bands.count {
            let band = eq.bands[index]
            if index < bands.count {
                let spec = bands[index]
                band.filterType = spec.type
                band.frequency = spec.frequency
                band.gain = spec.gain
                band.bandwidth = spec.bandwidth
                band.bypass = false
            } else {
                band.bypass = true
            }
        }
    }

    private func applyDynamics(_ settings: DynamicsSettings?) {
        guard let dynamics else { return }
        guard let settings else {
            setBypass(dynamics, true)
            return
        }
        setBypass(dynamics, false)
        setParameter(dynamics, kDynamicsProcessorParam_Threshold, settings.threshold)
        setParameter(dynamics, kDynamicsProcessorParam_HeadRoom, settings.headRoom)
        setParameter(dynamics, kDynamicsProcessorParam_ExpansionRatio, 1)
        setParameter(dynamics, kDynamicsProcessorParam_ExpansionThreshold, -40)
        setParameter(dynamics, kDynamicsProcessorParam_AttackTime, settings.attack)
        setParameter(dynamics, kDynamicsProcessorParam_ReleaseTime, settings.release)
        setParameter(dynamics, kDynamicsProcessorParam_OverallGain, settings.gain)
    }

    private func applyDrive(_ settings: DriveSettings?) {
        guard let settings else {
            drive.bypass = true
            drive.wetDryMix = 0
            return
        }
        drive.loadFactoryPreset(settings.preset)
        drive.preGain = settings.preGain
        drive.wetDryMix = settings.wet
        drive.bypass = false
    }

    private func applyDelay(_ settings: DelaySettings?) {
        guard let settings else {
            delay.bypass = true
            delay.wetDryMix = 0
            return
        }
        delay.delayTime = settings.time
        delay.feedback = settings.feedback
        delay.lowPassCutoff = settings.cutoff
        delay.wetDryMix = settings.wet
        delay.bypass = false
    }

    private func applyReverb(_ settings: ReverbSettings?) {
        guard let settings else {
            reverb.bypass = true
            reverb.wetDryMix = 0
            return
        }
        reverb.loadFactoryPreset(settings.preset)
        reverb.wetDryMix = settings.wet
        reverb.bypass = false
    }

    private func applyLimiter(enabled: Bool) {
        guard let limiter else { return }
        setBypass(limiter, !enabled)
        guard enabled else { return }
        setParameter(limiter, kLimiterParam_AttackTime, 0.002)
        setParameter(limiter, kLimiterParam_DecayTime, 0.020)
        setParameter(limiter, kLimiterParam_PreGain, 0)
    }

    private func setBypass(_ unit: AVAudioUnit, _ bypassed: Bool) {
        if let effect = unit as? AVAudioUnitEffect {
            effect.bypass = bypassed
            return
        }
        let audioUnit = unit.audioUnit
        var flag: UInt32 = bypassed ? 1 : 0
        AudioUnitSetProperty(
            audioUnit,
            kAudioUnitProperty_BypassEffect,
            kAudioUnitScope_Global,
            0,
            &flag,
            UInt32(MemoryLayout<UInt32>.size)
        )
    }

    private func setParameter(_ unit: AVAudioUnit, _ parameter: AudioUnitParameterID, _ value: Float) {
        AudioUnitSetParameter(unit.audioUnit, parameter, kAudioUnitScope_Global, 0, value, 0)
    }

    private func beginRecording() {
        guard !isRecording else { return }
        guard engine.isRunning, let format = captureFormat, format.sampleRate > 0, format.channelCount > 0 else {
            status = "L’ingresso non è pronto. Collega il Mustang e premi Ricollega."
            return
        }
        stopPlayback()
        let number = TakeStore.nextNumber()
        let stamp = TakeStore.stamp()
        let preset = selectedPreset
        do {
            let urls = try TakeStore.fileURLs(number: number, stamp: stamp, presetName: preset.name)
            let settings = wavSettings(format)
            let cleanFile = try AVAudioFile(
                forWriting: urls.clean,
                settings: settings,
                commonFormat: .pcmFormatFloat32,
                interleaved: format.isInterleaved
            )
            let processedFile = try AVAudioFile(
                forWriting: urls.processed,
                settings: settings,
                commonFormat: .pcmFormatFloat32,
                interleaved: format.isInterleaved
            )
            let dual = DualWriter(clean: cleanFile, processed: processedFile)
            writerLock.lock()
            writer = dual
            writerLock.unlock()
            activeURLs = urls
            activeTakeNumber = number
            recordSeconds = 0
            isRecording = true
            status = "Registrazione con «\(preset.name)». Il preset resta fisso fino allo Stop."
        } catch {
            status = "Non riesco a creare i WAV. \(error.localizedDescription)"
        }
    }

    private func stopRecording() {
        guard isRecording else { return }
        writerLock.lock()
        let finished = writer
        writer = nil
        writerLock.unlock()
        let snapshot = finished?.snapshot() ?? (frames: 0, failed: false)
        finished?.close()
        isRecording = false

        let seconds: TimeInterval
        if let format = captureFormat, format.sampleRate > 0 {
            seconds = Double(snapshot.frames) / format.sampleRate
        } else {
            seconds = 0
        }
        recordSeconds = seconds

        if snapshot.frames == 0 {
            if let activeURLs {
                try? FileManager.default.removeItem(at: activeURLs.clean)
                try? FileManager.default.removeItem(at: activeURLs.processed)
            }
            activeURLs = nil
            status = "Registrazione vuota. Non ho salvato nulla."
            return
        }

        takes = TakeStore.load()
        activeURLs = nil
        if snapshot.failed {
            status = "\(takeTitle(activeTakeNumber)) salvata, ma una scrittura su disco non è riuscita. Controlla i file."
        } else {
            status = "\(takeTitle(activeTakeNumber)) salvata in Musica/MustangStudio. Pulito e preset, WAV a 24 bit."
        }
    }

    private func stopPlayback() {
        audioPlayer?.stop()
        audioPlayer = nil
        isPlaying = false
        playingURL = nil
        playingTake = nil
        monitor.outputVolume = 1
    }

    private func tick() {
        let raw = Double(peaks.take())
        if raw >= displayPeak {
            displayPeak = raw
        } else {
            displayPeak = displayPeak * 0.82 + raw * 0.18
        }
        if displayPeak < 0.000_8 {
            displayPeak = 0
        }
        if raw >= 0.98 {
            clipping = true
            clipUntil = Date().addingTimeInterval(1.4)
        } else if let clipUntil, Date() > clipUntil {
            clipping = false
            self.clipUntil = nil
        }
        if isRecording {
            let frames = writerSnapshot().frames
            if let format = captureFormat, format.sampleRate > 0 {
                recordSeconds = Double(frames) / format.sampleRate
            }
        }
        if isPlaying, let audioPlayer {
            playbackSeconds = audioPlayer.currentTime
        }
    }

    private func withWriter(_ body: (DualWriter) -> Void) {
        writerLock.lock()
        let current = writer
        writerLock.unlock()
        if let current {
            body(current)
        }
    }

    private func writerSnapshot() -> (frames: AVAudioFramePosition, failed: Bool) {
        writerLock.lock()
        let current = writer
        writerLock.unlock()
        return current?.snapshot() ?? (0, false)
    }

    private func wavSettings(_ format: AVAudioFormat) -> [String: Any] {
        [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: format.sampleRate,
            AVNumberOfChannelsKey: Int(format.channelCount),
            AVLinearPCMBitDepthKey: 24,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false
        ]
    }

    private func takeTitle(_ number: Int) -> String {
        String(format: "Take %03d", number)
    }

    deinit {
        uiTimer?.invalidate()
        deviceTimer?.invalidate()
        engine.stop()
    }
}

private enum EngineFailure: LocalizedError {
    case invalidFormat

    var errorDescription: String? {
        switch self {
        case .invalidFormat:
            return "Il dispositivo non espone un formato audio valido."
        }
    }
}

private final class PeakHold: @unchecked Sendable {
    private let lock = NSLock()
    private var value: Float = 0

    func push(_ buffer: AVAudioPCMBuffer) {
        let level = Self.level(of: buffer)
        lock.lock()
        if level > value { value = level }
        lock.unlock()
    }

    func take() -> Float {
        lock.lock()
        let current = value
        value = 0
        lock.unlock()
        return current
    }

    private static func level(of buffer: AVAudioPCMBuffer) -> Float {
        guard let channels = buffer.floatChannelData else { return 0 }
        let frames = Int(buffer.frameLength)
        guard frames > 0 else { return 0 }
        var peak: Float = 0
        for channel in 0..<Int(buffer.format.channelCount) {
            let samples = channels[channel]
            for index in 0..<frames {
                let sample = abs(samples[index])
                if sample > peak { peak = sample }
            }
        }
        return peak
    }
}

private final class DualWriter: @unchecked Sendable {
    private let clean: AVAudioFile
    private let processed: AVAudioFile
    private let lock = NSLock()
    private var frames: AVAudioFramePosition = 0
    private var failed = false
    private var closed = false

    init(clean: AVAudioFile, processed: AVAudioFile) {
        self.clean = clean
        self.processed = processed
    }

    func writeClean(_ buffer: AVAudioPCMBuffer) {
        lock.lock()
        defer { lock.unlock() }
        guard !closed else { return }
        do {
            try clean.write(from: buffer)
            frames += AVAudioFramePosition(buffer.frameLength)
        } catch {
            failed = true
        }
    }

    func writeProcessed(_ buffer: AVAudioPCMBuffer) {
        lock.lock()
        defer { lock.unlock() }
        guard !closed else { return }
        do {
            try processed.write(from: buffer)
        } catch {
            failed = true
        }
    }

    func snapshot() -> (frames: AVAudioFramePosition, failed: Bool) {
        lock.lock()
        defer { lock.unlock() }
        return (frames, failed)
    }

    func close() {
        lock.lock()
        defer { lock.unlock() }
        guard !closed else { return }
        closed = true
        if #available(macOS 15.0, *) {
            clean.close()
            processed.close()
        }
    }
}
