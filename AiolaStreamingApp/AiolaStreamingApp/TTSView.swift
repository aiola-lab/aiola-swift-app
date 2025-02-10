//
//  TTSView.swift
//  AiolaStreamingApp
//
//  Created by Amour Shmuel on 06/02/2025.
//

import SwiftUI
import AVFoundation
import AiolaSwiftSDK

struct TTSView: View {
    @State private var textToSynthesize: String = "Hello, this is a test of the aiOla TTS synthesis feature."
    @State private var selectedVoice: String = "af_bella"
    @State private var isSynthesizing = false
    @State private var isStreaming = false
    @State private var statusMessage: String = ""
    @State private var audioPlayer: AVPlayer?
    
    private let ttsClient = AiolaTTSClient(baseUrl: "<your-base-url>/api/tts", bearerToken: "<your-bearer-token>")
    
    let availableVoices = [
        "af_bella", "af_nicole", "af_sarah", "af_sky",
        "am_adam", "am_michael",
        "bf_emma", "bf_isabella",
        "bm_george", "bm_lewis"
    ]
    
    var body: some View {
        VStack(spacing: 20) {
            Text("🔊 Aiola TTS Synthesize & Stream")
                .font(.largeTitle)
                .bold()
            
            // Text Input Field
            TextEditor(text: $textToSynthesize)
                .frame(height: 150)
                .border(Color.gray, width: 1)
                .padding()
            
            // Voice Selection Dropdown
            Picker("Select Voice", selection: $selectedVoice) {
                ForEach(availableVoices, id: \.self) { voice in
                    Text(voice).tag(voice)
                }
            }
            .pickerStyle(MenuPickerStyle())
            .padding()
            
            // Buttons for Synthesize & Streaming
            HStack(spacing: 20) {
                Button(action: synthesizeSpeech) {
                    Text("🗣️ Synthesize")
                        .frame(minWidth: 120)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .disabled(isSynthesizing)
                
                Button(action: streamSpeech) {
                    Text("🎙️ Stream")
                        .frame(minWidth: 120)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .disabled(isStreaming)
            }
            
            // Status Message
            Text(statusMessage)
                .foregroundColor(.gray)
                .padding()
            
            // ✅ Use Custom AudioPlayerView
            if let player = audioPlayer {
                AudioPlayerView(player: player)
                    .frame(height: 50)
                    .padding()
            }
        }
        .padding()
    }
    
    // ✅ Synthesize Speech (TTS)
    private func synthesizeSpeech() {
        guard !textToSynthesize.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            statusMessage = "⚠️ Text input cannot be empty!"
            return
        }
        
        isSynthesizing = true
        statusMessage = "⏳ Synthesizing speech..."
        
        ttsClient.synthesize(text: textToSynthesize, voice: selectedVoice) { result in
            DispatchQueue.main.async {
                self.isSynthesizing = false
                switch result {
                case .success(let audioData):
                    print("✅ TTS Audio Received (\(audioData.count) bytes)")
                    self.playAudio(audioData)
                    self.statusMessage = "✅ Synthesis complete!"
                case .failure(let error):
                    print("❌ Error: \(error.localizedDescription)")
                    self.statusMessage = "❌ Synthesis failed!"
                }
            }
        }
    }
    
    // ✅ Stream Speech (Real-time TTS)
    private func streamSpeech() {
        guard !textToSynthesize.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            statusMessage = "⚠️ Text input cannot be empty!"
            return
        }
        
        isStreaming = true
        statusMessage = "⏳ Streaming speech..."
        
        ttsClient.synthesizeStream(text: textToSynthesize, voice: selectedVoice) { result in
            DispatchQueue.main.async {
                self.isStreaming = false
                switch result {
                case .success(let audioData):
                    print("✅ TTS Stream Received (\(audioData.count) bytes)")
                    self.playAudio(audioData)
                    self.statusMessage = "✅ Streaming complete!"
                case .failure(let error):
                    print("❌ Streaming Error: \(error.localizedDescription)")
                    self.statusMessage = "❌ Streaming failed!"
                }
            }
        }
    }
    
    // ✅ Play Received Audio
    private func playAudio(_ audioData: Data) {
        let tempFileURL = FileManager.default.temporaryDirectory.appendingPathComponent("tts_output.wav")
        
        do {
            try audioData.write(to: tempFileURL)
            let playerItem = AVPlayerItem(url: tempFileURL)
            self.audioPlayer = AVPlayer(playerItem: playerItem)
            self.audioPlayer?.play()
            print("🎵 Playing audio...")
        } catch {
            print("❌ Failed to write audio file: \(error.localizedDescription)")
            statusMessage = "❌ Could not play audio."
        }
    }
}

#Preview {
    TTSView()
}
