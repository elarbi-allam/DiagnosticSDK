import SwiftUI
import Foundation
import UIKit

struct NetworkInteractionDetailView: View {
    /// Same thresholds as response body for plain text: request/response headers and bodies.
    private static let plainTextFullViewCharacterThreshold = 900
    private static let plainTextPreviewLineLimit = 10
    
    private let interactionId: String
    private let store: DiagnosticSessionStore?
    
    @State private var interaction: NetworkInteraction?
    @State private var isImagePreviewPresented = false
    @StateObject private var imagePreviewLoader = NonInterceptedImageLoader()
    
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
        ZStack {
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
            .onChange(of: interactionId) { _ in
                imagePreviewLoader.reset()
            }
            .overlay(storeUpdateOverlay)
            if isImagePreviewPresented, let live = interaction, NetworkImagePreviewEligibility.canPreviewRequestImage(live) {
                ImagePreviewToastOverlay(
                    image: imagePreviewLoader.image,
                    errorMessage: imagePreviewLoader.errorMessage,
                    urlString: live.request.url,
                    isPresented: $isImagePreviewPresented
                )
                .transition(AnyTransition.opacity.combined(with: .scale(scale: 0.92, anchor: .top)))
                .zIndex(1000)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.86), value: isImagePreviewPresented)
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
            if NetworkImagePreviewEligibility.canPreviewRequestImage(interaction) {
                PressablePreviewCard(
                    title: "Tap to preview image",
                    subtitle: "Shows a system-style image toast",
                    image: imagePreviewLoader.image,
                    isLoading: imagePreviewLoader.isLoading,
                    hasError: imagePreviewLoader.errorMessage != nil
                ) {
                    imagePreviewLoader.loadIfNeeded(from: interaction.request.url)
                    isImagePreviewPresented = true
                }
                .onAppear {
                    imagePreviewLoader.loadIfNeeded(from: interaction.request.url)
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
                value: interaction.screenName ?? "Background",
                titleStyle: .overview,
                valueStyle: .overview
            )
            urlOverviewRow(urlString: interaction.request.url)
            detailRow(
                title: "Method",
                value: interaction.request.method.uppercased(),
                titleStyle: .overview,
                valueStyle: .overview
            )
            detailRow(
                title: "Status",
                value: interaction.response.map { "\($0.status)" } ?? "Pending",
                titleStyle: .overview,
                valueStyle: .overview
            )
            detailRow(
                title: "Duration",
                value: interaction.durationMs.map { "\($0) ms" } ?? "—",
                titleStyle: .overview,
                valueStyle: .overview
            )
            detailRow(
                title: "Timestamp",
                value: interaction.startedAt.formatted(date: .abbreviated, time: .standard),
                titleStyle: .overview,
                valueStyle: .overview
            )
        }
    }
    
    private func urlOverviewRow(urlString: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("URL")
                .font(.subheadline.weight(.semibold))
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
                            .font(.subheadline.weight(.semibold))
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
                    detailRow(title: "Error", value: "None", titleStyle: .sectionLabel, valueStyle: .standard)
                }
            } else {
                Text("No response captured yet.")
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private enum DetailLabelFontStyle {
        case standard
        case overview
        case sectionLabel
    }
    
    private func detailRow(
        title: String,
        value: String,
        multiline: Bool = false,
        titleStyle: DetailLabelFontStyle = .standard,
        valueStyle: DetailLabelFontStyle = .standard
    ) -> some View {
        let titleFont: Font
        let valueFont: Font
        let titleWidth: CGFloat
        switch (titleStyle, valueStyle) {
        case (.overview, .overview):
            titleFont = .subheadline.weight(.semibold)
            valueFont = multiline ? .callout.monospaced() : .callout.weight(.medium)
            titleWidth = 100
        case (.sectionLabel, .standard):
            titleFont = .subheadline.weight(.semibold)
            valueFont = multiline ? .body.monospaced() : .body.weight(.medium)
            titleWidth = 100
        default:
            titleFont = .caption.weight(.semibold)
            valueFont = multiline ? .body.monospaced() : .body.weight(.medium)
            titleWidth = 90
        }
        return HStack(alignment: .top, spacing: 10) {
            Text(title)
                .font(titleFont)
                .foregroundColor(.secondary)
                .frame(width: titleWidth, alignment: .leading)
            
            Text(value)
                .font(valueFont)
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
                .font(.subheadline.weight(.semibold))
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
                .font(.subheadline.weight(.semibold))
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
    
}
