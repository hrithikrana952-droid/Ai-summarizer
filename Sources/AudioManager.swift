import AVFoundation

class AudioManager: NSObject, AVCaptureFileOutputRecordingDelegate {
    private var micSession = AVCaptureSession()
    private var blackholeSession = AVCaptureSession()
    
    private var micOutput = AVCaptureAudioFileOutput()
    private var blackholeOutput = AVCaptureAudioFileOutput()
    
    private let micURL = FileManager.default.temporaryDirectory.appendingPathComponent("mic.m4a")
    private let blackholeURL = FileManager.default.temporaryDirectory.appendingPathComponent("system.m4a")
    
    override init() {
        super.init()
    }
    
    func requestPermissionsAndSetup() async {
        let granted = await AVCaptureDevice.requestAccess(for: .audio)
        if granted {
            setupSessions()
        } else {
            print("Microphone permission denied.")
        }
    }
    
    private func setupSessions() {
        let devices = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInMicrophone, .microphone], mediaType: .audio, position: .unspecified).devices
        
        var micDevice: AVCaptureDevice?
        var blackholeDevice: AVCaptureDevice?
        
        for device in devices {
            print("Found Audio Device: \\(device.localizedName)")
            if device.localizedName.contains("BlackHole") {
                blackholeDevice = device
            } else if micDevice == nil {
                micDevice = device
            }
        }
        
        if let mic = micDevice, let input = try? AVCaptureDeviceInput(device: mic) {
            if micSession.canAddInput(input) { micSession.addInput(input) }
            if micSession.canAddOutput(micOutput) { micSession.addOutput(micOutput) }
        } else {
            print("Could not setup Mic input")
        }
        
        if let bh = blackholeDevice, let input = try? AVCaptureDeviceInput(device: bh) {
            if blackholeSession.canAddInput(input) { blackholeSession.addInput(input) }
            if blackholeSession.canAddOutput(blackholeOutput) { blackholeSession.addOutput(blackholeOutput) }
        } else {
            print("Could not setup BlackHole input")
        }
    }
    
    func startRecording() {
        if micSession.inputs.isEmpty && blackholeSession.inputs.isEmpty {
            setupSessions()
        }
        
        print("Starting audio recording...")
        if FileManager.default.fileExists(atPath: micURL.path) { try? FileManager.default.removeItem(at: micURL) }
        if FileManager.default.fileExists(atPath: blackholeURL.path) { try? FileManager.default.removeItem(at: blackholeURL) }
        
        micSession.startRunning()
        blackholeSession.startRunning()
        
        micOutput.startRecording(to: micURL, outputFileType: .m4a, recordingDelegate: self)
        blackholeOutput.startRecording(to: blackholeURL, outputFileType: .m4a, recordingDelegate: self)
    }
    
    func stopRecording() {
        print("Stopping audio recording...")
        micOutput.stopRecording()
        blackholeOutput.stopRecording()
        
        micSession.stopRunning()
        blackholeSession.stopRunning()
        
        // Transcription will be triggered from the app delegate when recording finishes
    }
    
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        if let error = error {
            print("Recording error for \\(outputFileURL.lastPathComponent): \\(error)")
        } else {
            print("Successfully recorded \\(outputFileURL.lastPathComponent)")
        }
    }
}
