import Foundation

struct SessionReportSummary {
    let sessionId: String
    let startedAtText: String
    let applicationText: String
    let requestCount: Int
    let failedRequestCount: Int
    let screens: [SessionReportScreenHeader]
    let hosts: [(name: String, requestCount: Int)]

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
        hosts = Dictionary(grouping: interactions) { SessionReportURLComponents(url: $0.request.url).host }
            .map { (name: $0.key, requestCount: $0.value.count) }
            .sorted { $0.requestCount == $1.requestCount ? $0.name < $1.name : $0.requestCount > $1.requestCount }
    }
}

struct SessionReportURLComponents {
    let host: String
    let pathAndQuery: String

    init(url: String) {
        guard let components = URLComponents(string: url), let host = components.host else {
            self.host = "Unknown host"
            pathAndQuery = url
            return
        }
        self.host = host
        let path = components.percentEncodedPath.isEmpty ? "/" : components.percentEncodedPath
        pathAndQuery = components.percentEncodedQuery.map { "\(path)?\($0)" } ?? path
    }
}

struct SessionReportScreenHeader {
    let number: Int
    let name: String
    let shortName: String
    let enteredAtText: String
    let requestCount: Int

    var requestCountText: String {
        SessionReportCountFormatting.text(count: requestCount, noun: "request")
    }

    init(number: Int, screen: ScreenNode) {
        self.number = number
        name = screen.name
        shortName = screen.name.split(separator: ".").last.map(String.init) ?? screen.name
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

    var label: String {
        reasonPhrase.map { "\(text) \($0)" } ?? text
    }

    var reasonPhrase: String? {
        switch self {
        case .success(let code), .redirection(let code), .clientError(let code), .serverError(let code):
            return Self.reasonPhrases[code]
        case .transportFailure, .noResponse:
            return nil
        }
    }

    private static let reasonPhrases: [Int: String] = [
        200: "OK", 201: "Created", 202: "Accepted", 204: "No Content", 206: "Partial Content",
        301: "Moved Permanently", 302: "Found", 303: "See Other", 304: "Not Modified", 307: "Temporary Redirect",
        308: "Permanent Redirect", 400: "Bad Request", 401: "Unauthorized", 403: "Forbidden", 404: "Not Found",
        405: "Method Not Allowed", 408: "Request Timeout", 409: "Conflict", 410: "Gone", 413: "Payload Too Large",
        415: "Unsupported Media Type", 422: "Unprocessable Content", 429: "Too Many Requests",
        500: "Internal Server Error", 501: "Not Implemented", 502: "Bad Gateway", 503: "Service Unavailable",
        504: "Gateway Timeout"
    ]

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
    let hasBody: Bool

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
        hasBody = sizeBytes > 0
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
    let host: String
    let pathAndQuery: String
    let status: SessionReportStatus
    let durationMs: Int?
    let durationText: String
    let startedAtText: String
    let request: SessionReportMessage
    let response: SessionReportMessage?
    let errorDescription: String?
    let timingRows: [NetworkTimingRow]
    let curlCommand: String

    init(number: Int, interaction: NetworkInteraction) {
        self.number = number
        method = interaction.request.method.uppercased()
        url = interaction.request.url
        let urlComponents = SessionReportURLComponents(url: interaction.request.url)
        host = urlComponents.host
        pathAndQuery = urlComponents.pathAndQuery
        status = SessionReportStatus(response: interaction.response)
        durationMs = interaction.durationMs
        durationText = interaction.durationMs.map { "\($0) ms" } ?? "—"
        startedAtText = SessionReportDateFormatting.timeText(of: interaction.startedAt)
        request = SessionReportMessage(request: interaction.request)
        switch status {
        case .transportFailure, .noResponse:
            response = nil
        case .success, .redirection, .clientError, .serverError:
            response = interaction.response.map(SessionReportMessage.init(response:))
        }
        errorDescription = interaction.response?.errorDescription
        timingRows = NetworkTimingRowsBuilder.makeRows(for: interaction.timing)
        curlCommand = CurlCommandBuilder.command(for: interaction.request)
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
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMM d, yyyy 'at' HH:mm:ss"
        return formatter
    }()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
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
