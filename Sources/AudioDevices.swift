import CoreAudio
import Foundation

struct InputDevice: Identifiable, Equatable {
    let id: AudioDeviceID
    let name: String
    let sampleRate: Double
    let bits: UInt32
    let channels: UInt32

    var formatLine: String {
        let bitText = bits == 0 ? "bit nativi" : "\(bits) bit"
        let channelText: String
        switch channels {
        case 1: channelText = "mono"
        case 2: channelText = "stereo"
        default: channelText = "\(channels) canali"
        }
        let rateText = sampleRate > 0 ? ItalianFormat.sampleRate(sampleRate) : "frequenza sconosciuta"
        return "\(rateText) · \(bitText) · \(channelText)"
    }

    var prefersMustang: Bool {
        let folded = name.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
        return folded.contains("mustang") || folded.contains("fender")
    }
}

enum AudioDevices {
    static func inputs() -> [InputDevice] {
        deviceIDs().compactMap(inputDevice(id:))
    }

    static func defaultInputID() -> AudioDeviceID? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var deviceID = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &size,
            &deviceID
        )
        guard status == noErr, deviceID != 0 else { return nil }
        return deviceID
    }

    private static func deviceIDs() -> [AudioDeviceID] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        let system = AudioObjectID(kAudioObjectSystemObject)
        guard AudioObjectGetPropertyDataSize(system, &address, 0, nil, &size) == noErr, size > 0 else {
            return []
        }
        let count = Int(size) / MemoryLayout<AudioDeviceID>.size
        var ids = [AudioDeviceID](repeating: 0, count: count)
        guard AudioObjectGetPropertyData(system, &address, 0, nil, &size, &ids) == noErr else {
            return []
        }
        return ids
    }

    private static func inputDevice(id: AudioDeviceID) -> InputDevice? {
        let channels = inputChannelCount(id)
        guard channels > 0 else { return nil }
        let format = streamFormat(id)
        let name = stringProperty(kAudioDevicePropertyDeviceNameCFString, device: id) ?? "Ingresso \(id)"
        let rate = (format?.sampleRate ?? 0) > 0 ? (format?.sampleRate ?? 0) : nominalSampleRate(id)
        return InputDevice(
            id: id,
            name: name,
            sampleRate: rate,
            bits: format?.bits ?? 0,
            channels: format?.channels ?? channels
        )
    }

    private static func inputChannelCount(_ device: AudioDeviceID) -> UInt32 {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: kAudioObjectPropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(device, &address, 0, nil, &size) == noErr, size > 0 else {
            return 0
        }
        let raw = UnsafeMutableRawPointer.allocate(byteCount: Int(size), alignment: MemoryLayout<AudioBufferList>.alignment)
        defer { raw.deallocate() }
        guard AudioObjectGetPropertyData(device, &address, 0, nil, &size, raw) == noErr else {
            return 0
        }
        let list = raw.bindMemory(to: AudioBufferList.self, capacity: 1)
        let buffers = UnsafeMutableAudioBufferListPointer(list)
        return buffers.reduce(UInt32(0)) { $0 + $1.mNumberChannels }
    }

    private static func streamFormat(_ device: AudioDeviceID) -> (sampleRate: Double, bits: UInt32, channels: UInt32)? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamFormat,
            mScope: kAudioObjectPropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        var asbd = AudioStreamBasicDescription()
        var size = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        guard AudioObjectGetPropertyData(device, &address, 0, nil, &size, &asbd) == noErr else {
            return nil
        }
        guard asbd.mChannelsPerFrame > 0 else { return nil }
        return (asbd.mSampleRate, asbd.mBitsPerChannel, asbd.mChannelsPerFrame)
    }

    private static func nominalSampleRate(_ device: AudioDeviceID) -> Double {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyNominalSampleRate,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var rate: Float64 = 0
        var size = UInt32(MemoryLayout<Float64>.size)
        guard AudioObjectGetPropertyData(device, &address, 0, nil, &size, &rate) == noErr else {
            return 0
        }
        return rate
    }

    private static func stringProperty(_ selector: AudioObjectPropertySelector, device: AudioDeviceID) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var value: CFString?
        var size = UInt32(MemoryLayout<CFString?>.size)
        let status = withUnsafeMutablePointer(to: &value) { pointer -> OSStatus in
            AudioObjectGetPropertyData(device, &address, 0, nil, &size, UnsafeMutableRawPointer(pointer))
        }
        guard status == noErr, let value else { return nil }
        return value as String
    }
}
