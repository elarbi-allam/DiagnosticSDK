//
//  RequestDetailViewController.swift
//  DiagnosticSDK
//
//  Created by wiame on 17/4/2026.
//

import UIKit

final class RequestDetailViewController: UIViewController {

    private let event: NetworkEvent
    private let textView = UITextView()

    init(event: NetworkEvent) {
        self.event = event
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0.06, green: 0.06, blue: 0.1, alpha: 1)

        title = URL(string: event.request.url)?.path ?? event.request.url

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Copy",
            style: .plain,
            target: self,
            action: #selector(copyToClipboard)
        )

        textView.isEditable = false
        textView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.backgroundColor = .clear
        textView.textColor = UIColor(red: 0.8, green: 0.9, blue: 1.0, alpha: 1)

        view.addSubview(textView)
        textView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            textView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            textView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            textView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        textView.text = buildText()
    }

    private func buildText() -> String {
        var lines: [String] = []

        // ── REQUEST ──────────────────────────────────
        lines.append("━━━ REQUEST ━━━━━━━━━━━━━━━━━━━━━━━━")
        lines.append("\(event.request.method)  \(event.request.url)")
        lines.append("")

        lines.append("Headers:")
        event.request.headers.sorted(by: { $0.key < $1.key }).forEach {
            lines.append("  \($0.key): \($0.value)")
        }

        if let body = event.request.body, !body.isEmpty {
            lines.append("")
            lines.append("Body:")
            lines.append(prettyJSON(body) ?? body)
        }

        // ── RESPONSE ─────────────────────────────────
        lines.append("")
        lines.append("━━━ RESPONSE ━━━━━━━━━━━━━━━━━━━━━━━")

        if let response = event.response {
            let statusEmoji = response.statusCode < 400 ? "✅" : "❌"
            lines.append("\(statusEmoji) \(response.statusCode)")
            lines.append("")

            if let headers = response.headers {
                lines.append("Headers:")
                headers.sorted(by: { $0.key < $1.key }).forEach {
                    lines.append("  \($0.key): \($0.value)")
                }
            }

            lines.append("")
            lines.append("Body (\(response.bodySizeBytes) bytes):")

            if let b64 = response.bodyBase64,
               let data = Data(base64Encoded: b64),
               let str = String(data: data, encoding: .utf8) {
                lines.append(prettyJSON(str) ?? str)
            } else {
                lines.append("[binary data]")
            }

            if let error = response.errorDescription {
                lines.append("")
                lines.append("❌ Error: \(error)")
            }
        } else {
            lines.append("No response captured")
        }

        lines.append("")
        lines.append("━━━ META ━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        let formatter = ISO8601DateFormatter()
        lines.append("Timestamp: \(formatter.string(from: event.timestamp))")

        return lines.joined(separator: "\n")
    }

    private func prettyJSON(_ string: String) -> String? {
        guard let data = string.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data),
              let pretty = try? JSONSerialization.data(
                withJSONObject: obj,
                options: .prettyPrinted
              ),
              let result = String(data: pretty, encoding: .utf8)
        else { return nil }
        return result
    }

    @objc private func copyToClipboard() {
        UIPasteboard.general.string = textView.text
        let alert = UIAlertController(
            title: "Copied",
            message: "Request detail copied to clipboard.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
