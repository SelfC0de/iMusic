import Foundation
import SwiftUI

final class SettingsStore: ObservableObject {
    static let shared = SettingsStore()
    private init() {}

    @AppStorage("im_autoplay") var autoplay: Bool = true
    @AppStorage("im_saveData") var saveData: Bool = false
    @AppStorage("im_quality") var quality: String = "high"
    @AppStorage("im_cacheLimit") var cacheLimit: Int = 500
    @AppStorage("im_showEqualizer") var showEqualizer: Bool = true
    @AppStorage("im_haptics") var haptics: Bool = true

    func triggerHaptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        guard haptics else { return }
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }
}
