import Foundation

public enum ResponseAvailability: Sendable, Equatable {
    case received
    case awaiting
    case neverReceived
}

enum TraceCaptureSource {
    case liveSession
    case archivedTrace
}

extension ResponseAvailability {

    init(response: ResponseDetails?, captureSource: TraceCaptureSource) {
        switch (response, captureSource) {
        case let (response?, _) where response.isInterruptedCapture:
            self = .neverReceived
        case (.some, _):
            self = .received
        case (nil, .liveSession):
            self = .awaiting
        case (nil, .archivedTrace):
            self = .neverReceived
        }
    }
}
