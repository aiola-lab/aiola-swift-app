//
//  AudioPlayerView.swift
//  AiolaStreamingApp
//
//  Created by Amour Shmuel on 06/02/2025.
//

import SwiftUI
import AVKit

struct AudioPlayerView: UIViewControllerRepresentable {
    let player: AVPlayer

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = true // ✅ Enables play/pause controls
        return controller
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        uiViewController.player = player
    }
}
