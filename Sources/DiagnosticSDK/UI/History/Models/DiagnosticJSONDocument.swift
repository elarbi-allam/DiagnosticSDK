import Foundation

struct DiagnosticJSONDocument {
    static let previewLineLimit = 14
    static let previewCharacterLimit = 4_000
    static let previewValueLengthLimit = 120

    let prettyJSON: String
    let lines: [String]
    let previewLines: [String]
    let requiresFullScreen: Bool

    init(prettyJSON: String) {
        let lines = prettyJSON.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let requiresFullScreen = lines.count > Self.previewLineLimit
            || prettyJSON.count > Self.previewCharacterLimit
            || lines.contains { DiagnosticJSONLineParser.hasOversizedValue($0, limit: Self.previewValueLengthLimit) }
        self.prettyJSON = prettyJSON
        self.lines = lines
        self.requiresFullScreen = requiresFullScreen
        self.previewLines = requiresFullScreen ? Array(lines.prefix(Self.previewLineLimit)) : lines
    }
}
