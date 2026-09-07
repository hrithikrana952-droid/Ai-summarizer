# ConversationAgent

ConversationAgent is a macOS menu bar application that records your screen, microphone, and system audio, and then uses local AI to generate a comprehensive summary of your session. 

Everything runs **100% locally** on your Mac for complete privacy.

## How It Works

1. **Capture**: When you start a recording from the menu bar, the app simultaneously captures your microphone, the system audio (what you hear), and performs continuous OCR (Optical Character Recognition) on your screen to read on-screen text.
2. **Transcription**: When you stop the recording, the app uses `whisper.cpp` to transcribe both audio streams into text.
3. **Summarization**: The combined audio transcripts and OCR text are sent to a local LLM running via Ollama. 
4. **Vault**: The LLM analyzes the context and produces a structured JSON output (including the transcript, bullet-point summary, action items, and highlights). This result, along with a `debug.log`, is saved to `~/ConversationVault/[Timestamp]_Session/`.

---

## Prerequisites & Installation

To run this app locally, you need to set up a few open-source tools:

### 1. Whisper.cpp (For Transcription)
The app relies on `whisper.cpp` for ultra-fast, local speech-to-text.
1. Clone the whisper repo into the root of this project:
   ```bash
   git clone https://github.com/ggerganov/whisper.cpp.git
   ```
2. Build the CLI tool:
   ```bash
   cd whisper.cpp
   make
   ```
3. Download the base English model:
   ```bash
   bash ./models/download-ggml-model.sh base.en
   ```

### 2. Ollama (For Summarization)
The app uses Ollama to run the LLM locally.
1. Download and install [Ollama](https://ollama.com/).
2. Pull the model. By default, the app is configured for `qwen2.5:32b` (ideal for M-series chips with 32GB+ RAM):
   ```bash
   ollama pull qwen2.5:32b
   ```

*(See **Model Selection for M2/M3 Chips** below if you have less RAM).*

### 3. BlackHole (For System Audio Capture)
To capture the audio playing from your computer (like a YouTube video or Zoom call), you need a virtual audio driver.
1. Install [BlackHole 2ch](https://existential.audio/blackhole/):
   ```bash
   brew install blackhole-2ch
   ```
2. Open the **Audio MIDI Setup** app on your Mac.
3. Click the `+` at the bottom left and create a **Multi-Output Device**.
4. Check both your main speakers/headphones AND "BlackHole 2ch".
5. Set your Mac's sound output to this new "Multi-Output Device".

---

## Building the App

Once the dependencies are set up, you can build and install the app:

1. Run the build script:
   ```bash
   ./build.sh
   ```
2. Install it to your Applications folder:
   ```bash
   sudo cp -R ConversationAgent.app /Applications/
   ```
3. Open the app:
   ```bash
   open /Applications/ConversationAgent.app
   ```

**Permissions:** On the first launch, the app will ask for Screen Recording, Microphone, and Notification permissions. You must grant these in System Settings for the app to function.

---

## Troubleshooting Permissions (Code Signing)

If macOS keeps asking you for Screen Recording or Microphone permissions every time you rebuild the app, or if it silently blocks access despite granting permissions in System Settings, it is because of **Code Signing**. 

By default, locally built macOS apps get an ad-hoc signature that changes on every build. macOS treats every rebuild as a "new" untrusted app and revokes permissions. To fix this:

1. Open **Keychain Access** on your Mac.
2. In the menu bar, go to **Keychain Access > Certificate Assistant > Create a Certificate...**
3. Name it exactly: **`ConversationAgentSign`**
4. Set Identity Type to **Self Signed Root**, and Certificate Type to **Code Signing**.
5. Click Create.
6. Find the certificate in Keychain, double-click it, open **Trust**, and set "When using this certificate" to **Always Trust**.
7. Close the window (you will be prompted for your Mac password to save the trust settings).

The `./build.sh` script is already configured to look for this `ConversationAgentSign` certificate and will automatically use it to sign your app. This guarantees the app hash stays consistent, and macOS will permanently remember your permissions!

---

## Model Selection for M2/M3 Chips

The code currently defaults to `qwen2.5:32b` in `Sources/OllamaManager.swift`. This is a heavy 32-billion parameter model that requires a powerful Mac (like an M5 Pro or Mac Studio).

If you are using a standard **M2 or M3 chip (with 8GB or 16GB of RAM)**, the 32B model will be too slow or crash. You should change the code to use a smaller model:

1. Open `Sources/OllamaManager.swift`.
2. Find this block of code:
   ```swift
   let reqBody = OllamaRequest(
       model: "qwen2.5:32b",
       prompt: prompt,
       stream: false,
       format: "json"
   )
   ```
3. Change `"qwen2.5:32b"` to a smaller model, such as:
   - `"qwen2.5:7b"` (Highly recommended for 8GB/16GB Macs)
   - `"llama3.1:8b"`
4. Save the file and run `./build.sh` again.
5. Don't forget to pull the new model in your terminal: `ollama pull qwen2.5:7b`.
