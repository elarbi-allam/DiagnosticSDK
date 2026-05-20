import Foundation

protocol SessionHistoryFileServicing {
    func listTraceFiles() throws -> [DiagnosticTraceFileInfo]
    func deleteFile(at fileURL: URL) throws -> SessionHistoryFileService.DeletionReport
    func copyImportedJSONToDocuments(from sourceURL: URL) throws -> URL
    func createSafeExportTemporaryFile(from traceFileURL: URL, password: String) throws -> URL
}

struct LiveSessionHistoryFileService: SessionHistoryFileServicing {
    func listTraceFiles() throws -> [DiagnosticTraceFileInfo] {
        try SessionHistoryFileService.listTraceFiles()
    }

    func deleteFile(at fileURL: URL) throws -> SessionHistoryFileService.DeletionReport {
        try SessionHistoryFileService.deleteFile(at: fileURL)
    }

    func copyImportedJSONToDocuments(from sourceURL: URL) throws -> URL {
        try SessionHistoryFileService.copyImportedJSONToDocuments(from: sourceURL)
    }

    func createSafeExportTemporaryFile(from traceFileURL: URL, password: String) throws -> URL {
        try SessionHistoryFileService.createSafeExportTemporaryFile(from: traceFileURL, password: password)
    }
}
