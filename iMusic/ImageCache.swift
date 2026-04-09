import SwiftUI
import Combine

final class ImageCache {
    static let shared = ImageCache()
    private var cache = NSCache<NSString, UIImage>()
    private init() { cache.countLimit = 150 }

    subscript(url: String) -> UIImage? {
        get { cache.object(forKey: url as NSString) }
        set {
            if let img = newValue { cache.setObject(img, forKey: url as NSString) }
            else { cache.removeObject(forKey: url as NSString) }
        }
    }
}

struct CachedAsyncImage: View {
    let url: String
    var placeholder: Image = Image(systemName: "music.note")

    @State private var image: UIImage?
    @State private var loading = false

    var body: some View {
        Group {
            if let img = image {
                Image(uiImage: img).resizable().scaledToFill()
            } else {
                ZStack {
                    Theme.bg3
                    placeholder
                        .font(.system(size: 24))
                        .foregroundColor(Theme.textTertiary)
                }
            }
        }
        .task(id: url) {
            await load()
        }
    }

    private func load() async {
        guard !url.isEmpty else { return }
        if let cached = ImageCache.shared[url] {
            image = cached
            return
        }
        guard let urlObj = URL(string: url) else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: urlObj)
            if let img = UIImage(data: data) {
                ImageCache.shared[url] = img
                await MainActor.run { image = img }
            }
        } catch {}
    }
}
