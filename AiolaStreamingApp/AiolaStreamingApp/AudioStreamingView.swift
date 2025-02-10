import SwiftUI

struct AudioStreamingView: View {
    @ObservedObject var audioManager = AudioStreamingManager()

    var body: some View {
        VStack {
            Text("🎤 Audio Streaming")
                .font(.headline)
                .bold()

            // ✅ Connection Status
            Text(audioManager.isConnected ? "✅ Connected" : "❌ Disconnected")
                .font(.subheadline)
                .foregroundColor(audioManager.isConnected ? .green : .red)
                .bold()
                .padding(.top, 3)

            VStack(alignment: .leading, spacing: 5) {
                Text("🔹 Original Sample Rate: \(audioManager.originalSampleRate, specifier: "%.0f") Hz")
                Text("🔹 Original Channels: \(audioManager.originalNumChannels)")

                Divider()

                Text("🎯 Converted Sample Rate: \(audioManager.convertedSampleRate, specifier: "%.0f") Hz")
                Text("🎯 Converted Channels: \(audioManager.convertedNumChannels)")
            }
            .font(.footnote)
            .padding()
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.gray.opacity(0.2)))

            Spacer()

            // ✅ Events List (Last 100 events)
            Text("📜 Event Logs")
                .font(.headline)
                .padding(.top)

            List(audioManager.events) { event in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(event.type)
                            .bold()
                        Spacer()
                        Text(event.timestamp)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    Text(event.content)
                        .font(.subheadline)
                }
                .padding(5)
            }
            .frame(maxHeight: 250)  // Limit height of the event list
            .listStyle(PlainListStyle())

            HStack {
                Button(action: {
                    audioManager.startStreaming()
                }) {
                    Text("▶️ Start")
                        .font(.subheadline)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(audioManager.isMicPermissionGranted ? Color.green : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .disabled(!audioManager.isMicPermissionGranted)

                Button(action: {
                    audioManager.stopStreaming()
                }) {
                    Text("⛔️ Stop")
                        .font(.subheadline)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            }
            .padding()
        }
        .padding()
    }
}
