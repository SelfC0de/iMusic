import Foundation

// MARK: – SearchService

final class SearchService {
    static let shared = SearchService()
    private init() {}

    private let ep1 = "https://rus.hitmotop.com"
    private let ep2 = "https://muz.zvukofon.com"
    private let pageSize = 48

    private let ua = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"

    // Parallel search from both sources, returns merged deduplicated list
    func searchBoth(query: String, page: Int) async -> [Track] {
        async let r1 = searchSource1(query: query, page: page)
        async let r2 = searchSource2(query: query, page: page)

        let (t1, t2) = await (r1, r2)

        // Interleave results: 1 from source1, 1 from source2, etc.
        var merged: [Track] = []
        var seen = Set<String>()
        let maxCount = max(t1.count, t2.count)
        for i in 0..<maxCount {
            if i < t1.count {
                let t = t1[i]
                let key = dedupeKey(t)
                if !seen.contains(key) { seen.insert(key); merged.append(t) }
            }
            if i < t2.count {
                let t = t2[i]
                let key = dedupeKey(t)
                if !seen.contains(key) { seen.insert(key); merged.append(t) }
            }
        }
        return merged
    }

    // For load-more we know which sources still have pages
    func searchSource1(query: String, page: Int) async -> [Track] {
        let start = page * pageSize
        let urlStr = start == 0
            ? "\(ep1)/search?q=\(query.urlEncoded)"
            : "\(ep1)/search/start/\(start)?q=\(query.urlEncoded)"
        guard let html = await fetchHTML(urlStr) else { return [] }
        return parseSource1(html)
    }

    func searchSource2(query: String, page: Int) async -> [Track] {
        // zvukofon uses /music/{query}?page=N (1-based)
        let urlStr = page == 0
            ? "\(ep2)/music/\(query.urlEncoded)"
            : "\(ep2)/music/\(query.urlEncoded)?page=\(page + 1)"
        guard let html = await fetchHTML(urlStr) else { return [] }
        return parseSource2(html)
    }

    // MARK: – HTTP

    private func fetchHTML(_ urlString: String) async -> String? {
        guard let url = URL(string: urlString) else { return nil }
        var req = URLRequest(url: url, timeoutInterval: 15)
        req.setValue(ua, forHTTPHeaderField: "User-Agent")
        req.setValue("text/html,application/xhtml+xml", forHTTPHeaderField: "Accept")
        req.setValue("ru,en;q=0.9", forHTTPHeaderField: "Accept-Language")
        req.setValue("https://google.com", forHTTPHeaderField: "Referer")
        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else { return nil }
            return String(data: data, encoding: .utf8)
                ?? String(data: data, encoding: .windowsCP1251)
                ?? String(data: data, encoding: .isoLatin1)
        } catch { return nil }
    }

    // MARK: – Parser Source1 (hitmotop)

    private func parseSource1(_ html: String) -> [Track] {
        var tracks: [Track] = []
        var pos = html.startIndex
        let pattern = #"<li[^>]*class="[^"]*tracks__item[^"]*"[^>]*>([\s\S]*?)</li>"#
        while let range = html.range(of: pattern, options: .regularExpression, range: pos..<html.endIndex) {
            let block = String(html[range])
            if let t = parseItem1(block) { tracks.append(t) }
            pos = range.upperBound
        }
        return tracks
    }

    private func parseItem1(_ block: String) -> Track? {
        var id = ""
        var title = ""
        var artist = ""
        var cover = ""
        var streamURL = ""
        var dlURL = ""
        var duration = "0:00"

        // data-musmeta JSON
        if let metaRaw = block.firstCapture(pattern: #"data-musmeta="([^"]+)""#) {
            let meta = metaRaw.htmlEntityDecoded
            if let json = meta.parseJSON {
                artist = json["artist"] as? String ?? ""
                title  = json["title"]  as? String ?? ""
                streamURL = json["url"] as? String ?? ""
                cover  = json["img"]   as? String ?? ""
                id     = json["id"]    as? String ?? ""
            }
        }
        if let idVal = block.firstCapture(pattern: #"data-musid="([^"]+)""#), id.isEmpty { id = idVal }

        if let v = block.firstCapture(pattern: #"<div class="track__title"[^>]*>\s*([\s\S]*?)\s*</div>"#), !v.isBlank { title = v.trimmed }
        if let v = block.firstCapture(pattern: #"<div class="track__desc"[^>]*>([\s\S]*?)</div>"#), !v.isBlank { artist = v.trimmed }
        if let v = block.firstCapture(pattern: #"background-image:\s*url\('([^']+)'\)"#) { cover = v }
        if let v = block.firstCapture(pattern: #"<div class="track__fulltime">([\d:]+)</div>"#) { duration = v }
        if let v = block.firstCapture(pattern: #"href="(/get/music/[^"]+)"[^>]*class="[^"]*track__download"#) {
            dlURL = "\(ep1)\(v)"
        }

        guard !streamURL.isEmpty else { return nil }
        if id.isEmpty { id = "s1_\(streamURL.stableHash)" }
        if !cover.hasPrefix("http") && !cover.isEmpty { cover = "\(ep1)\(cover)" }

        return Track(
            id: id, title: title.emptyFallback, artist: artist.emptyFallback,
            duration: duration, coverURL: cover,
            streamURL: streamURL,
            downloadURL: dlURL.isEmpty ? streamURL : dlURL,
            source: .source1
        )
    }

    // MARK: – Parser Source2 (zvukofon)

    private func parseSource2(_ html: String) -> [Track] {
        var tracks: [Track] = []
        var pos = html.startIndex
        let pattern = #"<li[^>]*class="[^"]*topcharts__item[^"]*"[^>]*>([\s\S]*?)</li>"#
        while let range = html.range(of: pattern, options: .regularExpression, range: pos..<html.endIndex) {
            let block = String(html[range])
            if let t = parseItem2(block) { tracks.append(t) }
            pos = range.upperBound
        }
        return tracks
    }

    private func parseItem2(_ block: String) -> Track? {
        var id = ""
        var title = ""
        var artist = ""
        var cover = ""
        var streamURL = ""
        var dlURL = ""
        var duration = "0:00"

        // data-musmeta JSON
        if let metaRaw = block.firstCapture(pattern: #"data-musmeta="([^"]+)""#) {
            let meta = metaRaw.htmlEntityDecoded
            if let json = meta.parseJSON {
                artist = json["artist"] as? String ?? ""
                title  = json["title"]  as? String ?? ""
                let rawUrl = json["url"] as? String ?? ""
                streamURL = rawUrl.hasPrefix("http") ? rawUrl : "\(ep2)\(rawUrl)"
                let rawImg = json["img"] as? String ?? ""
                cover = rawImg.hasPrefix("http") ? rawImg : "\(ep2)\(rawImg)"
                id = json["id"] as? String ?? ""
            }
        }
        if let idVal = block.firstCapture(pattern: #"data-musid="([^"]+)""#), id.isEmpty { id = idVal }

        // Explicit artist/title spans
        if let v = block.firstCapture(pattern: #"<span class="topcharts__item-title-artist">([\s\S]*?)</span>"#), !v.isBlank { artist = v.trimmed }
        if let v = block.firstCapture(pattern: #"<span class="topcharts__item-title-track">([\s\S]*?)</span>"#), !v.isBlank { title = v.trimmed }

        // Cover from style
        if let v = block.firstCapture(pattern: #"background-image:\s*url\('([^']+)'\)"#) {
            cover = v.hasPrefix("http") ? v : "\(ep2)\(v)"
        }

        // Duration
        if let v = block.firstCapture(pattern: #"<div class="topcharts__item-info-time_total">([\d:]+)</div>"#) { duration = v }

        // Download link - strip site attribution suffix like _(musportal.org) or _(muz.zvukofon.com)
        if let dlHref = block.firstCapture(pattern: #"href="(/dl/[^"]+\.mp3)""#) {
            let cleaned = dlHref.cleanMp3Suffix
            dlURL = "\(ep2)\(cleaned)"
        }

        // Stream URL fallback to download URL
        if streamURL.isEmpty && !dlURL.isEmpty { streamURL = dlURL }
        guard !streamURL.isEmpty else { return nil }
        if id.isEmpty { id = "s2_\(streamURL.stableHash)" }

        return Track(
            id: id, title: title.emptyFallback, artist: artist.emptyFallback,
            duration: duration, coverURL: cover,
            streamURL: streamURL,
            downloadURL: dlURL.isEmpty ? streamURL : dlURL,
            source: .source2
        )
    }

    // MARK: – Dedup key: normalize title+artist

    private func dedupeKey(_ t: Track) -> String {
        let a = t.artist.lowercased().filter { $0.isLetter || $0.isNumber }
        let ti = t.title.lowercased().filter { $0.isLetter || $0.isNumber }
        return "\(a)_\(ti)"
    }
}

// MARK: – String helpers

extension String {
    var urlEncoded: String { addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? self }

    var htmlEntityDecoded: String {
        var r = self
        [("&amp;","&"),("&quot;","\""),("&apos;","'"),("&lt;","<"),("&gt;",">"),("&#039;","'"),("&nbsp;"," ")]
            .forEach { r = r.replacingOccurrences(of: $0.0, with: $0.1) }
        return r
    }

    func firstCapture(pattern: String) -> String? {
        guard let re = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]),
              let m = re.firstMatch(in: self, range: NSRange(startIndex..., in: self)),
              m.numberOfRanges > 1,
              let range = Range(m.range(at: 1), in: self) else { return nil }
        return String(self[range])
    }

    var parseJSON: [String: Any]? {
        guard let d = data(using: .utf8) else { return nil }
        return (try? JSONSerialization.jsonObject(with: d)) as? [String: Any]
    }

    var stableHash: String {
        var h: UInt64 = 5381
        for c in unicodeScalars { h = ((h << 5) &+ h) &+ UInt64(c.value) }
        return String(h, radix: 16)
    }

    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
    var isBlank: Bool { trimmed.isEmpty }
    var emptyFallback: String { isBlank ? "Неизвестно" : trimmed }

    // Remove site attribution like _(musportal.org) or _(muz.zvukofon.com) from mp3 filename
    var cleanMp3Suffix: String {
        // Pattern: _([anything with dots and spaces]).mp3
        if let cleaned = self.firstCapture(pattern: #"^(.*?)(?:_\([^)]+\))?\.mp3$"#) {
            return cleaned + ".mp3"
        }
        return self
    }

    // WindowsCP1251 encoding alias
    static var windowsCP1251: String.Encoding { .init(rawValue: 1251) }
}
