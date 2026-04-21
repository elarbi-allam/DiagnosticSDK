//
//  JSONFileStore.swift
//  DiagnosticSDK
//
//  Created by Wiame on 15/4/2026.
//

import Foundation

public final class JSONFileStore: NetworkStoreProtocol {

    // MARK: - Properties

    public let fileURL: URL
    private let writeQueue = DispatchQueue(label: "diagnosticsdk.store.write")

    // MARK: - Init

    public init(filename: String = "network_events.json") {
        let docs = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        )[0]

        let folder = docs.appendingPathComponent("DiagnosticSDK", isDirectory: true)

        // Create folder if it doesn't exist
        try? FileManager.default.createDirectory(
            at: folder,
            withIntermediateDirectories: true
        )

        self.fileURL = folder.appendingPathComponent(filename)
    }

    // MARK: - NetworkStoreProtocol

    public func save(event: NetworkEvent) {
        writeQueue.async { [weak self] in
            self?.writeEvent(event)
        }
    }

    // MARK: - Private

    private func writeEvent(_ event: NetworkEvent) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601

        // 1. Load existing events from disk (or start with empty array)
        var events: [NetworkEvent] = loadExistingEvents()

        // 2. Append the new event
        events.append(event)

        // 3. Re-encode the full array
        guard let data = try? encoder.encode(events) else { return }

        // 4. Write back to disk (atomic = safe, no partial writes)
        try? data.write(to: fileURL, options: .atomic)
    }

    private func loadExistingEvents() -> [NetworkEvent] {
        guard
            FileManager.default.fileExists(atPath: fileURL.path),
            let data = try? Data(contentsOf: fileURL)
        else {
            return []
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        return (try? decoder.decode([NetworkEvent].self, from: data)) ?? []
    }
    
    public func readAll() -> [NetworkEvent] {
        writeQueue.sync {   // sync because we need the return value
            loadExistingEvents()
        }
    }
    func clearAll() {
        if FileManager.default.fileExists(atPath: fileURL.path) {
            do {
                try FileManager.default.removeItem(at: fileURL)
            } catch {
                print("Failed to clear file:", error)
            }
        }
    }
}
