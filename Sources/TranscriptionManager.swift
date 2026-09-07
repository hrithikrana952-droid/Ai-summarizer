import Foundation

class TranscriptionManager {
    static let shared = TranscriptionManager()
    
    private let whisperPath = "/Users/hrithikr/Screen-reader/whisper.cpp/build/bin/whisper-cli"
    private let modelPath = "/Users/hrithikr/Screen-reader/whisper.cpp/models/ggml-base.en.bin"
    
    func transcribe(m4aURL: URL) async -> String? {
        let wavURL = m4aURL.deletingPathExtension().appendingPathExtension("wav")
        
        // 1. Convert m4a to wav 16kHz
        let convertProcess = Process()
        convertProcess.executableURL = URL(fileURLWithPath: "/usr/bin/afconvert")
        convertProcess.arguments = ["-f", "WAVE", "-d", "LEI16@16000", m4aURL.path, wavURL.path]
        
        do {
            try convertProcess.run()
            convertProcess.waitUntilExit()
            if convertProcess.terminationStatus != 0 {
                print("Failed to convert audio to wav.")
                return nil
            }
            
            // 2. Run whisper.cpp
            let whisperProcess = Process()
            whisperProcess.executableURL = URL(fileURLWithPath: whisperPath)
            whisperProcess.arguments = ["-m", modelPath, "-f", wavURL.path, "-nt"]
            
            let stdoutPipe = Pipe()
            whisperProcess.standardOutput = stdoutPipe
            
            // Discard stderr (model loading info, timings, etc.)
            whisperProcess.standardError = FileHandle.nullDevice
            
            try whisperProcess.run()
            
            // IMPORTANT: Read data BEFORE waitUntilExit to avoid pipe buffer deadlock
            let data = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
            whisperProcess.waitUntilExit()
            
            let transcript = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            
            print("Whisper transcript (\(m4aURL.lastPathComponent)): \(transcript.prefix(200))...")
            
            if transcript.isEmpty || transcript.contains("[BLANK_AUDIO]") {
                print("Transcript was empty or blank audio.")
                return nil
            }
            return transcript
            
        } catch {
            print("Transcription error: \(error)")
            return nil
        }
    }
}
