import WidgetKit
import SwiftUI

// MARK: – Shared data via App Group

private let appGroupID = "group.com.selfcode.imusic"

struct NowPlayingEntry: TimelineEntry {
    let date: Date
    let title: String
    let artist: String
    let isPlaying: Bool
}

// MARK: – Provider

struct NowPlayingProvider: TimelineProvider {
    func placeholder(in context: Context) -> NowPlayingEntry {
        NowPlayingEntry(date: .now, title: "Track name", artist: "Artist", isPlaying: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (NowPlayingEntry) -> Void) {
        completion(entry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NowPlayingEntry>) -> Void) {
        let e = entry()
        completion(Timeline(entries: [e], policy: .after(.now.addingTimeInterval(15))))
    }

    private func entry() -> NowPlayingEntry {
        let defaults = UserDefaults(suiteName: appGroupID)
        let title    = defaults?.string(forKey: "widget_title")  ?? "iMusic"
        let artist   = defaults?.string(forKey: "widget_artist") ?? "Ничего не играет"
        let playing  = defaults?.bool(forKey: "widget_playing")  ?? false
        return NowPlayingEntry(date: .now, title: title, artist: artist, isPlaying: playing)
    }
}

// MARK: – Widget Views

struct NowPlayingWidgetView: View {
    let entry: NowPlayingEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .accessoryRectangular: rectangularView
        case .accessoryCircular:    circularView
        default:                    lockscreenView
        }
    }

    // Lock screen rectangular
    private var rectangularView: some View {
        HStack(spacing: 10) {
            Image(systemName: entry.isPlaying ? "waveform" : "music.note")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                .symbolEffect(.variableColor, isActive: entry.isPlaying)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(entry.artist)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(1)
            }
        }
        .widgetURL(URL(string: "imusic://open"))
        .containerBackground(.clear, for: .widget)
    }

    // Lock screen circular
    private var circularView: some View {
        ZStack {
            AccessoryWidgetBackground()
            Image(systemName: entry.isPlaying ? "pause.fill" : "play.fill")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
        }
        .widgetURL(URL(string: "imusic://open"))
        .containerBackground(.clear, for: .widget)
    }

    // Home screen small
    private var lockscreenView: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.08, green: 0.06, blue: 0.15), Color(red: 0.04, green: 0.03, blue: 0.09)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "music.note")
                        .font(.system(size: 12))
                        .foregroundStyle(Color(red: 0.6, green: 0.4, blue: 0.9))
                    Text("iMusic")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color(red: 0.6, green: 0.4, blue: 0.9))
                    Spacer()
                    Image(systemName: entry.isPlaying ? "waveform" : "pause.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.5))
                        .symbolEffect(.variableColor, isActive: entry.isPlaying)
                }

                Spacer()

                VStack(alignment: .leading, spacing: 3) {
                    Text(entry.title)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                    Text(entry.artist)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.6))
                        .lineLimit(1)
                }
            }
            .padding(14)
        }
        .widgetURL(URL(string: "imusic://open"))
        .containerBackground(.clear, for: .widget)
    }
}

// MARK: – Widget Config

@main
struct iMusicWidget: Widget {
    let kind = "iMusicWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NowPlayingProvider()) { entry in
            NowPlayingWidgetView(entry: entry)
        }
        .configurationDisplayName("iMusic")
        .description("Now Playing на экране блокировки")
        .supportedFamilies([.accessoryRectangular, .accessoryCircular, .systemSmall])
    }
}
