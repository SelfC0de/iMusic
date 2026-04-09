import Foundation

// MARK: – SearchService

final class SearchService {
    static let shared = SearchService()
    private init() {}

    private let ep1 = "https://rus.hitmotop.com"
    private let ep2 = "https://muz.zvukofon.com"
    private let ep3 = "https://ruo.morsmusic.org"
    private let ep4 = "https://box.hitplayer.ru"
    private let ep5 = "https://ru.monfons.com"
    private let pageSize = 48

    private let ua = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"

    // Parallel search from both sources, returns merged deduplicated list
    func searchBoth(query: String, page: Int) async -> [Track] {
        async let r1 = searchSource1(query: query, page: page)
        async let r2 = searchSource2(query: query, page: page)
        async let r3 = searchSource3(query: query, page: page)
        async let r4 = searchSource4(query: query, page: page)
        async let r5 = searchSource5(query: query, page: page)

        let (t1, t2, t3, t4, t5) = await (r1, r2, r3, r4, r5)

        var merged: [Track] = []
        var seen = Set<String>()
        let all = [t1, t2, t3, t4, t5]
        let maxCount = all.map(\.count).max() ?? 0
        for i in 0..<maxCount {
            for src in all {
                if i < src.count {
                    let t = src[i]
                    let key = dedupeKey(t)
                    if !seen.contains(key) { seen.insert(key); merged.append(t) }
                }
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

    func searchSource3(query: String, page: Int) async -> [Track] {
        let urlStr = page == 0
            ? "\(ep3)/search/\(query.urlEncoded)"
            : "\(ep3)/search/\(query.urlEncoded)?page=\(page + 1)"
        guard let html = await fetchHTML(urlStr) else { return [] }
        return parseSource3(html)
    }

    func searchSource4(query: String, page: Int) async -> [Track] {
        // page 0 → no p param, page N → &p=N+1
        let urlStr = page == 0
            ? "\(ep4)/?s=\(query.urlEncoded)"
            : "\(ep4)/?s=\(query.urlEncoded)&p=\(page + 1)"
        guard let html = await fetchHTML(urlStr) else { return [] }
        return parseSource4(html)
    }

        func searchSource5(query: String, page: Int) async -> [Track] {
        let urlStr = "\(ep5)/search/\(query.urlEncoded)"
        guard let html = await fetchHTML(urlStr) else { return [] }
        return parseSource5(html)
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

    // MARK: – Parser Source3 (morsmusic)

    private func parseSource3(_ html: String) -> [Track] {
        var tracks: [Track] = []
        var pos = html.startIndex
        // Find wrapper-tracklist container first
        guard let listStart = html.range(of: "wrapper-tracklist muslist") else { return [] }
        var searchFrom = listStart.lowerBound
        let pattern = #"<div[^>]*class="[^"]*track[^"]*mustoggler[^"]*"[^>]*data-musmeta="([^"]+)"[^>]*>"#
        while let range = html.range(of: pattern, options: .regularExpression, range: searchFrom..<html.endIndex) {
            // Extract the full track block — find next matching track div or end
            let blockStart = range.lowerBound
            let searchEnd = html.endIndex
            // Find closing </div> for track block (we need a reasonably sized chunk)
            let chunkEnd = html.index(blockStart, offsetBy: min(3000, html.distance(from: blockStart, to: searchEnd)))
            let block = String(html[blockStart..<chunkEnd])
            if let t = parseItem3(block) { tracks.append(t) }
            searchFrom = range.upperBound
        }
        return tracks
    }

    private func parseItem3(_ block: String) -> Track? {
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
                artist    = json["artist"] as? String ?? ""
                title     = json["title"]  as? String ?? ""
                let rawUrl = json["url"]   as? String ?? ""
                streamURL = rawUrl.hasPrefix("http") ? rawUrl : rawUrl.isEmpty ? "" : "\(ep3)\(rawUrl)"
                let rawImg = json["img"]   as? String ?? ""
                cover = rawImg.hasPrefix("http") ? rawImg : rawImg.isEmpty ? "" : "\(ep3)\(rawImg)"
                id    = json["id"] as? String ?? ""
            }
        }

        // Title from .media-link.media-name
        if let v = block.firstCapture(pattern: #"<a[^>]*class="[^"]*media-link media-name[^"]*"[^>]*>\s*([\s\S]*?)\s*</a>"#),
           !v.isBlank { title = v.trimmed }

        // Artist — collect all <a> inside .media-link.media-artist
        if let artistBlock = block.firstCapture(pattern: #"<div[^>]*class="media-link media-artist"[^>]*>([\s\S]*?)</div>"#) {
            let pattern2 = #"<a[^>]*>([^<]+)</a>"#
            if let re = try? NSRegularExpression(pattern: pattern2) {
                let matches = re.matches(in: artistBlock, range: NSRange(artistBlock.startIndex..., in: artistBlock))
                let names = matches.compactMap { m -> String? in
                    guard let r = Range(m.range(at: 1), in: artistBlock) else { return nil }
                    return String(artistBlock[r]).trimmed
                }
                if !names.isEmpty { artist = names.joined(separator: ", ") }
            }
        }

        // Cover from background-image style on track-img-box
        if let v = block.firstCapture(pattern: #"background-image:\s*url\('([^']+)'\)"#) {
            cover = v.hasPrefix("http") ? v : "\(ep3)\(v)"
        }

        // Duration
        if let v = block.firstCapture(pattern: #"<div[^>]*class="[^"]*track__fulltime[^"]*">([\d:]+)</div>"#) { duration = v }

        // Download link — /load/... .mp3
        if let dlHref = block.firstCapture(pattern: #"href="(/load/[^"]+\.mp3)""#) {
            let cleaned = dlHref.cleanMp3Suffix
            dlURL = "\(ep3)\(cleaned)"
            if streamURL.isEmpty { streamURL = dlURL }
        }

        guard !streamURL.isEmpty else { return nil }
        if id.isEmpty { id = "s3_\(streamURL.stableHash)" }

        return Track(
            id: id, title: title.emptyFallback, artist: artist.emptyFallback,
            duration: duration, coverURL: cover,
            streamURL: streamURL,
            downloadURL: dlURL.isEmpty ? streamURL : dlURL,
            source: .source3
        )
    }

    // MARK: – Parser Source4 (hitplayer)

    private func parseSource4(_ html: String) -> [Track] {
        var tracks: [Track] = []
        // Find class="result" container
        guard let resultStart = html.range(of: "class=\"result\"") else { return [] }
        let searchFrom = resultStart.lowerBound
        var pos = searchFrom
        // Each track is a <div class="i ___adv-rbtify-element"...>
        let pattern = #"<div[^>]*class="i ___adv-rbtify-element"[^>]*>([\s\S]*?)</div>\s*</div>"#
        while let range = html.range(of: pattern, options: .regularExpression, range: pos..<html.endIndex) {
            let block = String(html[range])
            if let t = parseItem4(block) { tracks.append(t) }
            pos = range.upperBound
            if tracks.count >= 40 { break }
        }
        return tracks
    }

    private func parseItem4(_ block: String) -> Track? {
        var title = ""
        var artist = ""
        var streamURL = ""
        var dlURL = ""
        var duration = "0:00"

        // No stream from data-audio (m3u8) — use download mp3 only

        // Download URL from .dwnld href — must end with .mp3 (strip query params)
        if let v = block.firstCapture(pattern: #"class="dwnld[^"]*"[^>]*href="([^"]+\.mp3(?:[^"]*)?)"#) {
            // Remove query string after .mp3
            let base = v.components(separatedBy: ".mp3").first.map { $0 + ".mp3" } ?? v
            // URL decode to readable, then clean site suffix like _(www.hotplayer.ru)
            let decoded = base.removingPercentEncoding ?? base
            let cleaned = decoded.replacingOccurrences(
                of: #"[ _]\(www\.hotplayer\.ru\)"#,
                with: "",
                options: .regularExpression
            )
            // Re-encode for actual URL usage
            if let encoded = cleaned.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
               let baseURL = base.components(separatedBy: "/downloadm").first {
                // keep original encoded URL but cleaned
                dlURL = base.components(separatedBy: "?").first ?? base
            } else {
                dlURL = base.components(separatedBy: "?").first ?? base
            }
        }

        // title="Слушать Artist - Title" → parse after "Слушать "
        if let fullTitle = block.firstCapture(pattern: #"title="Слушать ([^"]+)""#) {
            // Split on " — " (em dash) or " - " to get artist - title
            let parts: [String]
            if fullTitle.contains(" — ") {
                parts = fullTitle.components(separatedBy: " — ")
            } else {
                parts = fullTitle.components(separatedBy: " - ")
            }
            if parts.count >= 2 {
                artist = parts[0].trimmed
                title  = parts[1...].joined(separator: " - ").trimmed
            } else {
                title = fullTitle.trimmed
            }
        }

        // <span class="tt">Title</span>
        if let v = block.firstCapture(pattern: #"<span class="tt">([^<]+)</span>"#), !v.isBlank {
            title = v.trimmed
        }

        // <span class="a">artists</span> — collect itemprop="byArtist" content values
        if let artistBlock = block.firstCapture(pattern: #"<span class="a">([\s\S]*?)</span>"#) {
            if let re = try? NSRegularExpression(pattern: #"content="([^"]+)""#) {
                let ms = re.matches(in: artistBlock, range: NSRange(artistBlock.startIndex..., in: artistBlock))
                let names = ms.compactMap { m -> String? in
                    guard let r = Range(m.range(at: 1), in: artistBlock) else { return nil }
                    return String(artistBlock[r]).trimmed
                }
                if !names.isEmpty { artist = names.joined(separator: ", ") }
            }
        }

        // Duration
        if let v = block.firstCapture(pattern: #"<span class="dur">([\d:]+)</span>"#) { duration = v }

        guard !dlURL.isEmpty else { return nil }
        let id = "s4_\(dlURL.stableHash)"
        return Track(
            id: id,
            title: title.emptyFallback,
            artist: artist.emptyFallback,
            duration: duration,
            coverURL: "",
            streamURL: dlURL,
            downloadURL: dlURL,
            source: .source4
        )
    }

        // MARK: – Parser Source5 (monfons)

    private func parseSource5(_ html: String) -> [Track] {
        var tracks: [Track] = []
        guard html.contains("top-tracks__list muslist") else { return [] }
        var pos = html.startIndex
        let pattern = #"<div[^>]*class="[^"]*top-tracks__item[^"]*"[^>]*>([\s\S]*?)</div>\s*</div>\s*</div>"#
        while let range = html.range(of: pattern, options: .regularExpression, range: pos..<html.endIndex) {
            let block = String(html[range])
            if let t = parseItem5(block) { tracks.append(t) }
            pos = range.upperBound
            if tracks.count >= 40 { break }
        }
        return tracks
    }

    private func parseItem5(_ block: String) -> Track? {
        var title = ""
        var artist = ""
        var cover = ""
        var dlURL = ""
        var duration = "0:00"

        // Download link: href="/dl/...mp3"
        if let v = block.firstCapture(pattern: #"href="(/dl/[^"]+\.mp3)""#) {
            let cleaned = v.cleanMp3Suffix
            dlURL = "\(ep5)\(cleaned)"
        }
        guard !dlURL.isEmpty else { return nil }

        // Title
        if let v = block.firstCapture(pattern: #"<span[^>]*class="top-tracks__track"[^>]*>([^<]+)</span>"#) {
            title = v.trimmed
        }

        // Artist
        if let v = block.firstCapture(pattern: #"<[^>]*class="top-tracks__artist"[^>]*>([^<]+)</[^>]*>"#) {
            artist = v.trimmed
        }

        // Cover: background-image: url('/covers/...')
        if let v = block.firstCapture(pattern: #"background-image:\s*url\('(/[^']+)'\)"#) {
            cover = "\(ep5)\(v)"
        }

        // Duration
        if let v = block.firstCapture(pattern: #"<div[^>]*class="top-tracks__fulltime"[^>]*>([\d:]+)</div>"#) {
            duration = v
        }

        let id = "s5_\(dlURL.stableHash)"
        return Track(
            id: id,
            title: title.emptyFallback,
            artist: artist.emptyFallback,
            duration: duration,
            coverURL: cover,
            streamURL: dlURL,
            downloadURL: dlURL,
            source: .source5
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
