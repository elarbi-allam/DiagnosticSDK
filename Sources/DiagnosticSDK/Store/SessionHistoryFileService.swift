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
    
    private static let sessionTraceNamePrefix = "Diagnostic_"
    private static let importedTraceNamePrefix = "IMP-"
    private static let traceNameSuffix = ".json"
    
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
            guard isDiagnosticTraceFileName(name),
                  name.lowercased().hasSuffix(traceNameSuffix) else { return nil }
            
            let values = try url.resourceValues(forKeys: [
                .fileSizeKey,
                .contentModificationDateKey,
                .creationDateKey,
                .isRegularFileKey
            ])
            guard values.isRegularFile == true else { return nil }
            
            let size = Int64(values.fileSize ?? 0)
            let recorded = values.contentModificationDate
                ?? values.creationDate
                ?? Date.distantPast
            let source: DiagnosticTraceSource = name.hasPrefix(importedTraceNamePrefix) ? .imported : .session
            
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
        let fileManager = FileManager.default
        let candidate = url.standardizedFileURL
        let candidatePath = candidate.path
        if fileManager.fileExists(atPath: candidatePath) {
            try fileManager.removeItem(at: candidate)
            let deleted = !fileManager.fileExists(atPath: candidatePath)
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
        guard fileManager.fileExists(atPath: fallbackPath) else {
            return DeletionReport(
                deleted: false,
                deletedPath: nil,
                debugMessage: "File not found at candidate or fallback. candidate=\(candidatePath), fallback=\(fallbackPath)"
            )
        }
        
        try fileManager.removeItem(at: fallback)
        let deleted = !fileManager.fileExists(atPath: fallbackPath)
        return DeletionReport(
            deleted: deleted,
            deletedPath: fallbackPath,
            debugMessage: "Fallback delete path: \(fallbackPath)"
        )
    }
    
    /// Copies an imported JSON into Documents using `IMP-<originalFileName>`.
    static func copyImportedJSONToDocuments(from sourceURL: URL) throws -> URL {
        let destDir = try documentsDirectoryURL()
        let sourceFileName = sourceURL.lastPathComponent
        let destinationFileName = "\(importedTraceNamePrefix)\(sourceFileName)"
        
        let destination = destDir.appendingPathComponent(destinationFileName)
        let fileManager = FileManager.default
        if FileManager.default.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        try fileManager.copyItem(at: sourceURL, to: destination)
        try fileManager.setAttributes([.modificationDate: Date()], ofItemAtPath: destination.path)
        return destination
    }
    
    /// Creates an encrypted shareable trace file in Temporary from a history trace file.
    static func createSafeExportTemporaryFile(from traceFileURL: URL, password: String) throws -> URL {
        let trace = try SessionTraceJSONCodec.decodeFile(at: traceFileURL)
        let plainJSONData = try SessionTraceJSONCodec.encode(trace)
        let wrapper = try TraceEncryptionService.encryptTraceJSON(plainJSONData, password: password)
        
        let wrapperData = try JSONEncoder().encode(wrapper)
        let baseName = traceFileURL.deletingPathExtension().lastPathComponent
        let fileName = "\(baseName)_SAFE.json"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        try wrapperData.write(to: tempURL, options: .atomic)
        return tempURL
    }
    
    private static func isDiagnosticTraceFileName(_ name: String) -> Bool {
        name.hasPrefix(sessionTraceNamePrefix) || name.hasPrefix(importedTraceNamePrefix)
    }
}
