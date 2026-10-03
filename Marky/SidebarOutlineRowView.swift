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
    let outlineLevel: Int
    let showsDisclosure: Bool
    let isExpanded: Bool
    let showsFavoriteButton: Bool
    let isFavorite: Bool
}

final class SidebarOutlineRowView: NSTableCellView {
    private let disclosureButton = NSButton()
    private let iconView = NSImageView()
    private let titleField = NSTextField(labelWithString: "")
    private let favoriteButton = NSButton()
    private var leadingConstraint: NSLayoutConstraint?
    private var trackingAreaRef: NSTrackingArea?
    private var canShowFavoriteButton = false
    private var isFavorite = false
    private var onToggleDisclosure: (() -> Void)?
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
            disclosureButton.contentTintColor = isEmphasized ? .alternateSelectedControlTextColor : .secondaryLabelColor
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
        onToggleDisclosure: @escaping () -> Void,
        onToggleFavorite: @escaping () -> Void
    ) {
        titleField.stringValue = configuration.title
        iconView.image = configuration.icon == .folder ? Self.folderImage : Self.fileImage
        disclosureButton.isHidden = !configuration.showsDisclosure
        disclosureButton.image = configuration.isExpanded ? Self.expandedDisclosureImage : Self.collapsedDisclosureImage
        leadingConstraint?.constant = MarkyTheme.sidebarFilesOutlineLeadingInset
            + (CGFloat(configuration.outlineLevel) * MarkyTheme.sidebarFilesOutlineIndentPerLevel)
        favoriteButton.image = configuration.isFavorite ? Self.filledFavoriteStarImage : Self.emptyFavoriteStarImage
        canShowFavoriteButton = configuration.showsFavoriteButton
        isFavorite = configuration.isFavorite
        let favoriteActionTitle = configuration.isFavorite ? "Remove from Favorites" : "Add to Favorites"
        favoriteButton.toolTip = favoriteActionTitle
        favoriteButton.setAccessibilityLabel(favoriteActionTitle)
        self.onToggleDisclosure = onToggleDisclosure
        self.onToggleFavorite = onToggleFavorite
        isHovered = false
        updateFavoriteButtonVisibility()
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
        disclosureButton.translatesAutoresizingMaskIntoConstraints = false
        disclosureButton.isBordered = false
        disclosureButton.imagePosition = .imageOnly
        disclosureButton.focusRingType = .none
        disclosureButton.contentTintColor = .secondaryLabelColor
        disclosureButton.target = self
        disclosureButton.action = #selector(toggleDisclosure)

        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.contentTintColor = .secondaryLabelColor
        iconView.imageScaling = .scaleProportionallyUpOrDown

        titleField.translatesAutoresizingMaskIntoConstraints = false
        titleField.lineBreakMode = .byTruncatingMiddle
        titleField.textColor = .labelColor
        titleField.font = .systemFont(ofSize: 13)
        titleField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        favoriteButton.translatesAutoresizingMaskIntoConstraints = false
        favoriteButton.isBordered = false
        favoriteButton.imagePosition = .imageOnly
        favoriteButton.focusRingType = .none
        favoriteButton.contentTintColor = .secondaryLabelColor
        favoriteButton.target = self
        favoriteButton.action = #selector(toggleFavorite)

        addSubview(disclosureButton)
        addSubview(iconView)
        addSubview(titleField)
        addSubview(favoriteButton)

        leadingConstraint = disclosureButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 0)

        NSLayoutConstraint.activate([
            leadingConstraint!,
            disclosureButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            disclosureButton.widthAnchor.constraint(equalToConstant: MarkyTheme.sidebarFilesOutlineDisclosureWidth),
            disclosureButton.heightAnchor.constraint(equalToConstant: MarkyTheme.sidebarFilesOutlineDisclosureWidth),

            iconView.leadingAnchor.constraint(equalTo: disclosureButton.trailingAnchor, constant: 4),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 14),
            iconView.heightAnchor.constraint(equalToConstant: 14),

            titleField.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 6),
            titleField.centerYAnchor.constraint(equalTo: centerYAnchor),

            favoriteButton.leadingAnchor.constraint(greaterThanOrEqualTo: titleField.trailingAnchor, constant: 8),
            favoriteButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
            favoriteButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            favoriteButton.widthAnchor.constraint(equalToConstant: 14),
            favoriteButton.heightAnchor.constraint(equalToConstant: 14)
        ])
    }

    private func updateFavoriteButtonVisibility() {
        favoriteButton.isHidden = !(canShowFavoriteButton && (isHovered || isFavorite))
    }

    @objc
    private func toggleDisclosure() {
        onToggleDisclosure?()
    }

    @objc
    private func toggleFavorite() {
        onToggleFavorite?()
    }

    private static let fileImage: NSImage? = {
        let config = NSImage.SymbolConfiguration(pointSize: 12, weight: .regular)
        return NSImage(systemSymbolName: "doc.text", accessibilityDescription: nil)?
            .withSymbolConfiguration(config)
    }()

    private static let folderImage: NSImage? = {
        let config = NSImage.SymbolConfiguration(pointSize: 12, weight: .regular)
        return NSImage(systemSymbolName: "folder", accessibilityDescription: nil)?
            .withSymbolConfiguration(config)
    }()

    private static let collapsedDisclosureImage: NSImage? = {
        let config = NSImage.SymbolConfiguration(pointSize: 10, weight: .semibold)
        return NSImage(systemSymbolName: "chevron.right", accessibilityDescription: nil)?
            .withSymbolConfiguration(config)
    }()

    private static let expandedDisclosureImage: NSImage? = {
        let config = NSImage.SymbolConfiguration(pointSize: 10, weight: .semibold)
        return NSImage(systemSymbolName: "chevron.down", accessibilityDescription: nil)?
            .withSymbolConfiguration(config)
    }()

    private static let emptyFavoriteStarImage: NSImage? = {
        let config = NSImage.SymbolConfiguration(pointSize: 12, weight: .regular)
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
