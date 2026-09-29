import Combine

@MainActor
protocol ReplaySessionStatusProviding: AnyObject {
    var replaySessionRunningPublisher: AnyPublisher<Bool, Never> { get }
}
