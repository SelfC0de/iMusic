import Foundation

final class SearchService {
    static let shared = SearchService()
    private init() {}

    private let endpoint = "https://rus.hitmotop.com"
    private let pageSize = 48

    func search(query: String, page: Int) async throws -> [Track] {
        let start = page * pageSize
        var urlString: String
        if start == 0 {
            urlString = "\(endpoint)/search?q=\(query.urlEncoded)"
        } else {
            urlString = "\(endpoint)/search/start/\(start)?q=\(query.urlEncoded)"
        }

        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url, timeoutInterval: 15)
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")
        request.setValue("text/html,application/xhtml+xml", forHTTPHeaderField: "Accept")
        request.setValue("ru", forHTTPHeaderField: "Accept-Language")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        guard let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else {
            throw URLError(.cannotDecodeContentData)
        }

        return parseTracks(from: html)
    }

    private func parseTracks(from html: String) -> [Track] {
        var tracks: [Track] = []

        let listPattern = #"<ul[^>]*class="[^"]*tracks__list[^"]*"[^>]*>([\s\S]*?)</ul>"#
        guard let listRange = html.range(of: listPattern, options: .regularExpression),
              let listMatch = html[listRange].firstCapture(pattern: listPattern) else {
            return parseTracks_fallback(from: html)
        }

        return parseItems(from: listMatch)
    }

    private func parseTracks_fallback(from html: String) -> [Track] {
        let itemPattern = #"<li[^>]*class="[^"]*tracks__item[^"]*"[^>]*data-musmeta="([^"]*)"[^>]*>"#
        var tracks: [Track] = []
        var searchStart = html.startIndex

        while let range = html.range(of: itemPattern, options: .regularExpression, range: searchStart..<html.endIndex) {
            let matched = String(html[range])
            if let metaEncoded = matched.firstCapture(pattern: #"data-musmeta="([^"]+)""#) {
                let metaStr = metaEncoded.htmlEntityDecoded
                if let track = parseTrackFromMeta(metaStr) {
                    tracks.append(track)
                }
            }
            searchStart = range.upperBound
        }

        return tracks
    }

    private func parseItems(from listHtml: String) -> [Track] {
        let itemPattern = #"<li[^>]*class="[^"]*tracks__item[^"]*"[^>]*data-musmeta="([^"]*)"[^>]*>([\s\S]*?)</li>"#
        var tracks: [Track] = []
        var searchStart = listHtml.startIndex

        while let range = listHtml.range(of: itemPattern, options: .regularExpression, range: searchStart..<listHtml.endIndex) {
            let itemHtml = String(listHtml[range])
            if let track = parseTrackFromItem(itemHtml) {
                tracks.append(track)
            }
            searchStart = range.upperBound
        }

        return tracks
    }

    private func parseTrackFromItem(_ itemHtml: String) -> Track? {
        var trackId = ""
        var title = ""
        var artist = ""
        var coverURL = ""
        var streamURL = ""
        var downloadURL = ""
        var duration = "0:00"

        if let idVal = itemHtml.firstCapture(pattern: #"data-musid="([^"]+)""#) {
            trackId = idVal
        }

        if let metaEncoded = itemHtml.firstCapture(pattern: #"data-musmeta="([^"]+)""#) {
            let metaStr = metaEncoded.htmlEntityDecoded
            if let jsonData = metaStr.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                artist = json["artist"] as? String ?? ""
                title = json["title"] as? String ?? ""
                streamURL = json["url"] as? String ?? ""
                coverURL = json["img"] as? String ?? ""
                if let jsonId = json["id"] as? String, trackId.isEmpty {
                    trackId = jsonId
                }
            }
        }

        if let titleMatch = itemHtml.firstCapture(pattern: #"<div class="track__title"[^>]*>\s*([\s\S]*?)\s*</div>"#) {
            let cleaned = titleMatch.trimmingCharacters(in: .whitespacesAndNewlines)
            if !cleaned.isEmpty { title = cleaned }
        }

        if let artistMatch = itemHtml.firstCapture(pattern: #"<div class="track__desc"[^>]*>([\s\S]*?)</div>"#) {
            let cleaned = artistMatch.trimmingCharacters(in: .whitespacesAndNewlines)
            if !cleaned.isEmpty { artist = cleaned }
        }

        if let coverMatch = itemHtml.firstCapture(pattern: #"background-image:\s*url\('([^']+)'\)"#) {
            coverURL = coverMatch
        }

        if let fulltime = itemHtml.firstCapture(pattern: #"<div class="track__fulltime">([\d:]+)</div>"#) {
            duration = fulltime
        }

        if let dlHref = itemHtml.firstCapture(pattern: #"<a[^>]*href="(/get/music/[^"]+)"[^>]*class="[^"]*track__download-btn[^"]*""#) {
            downloadURL = "\(endpoint)\(dlHref)"
        }

        if streamURL.isEmpty { return nil }
        if trackId.isEmpty { trackId = streamURL.md5Hash }

        return Track(
            id: trackId,
            title: title.isEmpty ? "Неизвестно" : title,
            artist: artist.isEmpty ? "Неизвестен" : artist,
            duration: duration,
            coverURL: coverURL,
            streamURL: streamURL,
            downloadURL: downloadURL.isEmpty ? streamURL : downloadURL
        )
    }

    private func parseTrackFromMeta(_ metaStr: String) -> Track? {
        guard let jsonData = metaStr.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else { return nil }

        let artist = json["artist"] as? String ?? ""
        let title = json["title"] as? String ?? ""
        let url = json["url"] as? String ?? ""
        let img = json["img"] as? String ?? ""
        let id = json["id"] as? String ?? url.md5Hash

        if url.isEmpty { return nil }

        return Track(
            id: id,
            title: title.isEmpty ? "Неизвестно" : title,
            artist: artist.isEmpty ? "Неизвестен" : artist,
            duration: "0:00",
            coverURL: img,
            streamURL: url,
            downloadURL: url
        )
    }
}

extension String {
    var urlEncoded: String {
        addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? self
    }

    var htmlEntityDecoded: String {
        var result = self
        let entities: [String: String] = [
            "&amp;": "&", "&quot;": "\"", "&apos;": "'",
            "&lt;": "<", "&gt;": ">", "&#039;": "'",
            "&nbsp;": " "
        ]
        for (entity, char) in entities {
            result = result.replacingOccurrences(of: entity, with: char)
        }
        return result
    }

    func firstCapture(pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]),
              let match = regex.firstMatch(in: self, range: NSRange(self.startIndex..., in: self)),
              match.numberOfRanges > 1,
              let range = Range(match.range(at: 1), in: self) else { return nil }
        return String(self[range])
    }

    var md5Hash: String {
        var hash: UInt64 = 5381
        for char in unicodeScalars {
            hash = ((hash << 5) &+ hash) &+ UInt64(char.value)
        }
        return String(hash, radix: 16)
    }
}
