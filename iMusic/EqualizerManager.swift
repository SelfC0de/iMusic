import AVFoundation
import Combine

struct EQPreset: Identifiable, Equatable {
    let id: String
    let name: String
    let bands: [Float]  // 5 bands: 60Hz, 230Hz, 910Hz, 3.6kHz, 14kHz
}

final class EqualizerManager: ObservableObject {
    static let shared = EqualizerManager()

    @Published var isEnabled: Bool = false {
        didSet { applyEQ() }
    }
    @Published var bands: [Float] = [0, 0, 0, 0, 0] {
        didSet { applyEQ() }
    }
    @Published var currentPreset: String = "Flat"

    let presets: [EQPreset] = [
        EQPreset(id: "flat",     name: "Flat",      bands: [0,   0,   0,   0,   0]),
        EQPreset(id: "bass",     name: "Bass Boost", bands: [8,   5,   0,  -2,  -3]),
        EQPreset(id: "rock",     name: "Rock",       bands: [5,   3,  -1,   3,   4]),
        EQPreset(id: "pop",      name: "Pop",        bands: [-1,  3,   5,   3,  -1]),
        EQPreset(id: "jazz",     name: "Jazz",       bands: [4,   2,  -1,   2,   4]),
        EQPreset(id: "classic",  name: "Classical",  bands: [5,   3,   0,   2,   4]),
        EQPreset(id: "vocal",    name: "Vocal",      bands: [-2,  0,   4,   4,   2]),
        EQPreset(id: "dance",    name: "Dance",      bands: [6,   4,   0,   3,   5]),
        EQPreset(id: "treble",   name: "Treble",     bands: [-3, -2,   0,   5,   8]),
    ]

    let bandFrequencies = ["60Hz", "230Hz", "910Hz", "3.6k", "14kHz"]
    private var eqNode: AVAudioUnitEQ?
    private weak var audioEngine: AVAudioEngine?

    private init() {}

    func connect(to engine: AVAudioEngine, playerNode: AVAudioPlayerNode) {
        self.audioEngine = engine
        let eq = AVAudioUnitEQ(numberOfBands: 5)
        self.eqNode = eq

        let freqs: [Float] = [60, 230, 910, 3600, 14000]
        for (i, freq) in freqs.enumerated() {
            eq.bands[i].filterType = .parametric
            eq.bands[i].frequency = freq
            eq.bands[i].bandwidth = 1.0
            eq.bands[i].gain = 0
            eq.bands[i].bypass = false
        }

        engine.attach(eq)
        engine.connect(playerNode, to: eq, format: nil)
        engine.connect(eq, to: engine.mainMixerNode, format: nil)
        applyEQ()
    }

    func applyPreset(_ preset: EQPreset) {
        currentPreset = preset.name
        bands = preset.bands
    }

    private func applyEQ() {
        guard let eq = eqNode else { return }
        for i in 0..<5 {
            eq.bands[i].gain = isEnabled ? bands[i] : 0
        }
    }
}
