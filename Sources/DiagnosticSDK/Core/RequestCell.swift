//
//  RequestCell.swift
//  DiagnosticSDK
//
//  Created by wiame on 17/4/2026.
//

import UIKit

final class RequestCell: UITableViewCell {

    static let id = "RequestCell"

    // MARK: - UI
    private let methodBadge = UILabel()
    private let statusBadge = UILabel()
    private let urlLabel    = UILabel()
    private let metaLabel   = UILabel()

    // MARK: - Init
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setup()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        // Method badge
        methodBadge.font = .monospacedSystemFont(ofSize: 11, weight: .bold)
        methodBadge.textAlignment = .center
        methodBadge.layer.cornerRadius = 4
        methodBadge.clipsToBounds = true
        methodBadge.setContentHuggingPriority(.required, for: .horizontal)

        // Status badge
        statusBadge.font = .monospacedSystemFont(ofSize: 11, weight: .semibold)
        statusBadge.textAlignment = .center
        statusBadge.layer.cornerRadius = 4
        statusBadge.clipsToBounds = true
        statusBadge.setContentHuggingPriority(.required, for: .horizontal)

        // URL
        urlLabel.font = .systemFont(ofSize: 13, weight: .medium)
        urlLabel.numberOfLines = 2
        urlLabel.lineBreakMode = .byTruncatingMiddle

        // Meta (latency, size)
        metaLabel.font = .systemFont(ofSize: 11)
        metaLabel.textColor = .secondaryLabel

        let topRow = UIStackView(arrangedSubviews: [methodBadge, statusBadge, urlLabel])
        topRow.spacing = 6
        topRow.alignment = .center

        let stack = UIStackView(arrangedSubviews: [topRow, metaLabel])
        stack.axis = .vertical
        stack.spacing = 4

        contentView.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10)
        ])
    }

    // MARK: - Configure
    func configure(with event: NetworkEvent) {
        // Method badge
        let method = event.request.method
        methodBadge.text = " \(method) "
        methodBadge.backgroundColor = methodColor(method).withAlphaComponent(0.15)
        methodBadge.textColor = methodColor(method)

        // Status badge
        let code = event.response?.statusCode ?? 0
        let codeText = code > 0 ? "\(code)" : "ERR"
        statusBadge.text = " \(codeText) "
        statusBadge.backgroundColor = statusColor(code).withAlphaComponent(0.15)
        statusBadge.textColor = statusColor(code)

        // URL — show only path + host to keep it readable
        urlLabel.text = event.request.url

        // Meta
        let size = event.response?.bodySizeBytes ?? 0
        let sizeStr = ByteCountFormatter.string(
            fromByteCount: Int64(size), countStyle: .file
        )
        let date = event.timestamp
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        metaLabel.text = "\(formatter.string(from: date))  ·  \(sizeStr)"
    }

    // MARK: - Helpers
    private func methodColor(_ method: String) -> UIColor {
        switch method.uppercased() {
        case "GET":    return .systemBlue
        case "POST":   return .systemGreen
        case "PUT":    return .systemOrange
        case "DELETE": return .systemRed
        case "PATCH":  return .systemPurple
        default:       return .systemGray
        }
    }

    private func statusColor(_ code: Int) -> UIColor {
        switch code {
        case 200..<300: return .systemGreen
        case 300..<400: return .systemOrange
        case 400..<500: return .systemRed
        case 500..<600: return .systemPurple
        default:        return .systemGray
        }
    }
}
