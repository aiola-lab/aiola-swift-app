//
//  MainView.swift
//  AiolaStreamingApp
//
//  Created by Amour Shmuel on 06/02/2025.
//

import SwiftUI

struct MainView: View {
    var body: some View {
        TabView {
            AudioStreamingView()
                .tabItem {
                    Label("Streaming", systemImage: "waveform")
                }

            TTSView()
                .tabItem {
                    Label("TTS", systemImage: "speaker.wave.2.fill")
                }
        }
    }
}

#Preview {
    MainView()
}
