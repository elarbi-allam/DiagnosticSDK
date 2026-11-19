import Foundation

struct SessionReportSummary {
    let sessionId: String
    let startedAtText: String
    let applicationText: String
    let requestCount: Int
    let failedRequestCount: Int
    let screens: [SessionReportScreenHeader]

    init(session: SessionTrace) {
        let metadata = session.metadata
        let deviceName = DeviceModelCatalog.displayName(
            forHardwareIdentifier: metadata.deviceModel,
            isSimulator: metadata.isSimulator ?? false
        )
        let interactions = session.screens.flatMap(\.networkInteractions)
        sessionId = session.sessionId
        startedAtText = SessionReportDateFormatting.dateTimeText(of: session.startedAt)
        applicationText = "App \(metadata.appVersion) · iOS \(metadata.osVersion) · \(deviceName)"
        requestCount = interactions.count
        failedRequestCount = interactions.filter { SessionReportStatus(response: $0.response).isFailure }.count
        screens = session.screens.enumerated().map { index, screen in
            SessionReportScreenHeader(number: index + 1, screen: screen)
        }
    }
}

struct SessionReportScreenHeader {
    let number: Int
    let name: String
    let enteredAtText: String
    let requestCount: Int

    var requestCountText: String {
        SessionReportCountFormatting.text(count: requestCount, noun: "request")
    }

    init(number: Int, screen: ScreenNode) {
        self.number = number
        name = screen.name
        enteredAtText = SessionReportDateFormatting.timeText(of: screen.enteredAt)
        requestCount = screen.networkInteractions.count
    }
}

enum SessionReportStatus {
    case success(Int)
    case redirection(Int)
    case clientError(Int)
    case serverError(Int)
    case transportFailure
    case noResponse

    init(response: ResponseDetails?) {
        guard let response, !response.isInterruptedCapture else {
            self = .noResponse
            return
        }
        switch response.status {
        case 200..<300: self = .success(response.status)
        case 300..<400: self = .redirection(response.status)
        case 400..<500: self = .clientError(response.status)
        case 500...: self = .serverError(response.status)
        default: self = .transportFailure
        }
    }

    var text: String {
        switch self {
        case .success(let code), .redirection(let code), .clientError(let code), .serverError(let code):
            return "\(code)"
        case .transportFailure:
            return "FAILED"
        case .noResponse:
            return "NO RESPONSE"
        }
    }

    var isFailure: Bool {
        switch self {
        case .success, .redirection: return false
        case .clientError, .serverError, .transportFailure, .noResponse: return true
        }
    }
}

enum SessionReportBody {
    case json(String)
    case text(String)
    case placeholder(String)
}

struct SessionReportMessage {
    let headers: [(name: String, value: String)]
    let bodyTitle: String
    let body: SessionReportBody
    let bodyNotice: String?

    init(request: RequestDetails) {
        self.init(
            headers: request.headers,
            contentType: request.contentType,
            bodyData: request.bodyData,
            sizeBytes: request.bodySizeBytes,
            formattedBody: request.formattedBody,
            bodyNotice: request.bodyTruncationNotice
        )
    }

    init(response: ResponseDetails) {
        self.init(
            headers: response.headers,
            contentType: response.contentType,
            bodyData: response.bodyData,
            sizeBytes: response.bodySizeBytes,
            formattedBody: response.formattedBody,
            bodyNotice: response.bodyTruncationNotice
        )
    }

    private init(
        headers: [String: String]?,
        contentType: String?,
        bodyData: Data?,
        sizeBytes: Int,
        formattedBody: FormattedHTTPBody,
        bodyNotice: String?
    ) {
        self.headers = (headers ?? [:])
            .sorted { $0.key.localizedCaseInsensitiveCompare($1.key) == .orderedAscending }
            .map { (name: $0.key, value: $0.value) }
        if sizeBytes > 0 {
            let kind = NetworkContentType.kind(ofContentType: contentType, sniffing: bodyData)
            bodyTitle = "\(kind.displayName) · \(CapturedBodyPresentation.formattedByteCount(sizeBytes))"
        } else {
            bodyTitle = "Empty"
        }
        switch formattedBody {
        case .empty:
            body = .placeholder("No body")
        case .json(let document):
            body = .json(document.prettyJSON)
        case .plain(let text):
            body = .text(text)
        case .notCaptured(let message):
            body = .placeholder(message)
        }
        self.bodyNotice = bodyNotice
    }
}

struct SessionReportEntry {
    let number: Int
    let method: String
    let url: String
    let status: SessionReportStatus
    let durationText: String
    let startedAtText: String
    let request: SessionReportMessage
    let response: SessionReportMessage?
    let errorDescription: String?
    let timingRows: [NetworkTimingRow]

    init(number: Int, interaction: NetworkInteraction) {
        self.number = number
        method = interaction.request.method.uppercased()
        url = interaction.request.url
        status = SessionReportStatus(response: interaction.response)
        durationText = interaction.durationMs.map { "\($0) ms" } ?? "—"
        startedAtText = SessionReportDateFormatting.timeText(of: interaction.startedAt)
        request = SessionReportMessage(request: interaction.request)
        response = interaction.response.flatMap { $0.isInterruptedCapture ? nil : SessionReportMessage(response: $0) }
        errorDescription = interaction.response?.errorDescription
        timingRows = NetworkTimingRowsBuilder.makeRows(for: interaction.timing)
    }
}

enum SessionReportCountFormatting {
    static func text(count: Int, noun: String) -> String {
        "\(count) \(noun)\(count == 1 ? "" : "s")"
    }
}

enum SessionReportDateFormatting {
    private static let dateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter
    }()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()

    static func dateTimeText(of date: Date) -> String {
        dateTimeFormatter.string(from: date)
    }

    static func timeText(of date: Date) -> String {
        timeFormatter.string(from: date)
    }
}
