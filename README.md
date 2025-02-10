# Aiola Streaming & TTS App

## Overview
AiolaStreamingApp is an iOS application that enables real-time audio streaming and playback using Aiola's Live Streaming API. It provides a seamless experience for users to interact with audio streams, including text-to-speech (TTS) integration and audio player functionalities.

## Features
- Live audio streaming to Aiola's backend
- Text-to-speech (TTS) conversion and playback
- Audio player for streamed content
- Swift-based architecture optimized for performance

## Installation
### Prerequisites
- macOS with Xcode installed
- iOS device or Simulator running iOS 14+
- Active Aiola API credentials

### Steps
1. Clone the repository:
   ```bash
   git clone https://github.com/aiola-lab/aiola-swift-app.git
   cd AiolaStreamingApp
   ```
2. Open the project in Xcode:
   ```bash
   open AiolaStreamingApp.xcodeproj
   ```
3. Install the Aiola Swift SDK:
   ```bash
   git clone https://github.com/aiola-lab/aiola-swift-sdk.git

   swift package add https://github.com/aiola-lab/aiola-swift-sdk
   ```
4. Configure API keys and backend URL in `AudioStreamingManager.swift`
5. Build and run the app on a Simulator or iOS device

## Usage
1. Launch the Aiola Streaming App on your iOS device.
2. Navigate to the **Live Streaming** section to start an audio stream.
3. Use the **TTS View** to convert text to speech.
4. Access the **Audio Player** to play back stored streams.

## Configuration
Modify `AudioStreamingManager.swift` to configure API endpoints and authentication:
```swift
import AiolaSwiftSDK

let bearerToken = "<your-bearer-token>" \\ The Bearer token, obtained upon registration with Aiola
        
let config = StreamingConfig(
        endpoint: "<your-base-url>, \\ The URL of the Aiola server
        authType: "Bearer",
        authCredentials: ["token": bearerToken],
        flowId: "<your-flow-id>", \\ One of the IDs from the flows created for the user
        executionId: "1009",
        langCode: "en_US",
        timeZone: "UTC",
        namespace: "/events", \\ Namespace for subscription: /transcript (for transcription) or /events (for transcription + LLM solution)
        transports: "websocket" \\Communication method: 'websocket' for L4 or 'polling' for L7
    )

...

  
  // ✅ Update UI when socket connects
  func onConnect() {
      DispatchQueue.main.async {
          self.isConnected = true
      }
      print("✅ Connection established")
      // Add your code
  }
  
  // ✅ Update UI when socket disconnects
  func onDisconnect(connectionDuration: TimeInterval, totalAudioSentDuration: TimeInterval) {
      DispatchQueue.main.async {
          self.isConnected = false
      }
      print("❌ Connection closed. Duration: \(connectionDuration)ms, Total audio: \(totalAudioSentDuration)ms")
     // Add your code
  }
  
  func onTranscript(data: Any) {
      if let transcriptArray = data as? [[String: String]],
         let transcript = transcriptArray.first?["transcript"] {
          
          let newEvent = AudioEvent(type: "📝 Transcript",
                                    content: transcript)
          
          DispatchQueue.main.async {
              self.addEvent(newEvent)
          }
         // Add your code
      }
  }
    
    func onEvents(data: Any) {
        if let eventArray = data as? [[String: Any]],
           let results = eventArray.first?["results"] as? [String: Any],
           let maskedQuery = results["masked_query"] as? String {
            
            let newEvent = AudioEvent(type: "📢 Event",
                                      content: maskedQuery)
            
            DispatchQueue.main.async {
                self.addEvent(newEvent)
            }
          // Add your code
        }
    }
    
    func onError(error: String) {
        print("⚠️ Error occurred: \(error)")
        // Add your code
    }
```

---

Modify `TTSView.swift` to configure API endpoints and authentication:
```swift
import AiolaSwiftSDK

private let ttsClient = AiolaTTSClient(baseUrl: "<your-base-url>/api/tts", bearerToken: "<your-bearer-token>")
```
