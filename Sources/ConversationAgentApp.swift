import SwiftUI

@main
struct ConversationAgentApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra("Conversation Agent", systemImage: appDelegate.isRecording ? "record.circle.fill" : "waveform.circle") {
            Button(appDelegate.isRecording ? "Stop Recording (⌥⇧F)" : "Start Recording (⌥⇧F)") {
                appDelegate.toggleRecording()
            }
            Divider()
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    @Published var isRecording = false
    private var hotkeyManager: HotkeyManager?
    private var screenCaptureManager: ScreenCaptureManager?
    private var audioManager: AudioManager?
    
    private var currentSessionPath: URL?
    
    private func debugLog(_ message: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let line = "[\(timestamp)] \(message)\n"
        print(line, terminator: "")
        
        if let sessionPath = currentSessionPath {
            let logURL = sessionPath.appendingPathComponent("debug.log")
            if let data = line.data(using: .utf8) {
                if let handle = try? FileHandle(forWritingTo: logURL) {
                    handle.seekToEndOfFile()
                    handle.write(data)
                    handle.closeFile()
                } else {
                    try? data.write(to: logURL)
                }
            }
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        hotkeyManager = HotkeyManager()
        screenCaptureManager = ScreenCaptureManager()
        audioManager = AudioManager()
        
        hotkeyManager?.onToggleRecording = { [weak self] in
            self?.toggleRecording()
        }
        
        // Request Permissions Sequentially
        Task {
            await audioManager?.requestPermissionsAndSetup()
            await screenCaptureManager?.requestPermissions()
        }
    }

    func toggleRecording() {
        isRecording.toggle()
        if isRecording {
            currentSessionPath = VaultManager.shared.createSession()
            debugLog("Started recording session...")
            screenCaptureManager?.startCapture()
            audioManager?.startRecording()
        } else {
            debugLog("Stopped recording session.")
            screenCaptureManager?.stopCapture()
            audioManager?.stopRecording()
            
            // Trigger transcription
            Task {
                debugLog("--- Starting Transcription & Summarization ---")
                
                var fullTranscript = ""
                
                let micM4A = FileManager.default.temporaryDirectory.appendingPathComponent("mic.m4a")
                debugLog("Checking mic file: \(micM4A.path) exists=\(FileManager.default.fileExists(atPath: micM4A.path))")
                if FileManager.default.fileExists(atPath: micM4A.path) {
                    let micTranscript = await TranscriptionManager.shared.transcribe(m4aURL: micM4A)
                    debugLog("Mic transcript result: \(micTranscript == nil ? "nil" : "got \(micTranscript!.count) chars")")
                    if let micTranscript = micTranscript {
                        fullTranscript += "User (Me):\n\(micTranscript)\n\n"
                    }
                }
                
                let systemM4A = FileManager.default.temporaryDirectory.appendingPathComponent("system.m4a")
                debugLog("Checking system file: \(systemM4A.path) exists=\(FileManager.default.fileExists(atPath: systemM4A.path))")
                if FileManager.default.fileExists(atPath: systemM4A.path) {
                    let systemTranscript = await TranscriptionManager.shared.transcribe(m4aURL: systemM4A)
                    debugLog("System transcript result: \(systemTranscript == nil ? "nil" : "got \(systemTranscript!.count) chars")")
                    if let systemTranscript = systemTranscript {
                        fullTranscript += "System (Other Party):\n\(systemTranscript)\n\n"
                    }
                }
                
                let ocrFileURL = FileManager.default.temporaryDirectory.appendingPathComponent("ocr.txt")
                debugLog("Checking OCR file: \(ocrFileURL.path) exists=\(FileManager.default.fileExists(atPath: ocrFileURL.path))")
                if FileManager.default.fileExists(atPath: ocrFileURL.path) {
                    if let ocrText = try? String(contentsOf: ocrFileURL, encoding: .utf8) {
                        debugLog("OCR text: \(ocrText.count) chars")
                        fullTranscript += "On-Screen Visual Context (OCR):\n\(ocrText)\n\n"
                    }
                }
                
                debugLog("Full transcript length: \(fullTranscript.count) chars")
                debugLog("Full transcript preview: \(String(fullTranscript.prefix(500)))")
                
                if !fullTranscript.isEmpty {
                    debugLog("Sending to Ollama (qwen2.5:32b) for summarization...")
                    let sessionLogURL = self.currentSessionPath?.appendingPathComponent("debug.log")
                    if let jsonSummary = await OllamaManager.shared.summarize(transcript: fullTranscript, sessionLogURL: sessionLogURL) {
                        debugLog("Got summary from Ollama: \(jsonSummary.count) chars")
                        debugLog("Got actual summary from Ollama: \(jsonSummary)")
                        if let sessionPath = self.currentSessionPath {
                            VaultManager.shared.saveSession(sessionPath: sessionPath, jsonString: jsonSummary)
                        }
                    } else {
                        debugLog("ERROR: Ollama returned nil!")
                    }
                } else {
                    debugLog("ERROR: fullTranscript is EMPTY, nothing to send to Ollama.")
                }
                debugLog("--- Processing Complete ---")
            }
        }
    }
}
