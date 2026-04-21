import Foundation

enum DiagnosticTraceSource: String, Sendable {
    case session
    case imported
}

struct DiagnosticTraceFileInfo: Identifiable, Equatable {
    let id: String
    let url: URL
    let fileName: String
    let recordingDate: Date
    let byteCount: Int64
    let source: DiagnosticTraceSource
    
    var formattedByteCount: String {
        ByteCountFormatter.string(fromByteCount: byteCount, countStyle: .file)
    }
}

enum SessionHistoryFileService {
    
    private static let traceNamePrefix = "DiagnosticTrace_"
    private static let traceNameSuffix = ".json"
    private static let importMarker = "_IMP_"
    
    private static func documentsDirectoryURL() throws -> URL {
        guard let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw CocoaError(.fileNoSuchFile)
        }
        return url
    }
    
    /// Reads directory contents and file metadata. Intended for background queues.
    static func listTraceFiles() throws -> [DiagnosticTraceFileInfo] {
        let directory = try documentsDirectoryURL()
        let urls = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [
                .fileSizeKey,
                .contentModificationDateKey,
                .creationDateKey,
                .isRegularFileKey
            ],
            options: [.skipsHiddenFiles]
        )
        
        let infos: [DiagnosticTraceFileInfo] = try urls.compactMap { url in
            let name = url.lastPathComponent
            guard name.hasPrefix(traceNamePrefix),
                  name.lowercased().hasSuffix(traceNameSuffix) else { return nil }
            
            let values = try url.resourceValues(forKeys: [
                .fileSizeKey,
                .contentModificationDateKey,
                .creationDateKey,
                .isRegularFileKey
            ])
            guard values.isRegularFile == true else { return nil }
            
            let size = Int64(values.fileSize ?? 0)
            let recorded = values.creationDate
                ?? values.contentModificationDate
                ?? Date.distantPast
            let source: DiagnosticTraceSource = name.contains(importMarker) ? .imported : .session
            
            return DiagnosticTraceFileInfo(
                id: url.path,
                url: url,
                fileName: name,
                recordingDate: recorded,
                byteCount: size,
                source: source
            )
        }
        
        return infos.sorted { $0.recordingDate > $1.recordingDate }
    }
    
    struct DeletionReport: Sendable {
        let deleted: Bool
        let deletedPath: String?
        let debugMessage: String
    }
    
    /// Intended for background queues.
    static func deleteFile(at url: URL) throws -> DeletionReport {
        let fm = FileManager.default
        let candidate = url.standardizedFileURL
        let candidatePath = candidate.path
        if fm.fileExists(atPath: candidatePath) {
            try fm.removeItem(at: candidate)
            let deleted = !fm.fileExists(atPath: candidatePath)
            return DeletionReport(
                deleted: deleted,
                deletedPath: candidatePath,
                debugMessage: "Direct delete path: \(candidatePath)"
            )
        }
        
        // Fallback: re-resolve by filename inside Documents in case URL became stale.
        let docs = try documentsDirectoryURL()
        let fallback = docs.appendingPathComponent(candidate.lastPathComponent).standardizedFileURL
        let fallbackPath = fallback.path
        guard fm.fileExists(atPath: fallbackPath) else {
            return DeletionReport(
                deleted: false,
                deletedPath: nil,
                debugMessage: "File not found at candidate or fallback. candidate=\(candidatePath), fallback=\(fallbackPath)"
            )
        }
        
        try fm.removeItem(at: fallback)
        let deleted = !fm.fileExists(atPath: fallbackPath)
        return DeletionReport(
            deleted: deleted,
            deletedPath: fallbackPath,
            debugMessage: "Fallback delete path: \(fallbackPath)"
        )
    }
    
    /// Copies an imported JSON into Documents with a new `DiagnosticTrace_` name. Caller must manage security-scoped access to `sourceURL` when required.
    static func copyImportedJSONToDocuments(from sourceURL: URL) throws -> URL {
        let destDir = try documentsDirectoryURL()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let stamp = formatter.string(from: Date())
        var variant = 0
        var destination = destDir.appendingPathComponent("\(traceNamePrefix)IMP_\(stamp)\(traceNameSuffix)")
        while FileManager.default.fileExists(atPath: destination.path) {
            variant += 1
            destination = destDir.appendingPathComponent("\(traceNamePrefix)IMP_\(stamp)_\(variant)\(traceNameSuffix)")
        }
        try FileManager.default.copyItem(at: sourceURL, to: destination)
        return destination
    }
}
