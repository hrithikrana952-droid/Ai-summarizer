import Foundation

struct OllamaRequest: Codable {
    let model: String
    let prompt: String
    let stream: Bool
    let format: String
}

struct OllamaResponse: Codable {
    let response: String
}

class OllamaManager {
    static let shared = OllamaManager()

    private let endpoint = URL(string: "http://localhost:11434/api/generate")!

    func summarize(transcript: String, sessionLogURL: URL?) async -> String? {
        func log(_ message: String) {
            let timestamp = ISO8601DateFormatter().string(from: Date())
            let line = "[\(timestamp)] [Ollama] \(message)\n"
            print(line, terminator: "")
            if let logURL = sessionLogURL, let data = line.data(using: .utf8) {
                if let handle = try? FileHandle(forWritingTo: logURL) {
                    handle.seekToEndOfFile()
                    handle.write(data)
                    handle.closeFile()
                } else {
                    try? data.write(to: logURL)
                }
            }
        }

        // Build prompt via concatenation to avoid escaping issues
        let prompt = "You are a highly capable AI summarizer. Analyze the following transcript. " +
            "The audio could be a conversation, a meeting, a YouTube video, or a lecture.\n\n" +
            "Provide your analysis ONLY as a JSON object with these keys:\n" +
            "- \"transcript\": cleaned-up version of the transcript.\n" +
            "- \"summary\": array of strings summarizing the main topics.\n" +
            "- \"action_items\": array of action items (empty array if none).\n" +
            "- \"other_party_highlights\": array of key quotes from other speakers (empty array if none).\n\n" +
            "Transcript:\n" + transcript

        log("Prompt length: \(prompt.count) chars")
        log("Prompt first 300 chars: \(String(prompt.prefix(300)))")

        let reqBody = OllamaRequest(
            model: "qwen2.5:32b",
            prompt: prompt,
            stream: false,
            format: "json"
        )

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 300

        do {
            let encodedBody = try JSONEncoder().encode(reqBody)
            request.httpBody = encodedBody
            log("Request body size: \(encodedBody.count) bytes")

            let startTime = Date()
            let (data, response) = try await URLSession.shared.data(for: request)
            let elapsed = Date().timeIntervalSince(startTime)

            guard let httpResponse = response as? HTTPURLResponse else {
                log("ERROR: Not an HTTP response")
                return nil
            }

            log("HTTP \(httpResponse.statusCode) in \(String(format: "%.2f", elapsed))s, body: \(data.count) bytes")

            let rawString = String(data: data, encoding: .utf8) ?? "<unreadable>"
            log("Raw response: \(rawString)")

            guard httpResponse.statusCode == 200 else {
                log("ERROR: Non-200 status")
                return nil
            }

            let ollamaRes = try JSONDecoder().decode(OllamaResponse.self, from: data)
            log("Decoded response field: \(ollamaRes.response)")
            return ollamaRes.response
        } catch {
            log("ERROR calling Ollama: \(error)")
            return nil
        }
    }
}
