import Foundation

struct NetworkInteractionStart {
    let id: String
    let startedAt: Date
    let request: URLRequest
    let screenName: String?
    let screenVisitId: Int?
}
