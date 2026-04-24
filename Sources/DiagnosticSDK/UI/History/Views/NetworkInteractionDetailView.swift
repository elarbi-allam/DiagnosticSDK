import SwiftUI
import Foundation
import UIKit
import Combine

struct NetworkInteractionDetailView: View {
    /// Same thresholds as response body for plain text: request/response headers and bodies.
    private static let plainTextFullViewCharacterThreshold = 900
    private static let plainTextPreviewLineLimit = 10
    
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
            urlOverviewRow(urlString: interaction.request.url)
            detailRow(title: "Method", value: interaction.request.method.uppercased())
            detailRow(title: "Status", value: interaction.response.map { "\($0.status)" } ?? "Pending")
            detailRow(title: "Duration", value: interaction.durationMs.map { "\($0) ms" } ?? "—")
            detailRow(
                title: "Timestamp",
                value: interaction.startedAt.formatted(date: .abbreviated, time: .standard)
            )
        }
    }
    
    private func urlOverviewRow(urlString: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("URL")
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)
            DiagnosticReadableTextBlock(
                text: urlString,
                kind: .url,
                sheetTitle: "URL",
                maxCharactersBeforeFull: 500,
                previewLineLimit: 8
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
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
                if let errorText = response.errorDescription, !errorText.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Error")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.secondary)
                        if let prettyError = DiagnosticJSONFormatting.prettyString(parsing: errorText) {
                            DiagnosticJSONPreviewBlock(prettyJSON: prettyError, sheetTitle: "Error")
                        } else {
                            DiagnosticReadableTextBlock(
                                text: errorText,
                                kind: .plain,
                                sheetTitle: "Error",
                                maxCharactersBeforeFull: Self.plainTextFullViewCharacterThreshold,
                                previewLineLimit: Self.plainTextPreviewLineLimit
                            )
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
                } else {
                    detailRow(title: "Error", value: "None")
                }
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
                if let pretty = prettyJSONObjectString(from: headers) {
                    DiagnosticJSONPreviewBlock(prettyJSON: pretty, sheetTitle: title)
                } else {
                    Text("Unable to display headers")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            } else {
                Text("No headers")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
    
    /// Renders header maps with the same JSON preview component as the body (sorted keys, colors, View full).
    private func prettyJSONObjectString(from object: [String: String]) -> String? {
        guard JSONSerialization.isValidJSONObject(object) else { return nil }
        do {
            let data = try JSONSerialization.data(
                withJSONObject: object,
                options: [.sortedKeys, .prettyPrinted]
            )
            return String(data: data, encoding: .utf8)
        } catch {
            return nil
        }
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
            case .plain(let text):
                if let pretty = DiagnosticJSONFormatting.prettyString(parsing: text) {
                    DiagnosticJSONPreviewBlock(prettyJSON: pretty, sheetTitle: title)
                } else {
                    DiagnosticReadableTextBlock(
                        text: text,
                        kind: .plain,
                        sheetTitle: title,
                        maxCharactersBeforeFull: Self.plainTextFullViewCharacterThreshold,
                        previewLineLimit: Self.plainTextPreviewLineLimit
                    )
                }
            case .json(let pretty):
                DiagnosticJSONPreviewBlock(prettyJSON: pretty, sheetTitle: title)
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

// MARK: - Preview card

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
