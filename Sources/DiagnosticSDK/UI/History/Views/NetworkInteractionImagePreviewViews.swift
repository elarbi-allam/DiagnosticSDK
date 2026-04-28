import SwiftUI
import UIKit

struct ImagePreviewToastOverlay: View {
    let image: UIImage?
    let errorMessage: String?
    let urlString: String
    @Binding var isPresented: Bool
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack(alignment: .top) {
            Color.primary.opacity(colorScheme == .dark ? 0.45 : 0.2)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { isPresented = false }
            VStack(alignment: .center, spacing: 0) {
                ImagePreviewToastCard(
                    image: image,
                    errorMessage: errorMessage,
                    urlString: urlString,
                    onClose: { isPresented = false }
                )
                .padding(.horizontal, 16)
                .padding(.top, 8)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

struct ImagePreviewToastCard: View {
    let image: UIImage?
    let errorMessage: String?
    let urlString: String
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .trailing, spacing: 10) {
            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(Color(.secondaryLabel))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
            VStack(alignment: .center, spacing: 10) {
                Group {
                    if let image = image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: 320, maxHeight: 260)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    } else if let error = errorMessage {
                        Text(error)
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.primary)
                            .frame(maxWidth: 280)
                    } else {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: Color(.label)))
                            .frame(height: 120)
                    }
                }
                Text(urlString)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 300)
            }
            .frame(maxWidth: 340)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .shadow(color: Color.black.opacity(0.2), radius: 6, x: 0, y: 2)
    }
}

struct PressablePreviewCard: View {
    let title: String
    let subtitle: String
    let image: UIImage?
    let isLoading: Bool
    let hasError: Bool
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(.tertiarySystemFill))
                    if let image = image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .clipped()
                    } else if isLoading {
                        ProgressView()
                    } else if hasError {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(.orange)
                    } else {
                        Image(systemName: "photo")
                            .foregroundColor(.blue)
                    }
                }
                .frame(width: 78, height: 78)
                .clipped()
                .cornerRadius(10)
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .onTapGesture { action() }
    }
}
