import SwiftUI
import Foundation
import UIKit
import Combine

struct NetworkInteractionDetailView: View {
    private let interactionId: String
    private let store: DiagnosticSessionStore?
    
    @State private var interaction: NetworkInteraction?
    @State private var isImagePreviewPresented = false
    
    init(interactionId: String, store: DiagnosticSessionStore = .shared) {
        self.interactionId = interactionId
        self.store = store
        _interaction = State(initialValue: nil)
    }
    
    /// Static detail for an archived trace (no live store subscription).
    init(archivedInteraction: NetworkInteraction) {
        self.interactionId = archivedInteraction.id
        self.store = nil
        _interaction = State(initialValue: archivedInteraction)
    }
    
    var body: some View {
        Form {
            if let interaction {
                previewSection(interaction)
                overviewSection(interaction)
                requestSection(interaction)
                responseSection(interaction)
            } else {
                Section("Interaction") {
                    Text("Unable to load details for this request.")
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationBarTitle("Request Detail", displayMode: .inline)
        .onAppear {
            if interaction == nil, let store {
                interaction = store.getInteraction(byId: interactionId)
            }
        }
        .overlay(storeUpdateOverlay)
        .sheet(isPresented: $isImagePreviewPresented) {
            if let interaction {
                PreviewSheet(
                    title: "Image Preview",
                    subtitle: interaction.request.url,
                    urlString: interaction.request.url
                )
            }
        }
    }
    
    @ViewBuilder
    private var storeUpdateOverlay: some View {
        if let store {
            Color.clear
                .frame(width: 0, height: 0)
                .accessibilityHidden(true)
                .onReceive(NotificationCenter.default.publisher(for: .diagnosticSessionStoreDidUpdate)) { _ in
                    interaction = store.getInteraction(byId: interactionId)
                }
        }
    }
    
    private func previewSection(_ interaction: NetworkInteraction) -> some View {
        Section("Preview") {
            if canPreviewImage(interaction) {
                PressablePreviewCard(
                    title: "Tap to preview image",
                    subtitle: "Interactive zoom-like effect"
                ) {
                    isImagePreviewPresented = true
                }
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Preview unavailable")
                        .font(.subheadline.weight(.semibold))
                    Text("This request is not an image GET request.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
    }
    
    private func overviewSection(_ interaction: NetworkInteraction) -> some View {
        Section("Overview") {
            detailRow(
                title: "Screen",
                value: interaction.screenName ?? "Background"
            )
            detailRow(title: "URL", value: interaction.request.url, multiline: true)
            detailRow(title: "Method", value: interaction.request.method.uppercased())
            detailRow(title: "Status", value: interaction.response.map { "\($0.status)" } ?? "Pending")
            detailRow(title: "Duration", value: interaction.durationMs.map { "\($0) ms" } ?? "—")
            detailRow(
                title: "Timestamp",
                value: interaction.startedAt.formatted(date: .abbreviated, time: .standard)
            )
        }
    }
    
    private func requestSection(_ interaction: NetworkInteraction) -> some View {
        Section("Request") {
            headersBlock(title: "Headers", headers: interaction.request.headers)
            bodyBlock(title: "Body", rawValue: interaction.request.bodyBase64)
        }
    }
    
    private func responseSection(_ interaction: NetworkInteraction) -> some View {
        Section("Response") {
            if let response = interaction.response {
                headersBlock(title: "Headers", headers: response.headers)
                bodyBlock(title: "Body", rawValue: response.bodyBase64)
                detailRow(
                    title: "Error",
                    value: response.errorDescription ?? "None",
                    multiline: response.errorDescription != nil
                )
            } else {
                Text("No response captured yet.")
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private func detailRow(title: String, value: String, multiline: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)
                .frame(width: 90, alignment: .leading)
            
            Text(value)
                .font(multiline ? .body.monospaced() : .body.weight(.medium))
                .foregroundColor(.primary)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: multiline)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 4)
    }
    
    private func headersBlock(title: String, headers: [String: String]?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)
            
            if let headers, !headers.isEmpty {
                let sortedKeys = headers.keys.sorted {
                    $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
                }
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(sortedKeys, id: \.self) { key in
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text(headerNameLabel(key))
                                .font(.footnote.monospaced().weight(.bold))
                                .foregroundColor(.primary)
                            Text(headers[key] ?? "")
                                .font(.footnote.monospaced())
                                .foregroundColor(.primary)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(10)
            } else {
                Text("No headers")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(10)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func headerNameLabel(_ name: String) -> String {
        name.hasSuffix(":") ? name : "\(name):"
    }
    
    private func bodyBlock(title: String, rawValue: String?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)
            
            switch bodyDisplayMode(rawValue) {
            case .empty:
                Text("No body")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(10)
            case .plain(let text):
                Text(text)
                    .font(.footnote.monospaced())
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(10)
            case .json(let pretty):
                FormattedJSONBodyView(prettyJSON: pretty)
            }
        }
        .padding(.vertical, 4)
    }
    
    private enum BodyDisplayMode {
        case empty
        case plain(String)
        case json(String)
    }
    
    private func bodyDisplayMode(_ rawValue: String?) -> BodyDisplayMode {
        guard let rawValue, !rawValue.isEmpty else { return .empty }
        
        let data = Data(base64Encoded: rawValue) ?? rawValue.data(using: .utf8)
        guard let data else { return .plain(rawValue) }
        
        guard let jsonObject = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) else {
            return .plain(String(data: data, encoding: .utf8) ?? rawValue)
        }
        
        guard JSONSerialization.isValidJSONObject(jsonObject) else {
            return .plain(String(data: data, encoding: .utf8) ?? rawValue)
        }
        
        let options: JSONSerialization.WritingOptions = [.prettyPrinted, .sortedKeys]
        guard let prettyData = try? JSONSerialization.data(withJSONObject: jsonObject, options: options),
              let prettyString = String(data: prettyData, encoding: .utf8) else {
            return .plain(String(data: data, encoding: .utf8) ?? rawValue)
        }
        return .json(prettyString)
    }
    
    private func canPreviewImage(_ interaction: NetworkInteraction) -> Bool {
        guard interaction.request.method.uppercased() == "GET" else { return false }
        guard let url = URL(string: interaction.request.url) else { return false }
        
        let imageExtensions = ["png", "jpg", "jpeg", "gif", "webp", "bmp", "heic", "tiff"]
        if imageExtensions.contains(url.pathExtension.lowercased()) {
            return true
        }
        
        if let responseHeaders = interaction.response?.headers {
            let contentType = responseHeaders.first(where: {
                $0.key.caseInsensitiveCompare("Content-Type") == .orderedSame
            })?.value.lowercased()
            if contentType?.contains("image/") == true {
                return true
            }
        }
        
        return url.absoluteString.contains("image.tmdb.org")
    }
}

// MARK: - Structured JSON body (readable hierarchy + bold keys)

private struct FormattedJSONBodyView: View {
    let prettyJSON: String
    
    private var lines: [String] {
        prettyJSON.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                jsonLineView(line)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(10)
    }
    
    @ViewBuilder
    private func jsonLineView(_ line: String) -> some View {
        let leadingSpaces = line.prefix(while: { $0 == " " }).count
        let indent = CGFloat(leadingSpaces) * 3.5
        
        if let parsed = parseJSONKeyValueLine(line) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(parsed.keyDisplay)
                    .font(.footnote.monospaced())
                    .fontWeight(.bold)
                    .foregroundColor(Color(red: 0.12, green: 0.38, blue: 0.72))
                Text(parsed.valueDisplay)
                    .font(.footnote.monospaced())
                    .foregroundColor(.primary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.leading, indent)
        } else if isJSONStructuralLine(line) {
            Text(line)
                .font(.footnote.monospaced())
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
                .padding(.leading, indent)
                .textSelection(.enabled)
        } else {
            Text(line)
                .font(.footnote.monospaced())
                .foregroundColor(.primary)
                .padding(.leading, indent)
                .textSelection(.enabled)
        }
    }
}

private struct ParsedJSONKeyLine {
    let keyDisplay: String
    let valueDisplay: String
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
    let t = line.trimmingCharacters(in: .whitespaces)
    guard !t.isEmpty else { return false }
    if t.contains("\"") { return false }
    let structuralLines: Set<String> = ["{", "}", "[", "]", "},", "],", "}]", "[{"]
    return structuralLines.contains(t)
}

private struct PressablePreviewCard: View {
    let title: String
    let subtitle: String
    let action: () -> Void
    
    @GestureState private var isPressing = false
    
    var body: some View {
        let longPress = LongPressGesture(minimumDuration: 0.01)
            .updating($isPressing) { currentState, state, _ in
                state = currentState
            }
            .onEnded { _ in
                action()
            }
        
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "photo")
                    .foregroundColor(.blue)
                Text(title)
                    .font(.subheadline.weight(.semibold))
            }
            Text(subtitle)
                .font(.footnote)
                .foregroundColor(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .scaleEffect(isPressing ? 1.03 : 1.0)
        .animation(.spring(response: 0.28, dampingFraction: 0.72), value: isPressing)
        .gesture(longPress)
    }
}

private struct PreviewSheet: View {
    let title: String
    let subtitle: String
    let urlString: String
    
    @Environment(\.presentationMode) private var presentationMode
    @StateObject private var loader = NonInterceptedImageLoader()
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.opacity(0.92).ignoresSafeArea()
                
                VStack(spacing: 12) {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    if let image = loader.image {
                    GeometryReader { proxy in
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(width: proxy.size.width, height: proxy.size.height)
                            .padding()
                    }
                    } else if loader.errorMessage != nil {
                        Text("This request is not an image or could not be loaded.")
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .padding()
                    } else {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    }
                }
            }
            .navigationBarTitle(title, displayMode: .inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
        .onAppear {
            loader.load(from: urlString)
        }
    }
}

@MainActor
private final class NonInterceptedImageLoader: ObservableObject {
    @Published var image: UIImage?
    @Published var errorMessage: String?
    
    private var session: URLSession?
    private var task: URLSessionDataTask?
    
    deinit {
        task?.cancel()
        session?.invalidateAndCancel()
    }
    
    func load(from urlString: String) {
        guard image == nil else { return }
        guard let url = URL(string: urlString) else {
            errorMessage = "Invalid URL"
            return
        }
        
        let config = URLSessionConfiguration.ephemeral
        if let protocolClasses = config.protocolClasses {
            config.protocolClasses = protocolClasses.filter { protocolClass in
                NSStringFromClass(protocolClass) != "DiagnosticURLProtocol"
            }
        } else {
            config.protocolClasses = []
        }
        
        let session = URLSession(configuration: config)
        self.session = session
        task = session.dataTask(with: url) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                if let error = error {
                    self.errorMessage = error.localizedDescription
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse,
                   let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type")?.lowercased(),
                   !contentType.contains("image/") {
                    self.errorMessage = "Not an image response."
                    return
                }
                
                guard let data = data, let image = UIImage(data: data) else {
                    self.errorMessage = "Unable to decode image."
                    return
                }
                
                self.image = image
                self.errorMessage = nil
            }
        }
        task?.resume()
    }
}
