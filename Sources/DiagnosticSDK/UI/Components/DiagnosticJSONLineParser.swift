import Foundation

struct DiagnosticJSONKeyValueLine {
    let quotedKey: String
    let value: String

    var displayedValue: String {
        guard let firstCharacter = value.first, !firstCharacter.isWhitespace else { return value }
        return " " + value
    }
}

enum DiagnosticJSONLine {
    case keyValue(DiagnosticJSONKeyValueLine)
    case structural
    case value
}

enum DiagnosticJSONLineParser {
    private static let structuralTokens: Set<String> = ["{", "}", "[", "]", "},", "],", "}]", "[{"]

    static func classify(_ line: String) -> DiagnosticJSONLine {
        if let keyValueLine = parseKeyValueLine(line) {
            return .keyValue(keyValueLine)
        }
        return isStructuralLine(line) ? .structural : .value
    }

    static func leadingSpaceCount(of line: String) -> Int {
        line.prefix(while: { $0 == " " }).count
    }

    static func hasOversizedValue(_ line: String, limit: Int) -> Bool {
        switch classify(line) {
        case .keyValue(let keyValueLine):
            return keyValueLine.value.count > limit
        case .structural:
            return false
        case .value:
            return line.count > limit
        }
    }

    private static func isStructuralLine(_ line: String) -> Bool {
        structuralTokens.contains(line.trimmingCharacters(in: .whitespaces))
    }

    private static func parseKeyValueLine(_ line: String) -> DiagnosticJSONKeyValueLine? {
        var index = line.startIndex
        while index < line.endIndex, line[index] == " " || line[index] == "\t" {
            index = line.index(after: index)
        }
        guard index < line.endIndex, line[index] == "\"" else { return nil }
        index = line.index(after: index)
        let keyStartIndex = index
        while index < line.endIndex {
            if line[index] == "\\" {
                index = line.index(after: index)
                if index < line.endIndex { index = line.index(after: index) }
                continue
            }
            if line[index] == "\"" { break }
            index = line.index(after: index)
        }
        guard index < line.endIndex else { return nil }
        let key = line[keyStartIndex..<index]
        index = line.index(after: index)
        while index < line.endIndex, line[index].isWhitespace {
            index = line.index(after: index)
        }
        guard index < line.endIndex, line[index] == ":" else { return nil }
        index = line.index(after: index)
        return DiagnosticJSONKeyValueLine(quotedKey: "\"\(key)\"", value: String(line[index...]))
    }
}
