import Foundation

public struct LyricLine: Identifiable, Equatable {
    public let id: UUID
    public let time: TimeInterval
    public let text: String
    
    public init(id: UUID = UUID(), time: TimeInterval, text: String) {
        self.id = id
        self.time = time
        self.text = text
    }
}

public struct LyricsData: Equatable {
    public var lines: [LyricLine]
    public var isSynced: Bool
    public var plainText: String
    
    public init(lines: [LyricLine] = [], isSynced: Bool = false, plainText: String = "") {
        self.lines = lines
        self.isSynced = isSynced
        self.plainText = plainText
    }
    
    public func activeIndex(for position: TimeInterval) -> Int? {
        guard !lines.isEmpty else { return nil }
        // Find the last line whose timestamp is <= position
        for i in stride(from: lines.count - 1, through: 0, by: -1) {
            if position >= lines[i].time {
                return i
            }
        }
        return nil
    }
    
    public static func parseLRC(_ lrcString: String) -> LyricsData {
        var parsedLines: [LyricLine] = []
        let rawLines = lrcString.components(separatedBy: .newlines)
        
        // Regex pattern for [mm:ss.xx] or [mm:ss.xxx] or [mm:ss]
        let pattern = "\\[(\\d{2}):(\\d{2})(?:\\.(\\d{1,3}))?\\]"
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return LyricsData(plainText: lrcString)
        }
        
        for line in rawLines {
            let nsString = line as NSString
            let matches = regex.matches(in: line, range: NSRange(location: 0, length: nsString.length))
            
            guard !matches.isEmpty else { continue }
            
            // Extract the lyric text after the tags
            let lastMatch = matches.last!
            let lyricStartIndex = lastMatch.range.location + lastMatch.range.length
            var text = ""
            if lyricStartIndex < nsString.length {
                text = nsString.substring(from: lyricStartIndex).trimmingCharacters(in: .whitespaces)
            }
            
            // A line might have multiple tags, e.g. [00:12.00][00:24.00] repeats
            for match in matches {
                let minRange = match.range(at: 1)
                let secRange = match.range(at: 2)
                let minStr = nsString.substring(with: minRange)
                let secStr = nsString.substring(with: secRange)
                
                let minutes = Double(minStr) ?? 0.0
                let seconds = Double(secStr) ?? 0.0
                var fraction = 0.0
                
                if match.numberOfRanges > 3, match.range(at: 3).location != NSNotFound {
                    let fracStr = nsString.substring(with: match.range(at: 3))
                    if fracStr.count == 2 {
                        fraction = (Double(fracStr) ?? 0.0) / 100.0
                    } else if fracStr.count == 3 {
                        fraction = (Double(fracStr) ?? 0.0) / 1000.0
                    } else {
                        fraction = (Double(fracStr) ?? 0.0) / 10.0
                    }
                }
                
                let timestamp = minutes * 60.0 + seconds + fraction
                if !text.isEmpty {
                    parsedLines.append(LyricLine(time: timestamp, text: text))
                }
            }
        }
        
        parsedLines.sort { $0.time < $1.time }
        
        if parsedLines.isEmpty {
            return LyricsData(lines: [], isSynced: false, plainText: lrcString)
        } else {
            return LyricsData(lines: parsedLines, isSynced: true, plainText: lrcString)
        }
    }
    
}
