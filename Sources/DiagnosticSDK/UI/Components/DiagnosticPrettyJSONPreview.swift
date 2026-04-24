import Foundation
import SwiftUI
import UIKit

// MARK: - Formatting

enum DiagnosticJSONFormatting {
    static func prettyString(from raw: String) -> String? {
        guard let data = raw.data(using: .utf8) else { return nil }
        return prettyString(from: data)
    }
    
    static func prettyString(from data: Data) -> String? {
        guard let jsonObject = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]),
              JSONSerialization.isValidJSONObject(jsonObject),
              let out = try? JSONSerialization.data(withJSONObject: jsonObject, options: [.prettyPrinted, .sortedKeys]),
              let prettyJSONString = String(data: out, encoding: .utf8) else { return nil }
        return prettyJSONString
    }
    
    /// Try UTF-8 first, then Base64-decoded data (for headers and bodies that ship JSON in Base64).
    static func prettyString(parsing possibleJSON: String) -> String? {
        if let prettyJSONString = prettyString(from: possibleJSON) { return prettyJSONString }
        if let base64Data = Data(base64Encoded: possibleJSON) {
            if let prettyJSONDataString = prettyString(from: base64Data) { return prettyJSONDataString }
            if let inner = String(data: base64Data, encoding: .utf8),
               let prettyJSONFromInnerString = prettyString(from: inner) {
                return prettyJSONFromInnerString
            }
        }
        return nil
    }
}

// MARK: - Line rendering (syntax-friendly)

struct DiagnosticPrettyJSONLinesView: View {
    let prettyJSON: String
    /// When set, only the first N complete lines are rendered (preview).
    var visibleLineCount: Int?
    
    private var lines: [String] {
        prettyJSON.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    }
    
    private var displayedLineStrings: [String] {
        guard let cap = visibleLineCount, lines.count > cap else { return lines }
        return Array(lines.prefix(cap))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(displayedLineStrings.enumerated()), id: \.offset) { _, line in
                jsonLineView(line)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    @ViewBuilder
    private func jsonLineView(_ line: String) -> some View {
        let leadingSpaces = line.prefix(while: { $0 == " " }).count
        let indent = CGFloat(leadingSpaces) * 3.5
        
        if let parsed = parseJSONKeyValueLine(line) {
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text(parsed.keyDisplay)
                    .font(.system(size: 12, design: .monospaced))
                    .fontWeight(.bold)
                    .foregroundColor(Color(red: 0.12, green: 0.38, blue: 0.72))
                Text(":")
                    .font(.system(size: 12, design: .monospaced))
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                Text(parsed.valueDisplayForUI)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.primary)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.leading, indent)
        } else if isJSONStructuralLine(line) {
            Text(line)
                .font(.system(size: 12, design: .monospaced))
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
                .padding(.leading, indent)
                .textSelection(.enabled)
        } else {
            Text(line)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.primary)
                .padding(.leading, indent)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Preview + full screen

struct DiagnosticJSONPreviewBlock: View {
    let prettyJSON: String
    var sheetTitle: String = "JSON"
    
    private let maxPreviewLines = 14
    private let maxPreviewCharacters = 4_000
    
    @State private var isFullScreenPresented = false
    
    private let copyActionTextGutter: CGFloat = 32
    
    private var lineCount: Int {
        prettyJSON.split(separator: "\n", omittingEmptySubsequences: false).count
    }
    
    private var needsFullScreen: Bool {
        lineCount > maxPreviewLines || prettyJSON.count > maxPreviewCharacters
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            DiagnosticPrettyJSONLinesView(
                prettyJSON: prettyJSON,
                visibleLineCount: needsFullScreen ? maxPreviewLines : nil
            )
            .padding(.trailing, copyActionTextGutter)
            
            if needsFullScreen {
                Button {
                    isFullScreenPresented = true
                } label: {
                    HStack(spacing: 6) {
                        Text("View full")
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                    }
                    .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.035))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.secondary.opacity(0.22), lineWidth: 0.5)
        )
        .copyableOverlay(text: prettyJSON, accessibilityLabel: "Copy JSON")
        .sheet(isPresented: $isFullScreenPresented) {
            DiagnosticJSONFullScreenSheet(title: sheetTitle, prettyJSON: prettyJSON, isPresented: $isFullScreenPresented)
        }
    }
}

private struct DiagnosticJSONFullScreenSheet: View {
    let title: String
    let prettyJSON: String
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationView {
            ScrollView {
                DiagnosticPrettyJSONLinesView(prettyJSON: prettyJSON, visibleLineCount: nil)
                    .padding()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color(.systemBackground))
            .copyableOverlay(text: prettyJSON, accessibilityLabel: "Copy JSON")
            .navigationBarTitle(title, displayMode: .inline)
            .navigationBarItems(
                trailing: Button("Done") { isPresented = false }
            )
        }
    }
}

// MARK: - Line parsing (pretty-printed JSON lines)

private struct ParsedJSONKeyLine {
    let keyDisplay: String
    let valueDisplay: String
    
    /// After `:"`, Foundation pretty-JSON includes a space; if not, we insert one in the UI only.
    var valueDisplayForUI: String {
        if valueDisplay.isEmpty { return valueDisplay }
        if valueDisplay.first?.isWhitespace == true { return valueDisplay }
        return " " + valueDisplay
    }
}

private func parseJSONKeyValueLine(_ line: String) -> ParsedJSONKeyLine? {
    var idx = line.startIndex
    while idx < line.endIndex, line[idx] == " " || line[idx] == "\t" {
        idx = line.index(after: idx)
    }
    guard idx < line.endIndex, line[idx] == "\"" else { return nil }
    idx = line.index(after: idx)
    let keyStart = idx
    while idx < line.endIndex {
        if line[idx] == "\\" {
            idx = line.index(after: idx)
            if idx < line.endIndex { idx = line.index(after: idx) }
            continue
        }
        if line[idx] == "\"" { break }
        idx = line.index(after: idx)
    }
    guard idx < line.endIndex else { return nil }
    let keyInner = String(line[keyStart..<idx])
    idx = line.index(after: idx)
    while idx < line.endIndex, line[idx].isWhitespace {
        idx = line.index(after: idx)
    }
    guard idx < line.endIndex, line[idx] == ":" else { return nil }
    idx = line.index(after: idx)
    let valuePart = String(line[idx...])
    return ParsedJSONKeyLine(keyDisplay: "\"\(keyInner)\"", valueDisplay: valuePart)
}

private func isJSONStructuralLine(_ line: String) -> Bool {
    let trimmedLine = line.trimmingCharacters(in: .whitespaces)
    guard !trimmedLine.isEmpty else { return false }
    if trimmedLine.contains("\"") { return false }
    let structuralLines: Set<String> = ["{", "}", "[", "]", "},", "],", "}]", "[{"]
    return structuralLines.contains(trimmedLine)
}
