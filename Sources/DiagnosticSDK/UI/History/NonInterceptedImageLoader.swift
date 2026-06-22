import Combine
import Foundation
import UIKit

@MainActor
final class NonInterceptedImageLoader: ObservableObject {
    @Published var image: UIImage?
    @Published var errorMessage: String?
    @Published private(set) var isLoading: Bool = false

    private var session: URLSession?
    private var task: URLSessionDataTask?
    private var lastURLString: String?

    deinit {
        task?.cancel()
        session?.invalidateAndCancel()
    }

    func reset() {
        task?.cancel()
        task = nil
        image = nil
        errorMessage = nil
        isLoading = false
        lastURLString = nil
        session?.invalidateAndCancel()
        session = nil
    }

    func loadIfNeeded(from urlString: String) {
        if lastURLString == urlString, image != nil { return }
        if lastURLString == urlString, isLoading { return }
        load(from: urlString)
    }

    func load(from urlString: String) {
        lastURLString = urlString
        errorMessage = nil
        isLoading = true
        image = nil
        task?.cancel()
        task = nil
        session?.invalidateAndCancel()
        session = nil
        guard let url = URL(string: urlString) else {
            errorMessage = "Invalid URL"
            isLoading = false
            return
        }
        let session = URLSession(configuration: Self.makeEphemeralConfigurationExcludingInterception())
        self.session = session
        task = session.dataTask(with: url) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoading = false
                if let error = error {
                    self.errorMessage = error.localizedDescription
                    return
                }
                guard let data = data, !data.isEmpty else {
                    self.errorMessage = "Empty response data."
                    return
                }
                if let final = DiagnosticImageDataDecoder.makeUIImage(from: data) {
                    self.image = final
                    self.errorMessage = nil
                } else {
                    self.errorMessage = "Could not display this format (decode failed)."
                }
            }
        }
        task?.resume()
    }

    private static func makeEphemeralConfigurationExcludingInterception() -> URLSessionConfiguration {
        let config = URLSessionConfiguration.ephemeral
        if let protocolClasses = config.protocolClasses {
            config.protocolClasses = protocolClasses.filter { protocolClass in
                NSStringFromClass(protocolClass) != "DiagnosticURLProtocol"
            }
        } else {
            config.protocolClasses = []
        }
        return config
    }
}
