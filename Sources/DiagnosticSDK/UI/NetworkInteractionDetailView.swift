import SwiftUI
import Foundation
import UIKit
import Combine

struct NetworkInteractionDetailView: View {
    let interactionId: String
    private let store: DiagnosticSessionStore
    
    @State private var interaction: NetworkInteraction?
    @State private var isImagePreviewPresented = false
    
    init(interactionId: String, store: DiagnosticSessionStore = .shared) {
        self.interactionId = interactionId
        self.store = store
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
            if interaction == nil {
                interaction = store.getInteraction(byId: interactionId)
            }
        }
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
            detailsBlock(title: "Headers", value: formattedHeaders(interaction.request.headers))
            detailsBlock(title: "Body", value: prettifiedBodyText(interaction.request.bodyBase64))
        }
    }
    
    private func responseSection(_ interaction: NetworkInteraction) -> some View {
        Section("Response") {
            if let response = interaction.response {
                detailsBlock(title: "Headers", value: formattedHeaders(response.headers))
                detailsBlock(title: "Body", value: prettifiedBodyText(response.bodyBase64))
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
    
    private func detailsBlock(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)
            Text(value)
                .font(.footnote.monospaced())
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(10)
        }
        .padding(.vertical, 4)
    }
    
    private func formattedHeaders(_ headers: [String: String]?) -> String {
        guard let headers, !headers.isEmpty else { return "No headers" }
        
        return headers
            .sorted { lhs, rhs in lhs.key.localizedCaseInsensitiveCompare(rhs.key) == .orderedAscending }
            .map { "\($0.key): \($0.value)" }
            .joined(separator: "\n")
    }
    
    private func prettifiedBodyText(_ rawValue: String?) -> String {
        guard let rawValue, !rawValue.isEmpty else { return "No body" }
        
        let data = Data(base64Encoded: rawValue) ?? rawValue.data(using: .utf8)
        guard let data else { return rawValue }
        
        if let json = try? JSONSerialization.jsonObject(with: data, options: []),
           JSONSerialization.isValidJSONObject(json),
           let prettyData = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted]),
           let prettyString = String(data: prettyData, encoding: .utf8) {
            return prettyString
        }
        
        return String(data: data, encoding: .utf8) ?? rawValue
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
    
    private var task: URLSessionDataTask?
    
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
            }
        }
        task?.resume()
    }
}
