//
//  AudioStreamingManager.swift
//  AiolaStreamingApp
//
//  Created by Amour Shmuel on 05/02/2025.
//

import Foundation
import AVFoundation
import AiolaSwiftSDK

class AudioStreamingManager: NSObject, ObservableObject, AiolaStreamingDelegate {
    private var audioEngine: AVAudioEngine!
    private var client: AiolaStreamingClient?
    
    private var audioChunkBuffer = Data()  // 🔹 Global accumulator
    private let audioQueue = DispatchQueue(label: "audio.chunk.queue", qos: .userInitiated)  // 🔹 Dedicated queue for processing
    private let bufferLock = NSLock()  // 🔹 Prevents race conditions
    
    
    
    private var inputNode: AVAudioInputNode
    private var converter: AVAudioConverter?
    private var targetFormat: AVAudioFormat?
    
    @Published var isConnected: Bool = false // ✅ Track connection status
    @Published var sampleRate: Double = 0.0 // ✅ Track sample rate
    @Published var numChannels: Int = 0 // ✅ Track number of channels
    @Published var audioStatusMessage: String = "🎤 Waiting for audio status..." // ✅ Track audio engine status
    @Published var isMicPermissionGranted: Bool = false  // ✅ Tracks microphone permission status
    
    // 🔹 Audio format tracking
    @Published var originalSampleRate: Double = 0.0
    @Published var originalNumChannels: Int = 0
    @Published var convertedSampleRate: Double = 0.0
    @Published var convertedNumChannels: Int = 0
    
    @Published var events: [AudioEvent] = []  // Stores last 100 events
    
    
    enum AudioProcessingError: Error {
        case failedToCreateTargetFormat
    }
    
    
    struct AudioEvent: Identifiable {
        let id = UUID()
        let timestamp: String
        let type: String
        let content: String
    }
    
    override init() {
        self.audioEngine = AVAudioEngine()
        self.inputNode = audioEngine.inputNode
        
        super.init()
        configureSDK()
        
        requestMicrophonePermission { granted in
            DispatchQueue.main.async {
                self.isMicPermissionGranted = granted
            }
        }
    }
    
    // Initialize the SDK Client
    func configureSDK() {
        let bearerToken = "<your-bearer-token>"
        
        let config = StreamingConfig(
                endpoint: "<your-base-url>",
                authType: "Bearer",
                authCredentials: ["token": bearerToken],
                flowId: "<your-flow-id>",
                executionId: "1009",
                langCode: "en_US",
                timeZone: "UTC",
                namespace: "/events",
                transports: "websocket"
            )
        
        client = AiolaStreamingClient(config: config)
        client?.delegate = self
        client?.connect()
    }
    
    
    
    private func requestMicrophonePermission(completion: @escaping (Bool) -> Void) {
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            DispatchQueue.main.async {
                if granted {
                    print("🎤 Microphone permission granted.")
                    completion(true)
                } else {
                    print("🚫 Microphone permission denied. Cannot start audio processing.")
                    completion(false)
                }
            }
        }
    }
    
    private func configureAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.allowBluetooth, .defaultToSpeaker])
            try audioSession.setActive(true)
            print("✅ AVAudioSession configured successfully.")
        } catch {
            print("❌ Failed to configure AVAudioSession: \(error)")
        }
    }
    
    private func checkAudioInputAvailability() -> Bool {
        let audioSession = AVAudioSession.sharedInstance()
        return audioSession.isInputAvailable
    }
    
    private func setupAudioEngine() {
        do {
            configureAudioSession()
            try audioEngine.start()
            print("🎤 AVAudioEngine started successfully.")
            
            let inputFormat = inputNode.inputFormat(forBus: 0)
            print("🎤 Hardware Input Format: \(inputFormat)")
            
            // 🔹 Update UI with original audio format
            DispatchQueue.main.async {
                self.originalSampleRate = inputFormat.sampleRate
                self.originalNumChannels = Int(inputFormat.channelCount)
            }
            
            // 🔹 Define the target format (Int16, 16000Hz, 1 channel)
            guard let format16kInt16 = AVAudioFormat(commonFormat: .pcmFormatInt16,
                                                     sampleRate: 16000.0,
                                                     channels: inputFormat.channelCount,
                                                     interleaved: true) else {
                fatalError("❌ Failed to create target format.")
            }
            self.targetFormat = format16kInt16
            
            // 🔹 Update UI with converted audio format
            DispatchQueue.main.async {
                self.convertedSampleRate = format16kInt16.sampleRate
                self.convertedNumChannels = Int(format16kInt16.channelCount)
            }
            
            // 🔹 Create the audio converter
            guard let audioConverter = AVAudioConverter(from: inputFormat, to: format16kInt16) else {
                fatalError("❌ Failed to create AVAudioConverter.")
            }
            self.converter = audioConverter
            
            inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { buffer, _ in
                self.processAudioBuffer(buffer: buffer)
            }
        } catch {
            print("❌ Failed to start AVAudioEngine: \(error)")
        }
    }
    
    private func processAudioBuffer(buffer: AVAudioPCMBuffer) {
        guard let converter = converter, let targetFormat = targetFormat else {
            print("❌ Converter or target format is not set")
            return
        }
        
        let frameCapacity = AVAudioFrameCount(targetFormat.sampleRate / 10) // Approx 100ms buffer
        
        guard let convertedBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: frameCapacity) else {
            print("❌ Failed to create conversion buffer")
            return
        }
        
        let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
            outStatus.pointee = .haveData
            return buffer
        }
        
        var error: NSError?
        converter.convert(to: convertedBuffer, error: &error, withInputFrom: inputBlock)
        
        if let error = error {
            print("❌ Audio conversion error: \(error)")
        } else {
            // ✅ Convert PCM buffer to Data and send to `sendDataToServer_v3`
            if let pcmData = bufferToData(buffer: convertedBuffer) {
                sendDataToServer(data: pcmData)
            }
        }
    }
    
    private func sendDataToServer(data: Data) {
        let chunkSize = 4096
        
        audioQueue.async { [self] in  // ✅ Run processing on a background thread
            self.bufferLock.lock()
            self.audioChunkBuffer.append(data)  // 🔹 Append new incoming data
            //            print("append audioChunkBuffer.count \(self.audioChunkBuffer.count)")
            
            var chunkToSend: Data?
            
            if audioChunkBuffer.count >= chunkSize {
                chunkToSend = audioChunkBuffer.prefix(chunkSize)  // Extract first 4096 bytes
                //                print("extract chunkToSend \(String(describing: chunkToSend)), audioChunkBuffer.count \(self.audioChunkBuffer.count)")
                audioChunkBuffer.removeFirst(chunkSize)  // 🗑 Remove sent chunk
                
                client!.sendAudioData(data: chunkToSend!) { [self] success in
                    //                    if success {
                    //                        print("📤 Sent 4096-byte chunk to server")
                    //                    } else {
                    //                        print("❌ Failed to send 4096-byte chunk")
                    //                    }
                    bufferLock.unlock()
                }
            }
            else{
                bufferLock.unlock()
            }
        }
    }
    
    
    
    private func bufferToData(buffer: AVAudioPCMBuffer) -> Data? {
        let frameLength = Int(buffer.frameLength)
        guard let channelData = buffer.int16ChannelData else { return nil }
        
        let audioData = channelData.pointee
        return Data(bytes: audioData, count: frameLength * MemoryLayout<Int16>.size)
    }
    
    
    
    func startStreaming() {
        guard isMicPermissionGranted else {
            print("🚫 Cannot start streaming: Microphone permission not granted")
            return
        }
        
        print("🚀 Starting audio streaming...")
        setupAudioEngine()  // ✅ Start only when permission is granted
    }
    
    
    func stopStreaming() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        DispatchQueue.main.async {
            self.audioStatusMessage = "⛔️ Streaming stopped"
        }
        print("⛔️ Streaming stopped successfully.")
    }
    
    // ✅ Update UI when socket connects
    func onConnect() {
        DispatchQueue.main.async {
            self.isConnected = true
        }
        print("✅ Connection established")
    }
    
    // ✅ Update UI when socket disconnects
    func onDisconnect(connectionDuration: TimeInterval, totalAudioSentDuration: TimeInterval) {
        DispatchQueue.main.async {
            self.isConnected = false
        }
        print("❌ Connection closed. Duration: \(connectionDuration)ms, Total audio: \(totalAudioSentDuration)ms")
    }
    
    // ✅ Helper to format timestamps
    private func getCurrentTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: Date())
    }
    
    func onTranscript(data: Any) {
        if let transcriptArray = data as? [[String: String]],
           let transcript = transcriptArray.first?["transcript"] {
            
            let newEvent = AudioEvent(timestamp: getCurrentTimestamp(),
                                      type: "📝 Transcript",
                                      content: transcript)
            
            DispatchQueue.main.async {
                self.addEvent(newEvent)
            }
        }
    }
    
    func onEvents(data: Any) {
        if let eventArray = data as? [[String: Any]],
           let results = eventArray.first?["results"] as? [String: Any],
           let maskedQuery = results["masked_query"] as? String {
            
            let newEvent = AudioEvent(timestamp: getCurrentTimestamp(),
                                      type: "📢 Event",
                                      content: maskedQuery)
            
            DispatchQueue.main.async {
                self.addEvent(newEvent)
            }
        }
    }
    
    func onError(error: String) {
        print("⚠️ Error occurred: \(error)")
    }
    
    
    // ✅ Add event while keeping only the last 100
    private func addEvent(_ event: AudioEvent) {
        events.insert(event, at: 0)  // Add at the top
        if events.count > 100 {
            events.removeLast()  // Keep only the last 100
        }
    }
}
