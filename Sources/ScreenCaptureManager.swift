import Cocoa
import ScreenCaptureKit
import Vision
import CoreMedia

class ScreenCaptureManager: NSObject, SCStreamDelegate, SCStreamOutput {
    private var stream: SCStream?

    private let ocrFileURL = FileManager.default.temporaryDirectory.appendingPathComponent("ocr.txt")

    private var textRequest = VNRecognizeTextRequest()
    private var lastFrameTime: Date = Date.distantPast
    private var lastRecognizedText: String = ""

    override init() {
        super.init()
        setupOCR()
    }

    func setupOCR() {
        textRequest.recognitionLevel = .accurate
        textRequest.usesLanguageCorrection = true
    }

    private func calculateSimilarity(_ textA: String, _ textB: String) -> Double {
        let setA = Set(textA.components(separatedBy: .whitespacesAndNewlines))
        let setB = Set(textB.components(separatedBy: .whitespacesAndNewlines))
        let intersection = setA.intersection(setB)
        let union = setA.union(setB)
        guard !union.isEmpty else { return 1.0 }
        return Double(intersection.count) / Double(union.count)
    }

    func requestPermissions() async {
        do {
            _ = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        } catch {
            print("Failed to get shareable content (permissions missing?): \(error)")
        }
    }

    func startCapture() {
        // Clear previous OCR file
        if FileManager.default.fileExists(atPath: ocrFileURL.path) {
            try? FileManager.default.removeItem(at: ocrFileURL)
        }

        Task {
            do {
                let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                guard let display = content.displays.first else { return }

                let filter = SCContentFilter(display: display, excludingApplications: [], exceptingWindows: [])
                let configuration = SCStreamConfiguration()

                configuration.width = display.width
                configuration.height = display.height
                configuration.minimumFrameInterval = CMTime(value: 1, timescale: 1)
                configuration.showsCursor = false
                configuration.queueDepth = 5

                stream = SCStream(filter: filter, configuration: configuration, delegate: self)

                try stream?.addStreamOutput(self, type: .screen, sampleHandlerQueue: .global(qos: .userInitiated))

                try await stream?.startCapture()
                print("Capture started.")
            } catch {
                print("Failed to start capture: \(error)")
            }
        }
    }

    func stopCapture() {
        Task {
            do {
                try await stream?.stopCapture()
                print("Capture stopped.")
            } catch {
                print("Failed to stop capture: \(error)")
            }
        }
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen else { return }

        let now = Date()
        if now.timeIntervalSince(lastFrameTime) < 6.0 { return }
        lastFrameTime = now

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let requestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])

        do {
            try requestHandler.perform([textRequest])
            guard let observations = textRequest.results else { return }

            let recognizedText = observations.compactMap { observation in
                observation.topCandidates(1).first?.string
            }.joined(separator: "\n")

            if !recognizedText.isEmpty {
                let similarity = calculateSimilarity(recognizedText, lastRecognizedText)
                if similarity > 0.85 {
                    return // Skip logging if text is highly similar to last frame
                }
                
                lastRecognizedText = recognizedText

                let formatter = DateFormatter()
                formatter.dateFormat = "HH:mm:ss"
                let timeStr = formatter.string(from: now)
                let logEntry = "--- OCR at \(timeStr) ---\n\(recognizedText)\n\n"

                if let fileHandle = try? FileHandle(forWritingTo: ocrFileURL) {
                    fileHandle.seekToEndOfFile()
                    if let data = logEntry.data(using: .utf8) {
                        fileHandle.write(data)
                    }
                    fileHandle.closeFile()
                } else {
                    try? logEntry.write(to: ocrFileURL, atomically: true, encoding: .utf8)
                }

                print("OCR at \(timeStr): \(recognizedText.prefix(80))")
            }
        } catch {
            print("OCR failed: \(error)")
        }
    }
}
