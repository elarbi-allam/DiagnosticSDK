import SwiftUI
import Foundation

struct NetworkInteractionDetailView: View {
    let interactionId: String
    private let store: DiagnosticSessionStore
    
    @State private var interaction: NetworkInteraction?
    
    init(interactionId: String, store: DiagnosticSessionStore = .shared) {
        self.interactionId = interactionId
        self.store = store
    }
    
    var body: some View {
        Form {
            if let interaction {
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
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(multiline ? .body.monospaced() : .body)
                .foregroundColor(.primary)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: multiline)
        }
        .padding(.vertical, 2)
    }
    
    private func detailsBlock(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.footnote.monospaced())
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 2)
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
}
