import SwiftUI

struct MarkdownImagePreview: View {
    let image: NSImage
    let imageLabel: String

    @Environment(\.dismiss) private var dismiss
    @State private var viewportSize: CGSize = .zero
    @State private var explicitScale: CGFloat?

    private let zoomStep: CGFloat = 1.25
    private let maximumScale: CGFloat = 8

    private var fitScale: CGFloat {
        min(1, viewportSize.width / image.size.width, viewportSize.height / image.size.height)
    }

    private var scale: CGFloat { explicitScale ?? fitScale }
    private var minimumScale: CGFloat { min(0.125, fitScale / 4) }

    var body: some View {
        VStack {
            ScrollView([.horizontal, .vertical]) {
                if viewportSize.width > 0, viewportSize.height > 0 {
                    Image(nsImage: image)
                        .resizable()
                        .frame(width: image.size.width * scale, height: image.size.height * scale)
                        .accessibilityLabel(imageLabel)
                }
            }
            .defaultScrollAnchor(.center, for: .alignment)
            .scrollBounceBehavior(.basedOnSize)
            .onGeometryChange(for: CGSize.self, of: \.size) { viewportSize = $0 }
            .accessibilityIdentifier("image-preview-scroll-view")

            Divider()

            HStack {
                Button("Fit to Window") { explicitScale = nil }
                Button("Actual Size") { explicitScale = 1 }
                Button("Zoom Out") { explicitScale = max(minimumScale, scale / zoomStep) }
                    .disabled(scale <= minimumScale)
                Button("Zoom In") { explicitScale = min(maximumScale, scale * zoomStep) }
                    .disabled(scale >= maximumScale)
                Spacer()
                Button("Close") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
        }
        .padding()
        .frame(width: 620, height: 460)
    }
}
