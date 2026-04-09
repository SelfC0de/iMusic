import SwiftUI
import AVFoundation

@main
struct iMusicApp: App {
    @StateObject private var player = AudioPlayerManager.shared
    @StateObject private var settings = SettingsStore.shared
    @StateObject private var library = LibraryStore.shared
    @StateObject private var toast = ToastManager.shared

    init() {
        setupAudioSession()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(player)
                .environmentObject(settings)
                .environmentObject(library)
                .environmentObject(toast)
                .preferredColorScheme(.dark)
        }
    }

    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(
                .playback,
                mode: .default,
                options: [.mixWithOthers, .allowBluetooth]
            )
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {}
    }
}
