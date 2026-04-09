import SwiftUI
import Foundation

struct Track: Identifiable, Codable, Equatable, Hashable {
    let id: String
    var title: String
    var artist: String
    var duration: String
    var coverURL: String
    var streamURL: String
    var downloadURL: String
    var source: MusicSource

    static func == (lhs: Track, rhs: Track) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

enum MusicSource: String, Codable, CaseIterable {
    case source1 = "source1"
    case source2 = "source2"
    case source3 = "source3"
    case source4 = "source4"
}

enum PlayerState {
    case idle, loading, playing, paused, error(String)
}

enum TabItem: Int, CaseIterable {
    case search = 0
    case library = 1
    case settings = 2

    var title: String {
        switch self {
        case .search:   return "Поиск"
        case .library:  return "Библиотека"
        case .settings: return "Настройки"
        }
    }

    var icon: String {
        switch self {
        case .search:   return "magnifyingglass"
        case .library:  return "music.note.list"
        case .settings: return "gearshape"
        }
    }
}

struct ToastMessage: Identifiable {
    let id = UUID()
    let text: String
    let style: ToastStyle
    let position: ToastPosition

    enum ToastStyle {
        case info, success, error, warning
        var color: Color {
            switch self {
            case .info:    return Theme.accent
            case .success: return Theme.success
            case .error:   return Theme.danger
            case .warning: return Theme.warning
            }
        }
        var icon: String {
            switch self {
            case .info:    return "info.circle.fill"
            case .success: return "checkmark.circle.fill"
            case .error:   return "xmark.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            }
        }
    }

    enum ToastPosition {
        case top, center, slideLeft
    }
}
