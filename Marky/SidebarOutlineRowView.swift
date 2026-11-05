import SwiftUI

#if os(macOS)
import AppKit

enum SidebarOutlineRowIcon {
    case file
    case folder
}

struct SidebarOutlineRowConfiguration {
    let title: String
    let icon: SidebarOutlineRowIcon
    let showsFavoriteButton: Bool
    let isFavorite: Bool
}

final class SidebarOutlineRowView: NSTableCellView {
    private let iconView = NSImageView()
    private let titleField = NSTextField(labelWithString: "")
    private let favoriteButton = NSButton()
    private var trackingAreaRef: NSTrackingArea?
    private var canShowFavoriteButton = false
    private var isFavorite = false
    private var onToggleFavorite: (() -> Void)?
    private var isHovered = false {
        didSet {
            updateFavoriteButtonVisibility()
        }
    }

    override var backgroundStyle: NSView.BackgroundStyle {
        didSet {
            let isEmphasized = backgroundStyle == .emphasized
            titleField.textColor = isEmphasized ? .alternateSelectedControlTextColor : .labelColor
            iconView.contentTintColor = isEmphasized ? .alternateSelectedControlTextColor : .secondaryLabelColor
            favoriteButton.contentTintColor = isEmphasized ? .alternateSelectedControlTextColor : .secondaryLabelColor
        }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(
        with configuration: SidebarOutlineRowConfiguration,
        onToggleFavorite: @escaping () -> Void
    ) {
        titleField.stringValue = configuration.title
        iconView.image = configuration.icon == .folder ? Self.folderImage : Self.fileImage
        favoriteButton.image = configuration.isFavorite ? Self.filledFavoriteStarImage : Self.emptyFavoriteStarImage
        canShowFavoriteButton = configuration.showsFavoriteButton
        isFavorite = configuration.isFavorite
        let favoriteActionTitle = configuration.isFavorite ? String(localized: "Remove from Favorites") : String(localized: "Add to Favorites")
        favoriteButton.toolTip = favoriteActionTitle
        favoriteButton.setAccessibilityLabel(favoriteActionTitle)
        self.onToggleFavorite = onToggleFavorite
        refreshHoverState()
        updateFavoriteButtonVisibility()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        refreshHoverState()
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        if let trackingAreaRef {
            removeTrackingArea(trackingAreaRef)
        }

        let trackingAreaRef = NSTrackingArea(
            rect: bounds,
            options: [.activeInKeyWindow, .inVisibleRect, .mouseEnteredAndExited],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingAreaRef)
        self.trackingAreaRef = trackingAreaRef
        refreshHoverState()
    }

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
        super.mouseEntered(with: event)
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
        super.mouseExited(with: event)
    }

    private func setup() {
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.contentTintColor = .secondaryLabelColor
        iconView.imageScaling = .scaleProportionallyUpOrDown

        titleField.translatesAutoresizingMaskIntoConstraints = false
        titleField.lineBreakMode = .byTruncatingMiddle
        titleField.textColor = .labelColor
        titleField.font = .systemFont(ofSize: MarkyTheme.sidebarRowFontSize)
        titleField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        favoriteButton.translatesAutoresizingMaskIntoConstraints = false
        favoriteButton.isBordered = false
        favoriteButton.imagePosition = .imageOnly
        favoriteButton.focusRingType = .none
        favoriteButton.contentTintColor = .secondaryLabelColor
        favoriteButton.target = self
        favoriteButton.action = #selector(toggleFavorite)

        addSubview(iconView)
        addSubview(titleField)
        addSubview(favoriteButton)

        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: MarkyTheme.sidebarFilesOutlineLeadingInset),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: MarkyTheme.sidebarRowIconSize),
            iconView.heightAnchor.constraint(equalToConstant: MarkyTheme.sidebarRowIconSize),

            titleField.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: MarkyTheme.sidebarRowTitleGap),
            titleField.centerYAnchor.constraint(equalTo: centerYAnchor),

            favoriteButton.leadingAnchor.constraint(greaterThanOrEqualTo: titleField.trailingAnchor, constant: MarkyTheme.sidebarRowSpacing),
            favoriteButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -MarkyTheme.sidebarRowTrailingInset),
            favoriteButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            favoriteButton.widthAnchor.constraint(equalToConstant: MarkyTheme.sidebarRowIconSize),
            favoriteButton.heightAnchor.constraint(equalToConstant: MarkyTheme.sidebarRowIconSize)
        ])
    }

    private func refreshHoverState() {
        guard let window else {
            isHovered = false
            return
        }
        isHovered = bounds.contains(convert(window.mouseLocationOutsideOfEventStream, from: nil))
    }

    private func updateFavoriteButtonVisibility() {
        favoriteButton.isHidden = !(canShowFavoriteButton && (isHovered || isFavorite))
    }

    @objc
    private func toggleFavorite() {
        onToggleFavorite?()
    }

    private static let fileImage: NSImage? = {
        let config = NSImage.SymbolConfiguration(pointSize: MarkyTheme.sidebarRowSymbolSize, weight: .regular)
        return NSImage(systemSymbolName: "doc.text", accessibilityDescription: nil)?
            .withSymbolConfiguration(config)
    }()

    private static let folderImage: NSImage? = {
        let config = NSImage.SymbolConfiguration(pointSize: MarkyTheme.sidebarRowSymbolSize, weight: .regular)
        return NSImage(systemSymbolName: "folder", accessibilityDescription: nil)?
            .withSymbolConfiguration(config)
    }()

    private static let emptyFavoriteStarImage: NSImage? = {
        let config = NSImage.SymbolConfiguration(pointSize: MarkyTheme.sidebarRowSymbolSize, weight: .regular)
        return NSImage(systemSymbolName: "star", accessibilityDescription: nil)?
            .withSymbolConfiguration(config)
    }()

    private static let filledFavoriteStarImage: NSImage? = {
        guard let sourceImage = NSImage(named: "FavoriteStar") else { return nil }

        let canvasSize = NSSize(
            width: MarkyTheme.favoriteStarIconSize,
            height: MarkyTheme.favoriteStarIconSize
        )
        let scaledSize = NSSize(
            width: canvasSize.width * MarkyTheme.favoriteFilledStarContentScale,
            height: canvasSize.height * MarkyTheme.favoriteFilledStarContentScale
        )
        let image = NSImage(size: canvasSize)
        image.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        sourceImage.draw(
            in: NSRect(
                x: (canvasSize.width - scaledSize.width) / 2,
                y: (canvasSize.height - scaledSize.height) / 2,
                width: scaledSize.width,
                height: scaledSize.height
            ),
            from: NSRect(origin: .zero, size: sourceImage.size),
            operation: .sourceOver,
            fraction: 1
        )
        image.unlockFocus()
        return image
    }()
}
#endif
