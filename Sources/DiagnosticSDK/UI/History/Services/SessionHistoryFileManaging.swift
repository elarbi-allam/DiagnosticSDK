import Foundation

protocol SessionHistoryFileManaging {
    func listTraceFiles() throws -> [DiagnosticTraceFileInfo]
    func deleteTraceFile(at fileURL: URL) throws -> SessionHistoryFileService.DeletionReport
    func copyImportedTrace(from sourceURL: URL) throws -> URL
    func createSafeExportTemporaryFile(from traceFileURL: URL, password: String) throws -> URL
}

struct SessionHistoryFileManager: SessionHistoryFileManaging {
    private let fileService: SessionHistoryFileServicing

    init(fileService: SessionHistoryFileServicing) {
        self.fileService = fileService
    }

    func listTraceFiles() throws -> [DiagnosticTraceFileInfo] {
        try fileService.listTraceFiles()
    }

    func deleteTraceFile(at fileURL: URL) throws -> SessionHistoryFileService.DeletionReport {
        try fileService.deleteFile(at: fileURL)
    }

    func copyImportedTrace(from sourceURL: URL) throws -> URL {
        try fileService.copyImportedJSONToDocuments(from: sourceURL)
    }

    func createSafeExportTemporaryFile(from traceFileURL: URL, password: String) throws -> URL {
        try fileService.createSafeExportTemporaryFile(from: traceFileURL, password: password)
    }
}
