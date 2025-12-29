import Foundation
import CoreAudio
import AudioToolbox

/// Manages low-level audio output settings, including Exclusive Mode (Hog Mode)
class AudioOutputManager: ObservableObject {
    @Published var isAutoSampleRateMatchEnabled = false
    @Published var currentSampleRate: Double = 0
    @Published var availableDevices: [AudioDevice] = []
    
    static let shared = AudioOutputManager()
    
    // Tracks the current system default output device ID
    @Published var selectedDeviceID: AudioDeviceID = 0 {
        didSet {
            if selectedDeviceID != oldValue && selectedDeviceID != getSystemDefaultOutputDeviceID() {
                setOutputDevice(selectedDeviceID)
            }
        }
    }
    
    private func getSystemDefaultOutputDeviceID() -> AudioDeviceID? {
        var deviceID = kAudioObjectUnknown
        var dataSize = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        let result = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &dataSize,
            &deviceID
        )
        
        return result == noErr ? deviceID : nil
    }
    
    init() {
        updateDeviceStatus()
    }
    
    func updateDeviceStatus() {
        fetchAvailableDevices()
        
        if let defaultID = getSystemDefaultOutputDeviceID() {
            if self.selectedDeviceID != defaultID {
                self.selectedDeviceID = defaultID
            }
            
            // Get Sample Rate
            var sampleRate: Float64 = 0
            var dataSize = UInt32(MemoryLayout<Float64>.size)
            var address = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyNominalSampleRate,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            
            if AudioObjectGetPropertyData(defaultID, &address, 0, nil, &dataSize, &sampleRate) == noErr {
                self.currentSampleRate = sampleRate
            }
        }
    }
    
    func fetchAvailableDevices() {
        var propertySize: UInt32 = 0
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &propertySize) == noErr else { return }
        
        let deviceCount = Int(propertySize) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = [AudioDeviceID](repeating: 0, count: deviceCount)
        
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &propertySize, &deviceIDs) == noErr else { return }
        
        var devices: [AudioDevice] = []
        
        for id in deviceIDs {
            // Check if it has output channels
            var streamSize: UInt32 = 0
            var streamAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyStreams,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: kAudioObjectPropertyElementMain
            )
            
            AudioObjectGetPropertyDataSize(id, &streamAddress, 0, nil, &streamSize)
            
            if streamSize > 0 {
                let name = getDeviceName(id: id)
                devices.append(AudioDevice(id: id, name: name))
            }
        }
        
        DispatchQueue.main.async {
            self.availableDevices = devices
        }
    }
    
    private func getDeviceName(id: AudioDeviceID) -> String {
        var nameProp: Unmanaged<CFString>?
        var dataSize = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceNameCFString,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        if AudioObjectGetPropertyData(id, &address, 0, nil, &dataSize, &nameProp) == noErr {
            if let name = nameProp?.takeRetainedValue() {
                return name as String
            }
        }
        return "Unknown Device"
    }
    
    func setOutputDevice(_ deviceID: AudioDeviceID) {
        var id = deviceID
        let dataSize = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        let result = AudioObjectSetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            dataSize,
            &id
        )
        
        if result == noErr {
            print("Output device set to ID: \(id)")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.updateDeviceStatus()
            }
        } else {
            print("Failed to set output device: \(result)")
            if let defaultID = getSystemDefaultOutputDeviceID() {
                self.selectedDeviceID = defaultID
            }
        }
    }
    
    /// Sets the nominal sample rate of the current default output device
    func setDeviceSampleRate(_ rate: Double) {
        guard let deviceID = getSystemDefaultOutputDeviceID() else { return }
        
        var sampleRate = Float64(rate)
        let dataSize = UInt32(MemoryLayout<Float64>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyNominalSampleRate,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        // Check if writable (sometimes it's not)
        var writable: DarwinBoolean = false
        AudioObjectIsPropertySettable(deviceID, &address, &writable)
        
        if writable.boolValue {
           let result = AudioObjectSetPropertyData(
                deviceID,
                &address,
                0,
                nil,
                dataSize,
                &sampleRate
            )
            
            if result == noErr {
                 print("Set sample rate to: \(rate) Hz")
                 DispatchQueue.main.async {
                     self.currentSampleRate = rate
                 }
            } else {
                print("Failed to set sample rate: \(result)")
            }
        } else {
            print("Sample rate is not writable for this device")
        }
    }
}

struct AudioDevice: Identifiable, Hashable {
    let id: AudioDeviceID
    let name: String
}
