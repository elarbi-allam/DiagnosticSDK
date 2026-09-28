import SwiftUI
import Foundation
import UIKit

struct NetworkInteractionDetailView: View {
    /// Same thresholds as response body for plain text: request/response headers and bodies.
    private static let plainTextFullViewCharacterThreshold = 900
    private static let plainTextPreviewLineLimit = 10
    
    private let interactionId: String
    
    @StateObject private var viewModel: NetworkInteractionDetailViewModel
    @State private var isImagePreviewPresented = false
    @StateObject private var imagePreviewLoader = NonInterceptedImageLoader()
    @State private var selectedDecodedToken: DecodedTokenItem?
    
    init(interactionId: String, store: DiagnosticSessionStore = .shared) {
        self.interactionId = interactionId
        _viewModel = StateObject(wrappedValue: NetworkInteractionDetailViewModel(interactionId: interactionId, store: store))
    }
    
    /// Static detail for an archived trace (no live store subscription).
    init(archivedInteraction: NetworkInteraction) {
        self.interactionId = archivedInteraction.id
        _viewModel = StateObject(wrappedValue: NetworkInteractionDetailViewModel(archivedInteraction: archivedInteraction))
    }
    
    var body: some View {
        ZStack {
            Form {
                if let interaction = viewModel.interaction {
                    previewSection(interaction)
                    overviewSection(interaction)
                    timingSection(content: viewModel.content)
                    requestSection(content: viewModel.content)
                    responseSection(interaction, content: viewModel.content)
                } else {
                    Section("Interaction") {
                        Text("Unable to load details for this request.")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationBarTitle("Request Detail", displayMode: .inline)
            .onAppear {
                viewModel.start()
            }
            .onChange(of: interactionId) { _ in
                imagePreviewLoader.reset()
            }
            if isImagePreviewPresented, let live = viewModel.interaction, NetworkImagePreviewEligibility.canPreviewRequestImage(live) {
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
        .presentsDiagnosticFullScreenContent()
        .sheet(item: $selectedDecodedToken) { token in
            DecodedTokenPreviewSheet(token: token)
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
    
    private func timingSection(content: NetworkInteractionDetailContent?) -> some View {
        Section("Timing") {
            if let content {
                if content.timingRows.isEmpty {
                    Text("No timing captured.")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(content.timingRows) { row in
                        detailRow(title: row.title, value: row.value, titleStyle: .overview, valueStyle: .overview)
                    }
                }
            } else {
                contentFormattingRow
            }
        }
    }
    
    private func requestSection(content: NetworkInteractionDetailContent?) -> some View {
        Section("Request") {
            if let content {
                headersBlock(title: "Headers", headers: content.requestHeaders)
                bodyBlock(title: "Body", formattedBody: content.requestBody)
                tokenDecoderBlock(title: "Token Decoder", decodedTokens: content.requestTokens)
            } else {
                contentFormattingRow
            }
        }
    }
    
    private func responseSection(_ interaction: NetworkInteraction, content: NetworkInteractionDetailContent?) -> some View {
        Section("Response") {
            if interaction.response != nil, let content {
                headersBlock(title: "Headers", headers: content.responseHeaders)
                bodyBlock(title: "Body", formattedBody: content.responseBody)
                tokenDecoderBlock(title: "Token Decoder", decodedTokens: content.responseTokens)
                errorBlock(content.responseError)
            } else if interaction.response != nil {
                contentFormattingRow
            } else {
                Text("No response captured yet.")
                    .foregroundColor(.secondary)
            }
        }
    }
    
    @ViewBuilder
    private func errorBlock(_ responseError: FormattedHTTPBody) -> some View {
        switch responseError {
        case .empty:
            detailRow(title: "Error", value: "None", titleStyle: .sectionLabel, valueStyle: .standard)
        case .json(let document):
            errorContainer {
                DiagnosticJSONPreviewBlock(document: document, sheetTitle: "Error")
            }
        case .plain(let errorText):
            errorContainer {
                DiagnosticReadableTextBlock(
                    text: errorText,
                    kind: .plain,
                    sheetTitle: "Error",
                    maxCharactersBeforeFull: Self.plainTextFullViewCharacterThreshold,
                    previewLineLimit: Self.plainTextPreviewLineLimit
                )
            }
        }
    }
    
    private func errorContainer<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Error")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.secondary)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
    }
    
    private var contentFormattingRow: some View {
        HStack(spacing: 10) {
            ProgressView()
            Text("Formatting…")
                .font(.footnote)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
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

    private func tokenDecoderBlock(title: String, decodedTokens: [DecodedTokenItem]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)

            if decodedTokens.isEmpty {
                Text("No decodable JWT token found.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            } else {
                Text("Detected tokens: \(decodedTokens.count)")
                    .font(.footnote)
                    .foregroundColor(.secondary)

                ForEach(decodedTokens) { token in
                    Button {
                        selectedDecodedToken = token
                    } label: {
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(token.source)
                                    .font(.footnote.weight(.semibold))
                                    .foregroundColor(.primary)
                                    .lineLimit(2)
                                Text(token.rawToken)
                                    .font(.caption.monospaced())
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right")
                                .font(.footnote.weight(.semibold))
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private func headersBlock(title: String, headers: FormattedHTTPHeaders) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.secondary)
            
            switch headers {
            case .empty:
                Text("No headers")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            case .json(let document):
                DiagnosticJSONPreviewBlock(document: document, sheetTitle: title)
            case .unavailable:
                Text("Unable to display headers")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func bodyBlock(title: String, formattedBody: FormattedHTTPBody) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.secondary)
            
            switch formattedBody {
            case .empty:
                Text("No body")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            case .json(let document):
                DiagnosticJSONPreviewBlock(document: document, sheetTitle: title)
            case .plain(let text):
                DiagnosticReadableTextBlock(
                    text: text,
                    kind: .plain,
                    sheetTitle: title,
                    maxCharactersBeforeFull: Self.plainTextFullViewCharacterThreshold,
                    previewLineLimit: Self.plainTextPreviewLineLimit
                )
            }
        }
        .padding(.vertical, 4)
    }
}

private struct DecodedTokenPreviewSheet: View {
    let token: DecodedTokenItem
    @Environment(\.presentationMode) private var presentationMode

    var body: some View {
        NavigationView {
            Form {
                Section("Detected Value") {
                    DiagnosticReadableTextBlock(
                        text: token.rawToken,
                        kind: .plain,
                        sheetTitle: "\(token.source) Token",
                        maxCharactersBeforeFull: 280,
                        previewLineLimit: 2
                    )
                }

                Section("Decoded Token") {
                    DiagnosticJSONPreviewBlock(
                        prettyJSON: token.decodedJSON,
                        sheetTitle: "\(token.source) Decoded Token"
                    )
                }
            }
            .navigationBarTitle(token.source, displayMode: .inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .presentsDiagnosticFullScreenContent()
        }
    }
}
